WLAN_DEVICES=
WLAN_INCLUDED_DEVICES=
WLAN_VLAN_DEVICES=
WLAN_VLAN_STA_DEVICES=
WLAN_DEVICE_NUM=
ETHER_DEVICES=
PLC_DEVICE=
ALL_DEVICES=
IFACE_VLANIDS=

. /lib/functions/hyfi-debug.sh

ieee1905managed_found=0
ieee1905managed_bridge=""
ieee1905managed_bridge2=""
bound_bridge=""
device_wlan=1
backhaul_network="backhaul"
traffic_separation_enabled=0
traffic_separation_active=0
map_traffic_separation_active=0
map_bh_nw="backhaul"
# Network names parsed in hyfi_get_ieee1905_brguest_map()
map_nw_One=""
map_nw_Two=""
map_nw_Three=""
iface_config=
config_load 'repacd'
config_get_bool ezmesh repacd 'Ezmesh' '0'
    if [ "$ezmesh" -eq 1 ]; then
        MAP='ezmesh'
    else
        MAP='hyd'
    fi

__hyfi_get_wlan_vifnum() {
	local config="$1"
	local iface network disabled
	local phydev phydisabled

	config_get network "$config" network
	config_get disabled "$config" disabled '0'
	config_get phydev "$config" device ""

	if [ -z "$phydev" ]; then
		return
	fi

	config_get phydisabled ${phydev} disabled 0
	if [ $phydisabled -eq 0 -a "$2" = "$network" -a "$disabled" -eq 0 ]; then
		WLAN_DEVICE_NUM=$((WLAN_DEVICE_NUM + 1))
	fi
}

# hyfi_get_wlan_vifnum()
# input: $1 IEEE1905.1 managed bridge interface
# output: $2 number of WLAN interfaces bound to the bridge
hyfi_get_wlan_vifnum() {
	local ieee1905managed="$1"

	WLAN_DEVICE_NUM=0
	config_load wireless
	config_foreach __hyfi_get_wlan_vifnum wifi-iface $ieee1905managed

	eval "$2='${WLAN_DEVICE_NUM}'"
}

__hyfi_get_iface_vlanids() {
	local config="$1"
	local loc_iface loc_vid

	config_get loc_iface "$config" ifname
	config_get loc_vid "$config" vid

	if [ "$loc_iface" -a "$loc_vid"  ]; then
		IFACE_VLANIDS="${IFACE_VLANIDS}${IFACE_VLANIDS:+","}${loc_iface}.${loc_vid}"
	fi
}

hyfi_get_iface_vlanids() {
	IFACE_VLANIDS=""

	config_load $MAP
	config_foreach __hyfi_get_iface_vlanids Vlanid

	eval "$1='${IFACE_VLANIDS}'"
}

__hyfi_is_iface_up() {
	local iface="$1"
	bitRate=$(iwconfig $iface | grep Rate | awk '{print$2}' | cut -d ":" -f2 | cut -d "." -f1)
	accessPoint=$(iwconfig $iface | grep Access | awk '{print$6}')

	if [ "$bitRate" -eq 0 ] || [ "$accessPoint" = "Not-Associated" ]; then
		return 0
	fi

	return 1
}

__hyfi_get_wlan_ifaces() {
	local config="$1"
	local iface network disabled device

	config_get iface "$config" ifname
	config_get network "$config" network
	config_get disabled "$config" disabled '0'
	config_get device "$config" device
	config_get mapEnable "$config" map
	config_get mode "$config" mode

	if [ -n "$mapEnable" ]; then
		config_load $MAP
		config_get sigmaEnabled MultiAP 'EnableSigmaDUT' '0'

		# Ignore if sigma flag is enabled
		if [ -n "$iface" -a "$mapEnable" -gt 0 -a "$disabled" -eq 0 \
				-a "$mode" = "sta" -a "$sigmaEnabled" -eq 0 ]; then
			__hyfi_is_iface_up $iface
			is_iface_up=$?
			if [ "$is_iface_up" -eq 0 ]; then
				return
			fi
		fi
	fi

	if [ -n "$iface" -a "$disabled" -eq 0 ]; then
		if [ "$network" = "$2" ]; then
			WLAN_DEVICES="${WLAN_DEVICES}${WLAN_DEVICES:+","}${iface}@${device}&${network}:WLAN"
		fi
		# include network=backhaul for guest network support
		if [ "$network" = "$2" -o "$network" = "backhaul" ]; then
			WLAN_INCLUDED_DEVICES="${WLAN_INCLUDED_DEVICES}${WLAN_INCLUDED_DEVICES:+","}${device}:${iface}"
		fi
	fi
}

