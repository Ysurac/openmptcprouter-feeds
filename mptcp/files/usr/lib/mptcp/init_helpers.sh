#!/bin/sh

mptcp_has_master_multipath() {
	uci -q show network | grep -q "\.multipath='master'$"
}

mptcp_ensure_ipv6_oif_rule() {
	local table="$1"
	local iface="$2"

	[ -n "$table" ] || return 1
	[ -n "$iface" ] || return 1

	ip -6 rule show 2>/dev/null | grep -Fq "oif $iface lookup $table" && return 0
	ip -6 rule add oif "$iface" table "$table" pref 0
}
