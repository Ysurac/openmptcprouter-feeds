#!/bin/sh
#
# Copyright (C) 2018-2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Sourced by the post-tracking.d scripts from the omr-tracker bash process.

. /lib/functions/network.sh
. "${OMR_LIB_DIR:-/usr/share/omr/lib}/omr-state.sh"

# ── Per-run caches ────────────────────────────────────────────────────────────
# A post-tracking run for one interface walks every network interface and
# every server, and each step used to fork uci/ubus/ifstatus/jsonfilter again
# for values that don't change within the run: ~400 forks per cycle per WAN
# (traced live on a 2-core MT7981 where the trackers alone kept the load
# above 2.5). Everything below reads the openmptcprouter/network configs and
# each interface's netifd status once and answers from shell variables.
#
# The caches live in the sourcing shell: fill them from the parent shell
# (plain function calls), never only inside a $(...) substitution where the
# copy would be thrown away with the subshell.

_omr_nl='
'
_OMR_UCI_CACHE=""
_OMR_UCI_CACHE_LOADED=""
_OMR_UCI_MAP_OK=""

# The config cache is a bash associative array keyed by "pkg.section.option"
# (lookups are O(1)), worth about 200 ms of CPU per 003-up run on the MT7981
# this was written for: that script alone used to fork ~85 "uci get" calls
# (~4 ms each) walking every interface and server.
# Two dead ends measured on the way there are worth not repeating:
#  - scanning the "uci show" text with ${blob#*key} per lookup: bash tries
#    every prefix length, i.e. quadratic in the ~30 KB dump, tens of ms of
#    CPU per lookup -- far worse than the forks it replaced;
#  - filling the array with a "while read" loop over the ~350 dump lines:
#    ~120 ms, versus ~15 ms for one uci dump, ~40 ms for one awk pass and
#    ~17 ms to eval the array literal it produces.
# The load is lazy, so a script that reads only a couple of options (and
# would lose on the build) never triggers it -- use plain "uci -q get"
# there.
#
# uci quotes values exactly the way the shell does ('...', an embedded quote
# written as '\''), so the dump needs no re-quoting to become an array
# literal; only multi-value lists (opt='a' 'b') are joined into one word.
# Two safety nets, because a syntax error inside eval does not just fail --
# it terminates the shell running it, which here is the post-tracking
# subshell doing route management:
#  - keys that could break the literal are dropped in awk, and every key is
#    emitted quoted so bracketed section names (@device[0]) stay intact;
#  - the literal is parsed in a subshell first, so a malformed one costs
#    that throwaway subshell and nothing else.
# Without bash, or when the map ends up empty for any reason, the getters
# fall back to plain "uci get".
_omr_uci_cache_load() {
	[ -n "$_OMR_UCI_CACHE_LOADED" ] && return 0
	_OMR_UCI_CACHE_LOADED=1
	_OMR_UCI_MAP_OK=""
	_OMR_UCI_CACHE="${_omr_nl}$(command uci -q show openmptcprouter 2>/dev/null; command uci -q show network 2>/dev/null)${_omr_nl}"
	[ -n "$BASH_VERSION" ] || return 0
	local _lit
	# NOTE: the key filter uses index() rather than a bracket expression:
	# busybox awk silently fails to match a class containing an escaped
	# "]", which made this drop every line and yield an empty map.
	_lit="$(awk -v q="'" -F= '
		/^[^=]+\.[^=]+\.[^=]+=/ {
			k = $1
			if (index(k, "\"") || index(k, "\\")) next
			v = substr($0, length(k) + 2)
			gsub(q " " q, " ", v)
			printf "[\"%s\"]=%s ", k, v
		}' <<<"$_OMR_UCI_CACHE")"
	unset _OMR_UCI_MAP
	declare -gA _OMR_UCI_MAP
	[ -n "$_lit" ] || return 0
	if ( eval "declare -A _t=( $_lit )" ) 2>/dev/null; then
		eval "_OMR_UCI_MAP=( $_lit )"
		[ "${#_OMR_UCI_MAP[@]}" -gt 0 ] && _OMR_UCI_MAP_OK=1
	fi
	return 0
}

_omr_uci_cache_flush() {
	_OMR_UCI_CACHE_LOADED=""
	_OMR_UCI_CACHE=""
	_OMR_UCI_MAP_OK=""
}

# Every uci write done through the scripts invalidates the cached view so a
# value set earlier in the run is read back correctly.
uci() {
	case " $* " in
		*" set "*|*" del "*|*" delete "*|*" add_list "*|*" del_list "*|*" batch "*|*" batch"|*" revert "*|*" rename "*|*" reorder "*|*" import "*|*" commit "*|*" commit")
			_omr_uci_cache_flush ;;
	esac
	command uci "$@"
}

# _omr_uci_get_var <var> <package.section.option> [<default>]
# Assigns the option's value (default when unset) without forking. Only the
# openmptcprouter and network packages are cached; anything else goes to uci.
_omr_uci_get_var() {
	local _var="$1" _key="$2" _def="${3:-}" _val
	case "$_key" in
		openmptcprouter.*.*|network.*.*)
			if [ -n "$BASH_VERSION" ]; then
				_omr_uci_cache_load
				if [ -n "$_OMR_UCI_MAP_OK" ]; then
					if [ -n "${_OMR_UCI_MAP["$_key"]+set}" ]; then
						_val="${_OMR_UCI_MAP["$_key"]}"
						eval "$_var=\$_val"
						return 0
					fi
					eval "$_var=\$_def"
					return 1
				fi
			fi
			;;
	esac
	_val="$(command uci -q get "$_key" 2>/dev/null)" || { eval "$_var=\$_def"; return 1; }
	eval "$_var=\$_val"
	return 0
}

