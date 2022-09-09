#!/bin/sh
# Copyright (c) 2013 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary. 

ACD_DEBUG_OUTOUT=0
ACD_SWITCH_CONFIG_COMMAND=swconfig

. /lib/functions.sh
. /lib/functions/hyfi-iface.sh
. /lib/functions/hyfi-network.sh

local link prev_link=2 router_detected=0 gw_iface="" gw_switch_port=""
local ieee1905managed switch_iface="" vlan_group="" switch_ports
local cpu_portmap=0
local start_mode="init"

__acd_echo() {
	if [ "$ACD_DEBUG_OUTOUT" -gt 0 ]; then
		echo "$1" > /dev/console
	else
		echo "$1"
	fi
}

__acd_find_switch() {
	local vlan_grp

	__hyfi_get_switch_iface switch_iface

	if [ -n "$switch_iface" ]; then
		$ACD_SWITCH_CONFIG_COMMAND dev switch0 set flush_arl 2>/dev/null
		vlan_grp="`echo $ether_iface | awk -F. '{print $2}' 2>/dev/null`"
	fi

	if [ -z "$vlan_grp" ]; then
		vlan_group="1"
	else
		vlan_group="$vlan_grp"
	fi
}

__acd_get_switch_ports() {
        local local config="$1"
	local vlan_group="$2"
        local ports vlan cpu_port __cpu_portmap

        config_get vlan "$config" vlan
        config_get ports "$config" ports

        [ ! "$vlan" = "$vlan_group" ] && return

        cpu_port=`echo $ports | awk '{print $1}'`
        ports=`echo $ports | sed 's/'$cpu_port' //g'`
        eval "$3='$ports'"

		cpu_port=`echo $cpu_port | awk -Ft '{print $1}'`

		case $cpu_port in
			0) __cpu_portmap=0x01;;
			1) __cpu_portmap=0x02;;
			2) __cpu_portmap=0x04;;
			3) __cpu_portmap=0x08;;
			4) __cpu_portmap=0x10;;
			5) __cpu_portmap=0x20;;
			6) __cpu_portmap=0x40;;
			7) __cpu_portmap=0x80;;
		esac
        eval "$4='$__cpu_portmap'"
}

# __acd_check_links
# input: $1 1905.1 managed bridge
# output: $2 1 if link is up in at least 1 Ethernet port
__acd_check_links() {
	local ether_ifaces_full ether_ifaces
	local ether_iface ret

	# Get all Ethernet interfaces
	hyfi_get_ether_ifaces $1 ether_ifaces_full
	hyfi_strip_list $ether_ifaces_full ether_ifaces

	for ether_iface in $ether_ifaces; do
		if [ "$switch_iface" = "$ether_iface" ]; then
			local port link_status

			for port in $switch_ports; do

				if [ -n "$gw_switch_port" -a "$gw_switch_port" = "$port" ]; then
					continue
				fi

				link_status=`$ACD_SWITCH_CONFIG_COMMAND dev switch0 port $port show | grep link | awk -F: '{print $NF}' 2>/dev/null`

				if [ ! "$link_status" = "down" ]; then
					# link is up
					eval "$2='1'"
					__acd_echo "acd: Link on port $port is UP"
					return
				fi
			done
			continue
		fi

		if [ -n "$gw_iface" -a "$gw_iface" = "$ether_iface" ]; then
			continue
		fi

		ret=`ifconfig $ether_iface | grep UP[A-Z' ']*RUNNING`
		if [ -n "$ret" ]; then
			#link is up
			eval "$2='1'"
			__acd_echo "acd: Link on interface $ether_iface is UP"
			return
		fi
	done
	eval "$2='0'"
	__acd_echo "acd: Link is DOWN"
}

__acd_check_gw_iface_link() {
	local ret

	if [ "$gw_iface" = "$switch_iface" ]; then
		local link_status

		link_status=`$ACD_SWITCH_CONFIG_COMMAND dev switch0 port $gw_switch_port show | grep link | awk -F: '{print $NF}'`
		if [ ! "$link_status" = "down" ]; then
			# link is up
			__acd_echo "acd: Link to GW UP"
			return 1
		fi
	else
		ret=`ifconfig $gw_iface | grep UP[A-Z' ']*RUNNING`
		[ -n "$ret" ] && return 1
	fi
	__acd_echo "acd: Link to GW DOWN"
	return 0
}

