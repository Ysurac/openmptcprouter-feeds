#!/bin/sh
#
# Copyright (C) 2018-2025 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

. /lib/functions/network.sh

debug=$(uci -q get openmptcprouter.settings.debug)

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

# Common function to get multipath config to reduce code duplication
_get_multipath_config() {
	local interface="$1"
	local config

	config=$(uci -q get "openmptcprouter.${interface}.multipath")
	[ -z "$config" ] && config=$(uci -q get "network.${interface}.multipath")
	[ -z "$config" ] && config="off"

	# Handle VPN multipath
	if [ "$(uci -q get "openmptcprouter.${interface}.multipathvpn")" = "1" ]; then
		local mptcp_over_vpn=$(uci -q get "openmptcprouter.settings.mptcpovervpn")
		if [ "$mptcp_over_vpn" = "openvpn" ]; then
			config=$(uci -q get "openmptcprouter.ovpn${interface}.multipath")
		elif [ "$mptcp_over_vpn" = "wireguard" ]; then
			config=$(uci -q get "openmptcprouter.wg${interface}.multipath")
		fi
		[ -z "$config" ] && config="off"
	fi
	echo "$config"
}

# Common function to get interface device with fallback chain
_get_interface_device() {
	local interface="$1"
	local suffix="${2:-}"
	local device

	# Try different methods to get device
	device=$(ifstatus "${interface}${suffix}" 2>/dev/null | jsonfilter -q -e '@["l3_device"]')
	[ -z "$device" ] && device=$(ifstatus "${interface}_4" 2>/dev/null | jsonfilter -q -e '@["l3_device"]')
	[ -z "$device" ] && device=$(uci -q get "network.${interface}.ifname")
	[ -z "$device" ] && device=$(uci -q get "network.${interface}.device")

	# Handle special device names with '@'
	if [ -n "$(echo "$device" | grep '@')" ]; then
		device=$(ifstatus "$interface" 2>/dev/null | jsonfilter -q -e '@["device"]')
	fi

	echo "$device"
}

# Common function to get interface gateway with fallback chain
_get_interface_gateway() {
	local interface="$1"
	local ipv6="${2:-false}"
	local gateway

	if [ "$ipv6" = "true" ]; then
		gateway=$(uci -q get "network.${interface}.ip6gw")
		local interface_ip6=$(uci -q get "network.${interface}.ip6")

		# Try different jsonfilter queries for IPv6
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -q -l 1 -e "@.inactive.route[@.source=\"${interface_ip6}\"].nexthop" | tr -d "\n")
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -q -l 1 -e "@.inactive.route[@.source=\"${interface_ip6}/64\"].nexthop" | tr -d "\n")
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -q -l 1 -e "@.inactive.route[@.source=\"${interface_ip6}/56\"].nexthop" | tr -d "\n")
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -q -l 1 -e '@.inactive.route[@.target="::"].nexthop' | tr -d "\n")
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -q -l 1 -e '@.route[@.target="::"].nexthop' | tr -d "\n")
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."${interface}_6" status 2>/dev/null | jsonfilter -q -l 1 -e '@.inactive.route[@.target="::"].nexthop' | tr -d "\n")
	else
		gateway=$(uci -q get "network.${interface}.gateway")
		# Try different jsonfilter queries for IPv4
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -q -l 1 -e '@.inactive.route[@.target="0.0.0.0"].nexthop' | tr -d "\n")
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -q -l 1 -e '@.route[@.target="0.0.0.0"].nexthop' | tr -d "\n")
		[ -z "$gateway" ] && gateway=$(ubus call network.interface."${interface}_4" status 2>/dev/null | jsonfilter -q -l 1 -e '@.inactive.route[@.target="0.0.0.0"].nexthop' | tr -d "\n")
	fi

	echo "$gateway"
}

