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
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }

        span.env {
            padding: 1em 2em;
            border-radius: 10px;
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
            line-height: 200px;
            color: <?php echo($color); ?>;
            font-size: <?php echo($size); ?>px;
        }
    </style>
</head>
<body>
    <span class="env <?php echo($env); ?>">You are currently viewing the <strong><?php echo($env); ?></strong> environment.</span>
    <span class="word"><?php echo($word); ?></span>
    <?php if (!empty($podName) && !empty($podIp)): ?>
        <span>This request has been served from pod <strong><?php echo($podName); ?></strong> with IP <strong><?php echo($podIp); ?></strong>.</span>
    <?php endif; ?>
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