# _omr_uci_get <package.section.option>  -- drop-in for "uci -q get"
_omr_uci_get() {
	local _v
	_omr_uci_get_var _v "$1" || return 1
	printf '%s\n' "$_v"
}

# _omr_uci_has <literal>: does the cached openmptcprouter/network config
# contain this text (e.g. "get_config='1'")? Replaces "uci show | grep".
_omr_uci_has() {
	_omr_uci_cache_load
	case "$_OMR_UCI_CACHE" in
		*"$1"*) return 0 ;;
	esac
	return 1
}

# Interface status: one "ubus call network.interface.<name> status" and one
# jsonfilter per interface and run, memoized. Sets the _J_* fields for the
# requested interface:
#   _J_UP 1/0, _J_L3 l3_device, _J_DEV device,
#   _J_GW4 / _J_GW4I active/inactive default IPv4 nexthop,
#   _J_GW6 / _J_GW6I active/inactive default IPv6 nexthop,
#   _J_GW6S _J_GW6S64 _J_GW6S56 inactive IPv6 nexthop by source prefix
_omr_ifstatus_reset() {
	_J_UP=""; _J_L3=""; _J_DEV=""
	_J_GW4=""; _J_GW4I=""
	_J_GW6=""; _J_GW6I=""; _J_GW6S=""; _J_GW6S64=""; _J_GW6S56=""
}

_omr_ifstatus_fetch() {
	local _if="$1" _ip6 _out
	_omr_uci_get_var _ip6 "network.${_if}.ip6"
	set -- -e '_J_UP=@.up' -e '_J_L3=@.l3_device' -e '_J_DEV=@.device' \
		-e '_J_GW4=@.route[@.target="0.0.0.0"].nexthop' \
		-e '_J_GW4I=@.inactive.route[@.target="0.0.0.0"].nexthop' \
		-e '_J_GW6=@.route[@.target="::"].nexthop' \
		-e '_J_GW6I=@.inactive.route[@.target="::"].nexthop'
	[ -n "$_ip6" ] && set -- "$@" \
		-e "_J_GW6S=@.inactive.route[@.source=\"${_ip6}\"].nexthop" \
		-e "_J_GW6S64=@.inactive.route[@.source=\"${_ip6}/64\"].nexthop" \
		-e "_J_GW6S56=@.inactive.route[@.source=\"${_ip6}/56\"].nexthop"
	# jsonfilter prints "export NAME='value'; " per matching expression and
	# exits non-zero as soon as one expression has no match: ignore the code.
	_out="$(command ubus call "network.interface.${_if}" status 2>/dev/null | jsonfilter "$@" 2>/dev/null)"
	_out="${_out//export /}"
	printf '%s' "$_out"
}

_omr_ifstatus_load() {
	local _if="$1" _memo
	_omr_ifstatus_reset
	[ -n "$_if" ] || return 1
	case "$_if" in
		*[!A-Za-z0-9_]*)
			eval "$(_omr_ifstatus_fetch "$_if")"
			return 0 ;;
	esac
	eval "_memo=\${_OMR_IFC_${_if}-}"
	if [ -z "$_memo" ]; then
		_memo="$(_omr_ifstatus_fetch "$_if")"
		[ -n "$_memo" ] || _memo=" "
		eval "_OMR_IFC_${_if}=\$_memo"
	fi
	eval "$_memo"
	return 0
}

# _omr_if_up <interface>: exit 0 when netifd reports the interface up
_omr_if_up() {
	_omr_ifstatus_load "$1"
	[ "$_J_UP" = "1" ]
}

# resolveip results, memoized per family and name for the run
_OMR_RES_CACHE=""
_omr_resolve_var() {
	local _var="$1" _fam="$2" _name="$3" _key _rest _val
	[ -n "$_name" ] || { eval "$_var=''"; return; }
	_key="${_omr_nl}${_fam} ${_name}="
	case "$_OMR_RES_CACHE" in
		*"$_key"*)
			_rest="${_OMR_RES_CACHE#*"$_key"}"
			_val="${_rest%%"${_omr_nl}"*}"
			;;
		*)
			_val="$(resolveip "$_fam" -t 5 "$_name" 2>/dev/null)"
			_val="${_val%%"${_omr_nl}"*}"
			_OMR_RES_CACHE="${_OMR_RES_CACHE}${_key}${_val}${_omr_nl}"
			;;
	esac
	eval "$_var=\$_val"
}

# Read with a plain uci get, not through the cache: several scripts source
# this library only to log something (002-error's early exits, 001-initialize)
# and must not pay for building the config map just to learn whether debug
# logging is on.
debug=$(command uci -q get openmptcprouter.settings.debug 2>/dev/null)

find_network_device() {
	local interface="${1}"
	local device_section=""

	check_device() {
		local cfg="${1}"
		local device="${2}"

		local name
		config_get name "${cfg}" name

		[ "${name}" = "${device}" ] && device_section="${cfg}"
	}
	if [ -n "$device" ]; then
		config_load network
		config_foreach check_device device "$(uci -q network.${interface}.device)"
	fi
	echo "${device_section}"
}