# hyfi_get_wlan_ifaces()
# input: $1 IEEE1905.1 managed bridge interface
# output: $2 List of all WLAN interfaces bound to the bridge
# output: $3 List of all WLAN devices/radios bound to the bridge
hyfi_get_wlan_ifaces() {
	local ieee1905managed="$1"

	WLAN_DEVICES=""
	WLAN_INCLUDED_DEVICES=""
	hyfi_network_sync
	config_load wireless
	config_foreach __hyfi_get_wlan_ifaces wifi-iface $ieee1905managed

	eval "$2='${WLAN_DEVICES}'"
	eval "$3='${WLAN_INCLUDED_DEVICES}'"
}

__hyfi_get_switch_iface() {
	local loc_switch_iface loc_eswitch_support="0"
	local ref_design
	local loc_switch_num="0"
	local loc_switch_present="1"

	config_load hyd
	config_get loc_switch_iface config SwitchInterface ""

	if [ "$loc_switch_iface" = "auto" ]; then
		ref_design=`cat /tmp/sysinfo/board_name`

		# List of supported reference designs. For other designs
		# either add to cases, or setup SwitchInterface.
		case "$ref_design" in
		ap145|ap147|ap148*|db149|ap151)
		# S17c switch
		# ap148_1xx is also a supported board type
			loc_switch_iface="eth1"
			loc_eswitch_support="1"
			;;
		ap160|ap161)
		# S17c switch support is disabled even though interface is identified
			loc_switch_iface="eth1"
			loc_eswitch_support="0"
			;;
		ap152|apjet01)
			loc_switch_iface="eth0"
			loc_eswitch_support="0"
			;;
		ap-dk*)
		# Malibu switch with a single host port connected in a VLAN
		# tagged manner. Since the switch config indicates the host
		# port is tagged (as it is from the switch's perspective) but
		# the host interfaces are not VLAN tagged, a special option
		# is needed to force the interface names to be untagged.
			loc_switch_iface="eth1"
			force_untagged_iface=1
			loc_eswitch_support="0"
			;;
		ap-mp03.1*|db-mp03.1*)
			loc_switch_iface="eth1"
			force_untagged_iface=1
			loc_eswitch_support="0"
			loc_switch_num="1"
			echo 1 > /sys/ssdk/dev_id
			;;
		ap-mp02.1*|db-mp02.1*|ap-mp03.3*|dp-mp03.3*|ap-mp03.4*|db-mp03.4*|ap-mp03.5*|db-mp03.5*|ap-mp03.6*|db-mp03.6*)
			loc_switch_iface=""
			loc_switch_present="0"
			;;
		ap135)
			loc_switch_iface="eth1"
			loc_eswitch_support="0"
			;;
		*)
			loc_switch_iface=""
			;;
		esac
	fi

	if [ -z "$loc_switch_iface" ]; then
		eval "$1=''"
		eval "$2='$loc_eswitch_support'"
		eval "$3='$loc_switch_num'"
		eval "$4='$loc_switch_present'"
		return
	fi

	local loc_switch_cpu_port
	__hyfi_get_switch_cpu_port loc_switch_cpu_port

	local lan_vid
	__hyfi_get_switch_lan_vid lan_vid

	if [ -z "$switch_cpu_port_tagged" -o -n "$force_untagged_iface" ]; then
		eval "$1='$loc_switch_iface'"
	else
		eval "$1='${loc_switch_iface}.${lan_vid}'"
	fi

	eval "$2='$loc_eswitch_support'"
	eval "$3='$loc_switch_num'"
	eval "$4='$loc_switch_present'"
}

__hyfi_get_switch_lan_vid() {
	local loc_lan_vid

	config_load hyd
	config_get loc_lan_vid config SwitchLanVid ""

	eval "$1='$loc_lan_vid'"
}

