# Lean PHP image for CI jobs (tests, code style, composer install).
# Rebuilt weekly so PHP and Debian security updates land without manual work.
#
# Targets:
#   php       PHP CLI with extensions, composer, git and unzip
#   php-node  the same plus Node.js (current LTS), for jobs that run both, such
#             as a Vite build that calls php artisan

ARG PHP_VERSION=8.4
# "lts" follows the current Node.js LTS line; the weekly rebuild picks up its
# patches and moves to the next LTS when it is released.
ARG NODE_VERSION=lts

FROM mlocati/php-extension-installer:2.13.2 AS installer

FROM node:${NODE_VERSION}-trixie-slim AS node

FROM php:${PHP_VERSION}-cli AS php

COPY --from=installer /usr/bin/install-php-extensions /usr/local/bin/

# apt-get upgrade keeps the Debian packages patched, also for PHP versions
# whose official base image is no longer rebuilt (8.1).
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends git unzip \
    && install-php-extensions bcmath gd intl pcntl pdo_mysql pdo_pgsql redis soap sockets xsl zip @composer \
    && rm -rf /var/lib/apt/lists/*

ENV COMPOSER_ALLOW_SUPERUSER=1

FROM php AS php-node

# Node, npm and npx exactly as the official image installs them. Both images
# are Debian trixie, so the node binary finds the libraries it was built for.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