# _omr_get_multipath_config_var <var> <interface>
_omr_get_multipath_config_var() {
	local _var="$1" interface="$2" config mptcp_over_vpn multipathvpn

	_omr_uci_get_var config "openmptcprouter.${interface}.multipath"
	[ -z "$config" ] && _omr_uci_get_var config "network.${interface}.multipath"
	[ -z "$config" ] && config="off"

	# Handle VPN multipath
	_omr_uci_get_var multipathvpn "openmptcprouter.${interface}.multipathvpn"
	if [ "$multipathvpn" = "1" ]; then
		_omr_uci_get_var mptcp_over_vpn "openmptcprouter.settings.mptcpovervpn"
		if [ "$mptcp_over_vpn" = "openvpn" ]; then
			_omr_uci_get_var config "openmptcprouter.ovpn${interface}.multipath"
		elif [ "$mptcp_over_vpn" = "wireguard" ]; then
			_omr_uci_get_var config "openmptcprouter.wg${interface}.multipath"
		fi
		[ -z "$config" ] && config="off"
	fi
	eval "$_var=\$config"
}

# Common function to get multipath config to reduce code duplication
_get_multipath_config() {
	local _c
	_omr_get_multipath_config_var _c "$1"
	echo "$_c"
}

# _omr_get_interface_device_var <var> <interface> [<suffix>]
_omr_get_interface_device_var() {
	local _var="$1" interface="$2" suffix="${3:-}" device

	_omr_ifstatus_load "${interface}${suffix}"
	device="$_J_L3"
	if [ -z "$device" ]; then
		_omr_ifstatus_load "${interface}_4"
		device="$_J_L3"
	fi
	[ -z "$device" ] && _omr_uci_get_var device "network.${interface}.ifname"
	[ -z "$device" ] && _omr_uci_get_var device "network.${interface}.device"

	# Handle special device names with '@'
	case "$device" in
		*@*)
			_omr_ifstatus_load "$interface"
			device="$_J_DEV"
			;;
	esac
	eval "$_var=\$device"
}

# Common function to get interface device with fallback chain
_get_interface_device() {
	local _d
	_omr_get_interface_device_var _d "$1" "${2:-}"
	echo "$_d"
}

# _omr_get_interface_gateway_var <var> <interface> [true|false]
_omr_get_interface_gateway_var() {
	local _var="$1" interface="$2" ipv6="${3:-false}" gateway

	if [ "$ipv6" = "true" ]; then
		_omr_uci_get_var gateway "network.${interface}.ip6gw"
		if [ -z "$gateway" ]; then
			_omr_ifstatus_load "$interface"
			gateway="$_J_GW6S"
			[ -z "$gateway" ] && gateway="$_J_GW6S64"
			[ -z "$gateway" ] && gateway="$_J_GW6S56"
			[ -z "$gateway" ] && gateway="$_J_GW6I"
			[ -z "$gateway" ] && gateway="$_J_GW6"
		fi
		if [ -z "$gateway" ]; then
			_omr_ifstatus_load "${interface}_6"
			gateway="$_J_GW6I"
			[ -z "$gateway" ] && gateway="$_J_GW6"
		fi
	else
		_omr_uci_get_var gateway "network.${interface}.gateway"
		if [ -z "$gateway" ]; then
			_omr_ifstatus_load "$interface"
			gateway="$_J_GW4I"
			[ -z "$gateway" ] && gateway="$_J_GW4"
		fi
		if [ -z "$gateway" ]; then
			_omr_ifstatus_load "${interface}_4"
			gateway="$_J_GW4I"
		fi
	fi
	eval "$_var=\$gateway"
}

# Common function to get interface gateway with fallback chain
_get_interface_gateway() {
	local _g
	_omr_get_interface_gateway_var _g "$1" "${2:-false}"
	echo "$_g"
}

_set_route_common() {
	local multipath_config_route interface_gw interface_if defaultgw
	INTERFACE=$1
	PREVINTERFACE=$2
	SETDEFAULT="${3:-yes}"
	ipv6="${4:-false}"

	[ -z "$INTERFACE" ] && return

	# Set IP command and table based on IP version
	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		table_id="6991337"
		route_target="::"
	else
		ip_cmd="ip"
		table_id="991337"
		route_target="0.0.0.0"
	fi

	_omr_get_multipath_config_var multipath_config_route "$INTERFACE"

	#network_get_device interface_if $INTERFACE
	if _omr_if_up "$INTERFACE"; then interface_up="true"; else interface_up="false"; fi
	_omr_get_interface_device_var interface_if "$INTERFACE"
	_omr_uci_get_var interface_current_config "openmptcprouter.$INTERFACE.state" "up"
	if [ "$multipath_config_route" != "off" ] && [ "$SETROUTE" != true ] && [ "$INTERFACE" != "$PREVINTERFACE" ] && [ "$interface_current_config" = "up" ] && [ "$interface_up" = "true" ]; then
		_omr_get_interface_gateway_var interface_gw "$INTERFACE" "$ipv6"

		if [ "$interface_gw" != "" ] && [ "$interface_if" != "" ]; then
			[ "$debug" = "true" ] && [ "$SETDEFAULT" = "yes" ] && _log "$PREVINTERFACE down. Replace default route by $interface_gw dev $interface_if"
			[ "$debug" = "true" ] && [ "$SETDEFAULT" != "yes" ] && _log "$PREVINTERFACE down. Replace default in table 991337 route by $interface_gw dev $interface_if"
			_omr_uci_get_var defaultgw openmptcprouter.settings.defaultgw
			if [ "$SETDEFAULT" = "yes" ] && [ "$defaultgw" != "0" ]; then
				$ip_cmd route replace default scope global metric 1 via $interface_gw dev $interface_if $initcwrwnd >/dev/null 2>&1
			fi
			$ip_cmd route replace default via $interface_gw dev $interface_if table "$table_id" $initcwrwnd >/dev/null 2>&1 && SETROUTE=true
		fi
	fi
}

