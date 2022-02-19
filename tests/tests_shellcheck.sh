#!/bin/bash
# Project: Game Server Managers - LinuxGSM
# Author: Daniel Gibbs
# License: MIT License, Copyright (c) 2020 Daniel Gibbs
# Purpose: Travis CI Tests: Shellcheck | Linux Game Server Management Script
# Contributors: https://github.com/GameServerManagers/LinuxGSM/graphs/contributors
# Documentation: https://docs.linuxgsm.com/
# Website: https://linuxgsm.com
set -o errexit
set -o nounset
set -o pipefail
# variable referenced but not assigned https://github.com/koalaman/shellcheck/wiki/SC2154
# variable unused, verify or export it https://github.com/koalaman/shellcheck/wiki/SC2034
excluded_issues="SC2154,SC2034"

(
    echo -e "================================="
    echo -e "Travis CI Tests"
    echo -e "Linux Game Server Manager"
    echo -e "by Daniel Gibbs"
    echo -e "Contributors: http://goo.gl/qLmitD"
    echo -e "https://linuxgsm.com"
    echo -e "================================="
    echo -e ""
    echo -e "================================="
    echo -e "Bash Analysis Tests"
    echo -e "Using: Shellcheck"
    echo -e "Testing Branch: ${TRAVIS_BRANCH:-"not travis"}"
    echo -e "================================="
    echo -e ""

    cd "$(dirname "$0")/.."

    files=()
    mapfile -d $'\0' files < <( find . -type f \( -name "*.sh" -o -name "*.cfg" \) -print0 )

    echo "[info][shellcheck] testing on ${#files[@]} files"
    
    scissues="$(shellcheck --exclude="$excluded_issues" "${files[@]}" || true)"

    if [ -z "$scissues" ]; then
        echo "[info][shellcheck] successful"
    else
        echo "$scissues"
    fi

    echo -e "Found issues: $(grep -cF "^--" <<< "$scissues")"
    echo -e ""
    echo -e "================================="
    echo -e "Bash Analysis Tests - Complete!"
    echo -e "Using: Shellcheck"
    echo -e "================================="
)
