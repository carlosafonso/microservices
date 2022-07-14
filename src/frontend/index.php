<?php

require __DIR__ . '/vendor/autoload.php';

use Afonso\Gcp\Demos\Microservices\HttpClient;
use Google\Cloud\PubSub\PubSubClient;

$env = getenv('MICROSERVICES_ENV');
if (empty($env)) {
    $env = 'dev';
}

$fontColorSvcEndpoint = getenv('FONT_COLOR_SVC');
$fontSizeSvcEndpoint = getenv('FONT_SIZE_SVC');
$wordSvcEndpoint = getenv('WORD_SVC');

$pubSubEventsTopic = getenv('PUBSUB_EVENTS_TOPIC');
$emitToPubSub = $pubSubEventsTopic !== false && !empty($pubSubEventsTopic);

$httpClient = new HttpClient();

$wordResponse = $httpClient->get($wordSvcEndpoint);
$colorResponse = $httpClient->get($fontColorSvcEndpoint);
$sizeResponse = $httpClient->get($fontSizeSvcEndpoint);

$word = json_decode($wordResponse);
$color = json_decode($colorResponse);
$size = json_decode($sizeResponse);

if ($emitToPubSub) {
    $pubSub = new PubSubClient();
    $topic = $pubSub->topic($pubSubEventsTopic);

    // Publish an event into the Pub/Sub events topic.
    $eventPayload = [
        'word' => $word->word,
        'color' => $color->color,
        'size' => $size->size,
    ];
    $topic->publish(['data' => json_encode($eventPayload)]);
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Document</title>
    <style type="text/css">
        @import url(//fonts.googleapis.com/css2?family=Google+Sans:wght@400;500;700);

        html, body {
            height: 100%;
            font-family: 'Google Sans', Arial, sans-serif;
            margin: 0;
            padding: 0;
        }

        body {
            display: flex;
        }

        span.env {
            position: absolute;
            padding: 1em 2em;
            border-radius: 0 0 10px 0;
            background-color: gray;
            color: white;
        }

        span.env.dev {
            background-color: #185ABC;
        }

        span.env.staging {
            background-color: #EA8600;
        }

        span.env.prod {
            background-color: #B31412;
        }

        span.word {
            display: flex;
            flex-direction: column;
            justify-content: center;
            margin: 0 auto;
            text-align: center;
            color: <?php echo($color->color); ?>;
            font-size: <?php echo($size->size); ?>px;
        }
    </style>
</head>
<body>
    <span class="env <?php echo($env); ?>">You are currently viewing the <strong><?php echo($env); ?></strong> environment.</span>
    <span class="word"><?php echo($word->word); ?></span>
    <script type="text/javascript">
        window.onload = () => {
            // Only reload if query string has the right parameter.
            let params = new URLSearchParams(window.location.search);
            if (params.has('reload')) {
                window.setTimeout(() => {location.reload()}, 200);
            }
        };
    </script>
</body>
</html>