set_route() {
	_set_route_common "$1" "$2" "$3" false
}

set_route6() {
	_set_route_common "$1" "$2" "$3" true
}

_set_server_default_route_common() {
	local server=$1
	local ipv6="${2:-false}"
	local ip_cmd resolve_cmd

	[ -z "$OMR_TRACKER_INTERFACE" ] && return

	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		resolve_cmd="-6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
	else
		ip_cmd="ip"
		resolve_cmd="-4"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
	fi

	server_route() {
		local serverip multipath_config_route
		_omr_resolve_var serverip "$resolve_cmd" "$1"

		config_get disabled $server disabled
		[ "$disabled" = "1" ] && return

		_omr_get_multipath_config_var multipath_config_route "$OMR_TRACKER_INTERFACE"

		if [ -n "$serverip" ] && [ -n "$gateway_var" ] && [ -n "$OMR_TRACKER_DEVICE" ] && [ "$multipath_config_route" != "off" ]; then
			local existing_route=$($ip_cmd route show "$serverip" 2>/dev/null | grep "via ${gateway_var}" | grep "dev ${OMR_TRACKER_DEVICE}")
			if [ -z "$existing_route" ]; then
				[ "$debug" = "true" ] && _log "Set server $server ($serverip) default route via $gateway_var"
				$ip_cmd route replace $serverip via $gateway_var dev $OMR_TRACKER_DEVICE metric 1 $initcwrwnd >/dev/null 2>&1
			fi
		fi
	}
	config_list_foreach $server ip server_route
}

set_server_default_route() {
	_set_server_default_route_common "$1" false
}

set_server_default_route6() {
	_set_server_default_route_common "$1" true
}

delete_server_default_route_common() {
	local server=$1
	local ipv6="${2:-false}"

	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		resolve_cmd="-6"
	else
		ip_cmd="ip"
		resolve_cmd="-4"
	fi

	delete_route() {
		local serverip
		_omr_resolve_var serverip "$resolve_cmd" "$1"
		config_get disabled $server disabled
		[ "$disabled" = "1" ] && return
		if [ "$serverip" != "" ] && [ "$($ip_cmd route show $serverip metric 1)" != "" ]; then
			[ "$debug" = "true" ] && _log "Delete server ($serverip) default route"
			[ -n "$($ip_cmd route show $serverip metric 1)" ] && $ip_cmd route del $serverip metric 1 >/dev/null 2>&1
		fi
	}
	config_list_foreach $server ip delete_route
}
delete_server_default_route() {
	_common_delete_server_default_route $1 false
}

delete_server_default_route6() {
	_common_delete_server_default_route $1 true
}

# Append "nexthop via <gw> dev <if> weight <w>" for one interface to the
# route-fragment variables named by the caller (routesintf*/routesbalancing*).
# Shared by the two sweeps below; the weight rules are unchanged: explicit
# network/openmptcprouter weight, else 100 for the master, 1 otherwise.
# _omr_route_fragment_var <var> <interface> <multipath_config> <gateway> <device>
_omr_route_fragment_var() {
	local _var="$1" INTERFACE="$2" multipath_config_route="$3" interface_gw="$4" interface_if="$5" weight
	_omr_uci_get_var weight "network.$INTERFACE.weight"
	if [ -z "$weight" ]; then
		_omr_uci_get_var weight "openmptcprouter.$INTERFACE.weight"
	fi
	if [ -z "$weight" ]; then
		if [ "$multipath_config_route" = "master" ]; then
			weight=100
		else
			weight=1
		fi
	fi
	eval "$_var=\"nexthop via \$interface_gw dev \$interface_if weight \$weight\""
}

_set_routes_intf_common() {
	local multipath_config_route
	local interface_if interface_gw interface_vpn interface_current_config route_fragment
	local INTERFACE=$1
	local ipv6="${2:-false}"
	[ -z "$INTERFACE" ] && return
	[ "$INTERFACE" = "omrvpn" ] && return
	[ "$INTERFACE" = "omr6in4" ] && return

	# Cheapest checks first: everything below is ANDed, so the order of the
	# tests doesn't change the outcome, only how much is looked up for
	# interfaces that are down or excluded.
	_omr_if_up "$INTERFACE" || return
	_omr_uci_get_var interface_current_config "openmptcprouter.$INTERFACE.state" "up"
	[ "$interface_current_config" = "up" ] || return
	_omr_uci_get_var interface_vpn "openmptcprouter.$INTERFACE.vpn" "0"
	_omr_uci_get_var _allmptcpovervpn openmptcprouter.settings.allmptcpovervpn
	{ [ "$interface_vpn" = "0" ] || [ "$_allmptcpovervpn" = "0" ]; } || return
	_omr_get_multipath_config_var multipath_config_route "$INTERFACE"
	[ "$multipath_config_route" != "off" ] || return
	_omr_get_interface_device_var interface_if "$INTERFACE"
	[ -n "$interface_if" ] || return

	_omr_get_interface_gateway_var interface_gw "$INTERFACE" "$ipv6"
	#if [ "$interface_gw" != "" ] && [ "$interface_if" != "" ] && [ -n "$serverip" ] && [ "$(ip route show $serverip | grep $interface_if)" = "" ]; then
	[ -n "$interface_gw" ] || return
	case "$interface_gw" in *:*) return ;; esac

	# Build routes based on IPv6 flag and backup status
	_omr_route_fragment_var route_fragment "$INTERFACE" "$multipath_config_route" "$interface_gw" "$interface_if"

	if [ "$multipath_config_route" = "backup" ]; then
		if [ "$ipv6" = "true" ]; then
			nbintfb6=$((nbintfb6+1))
			if [ -z "$routesintfbackup6" ]; then
				routesintfbackup6="$route_fragment"
			else
				routesintfbackup6="$routesintfbackup6 $route_fragment"
			fi
		else
			nbintfb=$((nbintfb+1))
			if [ -z "$routesintfbackup" ]; then
				routesintfbackup="$route_fragment"
			else
				routesintfbackup="$routesintfbackup $route_fragment"
			fi
		fi
	else
		if [ "$ipv6" = "true" ]; then
			nbintf6=$((nbintf6+1))
			if [ -z "$routesintf6" ]; then
				routesintf6="$route_fragment"
			else
				routesintf6="$routesintf6 $route_fragment"
			fi
		else
			nbintf=$((nbintf+1))
			if [ -z "$routesintf" ]; then
				routesintf="$route_fragment"
			else
				routesintf="$routesintf $route_fragment"
			fi
		fi
	fi
}

