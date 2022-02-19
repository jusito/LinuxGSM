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
    ./"$servercode" auto-install
)