# __acd_check_gateway
# input: $1 1905.1 managed bridge
# output: $2 Gateway interface
# returns: 1 if gateway is detected
__acd_check_gateway() {
	local gw_ip gw_mac __gw_iface
	local ether_ifaces_full ether_ifaces
	local ether_iface ret

	gw_ip=`route | grep default | grep br-$1 | awk '{print $2}'`
	[ -z "$gw_ip" ] && return 0

	ping $gw_ip -c1 >/dev/null

	gw_mac=`cat /proc/net/arp | grep -w $gw_ip | awk '{print $4}'`
	[ -z "$gw_mac" ] && return 0

	__gw_iface=`hyctl getfdb br-$1 1024 | grep -i $gw_mac | awk '{print $4}'`
	[ -z "$__gw_iface" ] && return 0

	# Get all Ethernet interfaces
	hyfi_get_ether_ifaces $1 ether_ifaces_full
	hyfi_strip_list $ether_ifaces_full ether_ifaces

	# Check if this interface belongs to our network
	for ether_iface in $ether_ifaces; do
		if [ "$ether_iface" = "$__gw_iface" ]; then
			gw_iface=$__gw_iface
			__acd_echo "acd: Detected Gateway on interface $gw_iface"
			if [ "$ether_iface" = "$switch_iface" ]; then
				local portmap __gw_switch_port=99
				local __switch_iface="`echo $ether_iface | awk -F. '{print $1}' 2>/dev/null`"
				portmap=`$ACD_SWITCH_CONFIG_COMMAND dev $__switch_iface get dump_arl | grep -i $gw_mac | grep -v $cpu_portmap | awk '{print $NF}'`

				case $portmap in
					0x01) __gw_switch_port=0;;
					0x02) __gw_switch_port=1;;
					0x04) __gw_switch_port=2;;
					0x08) __gw_switch_port=3;;
					0x10) __gw_switch_port=4;;
					0x20) __gw_switch_port=5;;
					0x40) __gw_switch_port=6;;
					0x80) __gw_switch_port=7;;
				esac

				if [ "$__gw_switch_port" -eq 99 ]; then
					__acd_echo "acd: invalid port map $portmap"
					return 0
				fi
				gw_switch_port=$__gw_switch_port
			fi
			return 1
		fi
	done

	return 0
}

__acd_restart() {
	local __mode="$1"
	__acd_echo "acd: restart in $__mode mode"

	/etc/init.d/acd restart_in_${__mode}_mode
	exit 0
}

# __acd_disable_vaps
# input: $1 config
# input: $2 network
# input: $3 mode: sta or ap
# input: $4 1 - disable, 0 - enable
# input-output: $5 change counter
__acd_disable_vaps() {
	local config="$1"
	local mode network disabled
	local changed="$5"

	config_get mode "$config" mode
	config_get network "$config" network
	config_get disabled "$config" disabled

	if [ "$2" = "$network" -a "$3" = "$mode" -a ! "$4" = "$disabled" ]; then
		uci_set wireless $config disabled $4
		changed=$((changed + 1))
		eval "$5='$changed'"
	fi
}

# Get the IEEE1905.1 managed bridge name
hyfi_get_ieee1905_managed_iface ieee1905managed
__acd_find_switch $ieee1905managed
[ -n "$switch_iface" ] && __acd_echo "acd: found switch on $switch_iface VLAN=$vlan_group"

config_load network
config_foreach __acd_get_switch_ports switch_vlan $vlan_group switch_ports cpu_portmap
__acd_echo "acd: switch ports in the $ieee1905managed network: $switch_ports"

local hyd_mode

config_load hyd
config_get hyd_mode config 'Mode'
[ -n "$1" ] && start_mode="$1"
__acd_echo "acd: Hy-Fi mode: $hyd_mode, start mode: $start_mode"

__acd_check_gateway $ieee1905managed
router_detected=$?

if [ "$hyd_mode" = "HYROUTER" ]; then
	if [ "$router_detected" -eq 0 ]; then
		if [ ! "$start_mode" = "hr" ]; then
			__acd_restart hc
		else
			local retries=3

			while [ "$retries" -gt 0 ]; do
				__acd_check_gateway $ieee1905managed
				router_detected=$?
				[ "$router_detected" -gt 0 ] && break
				retries=$((retries -1))
				__acd_echo "acd: redetecting gateway ($retries retries left)"
			done
			if [ "$router_detected" -gt 0 ]; then
				__acd_restart hc
			fi
		fi
	fi
else
	if [ "$router_detected" -eq 1 ]; then
		__acd_restart hr
	fi
fi

local config_changed

while true; do
	config_changed=0
	if [ "$router_detected" -eq 0 ]; then
		__acd_check_gateway $ieee1905managed
		router_detected=$?

		if [ "$router_detected" -gt 0 ]; then
			__acd_restart hr
		fi
	else
		__acd_check_gw_iface_link

		if [ "$?" -eq 0 ]; then
			# Gateway is gone
			router_detected=0
			gw_iface=""
			gw_switch_port=""
			__acd_restart hc
		fi

		sleep 2;
		continue
	fi

	__acd_check_links $ieee1905managed link

	if [ ! "$prev_link" = "$link" ]; then
		if [ "$link" -gt 0 ]; then
			local disable_hc_mode

			config_load acd
			config_get disable_hc_mode config DisableHCMode

			config_load wireless

			if [ "$disable_hc_mode" -eq 0 ]; then
				# Link is up, turn off range extender
				config_foreach __acd_disable_vaps wifi-iface $ieee1905managed 'ap' '1' config_changed
			else
				config_foreach __acd_disable_vaps wifi-iface $ieee1905managed 'ap' '0' config_changed
			fi

			config_foreach __acd_disable_vaps wifi-iface $ieee1905managed 'sta' '0' config_changed
		else
			config_load wireless
			config_foreach __acd_disable_vaps wifi-iface $ieee1905managed 'sta' '0' config_changed
			config_foreach __acd_disable_vaps wifi-iface $ieee1905managed 'ap' '0' config_changed
		fi

		prev_link=link;
		if [ "$config_changed" -gt 0 ]; then
			uci commit wireless
			[ -f "/etc/init.d/hyd" ] && /etc/init.d/hyd stop
			[ -f "/etc/init.d/wsplcd" ] && /etc/init.d/wsplcd stop
			hyfi_network_restart
		fi
	fi

	sleep 2;
done
