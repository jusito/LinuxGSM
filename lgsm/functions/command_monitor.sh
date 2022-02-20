#!/bin/bash
# LinuxGSM command_monitor.sh module
# Author: Daniel Gibbs
# Contributors: http://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Monitors server by checking for running processes
# then passes to gamedig and gsquery.

commandname="MONITOR"
commandaction="Monitoring"
functionselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
fn_firstcommand_set

fn_monitor_check_lockfile(){
	echo ".1"
	# Monitor does not run it lockfile is not found.
	if [ ! -f "${lockdir}/${selfname}.lock" ]; then
		echo ".2"
		fn_print_dots "Checking lockfile: "
		echo ".3"
		fn_print_checking_eol
		echo ".4"
		fn_script_log_info "Checking lockfile: CHECKING"
		echo ".5"
		fn_print_error "Checking lockfile: No lockfile found: "
		echo ".6"
		fn_print_error_eol_nl
		echo ".7"
		fn_script_log_error "Checking lockfile: No lockfile found: ERROR"
		echo ".7"
		echo -e "* Start ${selfname} to run monitor."
		echo ".8"
		core_exit.sh
		echo ".9"
	fi

	# Fix if lockfile is not unix time or contains letters
	if [ -f "${lockdir}/${selfname}.lock" ]&&[[ "$(head -n 1 "${lockdir}/${selfname}.lock")" =~ [A-Za-z] ]]; then
		echo ".10"
		date '+%s' > "${lockdir}/${selfname}.lock"
		echo ".11"
		echo "${version}" >> "${lockdir}/${selfname}.lock"
		echo ".12"
		echo "${port}" >> "${lockdir}/${selfname}.lock"
		echo ".13"
	fi
	echo ".14"
}

fn_monitor_check_update(){
	# Monitor will check if update is already running.
	if [ "$(pgrep "${selfname} update" | wc -l)" != "0" ]; then
		echo "..1"
		fn_print_dots "Checking active updates: "
		echo "..2"
		fn_print_checking_eol
		echo "..3"
		fn_script_log_info "Checking active updates: CHECKING"
		echo "..4"
		fn_print_error_nl "Checking active updates: SteamCMD is currently checking for updates: "
		echo "..5"
		fn_print_error_eol
		echo "..6"
		fn_script_log_error "Checking active updates: SteamCMD is currently checking for updates: ERROR"
		echo "..7"
		core_exit.sh
		echo "..8"
	fi
	echo "..9"
}

fn_monitor_check_session(){
	echo "..10"
	fn_print_dots "Checking session: "
	echo "..11"
	fn_print_checking_eol
	echo "..12"
	fn_script_log_info "Checking session: CHECKING"
	echo "..13"
	# uses status var from check_status.sh
	if [ "${status}" != "0" ]; then
		echo "..14"
		fn_print_ok "Checking session: "
		echo "..15"
		fn_print_ok_eol_nl
		echo "..16"
		fn_script_log_pass "Checking session: OK"
		echo "..17"
	else
		echo "..18"
		fn_print_error "Checking session: "
		echo "..19"
		fn_print_fail_eol_nl
		echo "..20"
		fn_script_log_fatal "Checking session: FAIL"
		echo "..21"
		alert="restart"
		echo "..22"
		alert.sh
		echo "..23"
		fn_script_log_info "Checking session: Monitor is restarting ${selfname}"
		echo "..24"
		command_restart.sh
		echo "..25"
		core_exit.sh
	fi
	echo "..26"
}

fn_monitor_check_queryport(){
	# Monitor will check queryport is set before continuing.
	if grep -Eqe '^[0-9]+$' <<< "${queryport}"; then
		echo "...1"
		fn_print_dots "Checking port: \"${queryport}\""
		echo "...2"
		fn_print_checking_eol
		echo "...3"
		fn_script_log_info "Checking port: CHECKING"
		echo "...4"
		if [ -n "${rconenabled}" ]&&[ "${rconenabled}" != "true" ]&&[ ${shortname} == "av" ]; then
			echo "...5"
			fn_print_warn "Checking port: Unable to query, rcon is not enabled"
			echo "...6"
			fn_script_log_warn "Checking port: Unable to query, rcon is not enabled"
		else
			echo "...6"
			fn_print_error "Checking port: Unable to query, queryport is not set"
			echo "...7"
			fn_script_log_error "Checking port: Unable to query, queryport is not set"
		fi
		echo "...8"
		core_exit.sh
		echo "...9"
	else
		fn_print_warn "illegal queryport \"${queryport}\""
	fi
	echo "...10"
}

