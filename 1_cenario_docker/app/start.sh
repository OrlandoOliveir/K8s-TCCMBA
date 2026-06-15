#!/bin/sh
set -e
mkdir -p /run/nginx
php-fpm -D
nginx -g 'daemon off;'
