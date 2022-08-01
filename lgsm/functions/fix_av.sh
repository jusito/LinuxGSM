#!/bin/bash
# LinuxGSM fix_av.sh module
# Author: Daniel Gibbs
# Contributors: http://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Resolves startup issue with Avorion

functionselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${serverfiles}:${serverfiles}/linux64"

if [ "${postinstall}" == "1" ]; then
	fn_print_information "starting ${gamename} server to generate configs."
	fn_sleep_time
	# go to the executeable dir and start the init of the server
	if ! cd "${serverfiles}"; then
		fn_print_error_nl "cant fix avserver, folder \"${serverfiles}\" doesnt exist"
		exitcode="2"
		core_exit.sh
	fi
	"${executable}" --datapath "${avdatapath}" --galaxy-name "${selfname}" --init-folders-only

	if [ ! -f "${servercfgfullpath}" ]; then
		fn_print_error_nl "couldn't fix avserver, file \"${servercfgfullpath}\" not created"
		exitcode="2"
		core_exit.sh
	fi
fi
