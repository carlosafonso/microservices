<?php

function get($url) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    $output = curl_exec($ch);
    curl_close($ch);
    return $output;
}

$wordResponse = get('http://' . getenv('WORD_SVC'));
$colorResponse = get('http://' . getenv('FONT_COLOR_SVC'));
$sizeResponse = get('http://' . getenv('FONT_SIZE_SVC'));

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
