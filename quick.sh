#!/bin/bash

set -euo pipefail

servercode="$1"

(
    cd "$(dirname "$0")"
    rm -rf build || true
    mkdir build
    
    cp linuxgsm.sh build/
    cd build
    ./linuxgsm.sh "$servercode"
    ./"$servercode" auto-install
)