#!/bin/sh
# Smoke test for a built php-node image: everything php/test.sh checks, plus
# node, npm and npx, and that PHP and Node work in the same container.
# Usage: php/test-node.sh <image>
set -eu

image="$1"

"$(dirname "$0")/test.sh" "$image"

docker run --rm "$image" sh -ec '
    node -v
    npm -v
    npx -v
    node -e "process.exit(0)"
    php -r "exit(0);"
    echo "node and php present"
'
