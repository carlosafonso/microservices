FROM public.ecr.aws/dwchiang/nginx-php-fpm:7.3.32-fpm-alpine3.13-nginx-1.20.1 AS composer

# Install Composer and dependencies
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
RUN php composer-setup.php
RUN mv composer.phar /usr/bin/composer
RUN php -r "unlink('composer-setup.php');"

COPY composer.json /var/www/html
RUN cd /var/www/html && composer install --optimize-autoloader --no-interaction --no-progress --prefer-dist

FROM public.ecr.aws/dwchiang/nginx-php-fpm:7.3.32-fpm-alpine3.13-nginx-1.20.1

# Need extra PHP packages for the AWS PHP SDK
RUN apk --no-cache add php7-simplexml

COPY nginx.conf /etc/nginx/conf.d/default.conf

WORKDIR /var/www/html
COPY --from=composer /var/www/html/vendor ./vendor
COPY public ./public