fn_query_gsquery(){
	echo "_1"
	if [ ! -f "${functionsdir}/query_gsquery.py" ]; then
		echo "_2"
		fn_fetch_file_github "lgsm/functions" "query_gsquery.py" "${functionsdir}" "chmodx" "norun" "noforce" "nohash"
	fi
	echo "_3"
	"${functionsdir}"/query_gsquery.py -a "${queryip}" -p "${queryport}" -e "${querytype}" > /dev/null 2>&1
	querystatus="$?"
}

fn_query_tcp(){
	echo "__1"
	bash -c 'exec 3<> /dev/tcp/'${queryip}'/'${queryport}'' > /dev/null 2>&1
	querystatus="$?"
}

fn_monitor_query(){
	local seconds_between_attempts="15"
	local max_attempts="5"
	echo "___1"
# Will loop and query up to 5 times every 15 seconds.
# Query will wait up to 60 seconds to confirm server is down as server can become non-responsive during map changes.
totalseconds=0
for queryattempt in $(seq 1 "$max_attempts"); do
	log_current_query_info="${totalseconds}s in attempt ${queryattempt}"
	echo "___2 attempt: $queryattemp logdir? $lgsmlogdir exists=$([ -d "$lgsmlogdir" ] && echo true || echo false)"
	for queryip in "${queryips[@]}"; do
		echo "___3 $queryip"
		fn_print_dots "Querying port: ${querymethod}: ${queryip}:${queryport} : $log_current_query_info: "
		echo "___4"
		fn_print_querying_eol
		echo "___5"
		fn_script_log_info "Querying port: ${querymethod}: ${queryip}:${queryport} : ${queryattempt} : QUERYING"
		echo "___6" # av / wmc (query port not set) / zp failed & successful
		# querydelay
		if [ "$(head -n 1 "${lockdir}/${selfname}.lock")" -gt "$(date "+%s" -d "${querydelay} mins ago")" ]; then
			# TODO queryport "NOT SET" can be successful
			echo "___7" # avserver successful +1
			fn_script_log_info "Querying port: ${querymethod}: ${ip}:${queryport} : $log_current_query_info: "
			echo "___8"
			fn_print_delay_eol_nl
			echo "___9"
			fn_script_log_info "Querying port: ${querymethod}: ${ip}:${queryport} : ${queryattempt} : DELAY"
			echo "___10"
			fn_script_log_info "Query bypassed: ${gameservername} started less than ${querydelay} minutes ago"
			echo "___11"
			fn_script_log_info "Server started: $(date -d @$(head -n 1 "${lockdir}/${selfname}.lock"))"
			echo "___12"
			fn_script_log_info "Current time: $(date)"
			echo "___13"
			monitorpass=1
			echo "___14"
			exitcode="100" # exit here with non zero error code
			core_exit.sh
			echo "___15"
		# will use query method selected in fn_monitor_loop
		# gamedig
		elif [ "${querymethod}" ==  "gamedig" ]; then
			echo "___16"
			query_gamedig.sh
		# gsquery
		elif [ "${querymethod}" ==  "gsquery" ]; then
			echo "___17" # zp
			fn_query_gsquery
		#tcp query
		elif [ "${querymethod}" ==  "tcp" ]; then
			echo "___18" # avserver failed
			fn_query_tcp
		fi
		echo "___19"

		if [ "${querystatus}" == "0" ]; then
			echo "___20"
			# Server query OK.
			fn_print_ok "Querying port: ${querymethod}: ${queryip}:${queryport} : $log_current_query_info: "
			echo "___21"
			fn_print_ok_eol_nl
			echo "___22"
			fn_script_log_pass "Querying port: ${querymethod}: ${queryip}:${queryport} : ${queryattempt}: OK"
			echo "___23"
			monitorpass=1
			if [ "${querystatus}" == "0" ]; then
				echo "___24"
				# Add query data to log.
				if [ "${gdname}" ]; then
					echo "___25"
					fn_script_log_info "Server name: ${gdname}"
				fi
				if [ "${gdplayers}" ]; then
					echo "___26"
					fn_script_log_info "Players: ${gdplayers}/${gdmaxplayers}"
				fi
				if [ "${gdbots}" ]; then
					echo "___27"
					fn_script_log_info "Bots: ${gdbots}"
				fi
				if [ "${gdmap}" ]; then
					echo "___28"
					fn_script_log_info "Map: ${gdmap}"
				fi
				if [ "${gdgamemode}" ]; then
					echo "___29"
					fn_script_log_info "Game Mode: ${gdgamemode}"
				fi

				# send LinuxGSM stats if monitor is OK.
				if [ "${stats}" == "on" ]||[ "${stats}" == "y" ]; then
					echo "___30"
					info_stats.sh
				fi
			fi
			echo "___31"
			core_exit.sh
		else
			echo "___31"
			# Server query FAIL.
			fn_print_fail "Querying port: ${querymethod}: ${queryip}:${queryport} : $log_current_query_info: "
			echo "___32"
			fn_print_fail_eol
			echo "___33"
			fn_script_log_warn "Querying port: ${querymethod}: ${queryip}:${queryport} : ${queryattempt}: FAIL"
			echo "___34"
			# Monitor will try gamedig (if supported) for first 30s then gsquery before restarting.
			# gsquery will fail if longer than 60s
			if [ "${totalseconds}" -ge "59" ]; then
				echo "___35"
				# Monitor will FAIL if over 60s and trigger gane server reboot.
				fn_print_fail "Querying port: ${querymethod}: ${queryip}:${queryport} : $log_current_query_info: "
				echo "___36"
				fn_print_fail_eol_nl
				echo "___37"
				fn_script_log_warn "Querying port: ${querymethod}: ${queryip}:${queryport} : ${queryattempt}: FAIL"
				echo "___38"
				# Send alert if enabled.
				alert="restartquery"
				alert.sh
				echo "___39"
				command_restart.sh
				echo "___40"
				fn_firstcommand_reset
				echo "___41"
				core_exit.sh
			fi
			echo "___42"
		fi
		echo "___43"
	done
	echo "___44"
	# Second counter will wait at least 15s before next query attempt
	for seconds in $(seq 1 "$seconds_between_attempts"); do
		echo "___45 $seconds"
		fn_script_log_info "Querying port: ${querymethod}: ${ip}:${queryport} : $log_current_query_info: ${cyan}WAIT${default} $seconds/$seconds_between_attempts"
		sleep 1s
	done
	echo "___46"
done
echo "___47"
}

