FROM composer:2.3 AS composer
COPY composer.json composer.lock /app/
RUN composer install

FROM php:7.4.30-cli-alpine3.15
COPY --from=composer /app/vendor/ /app/vendor
COPY src/ /app/src
COPY templates/ /app/templates
COPY app.php /app/app.php
CMD ["php", "/app/app.php"]
