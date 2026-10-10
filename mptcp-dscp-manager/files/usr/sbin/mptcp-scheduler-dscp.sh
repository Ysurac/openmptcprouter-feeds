#!/bin/sh
# MPTCP DSCP Scheduler Manager
# (c) Yannick Chabanois for OpenMPTCProuter
#
# Manages the pinned BPF maps used by the bpf_dscp scheduler
# (mptcp-bpf-dscp): maps a DSCP class to either
#  - the local endpoint IP of the WAN interface that should carry it
#    (dscp_iface map, router-side: each WAN has a distinct local IP), or
#  - the MPTCP remote endpoint ids of the WAN that should carry it
#    (dscp_remote_ids map, server-side/VPS: every subflow shares the same
#    local IP there, but remote_id is the address id the router assigned
#    to that WAN and stays stable across the router's WAN IP changing).
#    One id per address of the WAN: a dual-stack WAN has its metric for
#    IPv4 and +128/+192 for IPv6 (see the router's multipath script).

MAP_PATH="/sys/fs/bpf/dscp_iface"
MAP_PATH2="/sys/fs/bpf/dscp_remote_ids"
# Single id per class, pinned by an mptcp-bpf-dscp older than the id set
MAP_PATH2_OLD="/sys/fs/bpf/dscp_remote_id"

# Check required commands
for cmd in bpftool ip; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Error: command '$cmd' not found."
		exit 1
	fi
done

# Check BPF map existence
if [ ! -e "$MAP_PATH" ]; then
	echo "Error: BPF map not found at $MAP_PATH"
	exit 1
fi

# Convert a DSCP class name (or raw 0-63 number) to its numeric codepoint
dscp_to_val() {
	case "$1" in
		cs0) echo 0 ;;
		cs1) echo 8 ;;
		cs2) echo 16 ;;
		cs3) echo 24 ;;
		cs4) echo 32 ;;
		cs5) echo 40 ;;
		cs6) echo 48 ;;
		cs7) echo 56 ;;
		le) echo 1 ;;
		af11) echo 10 ;;
		af12) echo 12 ;;
		af13) echo 14 ;;
		af21) echo 18 ;;
		af22) echo 20 ;;
		af23) echo 22 ;;
		af31) echo 26 ;;
		af32) echo 28 ;;
		af33) echo 30 ;;
		af41) echo 34 ;;
		af42) echo 36 ;;
		af43) echo 38 ;;
		ef) echo 46 ;;
		''|*[!0-9]*) echo "" ;;
		*) [ "$1" -ge 0 ] 2>/dev/null && [ "$1" -le 63 ] 2>/dev/null && echo "$1" || echo "" ;;
	esac
}

# Convert integer to little-endian hex (4 bytes)
to_le_hex() {
	printf "%08x" "$1" | sed 's/../& /g' | awk '{for(i=4;i>=1;i--) printf $i " "}'
}

to_byte_hex() {
	printf "%02x" "$1"
}

# Extract decimal value from bpftool map lookup output.
# $1 = key hex, $2 = pinned map path (defaults to $MAP_PATH)
get_value_from_key() {
	KEY_HEX="$1"
	MAP="${2:-$MAP_PATH}"
	bpftool map lookup pinned "$MAP" key hex $KEY_HEX 2>/dev/null | \
		awk '/"value":/ {
			for(i=1;i<=NF;i++) {
				if ($i ~ /^[0-9]+$/) {
					print $i
					exit
				}
			}
		}'
}

# The dscp_remote_ids value for the ids $@: a 256-bit set, bit (id & 7) of
# byte (id >> 3), as hex bytes for bpftool
ids_to_set_hex() {
	local byte bit id hex=""
	byte=0
	while [ "$byte" -lt 32 ]; do
		bit=0
		for id in "$@"; do
			[ $((id >> 3)) -eq "$byte" ] && bit=$((bit | (1 << (id & 7))))
		done
		hex="$hex $(to_byte_hex "$bit")"
		byte=$((byte + 1))
	done
	echo $hex
}

