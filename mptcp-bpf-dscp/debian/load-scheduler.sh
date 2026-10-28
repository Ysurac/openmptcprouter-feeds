#!/bin/sh
# Loads/pins (or unloads/unpins) the bpf_dscp MPTCP struct_ops scheduler.
# It does not choose net.mptcp.scheduler: the VPS installer installs
# every mptcp-bpf-* package and their units all start at boot, so a
# unit that set the sysctl to its own scheduler raced the others and
# overrode the scheduler the router picked (omradmin writes it to
# /etc/sysctl.d/90-shadowsocks.conf). start only applies the
# configured value, and only when it names this scheduler.
#
# Pin_dir layout (pin_dir="/sys/fs/bpf/mptcp") mirrors the router-side
# mptcp init script (mptcp/files/etc/init.d/mptcp in the
# openmptcprouter-feeds repo), so both ends of an OpenMPTCProuter
# multipath link use the same layout -- but NOT that script's
# unregister loop, which has a confirmed-live bug (see below); multiple
# different struct_ops CAN coexist registered simultaneously (confirmed
# live: a VPS had 5 different schedulers -- red/bkup/rr/first/burst --
# registered at once with no conflict), so unregistering anything other
# than the ONE this script itself manages is both unnecessary and, as
# implemented in that other script, broken anyway.

set -e

BPF_OBJ="/usr/share/bpf/scheduler/mptcp_bpf_dscp.o"
PIN_DIR="/sys/fs/bpf/mptcp"
# PIN_NAME matches the struct_ops variable name in the .c source
# (mptcp_bpf_dscp.c: "struct mptcp_sched_ops dscp = {...}") -- what
# `bpftool struct_ops register ... $PIN_DIR/` actually names the pinned
# file, i.e. $PIN_DIR/dscp. This is NOT the same string as SCHED_NAME
# below (the .name field inside that struct, used only for
# net.mptcp.scheduler) -- confirmed via `bpftool struct_ops list`
# showing short names (red, bkup, rr, ...) matching the C variable, not
# the "bpf_"-prefixed sysctl name.
PIN_NAME="dscp"
SCHED_NAME="bpf_dscp"

unregister_this() {
	# `bpftool struct_ops unregister pinned <path>` is NOT valid syntax
	# -- confirmed live (same bpftool v7.6.0 on both an OpenWrt router
	# and this Debian VPS): it just prints usage and exits 255. Only
	# `id <ID>` or `name <NAME>` are accepted selectors for unregister
	# (register, unlike unregister, does take a pin *directory* as its
	# second arg -- different subcommand, different syntax). Reference
	# by name instead, and only ever touch the one this script manages.
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
	# Switch away from bpf_dscp *before* unregistering it, otherwise
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
