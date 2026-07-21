#!/bin/sh
# MPTCP Burst Weight Scheduler Manager
# (c) Yannick Chabanois for Stellar

MAP_PATH="/sys/fs/bpf/endpoint_weights"

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

# Extract decimal weight from bpftool map lookup output
get_weight_from_key() {
	KEY_HEX="$1"
	WEIGHT=$(bpftool map lookup pinned "$MAP_PATH" key hex "$KEY_HEX" 2>/dev/null | \
		awk '/"value":/ {
			for(i=1;i<=NF;i++) {
				if ($i ~ /^[0-9]+$/) {
					print $i
					exit
				}
			}
		}')
	echo "$WEIGHT"
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

usage() {
	echo "Usage:"
	echo "  $0 show [interface]       # Show weight(s)"
	echo "  $0 set <interface> <w>    # Set weight"
	echo "  $0 debug                  # Show live BPF trace output"
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
		exit 0

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

	else
		usage
	fi

elif [ "$ACTION" = "set" ]; then
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

		if ! bpftool map update pinned "$MAP_PATH" key hex "$KEY_HEX" value hex "$VALUE_HEX"; then
			echo "Error updating map"
			exit 1
		fi

		EP_IP=$(printf "%d.%d.%d.%d\n" $(( BPF_EP_IP & 255 )) $(( (BPF_EP_IP >> 8) & 255 )) $(( (BPF_EP_IP >> 16) & 255 )) $(( (BPF_EP_IP >> 24) & 255 )) )
		echo "Weight updated: interface=$IFACE endpoint_ip=$EP_IP weight=$WEIGHT"
	done || exit 1
	exit 0

elif [ "$ACTION" = "debug" ]; then
	if [ ! -r /sys/kernel/debug/tracing/trace_pipe ]; then
		echo "Error: Cannot read BPF trace. Are you root? Is debugfs mounted?"
		exit 1
	fi

	echo "Reading BPF trace output (Ctrl+C to stop)..."
	cat /sys/kernel/debug/tracing/trace_pipe
	exit 0

else
	usage
fi