# The raw value bytes ("0x10"...) of the entry for key $1 (hex) in the map
# $2, from bpftool's JSON: its plain output is laid out by the map's BTF
# and spread over several lines.
get_value_bytes() {
	bpftool -j map lookup pinned "$2" key hex $1 2>/dev/null | \
		sed -n 's/.*"value":\[\([^]]*\)\].*/\1/p' | tr -d '"' | tr ',' ' '
}

# The ids of the dscp_remote_ids entry for key $1 (hex), space separated
get_remote_ids_from_key() {
	local byte val bit idx=0 ids=""
	for byte in $(get_value_bytes "$1" "$MAP_PATH2"); do
		val=$((byte))
		bit=0
		while [ "$bit" -lt 8 ]; do
			[ $(((val >> bit) & 1)) -eq 1 ] && ids="$ids $((idx * 8 + bit))"
			bit=$((bit + 1))
		done
		idx=$((idx + 1))
	done
	echo $ids
}

# Remote ids pinned for key $1 (hex), from whichever map this
# mptcp-bpf-dscp has
get_remote_ids() {
	local byte
	if [ -e "$MAP_PATH2" ]; then
		get_remote_ids_from_key "$1"
	elif [ -e "$MAP_PATH2_OLD" ]; then
		for byte in $(get_value_bytes "$1" "$MAP_PATH2_OLD"); do
			echo $((byte))
		done
	fi
}

# Get BPF endpoint IP (decimal, LE-integer form) from interface name
get_bpf_ep_ip_from_iface() {
	iface="$1"
	# The device is compared as a field, not as a regex ("dev eth0.2"
	# matched eth0.20, the "." any character), and only an IPv4 address
	# is a key of the map: on a dual-stack WAN whose IPv6 endpoint came
	# first, the IPv4 conversion below turned "2001:db8::1" into 2001.
	ep_ips=$(ip mptcp endpoint show | awk -v dev="$iface" '
		$1 !~ /:/ {
			for (i = 2; i < NF; i++)
				if ($i == "dev" && $(i + 1) == dev) { print $1; exit }
		}')
	if [ -z "$ep_ips" ]; then
		return 1
	fi
	echo "$ep_ips" | while read -r ip; do
		echo "$ip" | awk -F. '{print ($4 * 256^3) + ($3 * 256^2) + ($2 * 256) + $1}'
	done
	return 0
}

usage() {
	echo "Usage:"
	echo "  $0 show                    # Show all configured DSCP pins"
	echo "  $0 show <dscp>              # Show pin for one DSCP class/value"
	echo "  $0 set <dscp> <interface>   # Pin a DSCP class to a local WAN interface (router-side)"
	echo "  $0 set <dscp> id <N>...     # Pin a DSCP class to remote endpoint ids 0-255 (server/VPS-side)"
	echo "  $0 del <dscp>               # Remove a DSCP pin (both forms)"
	echo "  $0 prune [<dscp>...]        # Remove the interface pins of every other DSCP class"
	echo "  $0 debug                    # Show live BPF trace output"
	echo ""
	echo "<dscp> can be a class name (cs0-cs7, af11-af43, ef, le) or a raw 0-63 value."
	echo ""
	echo "Use 'set <dscp> <interface>' on the router, where each WAN has its own local"
	echo "endpoint IP. Use 'set <dscp> id <N>...' on the server (VPS) side, where every"
	echo "subflow shares the same local IP: <N> are the MPTCP endpoint ids the router"
	echo "assigned to that WAN (kept stable across reconnects, e.g. via 'multipath"
	echo "<iface> on <N>' or network.<iface>.ip4table, +128/+192 for its IPv6"
	echo "addresses)."
	exit 1
}

ACTION="$1"

case "$ACTION" in
show)
	if [ "$#" -eq 1 ]; then
		DSCP_LIST="cs0 cs1 cs2 cs3 cs4 cs5 cs6 cs7 le af11 af12 af13 af21 af22 af23 af31 af32 af33 af41 af42 af43 ef"
		for name in $DSCP_LIST; do
			val=$(dscp_to_val "$name")
			KEY_HEX=$(to_byte_hex "$val")
			BPF_EP_IP=$(get_value_from_key "$KEY_HEX" "$MAP_PATH")
			if [ -n "$BPF_EP_IP" ]; then
				EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
				echo "dscp=$name (${val}) endpoint_ip=$EP_IP"
			fi
			BPF_REMOTE_ID=$(get_remote_ids "$KEY_HEX")
			[ -n "$BPF_REMOTE_ID" ] && echo "dscp=$name (${val}) remote_id=$BPF_REMOTE_ID"
		done
		exit 0
	elif [ "$#" -eq 2 ]; then
		val=$(dscp_to_val "$2")
		[ -z "$val" ] && { echo "Unknown DSCP class '$2'"; exit 1; }
		KEY_HEX=$(to_byte_hex "$val")
		BPF_EP_IP=$(get_value_from_key "$KEY_HEX" "$MAP_PATH")
		BPF_REMOTE_ID=$(get_remote_ids "$KEY_HEX")
		if [ -z "$BPF_EP_IP" ] && [ -z "$BPF_REMOTE_ID" ]; then
			echo "dscp=$2 (${val}) not pinned"
			exit 0
		fi
		if [ -n "$BPF_EP_IP" ]; then
			EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
			echo "dscp=$2 (${val}) endpoint_ip=$EP_IP"
		fi
		[ -n "$BPF_REMOTE_ID" ] && echo "dscp=$2 (${val}) remote_id=$BPF_REMOTE_ID"
		exit 0
	else
		usage
	fi
	;;