set_routes_intf() {
	_set_routes_intf_common "$1" false
}
set_routes_intf6() {
	_set_routes_intf_common "$1" true
}

# NOTE: this sweep always looks up the IPv4 gateway and files the fragment
# under the IPv4 or IPv6 variables depending on the caller's global "ipv6"
# variable (not on its own second argument) -- long-standing behaviour that
# 003-up's balancing blocks rely on, kept as is.
_set_route_balancing_common() {
	local multipath_config_route interface_gw interface_if interface_vpn interface_current_config route_fragment
	INTERFACE=$1
	[ -z "$INTERFACE" ] && return
	[ "$INTERFACE" = "omrvpn" ] && return
	[ "$INTERFACE" = "omr6in4" ] && return

	_omr_if_up "$INTERFACE" || return
	_omr_uci_get_var interface_current_config "openmptcprouter.$INTERFACE.state" "up"
	[ "$interface_current_config" = "up" ] || return
	_omr_uci_get_var interface_vpn "openmptcprouter.$INTERFACE.vpn" "0"
	_omr_uci_get_var _allmptcpovervpn openmptcprouter.settings.allmptcpovervpn
	{ [ "$interface_vpn" = "0" ] || [ "$_allmptcpovervpn" = "0" ]; } || return
	_omr_get_multipath_config_var multipath_config_route "$INTERFACE"
	[ "$multipath_config_route" != "off" ] || return
	_omr_get_interface_device_var interface_if "$INTERFACE"
	[ -n "$interface_if" ] || return

	_omr_get_interface_gateway_var interface_gw "$INTERFACE" false
	[ -n "$interface_gw" ] || return

	_omr_route_fragment_var route_fragment "$INTERFACE" "$multipath_config_route" "$interface_gw" "$interface_if"

	if [ "$multipath_config_route" = "backup" ]; then
		if [ "$ipv6" = "true" ]; then
			nbintfb6=$((nbintfb6+1))
			if [ -z "$routesbalancingbackup6" ]; then
				routesbalancingbackup6="$route_fragment"
			else
				routesbalancingbackup6="$routesbalancingbackup6 $route_fragment"
			fi
		else
			nbintfb=$((nbintfb+1))
			if [ -z "$routesbalancingbackup" ]; then
				routesbalancingbackup="$route_fragment"
			else
				routesbalancingbackup="$routesbalancingbackup $route_fragment"
			fi
		fi
	else
		if [ "$ipv6" = "true" ]; then
			nbintf6=$((nbintf6+1))
			if [ -z "$routesbalancing6" ]; then
				routesbalancing6="$route_fragment"
			else
				routesbalancing6="$routesbalancing6 $route_fragment"
			fi
		else
			nbintf=$((nbintf+1))
			if [ -z "$routesbalancing" ]; then
				routesbalancing="$route_fragment"
			else
				routesbalancing="$routesbalancing $route_fragment"
			fi
		fi
	fi
}

set_route_balancing() {
	_set_route_balancing_common "$1" false
}
set_route_balancing6() {
	_set_route_balancing_common "$1" true
}

# Compare the kernel's default route at a given metric against the nexthop
# fragments we want installed ("nexthop via <gw> dev <if> weight <w> ...").
# Returns 0 when the route already carries exactly the expected gateway/device
# set, 1 otherwise. Grepping the route for the tracked device instead is wrong
# for interfaces that don't belong in that route (a backup interface is never
# in the metric-1 route), which made the caller replace and log an already
# correct route on every tracker cycle (issue #4358).
# With a single nexthop the kernel flattens the group and drops
# "nexthop"/"weight" from its output, so weights are ignored there or the
# route would look different on every cycle.
_default_route_matches() {
	local metric="$1"
	local expected_routes="$2"
	local nb="${3:-0}"
	local ipv6="${4:-false}"
	local ip_cmd="ip"
	local existing_gws expected_gws
	[ "$ipv6" = "true" ] && ip_cmd="ip -6"
	existing_gws=$($ip_cmd route show default metric "$metric" 2>/dev/null | grep -oE 'via [^ ]+ dev [^ ]+( weight [0-9]+)?' | sort | tr '\n' ' ')
	expected_gws=$(echo "$expected_routes" | grep -oE 'via [^ ]+ dev [^ ]+( weight [0-9]+)?' | sort | tr '\n' ' ')
	if [ "${nb:-0}" -le 1 ] 2>/dev/null; then
		existing_gws=$(echo "$existing_gws" | sed 's/ weight [0-9]*//g')
		expected_gws=$(echo "$expected_gws" | sed 's/ weight [0-9]*//g')
	fi
	[ -n "$expected_gws" ] && [ "$existing_gws" = "$expected_gws" ]
}

