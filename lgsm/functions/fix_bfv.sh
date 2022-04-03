#!/bin/bash
# LinuxGSM fix_av.sh module
# Author: Daniel Gibbs
# Contributors: http://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Resolves startup issue with Avorion

functionselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

sed -E -i 's/(serverInternet) .*/\1 0/g' "${servercfgfullpath}"
sed -E -i 's/(gameSpyLANPort) .*/\1 23000/g' "${servercfgfullpath}"
sed -E -i 's/(gameSpyPort) .*/\1 23000/g' "${servercfgfullpath}"
