FROM php:8.2-apache

ENV APP_ENV=production

RUN a2enmod rewrite

RUN apt-get update && apt-get install -y libsqlite3-dev sqlite3 && docker-php-ext-install pdo pdo_sqlite

COPY . /var/www/html/

RUN mkdir -p /var/www/html/data && chown -R www-data:www-data /var/www/html && chmod -R 777 /var/www/html

EXPOSE 80