__hyfi_get_switch_cpu_port_iterate() {
	config_get vlan "$1" "vlan"
	config_get ports "$1" "ports"

	if [ "${vlan}" = "$2" ]; then
		switch_cpu_port=`echo ${ports} |sed 's/t//g' |cut -f 1 -d " "`
		switch_cpu_port_tagged=`echo ${ports} |grep t`
	fi
}

__hyfi_get_switch_cpu_port() {
	local lan_vid
	__hyfi_get_switch_lan_vid lan_vid

	config_load network
	config_foreach __hyfi_get_switch_cpu_port_iterate switch_vlan $lan_vid

	eval "$1='$switch_cpu_port'"
}

__hyfi_get_ether_ifaces() {
	local config="$1"
	local ifnames network plciface bridge_name dev

	#config_get ifnames "$config" device
        ifnames=`uci get network.$1.ifname`
	config_get bridge_name "$config" ifname
	config_load plc
	config_get plciface config PlcIfname


	local switch_iface eswitch_support switch_num switch_present
	__hyfi_get_switch_iface switch_iface eswitch_support switch_num switch_present

	if [ "$2" = "$config" ]; then
		# Check the ifnames parameter is populated correctly
		if [ -z "$ifnames" ]; then
			# If the ifnames parameter doesn't contain the device list, it should
			# be present in the bridge_name.  However, it's possible a race
			# condition occured, and neither parameter contains the device list.
			# Check the device list again if the bridge_name actually contains the
			# name of the bridge.
			if echo $bridge_name | grep -q br-; then
				hyfi_debug hyiface "Missing device names, and ifname matches bridge, fetching device names again"
				config_get ifnames "$config" device
				if [ -z "$ifnames" ]; then
					ifnames=`uci get "network.$1.ifname"`
					hyfi_error hyiface "Device names missing, defaulting to $ifnames"
				else
					hyfi_debug hyiface "Device names now populated correctly"
				fi
			else
				ifnames=$bridge_name
				hyfi_debug hyiface "Missing device names, so using ifname parameter instead"
			fi
		fi

		for iface in $ifnames; do
			[ "$iface" = "$plciface" ] && continue

			if [ "$traffic_separation_enabled" -gt 0 ] && \
				[ "$traffic_separation_active" -gt 0 ]; then
					if __hyfi_is_vlan_iface $iface; then
						if __hyfi_is_device_wlan $iface dev; then
							continue
						fi
					fi
			fi

			if [ "$map_traffic_separation_active" -gt 0 ]; then
				if __hyfi_is_device_wlan $iface dev; then
					continue
				fi
			fi

			if [ "$iface" = "$switch_iface" -a "$eswitch_support" = "1" ]; then
				ETHER_DEVICES="${ETHER_DEVICES}${ETHER_DEVICES:+","}${iface}:ESWITCH"
			else
				ETHER_DEVICES="${ETHER_DEVICES}${ETHER_DEVICES:+","}${iface}&${config}:ETHER"
			fi
		done
	fi
}

# hyfi_get_ether_ifaces()
# input: $1 IEEE1905.1 managed bridge interface
# output: $2 List of all Ethernet interfaces bound to the bridge
hyfi_get_ether_ifaces() {
	local ieee1905managed="$1"

	ETHER_DEVICES=""
	hyfi_network_sync

	config_load repacd
	config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
	config_get traffic_separation_active repacd TrafficSeparationActive '0'
	config_get backhaul_network repacd NetworkBackhaul 'backhaul'
	config_get map_bh_nw MAPConfig VlanNetworkBackHaul 'backhaul'
	config_get map_traffic_separation_active MAPConfig 'MapTrafficSeparationActive' '0'

	config_load network
	config_foreach __hyfi_get_ether_ifaces interface $ieee1905managed

	eval "$2='${ETHER_DEVICES}'"
}

__hyfi_is_vlan_iface() {
	local iface="$1"

	echo "$iface" | grep '\.' >/dev/null 2>&1
	if [ "$?" -eq "0" ]; then
		return 0
	fi

	return 1
}

