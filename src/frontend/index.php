<?php

$wordResponse = file_get_contents('http://word:80');
$colorResponse = file_get_contents('http://font_color:8080');
$sizeResponse = file_get_contents('http://font_size:8080');

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
            window.setTimeout(() => {location.reload()}, 200);
        };
    </script>
</body>
</html>
