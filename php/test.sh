#!/bin/sh
# Smoke test for a built php image: fails when a tool or extension is missing
# or does not run. Every check looks at the output, not only the exit code: an
# empty executable exits 0 without doing anything.
# Usage: php/test.sh <image>
set -eu

image="$1"

docker run --rm "$image" sh -ec '
    check() {
        name="$1"; pattern="$2"; shift 2
        out=$("$@" 2>&1) || { echo "FAIL $name: exit $?"; echo "$out"; exit 1; }
        printf "%s\n" "$out" | grep -Eq "$pattern" || { echo "FAIL $name: unexpected output"; echo "$out"; exit 1; }
        echo "ok   $name: $(printf "%s\n" "$out" | head -n 1)"
    }

    check php      "^PHP [0-9]+\.[0-9]+\.[0-9]+" php -v
    check composer "^Composer version [0-9]"     composer --version --no-ansi
    check composer-run "^php +[0-9]+\.[0-9]+"    composer show --platform --no-ansi
    check git      "^git version [0-9]"          git --version
    check unzip    "^UnZip [0-9]"                unzip -v
    check curl     "^curl [0-9]"                 curl --version
    check tar      "^tar \(GNU tar\) [0-9]"      tar --version
    check xz       "^xz \(XZ Utils\) [0-9]"      xz --version
    test -s /etc/ssl/certs/ca-certificates.crt || { echo "FAIL CA certificates missing"; exit 1; }
    echo "ok   CA certificates present"

    for ext in bcmath gd intl pcntl pdo_mysql pdo_pgsql redis soap sockets xsl zip; do
        php -r "exit(extension_loaded(\"$ext\") ? 0 : 1);" || { echo "FAIL extension missing: $ext"; exit 1; }
    done
    echo "ok   all extensions present"
'
