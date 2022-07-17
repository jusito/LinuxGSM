#!/bin/bash
# LinuxGSM fix_wurm.sh module
# Author: Daniel Gibbs
# Contributors: http://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Resolves various issues with Wurm Unlimited.

functionselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

# First run requires start with no parms.
# After first run new dirs are created.
if [ ! -d "${serverfiles}/Creative" ]; then
	# maps need to be copied
	cp -rf "${serverfiles}/dist"/* "${serverfiles}/"
fi
