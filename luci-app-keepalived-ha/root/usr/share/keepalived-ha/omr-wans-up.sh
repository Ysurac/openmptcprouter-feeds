#!/bin/sh
# Report WAN pool health for keepalived priority tracking.
# Exit 0 = every tracked WAN is healthy, non-zero = demote this node by one
# rank (vrrp_script weight -15): node priorities are spaced 10 apart, so a
# degraded node slots just below its healthy neighbour while staying above
# the nodes further down the list - unlike the -200 VPN/proxy checks that
# drop an unhealthy node below every healthy one. When all nodes lose the
# same carrier they are demoted alike and the preference order is kept.
#
# A WAN is tracked when it takes part in multipath (master/on/backup/
# handover) and is not disabled. Healthy = the device holds a global IPv4
# or IPv6 address (catches config wipes such as a lost static ipaddr, which
# also makes the address-less device ARP-advertise the router's LAN IP on
# the wrong segment) and the omr-tracker verdict
# (openmptcprouter.<itf>.state) is not 'down'.
# No tracked WANs at all = healthy so tracking never demotes anyone.

. /lib/functions.sh

WANS_DOWN=0

kaha_check_wan() {
	local name="$1" multipath auto dev

	config_get multipath "$name" multipath
	case "$multipath" in
		master | on | backup | handover) ;;
		*) return 0 ;;
	esac

	config_get auto "$name" auto
	[ "$auto" = "0" ] && return 0

	if [ "$(uci -q get "openmptcprouter.$name.state")" = "down" ]; then
		WANS_DOWN=$((WANS_DOWN + 1))
		return 0
	fi

	network_get_device dev "$name"
	[ -n "$dev" ] || config_get dev "$name" device
	[ -n "$dev" ] || return 0
	ip -4 addr show dev "$dev" scope global 2>/dev/null | grep -q 'inet ' && return 0
	ip -6 addr show dev "$dev" scope global 2>/dev/null | grep -q 'inet6 ' && return 0
	WANS_DOWN=$((WANS_DOWN + 1))
	return 0
}

. /lib/functions/network.sh
network_flush_cache

config_load network
config_foreach kaha_check_wan interface

[ "$WANS_DOWN" -gt 0 ] && exit 1
exit 0
