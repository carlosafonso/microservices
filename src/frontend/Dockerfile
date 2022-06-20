FROM composer:2.3 AS composer

COPY composer.json composer.lock /app/

RUN composer install

FROM public.ecr.aws/m0i9w4q3/alpine-nginx-php7:2.0.1

COPY --from=composer /app/vendor/ /var/www/html/vendor/

COPY index.php /var/www/html