__hyfi_iterate_wlan_ifaces() {
	local config="$1"
	local iface network disabled
	local interface
	local device

	config_get iface "$config" ifname
	config_get network "$config" network
	config_get disabled "$config" disabled '0'
	config_get device "$config" device

	if [ -n "$iface" -a "$backhaul_network" = "$network" -a "$disabled" -eq 0 ]; then
		interface=`echo "$2" | cut -d '.' -f1`
		if [ "$interface" = "$iface" ]; then
			eval "$3='0'"
			eval "$4=$config"
			eval "$5=$device"
		fi
	fi

	if [ "$map_traffic_separation_active" -gt 0 ]; then
		if [ -n "$iface" -a "$disabled" -eq 0 ]; then
			if [ "$network" = "$map_bh_nw" ] || \
				[ "$network" = "$map_nw_One" ] || \
					[ "$network" = "$map_nw_Two" ] || \
						[ "$network" = "$map_nw_Three" ] || \
							[ "$network" = "lan" ]; then
							interface=`echo "$2" | cut -d '.' -f1`
							if [ "$interface" = "$iface" ]; then
								eval "$3='0'"
								eval "$4=$config"
								eval "$5=$device"
							fi
			fi
		fi
	fi
}

__hyfi_is_device_wlan() {
	local iface="$1"
	device_wlan=1
	local wdev

	if [ -n "$backhaul_network" ] || [ -n "$map_bh_nw" ]; then
		config_load wireless
		config_foreach __hyfi_iterate_wlan_ifaces wifi-iface $iface device_wlan iface_config wdev
	fi
	eval "$2=$wdev"
	return $device_wlan
}

__hyfi_get_wlan_vlan_ifaces() {
	local config="$1"
	local ifnames bridge_name
        local wdevice

	config_get ifnames "$config" device
	config_get bridge_name "$config" ifname

	if [ "$2" = "$config" ]; then
                #initially VLAN interfaces are added using vconfig and brctl tool
                #to avoid multiple restarts.VLAN interfaces added this way are not
                #detected by config_get, so using direct command here.
		ifnames=`uci get "network.$1.ifname"`
		for iface in $ifnames; do
			if __hyfi_is_vlan_iface $iface; then
				if __hyfi_is_device_wlan $iface wdevice; then
					WLAN_VLAN_DEVICES="${WLAN_VLAN_DEVICES}${WLAN_VLAN_DEVICES:+","}${iface}@${wdevice}&${config}:WLAN_VLAN"
				fi
			fi
		done
	fi
}

__hyfi_get_wlan_vlan_sta_ifaces() {
	local config="$1"
	local ifnames bridge_name dev
	local mode

	config_get ifnames "$config" device
	config_get bridge_name "$config" ifname

	if [ "$2" = "$config" ]; then
		ifnames=`uci get "network.$1.ifname"`
		for iface in $ifnames; do
			if __hyfi_is_vlan_iface $iface; then
				if __hyfi_is_device_wlan $iface dev; then
					config_load wireless
					config_get mode "$iface_config" mode
					if [ "$mode" = "sta" ]; then
						WLAN_VLAN_STA_DEVICES="${WLAN_VLAN_STA_DEVICES}${WLAN_VLAN_STA_DEVICES:+","}${iface}"
					fi
				fi
			fi
		done
	fi
}

hyfi_get_wlan_vlan_ifaces() {
	local ieee1905managed="$1"

	WLAN_VLAN_DEVICES=""
	hyfi_network_sync

	config_load repacd
	config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
	config_get traffic_separation_active repacd TrafficSeparationActive '0'
	config_get backhaul_network repacd NetworkBackhaul 'backhaul'
	config_get map_bh_nw MAPConfig VlanNetworkBackHaul 'backhaul'
	config_get map_traffic_separation_active MAPConfig 'MapTrafficSeparationActive' '0'
	if [ "$traffic_separation_enabled" -gt 0 ] && \
		[ "$traffic_separation_active" -gt 0 ] || \
			[ "$map_traffic_separation_active" -gt 0 ]; then
		config_load network
		config_foreach __hyfi_get_wlan_vlan_ifaces interface $ieee1905managed
	fi

	eval "$2='${WLAN_VLAN_DEVICES}'"

}

hyfi_get_wlan_vlan_sta_ifaces() {
	local ieee1905managed="$1"

	WLAN_VLAN_STA_DEVICES=""
	hyfi_network_sync

	config_load repacd
	config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
	config_get traffic_separation_active repacd TrafficSeparationActive '0'
	config_get backhaul_network repacd NetworkBackhaul 'backhaul'
	config_get map_bh_nw MAPConfig VlanNetworkBackHaul 'backhaul'
	config_get map_traffic_separation_active MAPConfig 'MapTrafficSeparationActive' '0'
	if [ "$traffic_separation_enabled" -gt 0 ] && \
		[ "$traffic_separation_active" -gt 0 ] || \
			[ "$map_traffic_separation_active" -gt 0 ]; then
		config_load network
		config_foreach __hyfi_get_wlan_vlan_sta_ifaces interface $ieee1905managed
	fi

	eval "$2='${WLAN_VLAN_STA_DEVICES}'"

}

