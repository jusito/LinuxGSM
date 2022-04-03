#!/bin/bash

set -euo pipefail

servercode="$1"

(
    cd "$(dirname "$0")"
    rm -rf build || true
    mkdir build
    
    cp -r linuxgsm.sh lgsm build/
    cd build
    touch .dev-debug
    ./linuxgsm.sh "$servercode"
    ./"$servercode" auto-install || (
        mkdir -p "lgsm/config-lgsm/$servercode/"
        echo 'steamuser="username"' > "lgsm/config-lgsm/$servercode/common.cfg"
        echo "steampass='password'" >> "lgsm/config-lgsm/$servercode/common.cfg"
        ./"$servercode" auto-install
    )
    ./"$servercode" start
    ./"$servercode" details || echo "[quick][error] details failed"
    ./"$servercode" monitor || echo "[quick][error] monitor failed"
    ./"$servercode" stop || echo "[quick][error] stop failed"
)