set)
	if [ "$3" = "id" ] && [ "$#" -lt 4 ]; then
		echo "Usage: $0 set <dscp> id <N>..."
		exit 1
	fi
	if [ "$#" -ge 4 ] && [ "$3" = "id" ]; then
		# Server/VPS-side: pin by MPTCP remote endpoint ids.
		val=$(dscp_to_val "$2")
		[ -z "$val" ] && { echo "Unknown DSCP class '$2'"; exit 1; }
		DSCP_NAME="$2"
		shift 3
		for REMOTE_ID in "$@"; do
			case "$REMOTE_ID" in
				''|*[!0-9]*) echo "Remote id must be a number 0-255"; exit 1 ;;
			esac
			{ [ "$REMOTE_ID" -ge 0 ] && [ "$REMOTE_ID" -le 255 ]; } 2>/dev/null || {
				echo "Remote id must be a number 0-255"
				exit 1
			}
		done
		KEY_HEX=$(to_byte_hex "$val")
		if [ -e "$MAP_PATH2" ]; then
			VALUE_HEX=$(ids_to_set_hex "$@")
			MAP="$MAP_PATH2"
		elif [ -e "$MAP_PATH2_OLD" ]; then
			# An older mptcp-bpf-dscp only takes one id: the first is the
			# WAN's IPv4 one
			[ "$#" -gt 1 ] && echo "Warning: this mptcp-bpf-dscp pins one id only, using $1"
			VALUE_HEX=$(to_byte_hex "$1")
			MAP="$MAP_PATH2_OLD"
			set -- "$1"
		else
			echo "Error: BPF map not found at $MAP_PATH2 (rebuild/upgrade mptcp-bpf-dscp?)"
			exit 1
		fi
		if ! bpftool map update pinned "$MAP" key hex $KEY_HEX value hex $VALUE_HEX; then
			echo "Error updating map"
			exit 1
		fi
		echo "DSCP pin updated: dscp=$DSCP_NAME (${val}) remote_id=$*"
		exit 0
	fi

	[ "$#" -eq 3 ] || usage
	val=$(dscp_to_val "$2")
	[ -z "$val" ] && { echo "Unknown DSCP class '$2'"; exit 1; }
	IFACE="$3"

	found=0
	# NOT "get_bpf_ep_ip_from_iface ... | while read ...": piping into a
	# while loop runs the loop in a SUBSHELL under POSIX sh (dash, this
	# script's own #!/bin/sh on Debian -- confirmed live, "found"'s
	# post-loop check needs to see what the loop body set), losing the
	# "found=1" assignment the moment the loop exits. The original used
	# bash-only "done < <(...)" process substitution to dodge that,
	# which fails outright on a real POSIX sh with "Syntax error:
	# redirection unexpected" (also confirmed live) -- process
	# substitution isn't POSIX, dash doesn't implement it, and this
	# script's shebang promises plain sh, not bash specifically. A
	# heredoc keeps the loop in the current shell (no subshell) while
	# staying POSIX.
	BPF_EP_IPS_LIST="$(get_bpf_ep_ip_from_iface "$IFACE")"
	while read -r BPF_EP_IP; do
		[ -z "$BPF_EP_IP" ] && continue
		found=1
		KEY_HEX=$(to_byte_hex "$val")
		VALUE_HEX=$(to_le_hex "$BPF_EP_IP")

		if ! bpftool map update pinned "$MAP_PATH" key hex $KEY_HEX value hex $VALUE_HEX; then
			echo "Error updating map"
			exit 1
		fi

		EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
		echo "DSCP pin updated: dscp=$2 (${val}) interface=$IFACE endpoint_ip=$EP_IP"
	done <<-EOF
		$BPF_EP_IPS_LIST
	EOF

	if [ "$found" -eq 0 ]; then
		echo "Interface '$IFACE' not found"
		exit 1
	fi
	exit 0
	;;

