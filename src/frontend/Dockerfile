FROM composer:2.3 AS composer

COPY composer.json composer.lock /app/

RUN composer install

FROM php:8.2-alpine

COPY --from=composer /app/vendor/ /var/www/html/vendor/

COPY src/ /var/www/html/src/
COPY templates/ /var/www/html/templates/
COPY index.php /var/www/html

ENTRYPOINT ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]
