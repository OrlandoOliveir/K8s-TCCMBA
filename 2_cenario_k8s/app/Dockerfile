FROM php:8.0-fpm-alpine

RUN apk add --no-cache nginx \
    && docker-php-ext-install pdo_mysql mysqli

COPY nginx.conf /etc/nginx/http.d/default.conf
COPY start.sh /usr/local/bin/start.sh
COPY index.php /var/www/html/index.php
COPY repositories /var/www/html/repositories

RUN chmod +x /usr/local/bin/start.sh \
    && mkdir -p /run/nginx /var/run/php

EXPOSE 80
CMD ["sh", "/usr/local/bin/start.sh"]