del)
	[ "$#" -eq 2 ] || usage
	val=$(dscp_to_val "$2")
	[ -z "$val" ] && { echo "Unknown DSCP class '$2'"; exit 1; }
	KEY_HEX=$(to_byte_hex "$val")
	bpftool map delete pinned "$MAP_PATH" key hex $KEY_HEX >/dev/null 2>&1
	[ -e "$MAP_PATH2" ] && bpftool map delete pinned "$MAP_PATH2" key hex $KEY_HEX >/dev/null 2>&1
	[ -e "$MAP_PATH2_OLD" ] && bpftool map delete pinned "$MAP_PATH2_OLD" key hex $KEY_HEX >/dev/null 2>&1
	echo "DSCP pin removed: dscp=$2 (${val})"
	exit 0
	;;

prune)
	# Pins are only ever set from the rows of the DSCP routing page, so a
	# deleted row left its class pinned to its WAN until the map went away
	# (a reboot). Every class of dscp_iface not given here is removed.
	shift
	keep=""
	for name in "$@"; do
		val=$(dscp_to_val "$name")
		[ -n "$val" ] && keep="$keep $val"
	done
	for hex in $(bpftool -j map dump pinned "$MAP_PATH" 2>/dev/null | \
		grep -o '"key":\["0x[0-9a-fA-F]*"' | sed 's/.*"0x//;s/"//'); do
		val=$((0x$hex))
		case " $keep " in
			*" $val "*) continue ;;
		esac
		bpftool map delete pinned "$MAP_PATH" key hex $(to_byte_hex "$val") >/dev/null 2>&1 && \
			echo "DSCP pin removed: dscp=$val"
	done
	exit 0
	;;

debug)
	# Prefer the plain tracefs mount (/sys/kernel/tracing) -- confirmed
	# live (bench router + VPS, 2026-08-07) that debugfs's
	# /sys/kernel/debug/tracing doesn't exist on either machine even
	# with debugfs mounted, while tracefs is auto-mounted at
	# /sys/kernel/tracing regardless. Still fall back to the debugfs
	# path for systems where that's the only one present.
	TRACE_PIPE="/sys/kernel/tracing/trace_pipe"
	[ -r "$TRACE_PIPE" ] || TRACE_PIPE="/sys/kernel/debug/tracing/trace_pipe"
	if [ ! -r "$TRACE_PIPE" ]; then
		echo "Error: Cannot read BPF trace. Are you root? Is tracefs mounted?"
		exit 1
	fi
	echo "Reading BPF trace output (Ctrl+C to stop)..."
	cat "$TRACE_PIPE"
	exit 0
	;;

*)
	usage
	;;
esac
