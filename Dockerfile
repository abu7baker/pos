# syntax=docker/dockerfile:1

FROM php:8.2-cli AS php-builder
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libzip-dev \
        libonig-dev \
        libpq-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        bcmath \
        exif \
        gd \
        mbstring \
        pdo_mysql \
        pdo_pgsql \
        zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader

COPY . .
RUN composer dump-autoload --no-dev --optimize


FROM node:18-alpine AS assets
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY resources resources
COPY public public
COPY webpack.mix.js webpack-rtl.config.js ./
RUN npm run production


FROM php:8.2-apache
WORKDIR /var/www

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libzip-dev \
        libonig-dev \
        libpq-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        bcmath \
        exif \
        gd \
        mbstring \
        pdo_mysql \
        pdo_pgsql \
        zip \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

ENV APACHE_DOCUMENT_ROOT=/var/www/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/000-default.conf \
    /etc/apache2/apache2.conf \
    /etc/apache2/conf-available/*.conf

COPY --from=php-builder /app /var/www
COPY --from=assets /app/public /var/www/public

RUN mkdir -p /var/www/storage/framework/cache \\
    /var/www/storage/framework/sessions \\
    /var/www/storage/framework/views \\
    /var/www/storage/logs \\
    && chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

ENV RUN_MIGRATIONS=false
EXPOSE 80
CMD ["sh", "-c", "if [ \"$RUN_MIGRATIONS\" = \"true\" ]; then php artisan migrate --force && php artisan db:seed --force || true; php artisan config:clear && php artisan config:cache; fi; apache2-foreground"]
