#!/bin/sh
# Loads/pins (or unloads/unpins) the bpf_dscp MPTCP struct_ops scheduler
# and switches net.mptcp.scheduler to/from it.
#
# Mirrors the pin_dir layout and register/unregister convention used by
# the router-side mptcp init script (mptcp/files/etc/init.d/mptcp in the
# openmptcprouter-feeds repo: pin_dir="/sys/fs/bpf/mptcp", iterate and
# unregister every existing pin there before registering the new one),
# so both ends of an OpenMPTCProuter multipath link use the same layout.

set -e

BPF_OBJ="/usr/share/bpf/scheduler/mptcp_bpf_dscp.o"
PIN_DIR="/sys/fs/bpf/mptcp"
SCHED_NAME="bpf_dscp"

unregister_all() {
	for pin in "$PIN_DIR"/*; do
		[ -e "$pin" ] || continue
		bpftool struct_ops unregister pinned "$pin" >/dev/null 2>&1
		rm -f "$pin"
	done
}

case "$1" in
start)
	mountpoint -q /sys/fs/bpf || mount -t bpf bpf /sys/fs/bpf
	mkdir -p "$PIN_DIR"
	unregister_all
	bpftool struct_ops register "$BPF_OBJ" "$PIN_DIR/"
	sysctl -q -w net.mptcp.scheduler="$SCHED_NAME"
	;;
stop)
	# Switch away from bpf_dscp *before* unregistering it, otherwise
	# net.mptcp.scheduler is left pointing at a scheduler name the
	# kernel no longer has, which would break new MPTCP connections.
	sysctl -q -w net.mptcp.scheduler=default >/dev/null 2>&1 || true
	unregister_all
	;;
*)
	echo "Usage: $0 {start|stop}" >&2
	exit 1
	;;
esac
