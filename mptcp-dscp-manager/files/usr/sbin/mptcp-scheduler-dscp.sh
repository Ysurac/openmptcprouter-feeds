#!/bin/sh
# MPTCP DSCP Scheduler Manager
# (c) Yannick Chabanois for OpenMPTCProuter
#
# Manages the pinned dscp_iface BPF map used by the bpf_dscp scheduler
# (mptcp-bpf-dscp): maps a DSCP class to the local endpoint IP of the
# WAN interface that should carry it.

MAP_PATH="/sys/fs/bpf/dscp_iface"

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

# Extract decimal value from bpftool map lookup output
get_value_from_key() {
	KEY_HEX="$1"
	bpftool map lookup pinned "$MAP_PATH" key hex $KEY_HEX 2>/dev/null | \
		awk '/"value":/ {
			for(i=1;i<=NF;i++) {
				if ($i ~ /^[0-9]+$/) {
					print $i
					exit
				}
			}
		}'
}

# Get BPF endpoint IP (decimal, LE-integer form) from interface name
get_bpf_ep_ip_from_iface() {
	iface="$1"
	ep_ips=$(ip mptcp endpoint show | awk -v dev="$iface" '
		$0 ~ "dev "dev {
			{ print $1; exit }
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
	echo "  $0 set <dscp> <interface>   # Pin a DSCP class to an interface"
	echo "  $0 del <dscp>               # Remove a DSCP pin"
	echo "  $0 debug                    # Show live BPF trace output"
	echo ""
	echo "<dscp> can be a class name (cs0-cs7, af11-af43, ef, le) or a raw 0-63 value."
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
			BPF_EP_IP=$(get_value_from_key "$KEY_HEX")
			[ -z "$BPF_EP_IP" ] && continue
			EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
			echo "dscp=$name (${val}) endpoint_ip=$EP_IP"
		done
		exit 0
	elif [ "$#" -eq 2 ]; then
		val=$(dscp_to_val "$2")
		[ -z "$val" ] && { echo "Unknown DSCP class '$2'"; exit 1; }
		KEY_HEX=$(to_byte_hex "$val")
		BPF_EP_IP=$(get_value_from_key "$KEY_HEX")
		if [ -z "$BPF_EP_IP" ]; then
			echo "dscp=$2 (${val}) not pinned"
			exit 0
		fi
		EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
		echo "dscp=$2 (${val}) endpoint_ip=$EP_IP"
		exit 0
	else
		usage
	fi
	;;

set)
	[ "$#" -eq 3 ] || usage
	val=$(dscp_to_val "$2")
	[ -z "$val" ] && { echo "Unknown DSCP class '$2'"; exit 1; }
	IFACE="$3"

	found=0
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
	done < <(get_bpf_ep_ip_from_iface "$IFACE")

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
	echo "DSCP pin removed: dscp=$2 (${val})"
	exit 0
	;;

debug)
	if [ ! -r /sys/kernel/debug/tracing/trace_pipe ]; then
		echo "Error: Cannot read BPF trace. Are you root? Is debugfs mounted?"
		exit 1
	fi
	echo "Reading BPF trace output (Ctrl+C to stop)..."
	cat /sys/kernel/debug/tracing/trace_pipe
	exit 0
	;;

*)
	usage
	;;
esac
