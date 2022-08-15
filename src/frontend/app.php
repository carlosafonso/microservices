<?php

require __DIR__ . '/vendor/autoload.php';

// DEPS
$log = new \Monolog\Logger('frontend');
$log->pushHandler(new \Monolog\Handler\StreamHandler('php://stdout'), \Monolog\Logger::DEBUG);

$httpClient = new \Afonso\Gcp\Demos\Microservices\HttpClient();

$templates = new \League\Plates\Engine(__DIR__ . '/templates');

// CONFIG
$port = getenv('PORT') ?: 8080;
$listenTo = sprintf("%s:%s", "0.0.0.0", $port);

$env = getenv('MICROSERVICES_ENV');
if (empty($env)) {
    $env = 'dev';
}

[$podName, $podIp] = [getenv('MSVC_POD_NAME'), getenv('MSVC_POD_IP')];

$fontColorSvcEndpoint = getenv('FONT_COLOR_SVC');
$fontSizeSvcEndpoint = getenv('FONT_SIZE_SVC');
$wordSvcEndpoint = getenv('WORD_SVC');

$pubSubEventsTopic = getenv('PUBSUB_EVENTS_TOPIC');
$emitToPubSub = $pubSubEventsTopic !== false && !empty($pubSubEventsTopic);

// BOOT
$log->info("Environment", [$env]);
$log->info("Pod info", ['pod_name' => $podName, 'pod_ip' => $podIp]);
$log->info(
    "Service endpoints",
    [
        'font-color' => $fontColorSvcEndpoint,
        'font-size' => $fontSizeSvcEndpoint,
        'word' => $wordSvcEndpoint,
    ]
);
$log->info("Emitting to Pub/Sub", [$emitToPubSub]);

$http = new \React\Http\HttpServer(
    function (\Psr\Http\Message\ServerRequestInterface $request) use ($log, $httpClient, $templates, $emitToPubSub, $wordSvcEndpoint, $fontColorSvcEndpoint, $fontSizeSvcEndpoint, $env, $podName, $podIp) {
        try {
            $wordResponse = $httpClient->get($wordSvcEndpoint);
            $colorResponse = $httpClient->get($fontColorSvcEndpoint);
            $sizeResponse = $httpClient->get($fontSizeSvcEndpoint);

            $word = json_decode($wordResponse);
            $color = json_decode($colorResponse);
            $size = json_decode($sizeResponse);

            $log->info("Invoked all services", ['font-color' => $color, 'font-size' => $size, 'word' => $word]);

            if ($emitToPubSub) {
                $pubSub = new \Google\Cloud\PubSub\PubSubClient();
                $topic = $pubSub->topic($pubSubEventsTopic);

                // Publish an event into the Pub/Sub events topic.
                $eventPayload = [
                    'word' => $word->word,
                    'color' => $color->color,
                    'size' => $size->size,
                ];
                $topic->publish(['data' => json_encode($eventPayload)]);

                $log->info("Sent event to Pub/Sub");
            }

            return React\Http\Message\Response::html(
                $templates->render(
                    'index',
                    [
                        'color' => $color,
                        'size' => $size,
                        'word' => $word,
                        'env' => $env,
                        'podName' => $podName,
                        'podIp' => $podIp,
                    ]
                )
            );
        } catch (\Exception $e) {
            $log->error($e->getMessage());
            $log->error($e->getTraceAsString());
            return React\Http\Message\Response::plaintext("An internal error occurred.");
        }
    }
);

$socket = new \React\Socket\SocketServer($listenTo);
$http->listen($socket);

$log->info("Server running at http://" . $listenTo);