__hyfi_get_plc_iface() {
	local plciface iface bridge_name
	local ieee1905managed="$1"

	config_load plc
	config_get plciface config PlcIfname

	[ -z "$plciface" ] && return

    config_get bridge_name "$ieee1905managed" ifname
	config_load network
	config_get ifnames $ieee1905managed device

    # Check the ifnames parameter is populated correctly
    if [ -z "$ifnames" ]; then
        # If the ifnames parameter doesn't contain the device list, it should
        # be present in the bridge_name.  However, it's possible a race
        # condition occured, and neither parameter contains the device list.
        # Check the device list again if the bridge_name actually contains the
        # name of the bridge.
        if echo $bridge_name | grep -q br-; then
            hyfi_debug hyiface "Missing device names, and ifname matches bridge, fetching device names again"
            config_get ifnames "$ieee1905managed" device
            if [ -z "$ifnames" ]; then
                ifnames=`uci get "network.$1.ifname"`
                hyfi_error hyiface "Device names missing, defaulting to $ifnames"
            else
                hyfi_debug hyiface "Device names now populated correctly"
            fi
        else
            ifnames=$bridge_name
            hyfi_debug hyiface "Missing device names, so using ifname parameter instead"
        fi
    fi

	for iface in $ifnames; do
		if [ "$iface" = "$plciface" ]; then
			PLC_DEVICE="${plciface}&${ieee1905managed}:PLC"
			return
		fi
	done
}

# hyfi_get_plc_iface()
# input: $1 IEEE1905.1 managed bridge interface
# output: $2 PLC interface bound to the bridge
hyfi_get_plc_iface() {
	local ieee1905managed="$1"

	PLC_DEVICE=""
	hyfi_network_sync

	__hyfi_get_plc_iface $ieee1905managed
	eval "$2='${PLC_DEVICE}'"
}

# hyfi_get_ifaces()
# input: $1 IEEE1905.1 managed bridge interface
# output: $2 List of ALL interface bound to the bridge
# output: $3 List of ALL WLAN devices/radios bound to the bridge
hyfi_get_ifaces() {
	local ieee1905managed="$1"

	WLAN_DEVICES=""
	WLAN_INCLUDED_DEVICES=""
	WLAN_VLAN_DEVICES=""
	ETHER_DEVICES=""
	PLC_DEVICE=""
	hyfi_network_sync

	config_load repacd
	config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
	config_get traffic_separation_active repacd TrafficSeparationActive '0'
	config_get backhaul_network repacd NetworkBackhaul 'backhaul'
	config_get map_traffic_separation_active MAPConfig 'MapTrafficSeparationActive' '0'
	config_get map_bh_nw MAPConfig VlanNetworkBackHaul 'backhaul'

	config_load network
	config_foreach __hyfi_get_ether_ifaces interface $ieee1905managed

	config_load wireless
	config_foreach __hyfi_get_wlan_ifaces wifi-iface $ieee1905managed

	if [ "$traffic_separation_enabled" -gt 0 ] && \
		[ "$traffic_separation_active" -gt 0 ] || \
			[ "$map_traffic_separation_active" -gt 0 ]; then
		config_load network
		config_foreach __hyfi_get_wlan_vlan_ifaces interface $ieee1905managed
	fi

	__hyfi_get_plc_iface $ieee1905managed

	ALL_DEVICES=$WLAN_DEVICES
	if [ -n "$ETHER_DEVICES" ]; then
		[ -z "$ALL_DEVICES" ] || ALL_DEVICES="${ALL_DEVICES},"
		ALL_DEVICES="${ALL_DEVICES}${ETHER_DEVICES}"
	fi
	if [ -n "$PLC_DEVICE" ]; then
		[ -z "$ALL_DEVICES" ] || ALL_DEVICES="${ALL_DEVICES},"
		ALL_DEVICES="${ALL_DEVICES}${PLC_DEVICE}"
	fi
	if [ -n "$WLAN_VLAN_DEVICES" ]; then
		[ -z "$ALL_DEVICES" ] || ALL_DEVICES="${ALL_DEVICES},"
		ALL_DEVICES="${ALL_DEVICES}${WLAN_VLAN_DEVICES}"
	fi

	eval "$2='${ALL_DEVICES}'"
	eval "$3='${WLAN_INCLUDED_DEVICES}'"
}

