FROM public.ecr.aws/m0i9w4q3/alpine-nginx-php7:2.0.1

# Need extra PHP packages for the AWS PHP SDK
USER root
RUN apk --no-cache add php7-simplexml
USER nobody

# Install Composer dependencies
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY composer.json /var/www/html
RUN cd /var/www/html && composer install --optimize-autoloader --no-interaction --no-progress --prefer-dist

COPY index.php /var/www/html
