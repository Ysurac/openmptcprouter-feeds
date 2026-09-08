#!/bin/bash

# launcher.sh spawns one cake-autorate.sh process per generated instance
# config (files/usr/share/sqm-autorate/config.<iface>.sh) and supervises
# them for the lifetime of the sqm-autorate service.
#
# Besides the original "kill everything on stop" behavior, it also acts as
# a minimal per-interface supervisor: on SIGUSR1 it looks for pending
# restart requests (one empty marker file per interface, dropped into
# RESTART_REQUEST_DIR by the sqm-autorate rpcd plugin's restart_instance
# call) and kills+respawns only the named interface's cake-autorate.sh,
# leaving every other WAN's instance -- and its warm OWD baselines/shaper
# rate history -- untouched. cake-autorate.sh itself is not modified for
# this: it is treated as an upstream black box (see docs/dev-guide.md);
# all of the per-interface reload logic lives here instead.

# Overridable for tests; production always uses the defaults below.
PREFIX="${SQM_AUTORATE_DIR:-/usr/share/sqm-autorate}"
RUN_DIR="${SQM_AUTORATE_RUN_DIR:-/var/run/sqm-autorate}"
RESTART_REQUEST_DIR="${RUN_DIR}/restart-request"

mkdir -p "${RESTART_REQUEST_DIR}"
rm -f "${RESTART_REQUEST_DIR}"/* 2>/dev/null

# interface -> pid / interface -> config file path
declare -A cake_instance_pids
declare -A cake_instance_configs
shutting_down=0

trap kill_cake_instances INT TERM EXIT
trap handle_restart_requests USR1

# Same derivation cake-autorate.sh itself uses for its own $INTERFACE
# (INTERFACE=$(basename "$1" | cut -d. -f2)), kept in sync with it.
config_iface()
{
	basename "${1}" | cut -d. -f2
}

start_instance()
{
	local config_file="${1}"
	local iface
	iface=$(config_iface "${config_file}")
	"${PREFIX}/cake-autorate.sh" "${config_file}" &
	cake_instance_pids["${iface}"]=${!}
	cake_instance_configs["${iface}"]="${config_file}"
}

kill_cake_instances()
{
	trap - INT TERM EXIT USR1
	shutting_down=1

	echo "Killing all instances of cake one-by-one now."

	local iface
	for iface in "${!cake_instance_pids[@]}"
	do
		kill "${cake_instance_pids[${iface}]}" 2>/dev/null || true
	done

	# Clean up state files before the (potentially longer) wait below, not
	# after: the trap was just disarmed above, so a second incoming signal
	# during `wait` would kill this process outright with the default TERM
	# disposition, same as it always could here (this trap-disarm-first
	# ordering predates this file's per-interface supervisor logic) --
	# skipping straight to "exit" rather than reaching the rest of this
	# function. Confirmed live: a real `/etc/init.d/sqm-autorate stop`
	# killed every cake-autorate.sh child correctly but left launcher.pid
	# and restart-request/ behind because the code below the wait never
	# ran. Harmless on its own (restart_instance's kill -0 check already
	# treats a dead pid as "not running", and the next start overwrites/
	# clears both), but doing it first removes the gap entirely.
	rm -f "${RUN_DIR}/launcher.pid"
	rm -rf "${RESTART_REQUEST_DIR}"

	wait
}

# Runs synchronously as a signal trap, interrupting any in-flight `wait -n`
# in the main loop below. Restarting is a plain kill + respawn: cake-autorate
# has no live "reload config" signal of its own (see docs/dev-guide.md), so
# the replacement process simply re-reads sqm.<iface>.* from UCI from
# scratch on start, same as any other fresh instance launch.
handle_restart_requests()
{
	local request iface pid config_file

	for request in "${RESTART_REQUEST_DIR}"/*
	do
		[[ -e "${request}" ]] || continue
		iface=$(basename "${request}")
		rm -f "${request}"

		pid="${cake_instance_pids[${iface}]:-}"
		config_file="${cake_instance_configs[${iface}]:-}"
		if [[ -z "${pid}" || -z "${config_file}" ]]
		then
			echo "Restart requested for unknown/inactive interface: ${iface}. Ignoring."
			continue
		fi

		echo "Restarting cake-autorate instance for interface: ${iface}."

		# Remove from tracking before killing so the reconciliation pass in
		# the main loop below doesn't treat this as an instance that died
		# on its own (which is left dead, not auto-restarted -- see below).
		unset "cake_instance_pids[${iface}]"
		unset "cake_instance_configs[${iface}]"

		kill "${pid}" 2>/dev/null || true
		# cake-autorate's own cleanup_and_killall trap tears down its child
		# processes (pingers, log file writer, ...) and removes its temp
		# dir synchronously before the process itself exits, so waiting on
		# it here ensures the replacement never races the old instance's
		# own cleanup (e.g. both briefly touching the same tc qdisc).
		wait "${pid}" 2>/dev/null || true

		# A TERM/INT that landed while we were blocked in that wait ran
		# kill_cake_instances *nested* inside this handler (bash runs a trap
		# for a different signal from within a running trap). It has already
		# taken every instance down and disarmed the traps, so respawning now
		# would leave a fresh cake-autorate.sh nobody tracks or kills -- the
		# main loop below exits straight away on shutting_down -- and the
		# next service start would then double up on this WAN's qdisc.
		# Reproduced by tests/test_010_launcher_supervisor.sh.
		((shutting_down)) && return

		[[ -f "${config_file}" ]] && start_instance "${config_file}"
	done
}

# Only advertise our pid once the USR1 trap above is armed and its handler
# defined: a restart_instance landing before that would hit bash's default
# USR1 disposition and terminate the launcher outright.
printf '%s' "$$" > "${RUN_DIR}/launcher.pid"

cake_instances=("${PREFIX}"/config.*.sh)
for cake_instance in "${cake_instances[@]}"
do
	[[ -f "${cake_instance}" ]] && start_instance "${cake_instance}"
done

# Supervise: block until every tracked instance has exited. `wait -n` also
# returns (with an exit status >128) when interrupted by the USR1 trap
# above, in which case nothing has actually exited -- so every wakeup, for
# whatever reason, is followed by a reconciliation pass that prunes any pid
# no longer alive. An instance killed via handle_restart_requests is
# already removed from (and, on successful respawn, back in) the tracking
# arrays by the time this runs, so only instances that died on their own
# (crashed, or failed cake-autorate's config validation gate) get pruned
# here -- matching the original script's behavior of not auto-restarting a
# crashed instance.
while (( ${#cake_instance_pids[@]} > 0 ))
do
	wait -n 2>/dev/null
	((shutting_down)) && break
	for iface in "${!cake_instance_pids[@]}"
	do
		kill -0 "${cake_instance_pids[${iface}]}" 2>/dev/null || {
			unset "cake_instance_pids[${iface}]"
			unset "cake_instance_configs[${iface}]"
		}
	done
done
