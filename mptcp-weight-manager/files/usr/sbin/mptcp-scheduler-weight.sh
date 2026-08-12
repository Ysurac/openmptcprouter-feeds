#!/bin/sh
# MPTCP Burst Weight Scheduler Manager
# (c) Yannick Chabanois for Stellar
#
# Manages the pinned BPF maps used by the bpf_weight/bpf_weight_rr
# schedulers: maps either a local WAN endpoint IP (router-side, each WAN
# has a distinct local IP) or an MPTCP remote endpoint id (server/VPS-side,
# every subflow shares the same local IP there) to a weight. Same
# router/VPS split as mptcp-scheduler-dscp.sh's dscp_iface/dscp_remote_id
# -- see that script's header comment for the underlying reasoning.

MAP_PATH="/sys/fs/bpf/endpoint_weights"
MAP_PATH2="/sys/fs/bpf/weight_remote_id"

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

# Convert integer to little-endian hex (4 bytes)
to_le_hex() {
	printf "%08x" "$1" | sed 's/../& /g' | awk '{for(i=4;i>=1;i--) printf $i " "}'
}

to_byte_hex() {
	printf "%02x" "$1"
}

# Extract decimal weight from bpftool map lookup output.
# $1 = key hex, $2 = pinned map path (defaults to $MAP_PATH)
get_weight_from_key() {
	KEY_HEX="$1"
	MAP="${2:-$MAP_PATH}"
	# $KEY_HEX must stay unquoted — see the "set" branch below for why.
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

# Get BPF endpoint IP from interface name
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
		# Convert IP to decimal
		echo "$ip" | awk -F. '{print ($4 * 256^3) + ($3 * 256^2) + ($2 * 256) + $1}'
	done
	return 0
}

is_uint_0_255() {
	case "$1" in
		''|*[!0-9]*) return 1 ;;
	esac
	[ "$1" -ge 0 ] 2>/dev/null && [ "$1" -le 255 ] 2>/dev/null
}

usage() {
	echo "Usage:"
	echo "  $0 show                  # Show all weights (router interfaces + VPS remote ids)"
	echo "  $0 show <interface>      # Show weight for a router-side interface"
	echo "  $0 show id <N>           # Show weight pinned to remote endpoint id <N> (server/VPS-side)"
	echo "  $0 set <interface> <w>   # Set weight for a router-side interface"
	echo "  $0 set id <N> <w>        # Set weight for remote endpoint id <N> (server/VPS-side)"
	echo "  $0 del <interface>       # Remove a router-side interface's weight (resets to neutral 100)"
	echo "  $0 del id <N>            # Remove a remote endpoint id's weight (server/VPS-side)"
	echo "  $0 debug                 # Show live BPF trace output"
	echo ""
	echo "Use 'set <interface> <w>' on the router, where each WAN has its own local"
	echo "endpoint IP. Use 'set id <N> <w>' on the server (VPS), where every subflow"
	echo "shares the same local IP: <N> is the MPTCP endpoint id the router assigned"
	echo "to that WAN (kept stable across reconnects, e.g. via network.<iface>.ip4table)."
	exit 1
}

ACTION="$1"

if [ "$ACTION" = "show" ]; then
	if [ "$#" -eq 1 ]; then
		ip mptcp endpoint show | while read -r line; do
			IP_EP=$(echo "$line" | awk '{print $1}')
			IFACE=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')

			if [ -n "$IP_EP" ] && [ -n "$IFACE" ]; then
				#BPF_EP_IP=$(echo $IP_EP | awk -F. '{print ($1*16777216)+($2*65536)+($3*256)+$4}')
				BPF_EP_IP=$(echo "$IP_EP" | awk -F. '{print ($4 * 256^3) + ($3 * 256^2) + ($2 * 256) + $1}')
				KEY_HEX=$(to_le_hex "$BPF_EP_IP")
				WEIGHT=$(get_weight_from_key "$KEY_HEX")

				if [ -z "$WEIGHT" ]; then
					WEIGHT=100
				fi

				echo "interface=$IFACE endpoint_ip=$IP_EP weight=$WEIGHT"
			fi
		done
		if [ -e "$MAP_PATH2" ]; then
			bpftool map dump pinned "$MAP_PATH2" 2>/dev/null | awk '
				/"key":/   { k=$2; gsub(/,/, "", k) }
				/"value":/ { v=$2; gsub(/,/, "", v); print "remote_id="k" weight="v }'
		fi
		exit 0

	elif [ "$#" -eq 2 ] && [ "$2" = "id" ]; then
		usage

	elif [ "$#" -eq 2 ]; then
		IFACE="$2"

		get_bpf_ep_ip_from_iface "$IFACE" | while read -r BPF_EP_IP; do
			if [ -z "$BPF_EP_IP" ]; then
				echo "Interface '$IFACE' not found"
				exit 1
			fi

			KEY_HEX=$(to_le_hex "$BPF_EP_IP")
			WEIGHT=$(get_weight_from_key "$KEY_HEX")

			if [ -z "$WEIGHT" ]; then
				WEIGHT=100
			fi

			EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
			echo "interface=$IFACE endpoint_ip=$EP_IP weight=$WEIGHT"
		done
		exit 0

	elif [ "$#" -eq 3 ] && [ "$2" = "id" ]; then
		REMOTE_ID="$3"
		is_uint_0_255 "$REMOTE_ID" || { echo "Remote id must be a number 0-255"; exit 1; }
		if [ ! -e "$MAP_PATH2" ]; then
			echo "Error: BPF map not found at $MAP_PATH2 (rebuild/upgrade mptcp-bpf-weight?)"
			exit 1
		fi
		KEY_HEX=$(to_byte_hex "$REMOTE_ID")
		WEIGHT=$(get_weight_from_key "$KEY_HEX" "$MAP_PATH2")
		[ -z "$WEIGHT" ] && WEIGHT=100
		echo "remote_id=$REMOTE_ID weight=$WEIGHT"
		exit 0

	else
		usage
	fi

