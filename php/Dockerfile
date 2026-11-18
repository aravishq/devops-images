# Lean PHP image for CI jobs (tests, code style, composer install).
# Rebuilt weekly so PHP and Debian security updates land without manual work.

ARG PHP_VERSION=8.4

FROM mlocati/php-extension-installer:2.13.2 AS installer

FROM php:${PHP_VERSION}-cli

COPY --from=installer /usr/bin/install-php-extensions /usr/local/bin/

# apt-get upgrade keeps the Debian packages patched, also for PHP versions
# whose official base image is no longer rebuilt (8.1).
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends git unzip \
    && install-php-extensions bcmath gd intl pcntl pdo_mysql pdo_pgsql redis zip @composer \
    && rm -rf /var/lib/apt/lists/*

ENV COMPOSER_ALLOW_SUPERUSER=1
