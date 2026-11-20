#!/bin/sh
# Smoke test for a built php image: fails when a tool or extension is missing.
# Usage: php/test.sh <image>
set -eu

image="$1"

docker run --rm "$image" sh -ec '
    php -v
    composer --version
    git --version
    unzip -v | head -n 1
    for ext in bcmath gd intl pcntl pdo_mysql pdo_pgsql redis soap sockets xsl zip; do
        php -r "exit(extension_loaded(\"$ext\") ? 0 : 1);" || { echo "missing extension: $ext"; exit 1; }
    done
    echo "all extensions present"
'
