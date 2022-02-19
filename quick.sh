#!/bin/bash

set -euo pipefail

(
    cd "$(dirname "$0")"
    rm -rf build || true
    mkdir build
    
    cp linuxgsm.sh build/
    cd build
    ./linuxgsm.sh gmodserver
    ./gmodserver auto-install
)