#!/bin/sh
#
# Copyright (C) 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Volatile per-interface state (latency, last-check timestamps, ...) that
# omr-tracker refreshes on every post-tracking cycle. It used to be written
# to /etc/config/openmptcprouter with a uci commit each time, i.e. a flash
# write every ~10 s per WAN on the overlay. Keep it in the tmpfs-backed uci
# state directory instead (the same mechanism netifd uses for /var/state):
# readers that want the live value use "uci -P /var/state get", plain
# "uci get" only sees the persistent config.
#
# uci deltas are append-only, so every write first reverts the option's
# existing state entry to keep the state file bounded.

OMR_STATE_DIR="${OMR_STATE_DIR:-/var/state}"

# omr_state_get <package>.<section>.<option>
omr_state_get() {
	command uci -q -P "$OMR_STATE_DIR" get "$1" 2>/dev/null
}

# omr_state_set <package> <section> <option> <value> [<option> <value> ...]
# Sets one or more options in one uci run. The section must exist in the
# persistent config or in state: create it in state when it doesn't.
omr_state_set() {
	local _pkg="$1" _sec="$2" _batch=""
	shift 2
	[ -n "$_pkg" ] && [ -n "$_sec" ] || return 1
	if ! command uci -q -P "$OMR_STATE_DIR" get "${_pkg}.${_sec}" >/dev/null 2>&1; then
		command uci -q -P "$OMR_STATE_DIR" set "${_pkg}.${_sec}=interface" 2>/dev/null
	fi
	while [ $# -ge 2 ]; do
		_batch="${_batch}revert ${_pkg}.${_sec}.${1}
set ${_pkg}.${_sec}.${1}=${2}
"
		shift 2
	done
	[ -n "$_batch" ] || return 0
	printf '%s' "$_batch" | command uci -q -P "$OMR_STATE_DIR" batch 2>/dev/null
}

# omr_state_del <package> <section> [<option>]
omr_state_del() {
	local _pkg="$1" _sec="$2" _opt="$3"
	[ -n "$_pkg" ] && [ -n "$_sec" ] || return 1
	command uci -q -P "$OMR_STATE_DIR" revert "${_pkg}.${_sec}${_opt:+.$_opt}" 2>/dev/null
}

# omr_state_migrate <package> <section> <option> [<option> ...]
# Drop legacy copies of state options from the persistent config (one
# commit, only when something is actually there), so stale values don't
# shadow the live state for readers still using plain "uci get".
omr_state_migrate() {
	local _pkg="$1" _sec="$2" _changed=""
	shift 2
	[ -n "$_pkg" ] && [ -n "$_sec" ] || return 1
	for _opt in "$@"; do
		if command uci -q get "${_pkg}.${_sec}.${_opt}" >/dev/null 2>&1; then
			command uci -q delete "${_pkg}.${_sec}.${_opt}"
			_changed=1
		fi
	done
	[ -n "$_changed" ] && command uci -q commit "$_pkg"
	return 0
}