_set_route_common() {
	local multipath_config_route interface_gw interface_if
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

	multipath_config_route=$(_get_multipath_config $INTERFACE)

	#network_get_device interface_if $INTERFACE
	interface_up=$(ifstatus "$INTERFACE" 2>/dev/null | jsonfilter -q -e '@["up"]')
	interface_if=$(_get_interface_device "$INTERFACE")
	interface_current_config=$(uci -q get openmptcprouter.$INTERFACE.state || echo "up")
	if [ "$multipath_config_route" != "off" ] && [ "$SETROUTE" != true ] && [ "$INTERFACE" != "$PREVINTERFACE" ] && [ "$interface_current_config" = "up" ] && [ "$interface_up" = "true" ]; then
		interface_gw=$(_get_interface_gateway "$INTERFACE" "$ipv6")
		
		if [ "$interface_gw" != "" ] && [ "$interface_if" != "" ]; then
			[ "$debug" = "true" ] && [ "$SETDEFAULT" = "yes" ] && _log "$PREVINTERFACE down. Replace default route by $interface_gw dev $interface_if"
			[ "$debug" = "true" ] && [ "$SETDEFAULT" != "yes" ] && _log "$PREVINTERFACE down. Replace default in table 991337 route by $interface_gw dev $interface_if"
			if [ "$SETDEFAULT" = "yes" ] && [ "$(uci -q get openmptcprouter.settings.defaultgw)" != "0" ]; then
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
		resolve_cmd="resolveip -6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
	else
		ip_cmd="ip"
		resolve_cmd="resolveip -4"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
	fi

	server_route() {
		local serverip multipath_config_route
		serverip=$1
		[ -n "$serverip" ] && serverip="$($resolve_cmd -t 5 $serverip | head -n 1 | tr -d '\n')"
		
		config_get disabled $server disabled
		[ "$disabled" = "1" ] && return

		multipath_config_route=$(_get_multipath_config $OMR_TRACKER_INTERFACE)

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
		resolve_cmd="resolveip -6"
	else
		ip_cmd="ip"
		resolve_cmd="resolveip -4"
	fi

	delete_route() {
		local serverip=$1
		[ -n "$serverip" ] && serverip="$($resolve_cmd -t 5 $serverip | head -n 1 | tr -d '\n')"
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

_set_routes_intf_common() {
	local multipath_config_route
	local interface_if
	local INTERFACE=$1
	local ipv6="${2:false}"
	[ -z "$INTERFACE" ] && return
	[ "$INTERFACE" = "omrvpn" ] && return
	[ "$INTERFACE" = "omr6in4" ] && return

	multipath_config_route=$(_get_multipath_config $INTERFACE)

	#network_get_device interface_if $INTERFACE
	interface_if=$(_get_interface_device "$INTERFACE")
	interface_up=$(ifstatus "$INTERFACE" 2>/dev/null | jsonfilter -q -e '@["up"]')
	#multipath_current_config=$(multipath $interface_if | grep 'deactivated')
	interface_current_config=$(uci -q get openmptcprouter.$INTERFACE.state || echo "up")
	interface_vpn=$(uci -q get openmptcprouter.$INTERFACE.vpn || echo "0")
	if { [ "$interface_vpn" = "0" ] || [ "$(uci -q get openmptcprouter.settings.allmptcpovervpn)" = "0" ]; } && [ "$multipath_config_route" != "off" ] && [ "$interface_current_config" = "up" ] && [ "$interface_if" != "" ] && [ "$interface_up" = "true" ]; then
		interface_gw=$(_get_interface_gateway "$INTERFACE" "$ipv6")
		#if [ "$interface_gw" != "" ] && [ "$interface_if" != "" ] && [ -n "$serverip" ] && [ "$(ip route show $serverip | grep $interface_if)" = "" ]; then
		if [ "$interface_gw" != "" ] && [ "$interface_if" != "" ] && [ -z "$(echo $interface_gw | grep :)" ]; then
			if [ "$(uci -q get network.$INTERFACE.weight)" != "" ]; then
				weight=$(uci -q get network.$INTERFACE.weight)
			elif [ "$(uci -q get openmptcprouter.$INTERFACE.weight)" != "" ]; then
				weight=$(uci -q get openmptcprouter.$INTERFACE.weight)
			elif [ "$multipath_config_route" = "master" ]; then
				weight=100
			else
				weight=1
			fi

			# Build routes based on IPv6 flag and backup status
			local route_fragment="nexthop via $interface_gw dev $interface_if weight $weight"

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
		fi
	fi
}

set_routes_intf() {
	_set_routes_intf_common "$1" false
}
set_routes_intf6() {
	_set_routes_intf_common "$1" true
}

_set_route_balancing_common() {
	local multipath_config_route interface_gw interface_if
	INTERFACE=$1
	[ -z "$INTERFACE" ] && return
	[ "$INTERFACE" = "omrvpn" ] && return
	[ "$INTERFACE" = "omr6in4" ] && return
	multipath_config_route=$(_get_multipath_config $INTERFACE)

	#network_get_device interface_if $INTERFACE
	interface_if=$(_get_interface_device "$INTERFACE")
	interface_up=$(ifstatus "$INTERFACE" 2>/dev/null | jsonfilter -q -e '@["up"]')
	interface_current_config=$(uci -q get openmptcprouter.$INTERFACE.state || echo "up")
	interface_vpn=$(uci -q get openmptcprouter.$INTERFACE.vpn || echo "0")
	if { [ "$interface_vpn" = "0" ] || [ "$(uci -q get openmptcprouter.settings.allmptcpovervpn)" = "0" ]; } && [ "$multipath_config_route" != "off" ] && [ "$interface_current_config" = "up" ] && [ "$interface_up" = "true" ]; then
		interface_gw=$(_get_interface_gateway "$INTERFACE" false)

		if [ "$interface_gw" != "" ] && [ "$interface_if" != "" ]; then
			if [ "$(uci -q get network.$INTERFACE.weight)" != "" ]; then
				weight=$(uci -q get network.$INTERFACE.weight)
			elif [ "$(uci -q get openmptcprouter.$INTERFACE.weight)" != "" ]; then
				weight=$(uci -q get openmptcprouter.$INTERFACE.weight)
			elif [ "$multipath_config_route" = "master" ]; then
				weight=100
			else
				weight=1
			fi

			local route_fragment="nexthop via $interface_gw dev $interface_if weight $weight"

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
		fi
	fi
}

set_route_balancing() {
	_set_route_balancing_common "$1" false
}
set_route_balancing6() {
	_set_route_balancing_common "$1" true
}

_set_server_all_routes_common() {
	local server=$1
	local ipv6="${2:-false}"
	local ip_cmd resolve_cmd routes_var backup_var nbintf_var nbintfb_var gateway_var suffix
	[ -z "$OMR_TRACKER_INTERFACE" ] && return

	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		resolve_cmd="resolveip -6"
		routes_var="routesintf6"
		backup_var="routesintfbackup6" 
		nbintf_var="nbintf6"
		nbintfb_var="nbintfb6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
		suffix="_6"
	else
		ip_cmd="ip"
		resolve_cmd="resolveip -4"
		routes_var="routesintf"
		backup_var="routesintfbackup"
		nbintf_var="nbintf"
		nbintfb_var="nbintfb"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
		suffix="_4"
	fi

	server_route() {
		local serverip multipath_config_route interface_if interface_up
		serverip=$1
		[ -n "$serverip" ] && serverip="$($resolve_cmd -t 5 $serverip | head -n 1 | tr -d '\n')"
		config_get disabled $server disabled
		[ "$disabled" = "1" ] && return
		#network_get_device interface_if $OMR_TRACKER_INTERFACE
		interface_if=$(_get_interface_device "$OMR_TRACKER_INTERFACE")
		interface_up=$(ifstatus "$OMR_TRACKER_INTERFACE" 2>/dev/null | jsonfilter -q -e '@["up"]')

		multipath_config_route=$(_get_multipath_config $OMR_TRACKER_INTERFACE)

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
			local current_routes=$(eval "echo \$${routes_var}")
			local current_backup=$(eval "echo \$${backup_var}")
			local current_nbintf=$(eval "echo \$${nbintf_var}")
			local current_nbintfb=$(eval "echo \$${nbintfb_var}")

			if [ -n "$current_routes" ]; then
				local existing_gws
				existing_gws=$($ip_cmd r show "$serverip" metric 1 2>/dev/null | grep -oE 'via [^ ]+ dev [^ ]+ weight [0-9]+' | sort | tr '\n' ' ')
				local expected_gws
				expected_gws=$(echo "$current_routes" | grep -oE 'via [^ ]+ dev [^ ]+ weight [0-9]+' | sort | tr '\n' ' ')
				if [ "$existing_gws" != "$expected_gws" ]; then
					[ "$debug" = "true" ] && _log "Set server $server ($serverip) default route $serverip $current_routes"
					$ip_cmd route replace "$serverip" scope global metric 1 $current_routes >/dev/null 2>&1
					[ "$debug" = "true" ] && _log "New server route is $($ip_cmd r show "$serverip" metric 1 | tr -d '\t' | tr -d '\n')"
				fi
			fi

			if [ -n "$current_backup" ]; then
				local existing_backup_gws
				existing_backup_gws=$($ip_cmd r show "$serverip" metric 999 2>/dev/null | grep -oE 'via [^ ]+ dev [^ ]+ weight [0-9]+' | sort | tr '\n' ' ')
				local expected_backup_gws
				expected_backup_gws=$(echo "$current_backup" | grep -oE 'via [^ ]+ dev [^ ]+ weight [0-9]+' | sort | tr '\n' ' ')
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
		resolve_cmd="resolveip -6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
		suffix="_6"
	else
		ip_cmd="ip"
		resolve_cmd="resolveip -4"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
		suffix="_4"
	fi

	server_route() {
		local serverip multipath_config_route interface_if interface_up interface_current_config
		local metric

		serverip="$1"
		[ -n "$serverip" ] && serverip="$($resolve_cmd -t 5 "$serverip" | head -n 1 | tr -d '\n')"

		config_get disabled "$server" disabled
		[ "$disabled" = "1" ] && return

		metric="${2:-$(uci -q get "network.${OMR_TRACKER_INTERFACE}.metric")}"
		#"
		multipath_config_route=$(_get_multipath_config "$OMR_TRACKER_INTERFACE")

		interface_if=$(_get_interface_device "$OMR_TRACKER_INTERFACE")
		interface_up=$(ifstatus "$OMR_TRACKER_INTERFACE" 2>/dev/null | jsonfilter -q -e '@["up"]')
		interface_current_config=$(uci -q get "openmptcprouter.${OMR_TRACKER_INTERFACE}.state")
		[ -z "$interface_current_config" ] && interface_current_config="up"

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
	local default_gw_enabled=$(uci -q get "openmptcprouter.settings.defaultgw")
	local interface_up=$(ifstatus "$OMR_TRACKER_INTERFACE" 2>/dev/null | jsonfilter -q -e '@["up"]')
	local interface_current_config=$(uci -q get "openmptcprouter.${OMR_TRACKER_INTERFACE}.state")
	[ -z "$interface_current_config" ] && interface_current_config="up"
	local multipath_config_route=$(_get_multipath_config "$OMR_TRACKER_INTERFACE")
	local metric=$(uci -q get "network.${OMR_TRACKER_INTERFACE}.metric")

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

_del_server_route_common() {
	local server="$1"
	local ipv6="${2:-false}"
	local ip_cmd resolve_cmd gateway_var

	[ -z "$OMR_TRACKER_DEVICE" ] && return
	if [ "$ipv6" = "true" ]; then
		ip_cmd="ip -6"
		resolve_cmd="resolveip -6"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY6"
	else
		ip_cmd="ip"
		resolve_cmd="resolveip -4"
		gateway_var="$OMR_TRACKER_DEVICE_GATEWAY"
	fi

	remove_route() {
		local serverip="$1"
		[ -n "$serverip" ] && serverip="$($resolve_cmd -t 5 "$serverip" | head -n 1 | tr -d '\n')"

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
				metric=$(uci -q get "network.${OMR_TRACKER_INTERFACE}.metric")
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