_set_server_all_routes_common() {
	local server=$1
	local ipv6="${2:-false}"
	local ip_cmd resolve_cmd routes_var backup_var nbintf_var nbintfb_var gateway_var suffix
	[ -z "$OMR_TRACKER_INTERFACE" ] && return

	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		resolve_cmd="-6"
		routes_var="routesintf6"
		backup_var="routesintfbackup6"
		nbintf_var="nbintf6"
		nbintfb_var="nbintfb6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
		suffix="_6"
	else
		ip_cmd="ip"
		resolve_cmd="-4"
		routes_var="routesintf"
		backup_var="routesintfbackup"
		nbintf_var="nbintf"
		nbintfb_var="nbintfb"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
		suffix="_4"
	fi

	server_route() {
		local serverip multipath_config_route interface_if interface_up
		_omr_resolve_var serverip "$resolve_cmd" "$1"
		config_get disabled $server disabled
		[ "$disabled" = "1" ] && return
		#network_get_device interface_if $OMR_TRACKER_INTERFACE
		_omr_get_interface_device_var interface_if "$OMR_TRACKER_INTERFACE"
		if _omr_if_up "$OMR_TRACKER_INTERFACE"; then interface_up="true"; else interface_up="false"; fi

		_omr_get_multipath_config_var multipath_config_route "$OMR_TRACKER_INTERFACE"

		if [ "$serverip" != "" ] && [ "$multipath_config_route" != "off" ]; then
			eval "${routes_var}=''"
			eval "${backup_var}=''"
			eval "${nbintf_var}=0"
			eval "${nbintfb_var}=0"

			config_load network
			if [ "$ipv6" = "true" ]; then
				config_foreach set_routes_intf6 interface
			else
				config_foreach set_routes_intf interface
			fi

			# Get current values
			local current_routes current_backup current_nbintf current_nbintfb
			eval "current_routes=\$${routes_var}"
			eval "current_backup=\$${backup_var}"
			eval "current_nbintf=\$${nbintf_var}"
			eval "current_nbintfb=\$${nbintfb_var}"

			if [ -n "$current_routes" ]; then
				local existing_gws
				existing_gws=$($ip_cmd r show "$serverip" metric 1 2>/dev/null | grep -oE 'via [^ ]+ dev [^ ]+( weight [0-9]+)?' | sort | tr '\n' ' ')
				local expected_gws
				expected_gws=$(echo "$current_routes" | grep -oE 'via [^ ]+ dev [^ ]+( weight [0-9]+)?' | sort | tr '\n' ' ')
				# With a single nexthop the kernel flattens the group and drops
				# "weight", so ignore weights there or the route would be
				# replaced on every tracker cycle
				if [ "${current_nbintf:-0}" -le 1 ]; then
					existing_gws=$(echo "$existing_gws" | sed 's/ weight [0-9]*//g')
					expected_gws=$(echo "$expected_gws" | sed 's/ weight [0-9]*//g')
				fi
				if [ "$existing_gws" != "$expected_gws" ]; then
					[ "$debug" = "true" ] && _log "Set server $server ($serverip) default route $serverip $current_routes"
					$ip_cmd route replace "$serverip" scope global metric 1 $current_routes >/dev/null 2>&1
					[ "$debug" = "true" ] && _log "New server route is $($ip_cmd r show "$serverip" metric 1 | tr -d '\t' | tr -d '\n')"
				fi
			fi

			if [ -n "$current_backup" ]; then
				local existing_backup_gws
				existing_backup_gws=$($ip_cmd r show "$serverip" metric 999 2>/dev/null | grep -oE 'via [^ ]+ dev [^ ]+( weight [0-9]+)?' | sort | tr '\n' ' ')
				local expected_backup_gws
				expected_backup_gws=$(echo "$current_backup" | grep -oE 'via [^ ]+ dev [^ ]+( weight [0-9]+)?' | sort | tr '\n' ' ')
				if [ "${current_nbintfb:-0}" -le 1 ]; then
					existing_backup_gws=$(echo "$existing_backup_gws" | sed 's/ weight [0-9]*//g')
					expected_backup_gws=$(echo "$expected_backup_gws" | sed 's/ weight [0-9]*//g')
				fi
				if [ "$existing_backup_gws" != "$expected_backup_gws" ]; then
					[ "$debug" = "true" ] && _log "Set server $server ($serverip) backup default route $serverip $current_backup nbintfb $current_nbintfb $OMR_TRACKER_DEVICE"
					$ip_cmd route replace "$serverip" scope global metric 999 $current_backup >/dev/null 2>&1
				fi
			fi
		fi
	}
	config_load openmptcprouter
	config_list_foreach $server ip server_route
}

set_server_all_routes() {
	_set_server_all_routes_common "$1" false
}

set_server_all_routes6() {
	_set_server_all_routes_common "$1" true
}


