#!/bin/sh
#
# Copyright (C) 2018-2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Shared by the omr-events writers (post-tracking.d/050-events for the
# interfaces, hotplug.d/dhcp/50-omr-events-newdevice for new LAN devices):
# events are appended as one JSON object per line to $EVENTS_FILE and kept
# under a configurable age and/or size cap (omr-events.settings.max_age /
# max_size), whichever limit is hit first. The file lives in /tmp (tmpfs) to
# avoid flash wear, same as omr-metrics' /tmp/metrics.

EVENTS_DIR="${OMR_EVENTS_DIR:-/tmp/omr-events}"
EVENTS_FILE="${EVENTS_DIR}/events.log"

# _omr_events_lock <fd>: Busybox flock has no -w: poll it, and go ahead
# unlocked rather than never.
_omr_events_lock() {
	command -v flock >/dev/null 2>&1 || return 0
	_tries=0
	until flock -n "$1" 2>/dev/null; do
		_tries=$((_tries + 1))
		[ "$_tries" -ge 10 ] && break
		sleep 1
	done
}

# omr_events_write <now> <json line>: the line must start with {"ts":<now>,
# the retention pass extracts it with a cheap awk split instead of a full
# JSON parse.
omr_events_write() {
	_now="$1"
	[ -d "$EVENTS_DIR" ] || mkdir -p "$EVENTS_DIR" 2>/dev/null
	[ -w "$EVENTS_DIR" ] || return 0

	_max_age=$(uci -q get omr-events.settings.max_age)
	[ -z "$_max_age" ] && _max_age=172800
	_max_size=$(uci -q get omr-events.settings.max_size)
	[ -z "$_max_size" ] && _max_size=10485760

	# Every tracker runs 050-events for its own interface, and a WAN problem
	# changes several of them at once: one prune rewrote the file from a copy
	# taken before another tracker's append, or two of them shared the same
	# .tmp file, and the whole history was lost (1 round in 6 with six
	# trackers).
	exec 7>>"${EVENTS_FILE}.lock"
	_omr_events_lock 7

	printf '%s\n' "$2" >> "$EVENTS_FILE" 2>/dev/null

	# Prune by age then by size (whichever limit is hit first) in a single
	# pass: drop lines older than the cutoff, then drop from the oldest
	# remaining line until the file is back under the size cap. Only when a
	# limit is hit: the lines are in time order, so the first one tells
	# whether any is too old.
	_cutoff=$((_now - _max_age))
	_size=$(wc -c < "$EVENTS_FILE" 2>/dev/null)
	_first_ts=$(head -n 1 "$EVENTS_FILE" 2>/dev/null | sed -n 's/^{"ts":\([0-9]*\),.*/\1/p')
	if [ "${_size:-0}" -gt "$_max_size" ] || [ "${_first_ts:-0}" -lt "$_cutoff" ]; then
		awk -v cutoff="$_cutoff" -v maxsize="$_max_size" '
			{
				split($0, a, "\"ts\":")
				split(a[2], b, ",")
				ts = b[1] + 0
				if (ts >= cutoff) {
					n++
					lines[n] = $0
					sz = length($0) + 1
					sizes[n] = sz
					total += sz
				}
			}
			END {
				start = 1
				while (total > maxsize && start <= n) { total -= sizes[start]; start++ }
				for (i = start; i <= n; i++) print lines[i]
			}' "$EVENTS_FILE" > "${EVENTS_FILE}.tmp.$$" 2>/dev/null && mv "${EVENTS_FILE}.tmp.$$" "$EVENTS_FILE" 2>/dev/null
		rm -f "${EVENTS_FILE}.tmp.$$"
	fi
	exec 7>&-
}
