#!/bin/bash

set -euo pipefail

(
    log_dir="$(realpath "$(dirname "$0")")/logs"
    cd "$(dirname "$0")/.."
    ansi="on"; commandaction=""; travistest="1"; sleeptime="0"
    source lgsm/functions/core_messages.sh
    fn_ansi_loader

    rm -rf "$log_dir" > /dev/null 2>&1 || true
    mkdir -p "$log_dir/"

    cd "lgsm/data/"
    for csv in *-[1-9]*.csv; do
        distribution="${csv//-*/}"
        version="${csv#*-}"
        version="${version:: -4}" # removing .csv
        
        mapfile -t packages < <(grep -Poe '(?<=,)[^,]*' "$csv" | sort | uniq)
        
        image=""
        shell="bash"
        install_cmd=""
        case "$distribution" in
            almalinux)
                image="almalinux:$version"
                install_cmd="set -x; dnf check-update; dnf install -y ${packages[*]}";;
            centos)
                image="centos:$version"
                install_cmd="set -x; yum check-update; yum install -y ${packages[*]}";;
            debian)
                image="debian:$version"
                install_cmd="set -x; dpkg --add-architecture i386; apt-get update; apt-get install -y ${packages[*]}";;
            rhel)
                image="redhat/ubi$version:latest"
                install_cmd="set -x; yum check-update; yum install -y ${packages[*]}";;
            rocky)
                image="rockylinux:$version"
                install_cmd="set -x; yum check-update; yum install -y ${packages[*]}";;
            ubuntu)
                image="ubuntu:$version"
                install_cmd="set -x; dpkg --add-architecture i386; apt-get update; apt-get install -y ${packages[*]}";;
            *)
                echo "unhandled distribution \"$distribution\"($csv)"
                continue;;
        esac

        fn_print_dots "pulling $image"
        if docker pull "$image" > /dev/null 2>&1; then
            fn_print_dots "checking ${#packages[*]} packages "
            echo "docker run -it --rm \"$image\" \"$shell\" -c \"$install_cmd\"" > "$log_dir/$csv.log"
            if (docker run -i --rm --name "linuxgsm-test_packages" "$image" "$shell" -c "$install_cmd") >> "$log_dir/$csv.log" 2>&1; then
                fn_print_ok_nl "$csv is fine"
            else
                fn_print_error_nl "$csv packages could not be found, see log \"$log_dir/$csv.log\""
            fi
        else
            fn_print_error_nl "$csv couldn't pull image \"$image\""
        fi
    done
)