_set_server_route_common() {
	local server="$1"
	local ipv6="${2:-false}"
	local ip_cmd resolve_cmd gateway_var suffix

	[ -z "$OMR_TRACKER_INTERFACE" ] && return

	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		resolve_cmd="-6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
		suffix="_6"
	else
		ip_cmd="ip"
		resolve_cmd="-4"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
		suffix="_4"
	fi

	server_route() {
		local serverip multipath_config_route interface_if interface_up interface_current_config
		local metric

		_omr_resolve_var serverip "$resolve_cmd" "$1"

		config_get disabled "$server" disabled
		[ "$disabled" = "1" ] && return

		metric="$2"
		[ -n "$metric" ] || _omr_uci_get_var metric "network.${OMR_TRACKER_INTERFACE}.metric"
		_omr_get_multipath_config_var multipath_config_route "$OMR_TRACKER_INTERFACE"

		_omr_get_interface_device_var interface_if "$OMR_TRACKER_INTERFACE"
		if _omr_if_up "$OMR_TRACKER_INTERFACE"; then interface_up="true"; else interface_up="false"; fi
		_omr_uci_get_var interface_current_config "openmptcprouter.${OMR_TRACKER_INTERFACE}.state" "up"

		if [ -n "$serverip" ] && [ -n "$OMR_TRACKER_DEVICE" ] && [ -n "$gateway_var" ] && [ "$multipath_config_route" != "off" ] && [ "$interface_current_config" = "up" ] && [ "$interface_up" = "true" ]; then
			local existing_route=$($ip_cmd route show "$serverip" 2>/dev/null | grep "via ${gateway_var}" | grep "dev ${OMR_TRACKER_DEVICE}")
			if [ -z "$existing_route" ]; then
				[ "$debug" = "true" ] && _log "Set server $server ($serverip) route via $gateway_var metric $metric"
				$ip_cmd route replace "$serverip" via "$gateway_var" dev "$OMR_TRACKER_DEVICE" metric "$metric" $initcwrwnd >/dev/null 2>&1
			fi
		fi
	}

	config_list_foreach "$server" ip server_route

	# Set default route if conditions are met
	local default_gw_enabled interface_up interface_current_config multipath_config_route metric
	_omr_uci_get_var default_gw_enabled "openmptcprouter.settings.defaultgw"
	if _omr_if_up "$OMR_TRACKER_INTERFACE"; then interface_up="true"; else interface_up="false"; fi
	_omr_uci_get_var interface_current_config "openmptcprouter.${OMR_TRACKER_INTERFACE}.state" "up"
	_omr_get_multipath_config_var multipath_config_route "$OMR_TRACKER_INTERFACE"
	_omr_uci_get_var metric "network.${OMR_TRACKER_INTERFACE}.metric"

	if [ "$default_gw_enabled" != "0" ] && [ -n "$metric" ] && [ -n "$gateway_var" ] && [ -n "$OMR_TRACKER_DEVICE" ] && [ "$multipath_config_route" != "off" ] && [ "$interface_current_config" = "up" ] && [ "$interface_up" = "true" ]; then
		local existing_default=$($ip_cmd route show dev "$OMR_TRACKER_DEVICE" metric "$metric" 2>/dev/null | grep default | grep "$gateway_var")
		if [ -z "$existing_default" ]; then
			$ip_cmd route replace default via "$gateway_var" dev "$OMR_TRACKER_DEVICE" metric "$metric" $initcwrwnd >/dev/null 2>&1
		fi
	fi
}

set_server_route() {
	_set_server_route_common "$1" false
}

set_server_route6() {
	_set_server_route_common "$1" true
}


_del_default_route_common() {
	local server="$1"
	local ipv6="${2:-false}"
	local ip_cmd

	[ -z "$OMR_TRACKER_DEVICE" ] && return
	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
	else
		ip_cmd="ip"
	fi
	${ip_cmd} route del default dev $OMR_TRACKER_DEVICE >/dev/null 2>&1
}

del_default_route() {
    _del_default_route_common "$1" false
}
del_default_route6() {
    _del_default_route_common "$1" true
}

# del_default_route/6 only ever remove a default route ON $OMR_TRACKER_DEVICE
# (the VPN's own tunnel device), so they never touch the raw-WAN default
# routes installed by other mechanisms while defaultgw was enabled:
#  - the per-WAN "own gateway, own metric" fallback route 003-up adds once
#    via `ip r add default via <gw> dev <wan> metric <network.<wan>.metric>`
#    (and its IPv6 twin at metric 6<metric>) -- an ADD, never a REPLACE, and
#    nothing ever deletes it again, so it outlives both the WAN's own up/down
#    cycles and settings.defaultgw being switched off afterwards
#  - the shared ECMP "default metric 1" (and backup "metric 999") balancing
#    routes built from every multipath WAN's gateway
# Called when settings.defaultgw=0 and the tracked VPN interface just went
# down, so that "no internet if VPS are down" (the option's own LuCI
# description) actually holds: no raw WAN may be left as a main-table
# default-route nexthop, not just the ones this handler itself manages.
_purge_wan_default_route() {
	local iface="$1"
	local multipath device metric

	case "$iface" in
		omrvpn|glorytun|omr6in4|"") return;;
	esac
	config_get multipath "$iface" multipath
	case "$multipath" in
		on|master|backup) ;;
		*) return;;
	esac
	_omr_get_interface_device_var device "$iface"
	[ -z "$device" ] && return
	_omr_uci_get_var metric "network.${iface}.metric"

	[ -n "$metric" ] && ip route del default dev "$device" metric "$metric" >/dev/null 2>&1
	ip route del default dev "$device" >/dev/null 2>&1
	[ -n "$metric" ] && ip -6 route del default dev "$device" metric "6$metric" >/dev/null 2>&1
	ip -6 route del default dev "$device" >/dev/null 2>&1
}