elif [ "$ACTION" = "set" ]; then
	if [ "$2" = "id" ]; then
		[ "$#" -eq 4 ] || usage
		REMOTE_ID="$3"
		WEIGHT="$4"
		is_uint_0_255 "$REMOTE_ID" || { echo "Remote id must be a number 0-255"; exit 1; }
		if [ ! -e "$MAP_PATH2" ]; then
			echo "Error: BPF map not found at $MAP_PATH2 (rebuild/upgrade mptcp-bpf-weight?)"
			exit 1
		fi
		KEY_HEX=$(to_byte_hex "$REMOTE_ID")
		VALUE_HEX=$(to_le_hex "$WEIGHT")
		if ! bpftool map update pinned "$MAP_PATH2" key hex $KEY_HEX value hex $VALUE_HEX; then
			echo "Error updating map"
			exit 1
		fi
		echo "Weight updated: remote_id=$REMOTE_ID weight=$WEIGHT"
		exit 0
	fi

	if [ "$#" -ne 3 ]; then
		usage
	fi

	IFACE="$2"
	WEIGHT="$3"
	BPF_EP_IPS="$(get_bpf_ep_ip_from_iface "$IFACE")"

	if [ -z "$BPF_EP_IPS" ]; then
		echo "Interface '$IFACE' not found"
		exit 1
	fi

	echo "$BPF_EP_IPS" | while read -r BPF_EP_IP; do
		KEY_HEX=$(to_le_hex "$BPF_EP_IP")
		VALUE_HEX=$(to_le_hex "$WEIGHT")

		# KEY_HEX/VALUE_HEX must stay unquoted: bpftool's "key hex" and
		# "value hex" syntax takes each byte as its own argument, and
		# to_le_hex() returns a space-separated byte list that needs
		# word-splitting to reach bpftool that way.
		if ! bpftool map update pinned "$MAP_PATH" key hex $KEY_HEX value hex $VALUE_HEX; then
			echo "Error updating map"
			exit 1
		fi

		EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
		echo "Weight updated: interface=$IFACE endpoint_ip=$EP_IP weight=$WEIGHT"
	done || exit 1
	exit 0

elif [ "$ACTION" = "del" ]; then
	if [ "$2" = "id" ]; then
		[ "$#" -eq 3 ] || usage
		REMOTE_ID="$3"
		is_uint_0_255 "$REMOTE_ID" || { echo "Remote id must be a number 0-255"; exit 1; }
		[ -e "$MAP_PATH2" ] || { echo "Error: BPF map not found at $MAP_PATH2"; exit 1; }
		KEY_HEX=$(to_byte_hex "$REMOTE_ID")
		bpftool map delete pinned "$MAP_PATH2" key hex $KEY_HEX >/dev/null 2>&1
		echo "Weight removed: remote_id=$REMOTE_ID (reset to neutral 100)"
		exit 0
	fi

	[ "$#" -eq 2 ] || usage
	IFACE="$2"
	BPF_EP_IPS="$(get_bpf_ep_ip_from_iface "$IFACE")"
	if [ -z "$BPF_EP_IPS" ]; then
		echo "Interface '$IFACE' not found"
		exit 1
	fi
	echo "$BPF_EP_IPS" | while read -r BPF_EP_IP; do
		KEY_HEX=$(to_le_hex "$BPF_EP_IP")
		bpftool map delete pinned "$MAP_PATH" key hex $KEY_HEX >/dev/null 2>&1
		EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
		echo "Weight removed: interface=$IFACE endpoint_ip=$EP_IP (reset to neutral 100)"
	done
	exit 0

elif [ "$ACTION" = "debug" ]; then
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

else
	usage
fi
