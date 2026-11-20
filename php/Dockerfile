# CI images for PHP projects, rebuilt weekly so PHP, Debian and Node.js updates
# land without manual work.
#
# Targets (always pass --target; without it Docker builds the last one):
#   php       PHP CLI with extensions, composer, curl, git, tar, unzip and xz
#   php-node  the same plus Node.js (current LTS), npm, npx and python3, for
#             jobs that run both, such as a Vite build that calls php artisan

ARG PHP_VERSION=8.4
# "lts" follows the current Node.js LTS line; the weekly rebuild picks up its
# patches and moves to the next LTS when Node.js promotes one.
ARG NODE_VERSION=lts
# Debian release of both base images. Keep them equal: node is copied from the
# Node image into the PHP image and relies on that image's system libraries.
ARG DEBIAN=trixie

FROM mlocati/php-extension-installer:2.13.2 AS installer

FROM node:${NODE_VERSION}-${DEBIAN}-slim AS node

FROM php:${PHP_VERSION}-cli-${DEBIAN} AS php

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

# The node binary, npm (with npx) and the Node headers from the official Node
# image; that image has no yarn or corepack.
#
# Native modules without a prebuilt binary are compiled by node-gyp, which
# needs python3 (added here), gcc, g++ and make (already in the PHP image) and
# the Node headers. node-gyp does not look in /usr/local/include/node: it uses
# its own cache and downloads the headers from nodejs.org when they are not
# there. Linking the headers into that cache for root (the user CI jobs run as)
# makes the compile work offline and without that download. The cache entry is
# only used when its installVersion matches the node-gyp that runs, which the
# npm-bundled node-gyp does; another node-gyp version downloads as usual.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/include/node /usr/local/include/node
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && cache="/root/.cache/node-gyp/$(node -p process.versions.node)" \
    && mkdir -p "$cache/include" \
    && ln -s /usr/local/include/node "$cache/include/node" \
    && node -p "require('/usr/local/lib/node_modules/npm/node_modules/node-gyp/package.json').installVersion" > "$cache/installVersion" \
    && apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*