purge_wan_default_routes() {
	config_load network
	config_foreach _purge_wan_default_route interface
	ip route del default metric 1 >/dev/null 2>&1
	ip route del default metric 999 >/dev/null 2>&1
	ip -6 route del default metric 1 >/dev/null 2>&1
	ip -6 route del default metric 999 >/dev/null 2>&1
}

_del_server_route_common() {
	local server="$1"
	local ipv6="${2:-false}"
	local ip_cmd resolve_cmd gateway_var

	[ -z "$OMR_TRACKER_DEVICE" ] && return
	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		resolve_cmd="-6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
	else
		ip_cmd="ip"
		resolve_cmd="-4"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
	fi

	remove_route() {
		local serverip
		_omr_resolve_var serverip "$resolve_cmd" "$1"

		if [ -n "$serverip" ]; then
			# A nexthop group route can't be deleted by device: 'route del dev X'
			# either fails or removes the whole group, set_server_all_routes
			# rebuilds the group without the down interface
			if [ -n "$($ip_cmd route show "$serverip" 2>/dev/null | grep nexthop)" ]; then
				return
			fi
			_log "Delete default route to $serverip dev $OMR_TRACKER_DEVICE"
			local metric
			if [ -z "$OMR_TRACKER_INTERFACE" ]; then
				metric=0
			else
				_omr_uci_get_var metric "network.${OMR_TRACKER_INTERFACE}.metric"
			fi

			# Try to delete route with metric first, then without
			[ -n "$metric" ] && [ -n "$OMR_TRACKER_DEVICE" ] && [ -n "$($ip_cmd route show "$serverip" dev "$OMR_TRACKER_DEVICE" metric "$metric" 2>/dev/null)" ] && $ip_cmd route del "$serverip" dev "$OMR_TRACKER_DEVICE" metric "$metric" >/dev/null 2>&1

			[ -n "$OMR_TRACKER_DEVICE" ] && [ -n "$($ip_cmd route show "$serverip" dev "$OMR_TRACKER_DEVICE" 2>/dev/null)" ] && $ip_cmd route del "$serverip" dev "$OMR_TRACKER_DEVICE" >/dev/null 2>&1

			[ -n "$OMR_TRACKER_DEVICE" ] && [ -n "$($ip_cmd route show "$serverip" | grep "$OMR_TRACKER_DEVICE")" ] && $ip_cmd route del "$serverip" dev "$OMR_TRACKER_DEVICE" >/dev/null 2>&1
		fi
	}
	config_list_foreach "$server" ip remove_route
	# Remove default route
	if [ -n "$gateway_var" ] && [ -n "$OMR_TRACKER_DEVICE" ]; then
		[ -n "$($ip_cmd route show default via "$gateway_var" dev "$OMR_TRACKER_DEVICE" 2>/dev/null)" ] && $ip_cmd route del default via "$gateway_var" dev "$OMR_TRACKER_DEVICE" >/dev/null 2>&1
	elif [ -n "$OMR_TRACKER_DEVICE" ]; then
		[ -n "$($ip_cmd route show default dev "$OMR_TRACKER_DEVICE" 2>/dev/null)" ] && $ip_cmd route del default dev "$OMR_TRACKER_DEVICE" >/dev/null 2>&1
	fi
}

del_server_route() {
    _del_server_route_common "$1" false
}

del_server_route6() {
    _del_server_route_common "$1" true
}

enable_pihole() {
	local server=$1
	nbserver=$((nbserver+1))
	if [ -n "$server" ] && [ "$(uci -q get openmptcprouter.${server}.pihole)" = "1" ] && [ "$(uci -q get dhcp.@dnsmasq[0].server | grep '127.0.0.1#5353')" != "" ]; then
		piholeenabled=$((piholeenabled+1))
	fi
}

disable_pihole() {
	local server=$1
	if [ -n "$(uci -q get dhcp.@dnsmasq[0].server | grep '#53' | grep '10.255.25')" ]; then
		_log "Disable Pi-Hole..."
		uci -q del_list dhcp.@dnsmasq[0].server="$(uci -q get dhcp.@dnsmasq[0].server | tr ' ' '\n' | grep '#53' | grep '10.255.25')"
		if [ -z "$(uci -q get dhcp.@dnsmasq[0].server | grep '127.0.0.1#5353')" ]; then
			uci -q batch <<-EOF >/dev/null
				add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
				commit dhcp
			EOF
		fi
		/etc/init.d/dnsmasq restart >/dev/null 2>&1
	fi
}

dns_flush() {
	_log "DNS flush"
	unbound-control flush-negative >/dev/null 2>&1
	unbound-control flush-bogus >/dev/null 2>&1
}

set_vpn_balancing_routes() {
	vpngw="$1"
	vpn_route() {
		local vpnname
		vpnname=$1
		[ -z "$(echo $vpnname | grep omr)" ] && return
		config_get enabled $vpnname enabled
		[ "$enabled" != "1" ] && return
		config_get dev $vpnname dev
		[ -z "$dev" ] && return
		allvpnroutes="$allvpnroutes nexthop via $vpngw dev $dev"
	}
	allvpnroutes=""
	config_load openvpn
	config_foreach vpn_route openvpn
	_log "allvpnroutes: $allvpnroutes"
	[ -n "$allvpnroutes" ] && ip route replace default scope global${allvpnroutes} >/dev/null 2>&1
}