__hyfi_iterate_networks() {
	local config="$1"
	local type ieee1905managed

	config_get type "$config" type
	[ -z "$type" -o ! "$type" = "bridge" ] && return

	config_get_bool ieee1905managed "$config" ieee1905managed

	[ -z "$ieee1905managed" ] && return

	if [ "$ieee1905managed" -eq "1" ]; then
		ieee1905managed_found=1
		if [ -n "$ieee1905managed_bridge" ]
		then
			ieee1905managed_bridge2="$config"
		else
			ieee1905managed_bridge="$config"
		fi
	fi
}

__hyfi_iterate_networks2() {
	local config="$1"
	local my_iface="$2"
	local ifnames iface type

	[ -n "$bound_bridge" ] && return

	config_get type "$config" type
	[ -z "$type" -o ! "$type" = "bridge" ] && return

	config_get ifnames "$config" device

	for iface in $ifnames; do
		if [ "$iface" = "$my_iface" ]; then
			bound_bridge=br-$config
			return
		fi
	done
}

# hyfi_get_ieee1905_managed_iface()
# output: $1 IEEE1905.1 managed bridge interface
# output: $2 2nd IEEE1905.1 managed bridge interface
# Note: If no entry exists, the function will set the "lan"
# interface as the default managed bridge
hyfi_get_ieee1905_managed_iface() {
	ieee1905managed_found=0
	ieee1905managed_bridge=""
	ieee1905managed_bridge2=""

	config_load network
	config_foreach __hyfi_iterate_networks interface
	eval "$1='$ieee1905managed_bridge'"
	eval "$2='$ieee1905managed_bridge2'"
	[ "$ieee1905managed_found" -eq "1" ] && return

	ieee1905managed_bridge="lan"
	uci_set network $ieee1905managed_bridge ieee1905managed 1
	uci_commit network

	config_load network
	__hyfi_iterate_networks $ieee1905managed_bridge

	eval "$1='$ieee1905managed_bridge'"
}

# hyfi_strip_list
# input: $1 list of interfaces with attached type
# output: $2 same list with type stripped
hyfi_strip_list() {
	eval "$2='`echo $1 | sed 's/@[a-zA-Z0-9]*//g' | sed 's/:[A-Z]*,/ /g' | sed 's/:[A-Z]*//g' | sed 's/&[a-zA-Z0-9]*//g'`'"
}

# hyfi_get_bridge_from_iface()
# input: $1 interface name
# output: $2 bridge the interface is bound to
hyfi_get_bridge_from_iface() {
	bound_bridge=""
	local iface="$1"

	config_load network
	config_foreach __hyfi_iterate_networks2 interface $iface

	eval "$2='$bound_bridge'"
}

# hyfi_get_ieee1905_brguest_map()
# output: $1 IEEE1905.1 secondary network names
# output: $2 IEEE1905.1 backhaul network name
hyfi_get_ieee1905_brguest_map() {
	nw_names=""
	config_load repacd
	config_get num_vlan_supported MAPConfig 'NumberOfVLANSupported' '0'

	# Exclude lan from this list
	num_vlan_supported=$((num_vlan_supported-1))

	for i in One Two Three; do
		if [ "$num_vlan_supported" -eq 0 ]; then
			break
		fi

		config_get nw MAPConfig "VlanNetwork"$i '0'
		config_get type $nw type
		[ -z "$type" -o ! "$type" = "bridge" ] && return

		if [ -n "$nw_names" ]; then
			nw_names="$nw_names $nw"
		else
			nw_names="$nw"
		fi

		eval map_nw_$i=$nw
		num_vlan_supported=$((num_vlan_supported-1))
	done

	# Get BackHaul Network Name
	config_get nw_bh MAPConfig VlanNetworkBackHaul '0'

	eval "$1='$nw_names'"
	eval "$2='$nw_bh'"
}
