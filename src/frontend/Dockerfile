FROM composer:2.3 AS composer

COPY composer.json composer.lock /app/

# This environment does not have the OpenTelemetry PHP extension (we'll install
# it in the later stage), so tell Composer to ignore it. Otherwise this command
# will fail.
RUN composer install --ignore-platform-req=ext-opentelemetry

FROM php:8.2-alpine

# Install and enable the OpenTelemetry PHP extension for auto-instrumentation.
RUN apk --no-cache add autoconf g++ make && \
    pecl install opentelemetry-beta && \
    docker-php-ext-enable opentelemetry && \
    apk del autoconf g++ make

COPY --from=composer /app/vendor /var/www/html/vendor

COPY src/ /var/www/html/src/
COPY templates/ /var/www/html/templates/
COPY index.php dependencies.php /var/www/html/

ENTRYPOINT ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]
