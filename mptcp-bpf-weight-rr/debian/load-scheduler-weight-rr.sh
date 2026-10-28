#!/bin/sh
# Loads/pins (or unloads/unpins) the bpf_weight_rr MPTCP struct_ops scheduler.
# It does not choose net.mptcp.scheduler: the VPS installer installs
# every mptcp-bpf-* package and their units all start at boot, so a
# unit that set the sysctl to its own scheduler raced the others and
# overrode the scheduler the router picked (omradmin writes it to
# /etc/sysctl.d/90-shadowsocks.conf). start only applies the
# configured value, and only when it names this scheduler.
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

configured_scheduler() {
	# Last net.mptcp.scheduler line of sysctl.d, the order systemd-sysctl
	# applies them in. omradmin may have stored the .o file stem
	# (mptcp_bpf_<x>) before it normalizes it: strip that prefix.
	cat /etc/sysctl.d/*.conf /etc/sysctl.conf 2>/dev/null | \
		sed -n 's/^[[:space:]]*net\.mptcp\.scheduler[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/p' | \
		tail -n 1 | sed 's/^mptcp_//'
}

case "$1" in
start)
	mountpoint -q /sys/fs/bpf || mount -t bpf bpf /sys/fs/bpf
	mkdir -p "$PIN_DIR"
	unregister_this
	bpftool struct_ops register "$BPF_OBJ" "$PIN_DIR/"
	# systemd-sysctl may have run before the register (the write fails
	# then), and a package upgrade's stop just reset it to default.
	if [ "$(configured_scheduler)" = "$SCHED_NAME" ]; then
		sysctl -q -w net.mptcp.scheduler="$SCHED_NAME" || true
	fi
	;;
stop)
	# Switch away from bpf_weight_rr *before* unregistering it, otherwise
	# net.mptcp.scheduler is left pointing at a scheduler name the
	# kernel no longer has. Leave any other scheduler alone.
	if [ "$(sysctl -n net.mptcp.scheduler 2>/dev/null || true)" = "$SCHED_NAME" ]; then
		sysctl -q -w net.mptcp.scheduler=default >/dev/null 2>&1 || true
	fi
	unregister_this
	;;
*)
	echo "Usage: $0 {start|stop}" >&2
	exit 1
	;;
esac