fn_monitor_loop(){
	echo "fn_monitor_loop ${querymode}"
	# loop though query methods selected by querymode.
	totalseconds=0
	if [ "${querymode}" == "2" ]; then
		local query_methods_array=( gamedig gsquery )
	elif [ "${querymode}" == "3" ]; then
		local query_methods_array=( gamedig )
	elif [ "${querymode}" == "4" ]; then
			local query_methods_array=( gsquery )
	elif [ "${querymode}" == "5" ]; then
		local query_methods_array=( tcp )
	fi
			echo "+6"
	for querymethod in "${query_methods_array[@]}"; do
			echo "+7 $querymethod"
		# Will check if gamedig is installed and bypass if not.
		if [ "${querymethod}" == "gamedig" ]; then
		echo "+8"
			if [ "$(command -v gamedig 2>/dev/null)" ]&&[ "$(command -v jq 2>/dev/null)" ]; then
			echo "+9"
				if [ -z "${monitorpass}" ]; then
				echo "+10"
					fn_monitor_query
				fi
			else
			echo "+11"
				fn_script_log_info "gamedig is not installed"
				echo "+12"
				fn_script_log_info "https://docs.linuxgsm.com/requirements/gamedig"
			fi
			echo "+12"
		else
		echo "+13"
			# will not query if query already passed.
			if [ -z "${monitorpass}" ]; then
			echo "+14"
				fn_monitor_query
			fi
		fi
		echo "+15"
	done
	echo "+16"
}

echo "1"
monitorflag=1
echo "2"
check.sh
echo "3"
core_logs.sh
echo "4"
info_game.sh

# query pre-checks
echo "5"
fn_monitor_check_lockfile
echo "6"
fn_monitor_check_update
echo "7"
fn_monitor_check_session
echo "8"
# Monitor will not continue if session only check.
if [ "${querymode}" != "1" ]; then
	echo "9"
	fn_monitor_check_queryport
	echo "10"

	# Add a querydelay of 1 min if var missing.
	if [ -z "${querydelay}" ]; then
		echo "11"
		querydelay="1"
	fi

	echo "12"
	fn_monitor_loop
fi
echo "13"
core_exit.sh
echo "14"
