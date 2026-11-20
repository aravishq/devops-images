#!/bin/sh
# Smoke test for a built php-node image: everything php/test.sh checks, plus
# node, npm, npx and python3, and an offline compile of a small native module
# with node-gyp. As in test.sh every check looks at the output: a 0-byte npm
# exits 0 and prints nothing, which must fail.
# Usage: php/test-node.sh <image>
set -eu

image="$1"
here=$(cd "$(dirname "$0")" && pwd)

"$here/test.sh" "$image"

docker run --rm "$image" sh -ec '
    check() {
        name="$1"; pattern="$2"; shift 2
        out=$("$@" 2>&1) || { echo "FAIL $name: exit $?"; echo "$out"; exit 1; }
        printf "%s\n" "$out" | grep -Eq "$pattern" || { echo "FAIL $name: unexpected output"; echo "$out"; exit 1; }
        echo "ok   $name: $(printf "%s\n" "$out" | head -n 1)"
    }

    test -L /usr/local/bin/npm || { echo "FAIL npm is not a symlink"; exit 1; }
    test -L /usr/local/bin/npx || { echo "FAIL npx is not a symlink"; exit 1; }

    check node    "^v[0-9]+\.[0-9]+\.[0-9]+$" node -v
    check npm     "^[0-9]+\.[0-9]+\.[0-9]+$"  npm -v
    check npx     "^[0-9]+\.[0-9]+\.[0-9]+$"  npx -v
    check npm-ls  "npm@[0-9]"                 npm ls -g --depth=0
    check python3 "^Python 3\.[0-9]+"         python3 --version
    check node-run "^2$"                      node -p 1+1
'

# Without network: node-gyp must find the Node headers in its cache instead of
# downloading them, and the compiled module must load.
docker run --rm --network none -v "$here/test-fixtures/native-addon:/src:ro" "$image" sh -ec '
    cp -r /src /tmp/addon && cd /tmp/addon
    node "$(npm root -g)/npm/node_modules/node-gyp/bin/node-gyp.js" rebuild > /tmp/node-gyp.log 2>&1 \
        || { echo "FAIL native module build"; tail -n 20 /tmp/node-gyp.log; exit 1; }
    out=$(node -p "require(\"./build/Release/hello.node\").hello()")
    [ "$out" = 42 ] || { echo "FAIL native module returned \"$out\""; exit 1; }
    echo "ok   native module compiled offline and loaded"
'
