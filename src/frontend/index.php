<?php

require __DIR__ . '/vendor/autoload.php';

use Google\Auth\ApplicationDefaultCredentials;
use GuzzleHttp\Client;
use GuzzleHttp\HandlerStack;

$fontColorSvcEndpoint = getenv('FONT_COLOR_SVC');
$fontSizeSvcEndpoint = getenv('FONT_SIZE_SVC');
$wordSvcEndpoint = getenv('WORD_SVC');

/**
 * Make an HTTP GET request to the given URL, signing the request in the
 * process.
 */
function get($url) {
    // We can use the URL as the audience for now, because the audience should
    // be the root URL of the Cloud Run service we are invoking, which holds
    // true for the time being.
    $middleware = ApplicationDefaultCredentials::getIdTokenMiddleware($url);
    $stack = HandlerStack::create();
    $stack->push($middleware);

    $client = new Client([
        'handler' => $stack,
        'auth' => 'google_auth',
    ]);

    return $client->get($url)->getBody();
}

$wordResponse = get($wordSvcEndpoint);
$colorResponse = get($fontColorSvcEndpoint);
$sizeResponse = get($fontSizeSvcEndpoint);

$word = json_decode($wordResponse);
$color = json_decode($colorResponse);
$size = json_decode($sizeResponse);

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Document</title>
    <style type="text/css">
        html, body {
            height: 100%;
        }

        body {
            display: flex;
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
