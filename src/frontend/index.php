<?php

require __DIR__ . '/vendor/autoload.php';

use Afonso\Gcp\Demos\Microservices\HttpClient;
use Google\Cloud\PubSub\PubSubClient;
use League\Plates\Engine;
use Monolog\Handler\StreamHandler;
use Monolog\Logger;

$log = new Logger('frontend');
$log->pushHandler(new StreamHandler('php://stdout'));

$templates = new Engine(__DIR__ . '/templates');

$env = getenv('MICROSERVICES_ENV');
if (empty($env)) {
    $env = 'dev';
}

$log->info("Environment is $env");

[$podName, $podIp] = [getenv('MSVC_POD_NAME'), getenv('MSVC_POD_IP')];
$log->info("Retrieved pod name and IP", ['pod_name' => $podName, 'pod_ip' => $podIp]);

$fontColorSvcEndpoint = getenv('FONT_COLOR_SVC');
$fontSizeSvcEndpoint = getenv('FONT_SIZE_SVC');
$wordSvcEndpoint = getenv('WORD_SVC');

$log->info(
    "Service endpoints retrieved",
    [
        'font-color' => $fontColorSvcEndpoint,
        'font-size' => $fontSizeSvcEndpoint,
        'word' => $wordSvcEndpoint,
    ]
);

$pubSubEventsTopic = getenv('PUBSUB_EVENTS_TOPIC');
$emitToPubSub = $pubSubEventsTopic !== false && !empty($pubSubEventsTopic);

$httpClient = new HttpClient(timeout: 1);

$word = $color = $size = null;

try {
    $wordResponse = $httpClient->get($wordSvcEndpoint);
    $word = json_decode($wordResponse)->word;
} catch (\Exception $e) {
    $log->critical('Failed to get word', ['exception' => $e]);
    $word = '(ERROR)';
}

try {
    $colorResponse = $httpClient->get($fontColorSvcEndpoint);
    $color = json_decode($colorResponse)->color;
} catch (\Exception $e) {
    $log->critical('Failed to get font color', ['exception' => $e]);
    $color = 'red';
}

try {
    $sizeResponse = $httpClient->get($fontSizeSvcEndpoint);
    $size = json_decode($sizeResponse)->size;
} catch (\Exception $e) {
    $log->critical('Failed to get font size', ['exception' => $e]);
    $size = 50;
}

$log->info("Invoked all services", ['font-color' => $color, 'font-size' => $size, 'word' => $word]);

if ($emitToPubSub) {
    $pubSub = new PubSubClient();
    $topic = $pubSub->topic($pubSubEventsTopic);

    // Publish an event into the Pub/Sub events topic.
    $eventPayload = [
        'word' => $word,
        'color' => $color,
        'size' => $size,
    ];
    $topic->publish(['data' => json_encode($eventPayload)]);

    $log->info("Sent event to Pub/Sub");
}

echo(
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
