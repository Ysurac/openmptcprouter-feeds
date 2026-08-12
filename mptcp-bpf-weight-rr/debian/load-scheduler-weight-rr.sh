#!/bin/sh
# Loads/pins (or unloads/unpins) the bpf_weight_rr MPTCP struct_ops
# scheduler and switches net.mptcp.scheduler to/from it.
#
# Pin_dir layout mirrors mptcp-bpf-dscp's load-scheduler.sh and the
# router-side mptcp init script, but NOT their unregister-everything
# loop -- see mptcp-bpf-dscp/debian/load-scheduler.sh's header comment
# for why that's both unnecessary (multiple different struct_ops CAN
# coexist registered simultaneously, confirmed live) and, as
# implemented there, broken anyway (`unregister pinned <path>` isn't
# valid bpftool syntax; only `id`/`name` are).

set -e

BPF_OBJ="/usr/share/bpf/scheduler/mptcp_bpf_weight_rr.o"
PIN_DIR="/sys/fs/bpf/mptcp"
# Matches the struct_ops variable name in mptcp_bpf_weight_rr.c ("struct
# mptcp_sched_ops weight_rr = {...}"), i.e. what gets pinned at
# $PIN_DIR/weight_rr -- NOT the same as SCHED_NAME below (that struct's
# .name field, used only for net.mptcp.scheduler).
PIN_NAME="weight_rr"
SCHED_NAME="bpf_weight_rr"

unregister_this() {
	bpftool struct_ops unregister name "$PIN_NAME" >/dev/null 2>&1 || true
	rm -f "$PIN_DIR/$PIN_NAME"
}

case "$1" in
start)
	mountpoint -q /sys/fs/bpf || mount -t bpf bpf /sys/fs/bpf
	mkdir -p "$PIN_DIR"
	unregister_this
	bpftool struct_ops register "$BPF_OBJ" "$PIN_DIR/"
	sysctl -q -w net.mptcp.scheduler="$SCHED_NAME"
	;;
stop)
	# Switch away from bpf_weight_rr *before* unregistering it,
	# otherwise net.mptcp.scheduler is left pointing at a scheduler
	# name the kernel no longer has, which would break new MPTCP
	# connections.
	sysctl -q -w net.mptcp.scheduler=default >/dev/null 2>&1 || true
	unregister_this
	;;
*)
	echo "Usage: $0 {start|stop}" >&2
	exit 1
	;;
esac
