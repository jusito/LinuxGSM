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

fn__restart_server() {
	alert="${1:?}}"
	alert.sh
	(
		command_restart.sh
	)

	fn_firstcommand_reset
}

fn_monitor_check_lockfile(){
	fn_print_dots "Checking lockfile"

	# Monitor does not run if lockfile is not found.
	if [ ! -f "${lockdir}/${selfname}.lock" ]; then
		fn_print_fail_nl "Checking lockfile: No lockfile found"
		echo -e "* Start ${selfname} to run monitor."
		exitcode="1"
		core_exit.sh
	
	# Fix if lockfile is not unix time or contains letters
	elif [[ "$(head -n 1 "${lockdir}/${selfname}.lock")" =~ [A-Za-z] ]]; then
		fn_print_warn_nl "Checking lockfile: fixing illegal lockfile"
		date '+%s' > "${lockdir}/${selfname}.lock"
		echo "${version}" >> "${lockdir}/${selfname}.lock"
		echo "${port}" >> "${lockdir}/${selfname}.lock"
	else
		fn_print_ok_nl "Checking lockfile"
	fi
}

fn_monitor_check_update(){
	fn_print_dots "Checking active updates"

	# Monitor will check if update is already running.
	if [ "$(pgrep "${selfname} update" | wc -l)" != "0" ]; then
		fn_print_fail_nl "SteamCMD is currently checking for updates"
		exitcode="2"
		core_exit.sh
	else
		fn_print_ok_nl "Checking active updates"
	fi
}

fn_monitor_check_session(){
	fn_print_dots "Checking session"

	# uses status var from check_status.sh
	if [ "${status}" != "0" ]; then
		fn_print_ok_nl "Checking session"
		return 0
	else
		fn_print_error_nl "Checking session"
		return 1
	fi
}

fn_monitor_check_queryport(){
	fn_print_dots "Checking port: \"${queryport}\""

	if ! grep -qe '^[1-9][0-9]*$' <<< "${queryport}"; then
		if [ -n "${rconenabled}" ]&&[ "${rconenabled}" != "true" ]&&[ ${shortname} == "av" ]; then
			fn_print_error_nl "Checking port: Unable to query, rcon is not enabled"
		else
			fn_print_error_nl "Checking port: Unable to query, queryport is not set"
		fi
		return 1
	else
		fn_print_ok_nl "Checking port: \"${queryport}\""
	fi
	return 0
}

fn_query_gsquery(){
	if [ ! -f "${functionsdir}/query_gsquery.py" ]; then
		fn_fetch_file_github "lgsm/functions" "query_gsquery.py" "${functionsdir}" "chmodx" "norun" "noforce" "nohash"
	fi
	"${functionsdir}"/query_gsquery.py -a "${queryip}" -p "${queryport}" -e "${querytype}" > /dev/null 2>&1
	querystatus="$?"
}

fn_query_tcp(){
	bash -c 'exec 3<> /dev/tcp/'${queryip}'/'${queryport}'' > /dev/null 2>&1
	querystatus="$?"
}

fn_monitor_query(){
	local seconds_between_attempts="15"
	local max_attempts="5"

	# Will loop and query up to 5 times every 15 seconds.
	# Query will wait up to 60 seconds to confirm server is down as server can become non-responsive during map changes.
	start_time="$(date '+%s')"
	for queryattempt in $(seq 1 "$max_attempts"); do
		log_current_query_info="$(($(date '+%s') - $start_time))s in attempt ${queryattempt}"
		for queryip in "${queryips[@]}"; do
			log_msg="Starting to query in mode \"${querymethod}\" to target \"${queryip}:${queryport}\" $log_current_query_info"
			fn_print_dots "$log_msg"

			# will use query method selected in fn_monitor_loop
			querystatus="100"
			if [ "${querymethod}" ==  "gamedig" ]; then
				query_gamedig.sh

			elif [ "${querymethod}" ==  "gsquery" ]; then
				fn_query_gsquery

			elif [ "${querymethod}" ==  "tcp" ]; then
				fn_query_tcp

			else
				fn_print_fail_nl "$log_msg reason: unhandled query method \"${querymethod}\""
			fi
			
			# if serverquery is fine
			if [ "${querystatus}" == "0" ]; then
				fn_print_dots_nl "$log_msg"

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
					info_stats.sh
				fi

				return 0
			else
				fn_print_fail_nl "$log_msg reason: illegal script state \"$querystatus\""
			fi
			echo "___43"
		done

		# Second counter will wait at least 15s before next query attempt
		for seconds in $(seq 1 "$seconds_between_attempts"); do
			#fn_script_log_info "Querying port: ${querymethod}: ${ip}:${queryport} : $log_current_query_info: ${cyan}WAIT${default} $seconds/$seconds_between_attempts"
			sleep 1s
		done
		echo "___46"
	done
	echo "___47"
	return 1
}

fn_monitor__await_execution_time(){
	# Add a querydelay of 1 min if var missing.
	querydelay="${querydelay:-"1"}"

	last_execution="$(head -n 1 "${lockdir}/${selfname}.lock")"
	delay_seconds="$((querydelay * 60))"
	next_allowed_execution="$((last_execution + delay_seconds))"
	seconds_to_wait="$((next_allowed_execution - $(date '+%s')))"
	
	if [ "$seconds_to_wait" -gt "0" ]; then
		fn_print_dots "monitoring delayed for ${seconds_to_wait}s"
		for i in $(seq 1 "$seconds_to_wait"); do
			sleep 1s
		done
		fn_print_ok_nl "monitoring delayed for ${seconds_to_wait}s"
	fi
}

fn_monitor_loop(){
	fn_monitor__await_execution_time
	is_gamedig_installed="$([ "$(command -v gamedig 2>/dev/null)" ]&&[ "$(command -v jq 2>/dev/null)" ] && echo true || echo false )"

	# loop though query methods selected by querymode.
	if [ "${querymode}" == "2" ]; then
		local query_methods_array=( gamedig gsquery )
	elif [ "${querymode}" == "3" ]; then
		local query_methods_array=( gamedig )
	elif [ "${querymode}" == "4" ]; then
		local query_methods_array=( gsquery )
	elif [ "${querymode}" == "5" ]; then
		local query_methods_array=( tcp )
	fi

	for querymethod in "${query_methods_array[@]}"; do
		# Will check if gamedig is installed and bypass if not.
		if [ "${querymethod}" == "gamedig" ] && ! "$is_gamedig_installed"; then
			fn_print_warn_nl "gamedig is not installed"
			fn_print_warn_nl "https://docs.linuxgsm.com/requirements/gamedig"
		elif fn_monitor_query; then
			fn_print_complete_nl "monitoring successful"
			return 0
		fi
	done
	return 1
}

monitorflag=1
check.sh
core_logs.sh
info_game.sh
set -euo pipefail

# query pre-checks
fn_monitor_check_lockfile
fn_monitor_check_update
session_check_failed="$(fn_monitor_check_session && echo false || echo true )"
session_check_only="$([ "${querymode}" = "1" ] && echo true || echo false )"

if "$session_check_failed"; then
	fn__restart_server "restart"
	exitcode="2"

elif "$session_check_only"; then
	exitcode="0"

elif fn_monitor_check_queryport; then
	if fn_monitor_loop; then
		exitcode="0"
	else
		fn__restart_server "restartquery"
		exitcode="2"
	fi

else
	exitcode="2"
fi

core_exit.sh
