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
	if ! grep -qe '^[1-9][0-9]*$' <<< "${queryport}"; then
		echo "...1"
		fn_print_dots "Checking port: \"${queryport}\""
		echo "...2"
		#fn_print_checking_eol
		#echo "...3"
		#fn_script_log_info "Checking port: CHECKING"
		#echo "...4"
		if [ -n "${rconenabled}" ]&&[ "${rconenabled}" != "true" ]&&[ ${shortname} == "av" ]; then
			echo "...5"
			fn_print_warn "Checking port: Unable to query, rcon is not enabled"
			#echo "...6"
			fn_script_log_warn "Checking port: Unable to query, rcon is not enabled"
		else
			echo "...6"
			fn_print_error "Checking port: Unable to query, queryport is not set"
			#echo "...7"
			fn_script_log_error "Checking port: Unable to query, queryport is not set"
		fi
		return 1
	else
		return 0
	fi
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
start_time="$(date '+%s')"
for queryattempt in $(seq 1 "$max_attempts"); do
	log_current_query_info="$(($(date '+%s') - $start_time))s in attempt ${queryattempt}"
	for queryip in "${queryips[@]}"; do
		echo "___3 $queryip" # av / wmc (query port not set) / zp failed & successful
		#fn_print_dots "Querying port: ${querymethod}: ${queryip}:${queryport} : $log_current_query_info: "
		#fn_print_querying_eol
		#fn_script_log_info "Querying port: ${querymethod}: ${queryip}:${queryport} : ${queryattempt} : QUERYING" 
		# will use query method selected in fn_monitor_loop
		# gamedig
		if [ "${querymethod}" ==  "gamedig" ]; then
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
		else
			fn_print_error "unhandled query method \"${querymethod}\""
		fi
		echo "___19"

		if [ "${querystatus}" == "0" ]; then
			echo "___20"
			# Server query OK.
			#fn_print_ok "Querying port: ${querymethod}: ${queryip}:${queryport} : $log_current_query_info: "
			#fn_print_ok_eol_nl
			#fn_script_log_pass "Querying port: ${querymethod}: ${queryip}:${queryport} : ${queryattempt}: OK"
			monitorpass=1
			# Add query data to log.
			if [ "${gdname}" ]; then
				fn_script_log_info "Server name: ${gdname}"
			fi
			if [ "${gdplayers}" ]; then
				fn_script_log_info "Players: ${gdplayers}/${gdmaxplayers}"
			fi
			if [ "${gdbots}" ]; then
				fn_script_log_info "Bots: ${gdbots}"
			fi
			if [ "${gdmap}" ]; then
				fn_script_log_info "Map: ${gdmap}"
			fi
			if [ "${gdgamemode}" ]; then
				fn_script_log_info "Game Mode: ${gdgamemode}"
			fi

			# send LinuxGSM stats if monitor is OK.
			if [ "${stats}" == "on" ]||[ "${stats}" == "y" ]; then
				echo "___30"
				info_stats.sh
			fi
			echo "___31"
			return 0
		fi
		echo "___43"
	done
	echo "___44"
	# Second counter will wait at least 15s before next query attempt
	for seconds in $(seq 1 "$seconds_between_attempts"); do
		# TODO temp commented out, healthcheck will only show last 4096 bytes
		#echo "___45 $seconds"
		#fn_script_log_info "Querying port: ${querymethod}: ${ip}:${queryport} : $log_current_query_info: ${cyan}WAIT${default} $seconds/$seconds_between_attempts"
		sleep 1s
	done
	echo "___46"
done
return 1
echo "___47"
}

fn_monitor__await_execution_time(){
	# Add a querydelay of 1 min if var missing.
	querydelay="${querydelay:-"1"}"

	last_execution="$(head -n 1 "${lockdir}/${selfname}.lock")"
	delay_seconds="$((querydelay * 60))"
	next_allowed_execution="$((last_execution + delay_seconds))"
	seconds_to_wait="$((next_allowed_execution - $(date '+%s')))"
	
	if [ "$seconds_to_wait" -gt "0" ]; then
		fn_script_log_info "monitoring delayed for ${seconds_to_wait}s"
		for i in $(seq 1 "$seconds_to_wait"); do
			#fn_script_log_info "Querying port: ${querymethod}: ${ip}:${queryport} : $log_current_query_info: ${cyan}WAIT${default} $seconds/$seconds_between_attempts"
			sleep 1s
		done
	fi
}

fn_monitor_loop(){
	fn_monitor__await_execution_time
	echo "+5"
	is_gamedig_installed="$([ "$(command -v gamedig 2>/dev/null)" ]&&[ "$(command -v jq 2>/dev/null)" ] && echo true || echo false)"

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
		if [ "${querymethod}" == "gamedig" ] && ! "$is_gamedig_installed"; then
			fn_script_log_info "gamedig is not installed"
			fn_script_log_info "https://docs.linuxgsm.com/requirements/gamedig"
		elif [ -z "${monitorpass}" ] && fn_monitor_query; then
			fn_print_ok "monitoring successful"
			return 0
		fi
	done
	return 1
}

monitorflag=1
check.sh
core_logs.sh
info_game.sh

# query pre-checks
fn_monitor_check_lockfile
fn_monitor_check_update
fn_monitor_check_session

# Monitor will not continue if session only check.
if [ "${querymode}" = "1" ]; then
	exitcode="0"
if fn_monitor_check_queryport; then
	if fn_monitor_loop; then
		exitcode="0"
	else # restart 
		fn_print_fail "Querying port: ${querymethod}: ${queryip}:${queryport} : $log_current_query_info: "
		fn_print_fail_eol_nl

		alert="restartquery"
		alert.sh
		echo "___39"
		(
			command_restart.sh
		)

		fn_firstcommand_reset
		exitcode="1"
	fi
else
	exitcode="1"
fi
core_exit.sh
