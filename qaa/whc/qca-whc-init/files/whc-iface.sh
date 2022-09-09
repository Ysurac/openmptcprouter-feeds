guest_network="guest"
traffic_separation_enabled=0
traffic_separation_active=0
WLAN_INCLUDED_IFACES=""
WLAN_INCLUDED_DEVICES=""
WLAN_EXCLUDE=

__whc_get_wlan_ifaces() {
	local config="$1"
	local ssid_to_match="$2"
	local network_to_match="$3"
	local device iface disabled mode ssid network radio_disabled

	config_get device "$config" device
	config_get iface "$config" ifname
	config_get disabled "$config" disabled '0'
	config_get mode "$config" mode
	config_get ssid "$config" ssid
	config_get network "$config" network
	config_get radio_disabled "$device" disabled '0'
	config_get SteeringDisabled "$config" SteeringDisabled '0'

	if [ "$traffic_separation_enabled" -gt 0 ] && \
		[ "$traffic_separation_active" -gt 0 ] && \
                [ -n "$network_to_match" -a "$network" != "$network_to_match" -a "$network" != "backhaul" ]; then
			return
	fi

	driver=$(lsmod | cut -d' ' -f 1 | grep ath10k_core)
	#TODO: Read the interface name from config rather than assuming single interface per radio.
	if [ "$driver" == "ath10k_core" -a "$radio_disabled" -eq 0 ]; then
		if [ "$device" == "radio0" ]; then
			iface="wlan0"
		elif [ "$device" == "radio1" ]; then
			iface="wlan1"
		else
			iface="wlan2"
		fi
	fi

	if [ -n "$iface" -a "$disabled" -eq 0 -a $SteeringDisabled -eq 0 ]; then
		if [ "$mode" == "ap" -o "$mode" == "wrap" ]; then
			if [ -z "$ssid_to_match" ]; then
				WLAN_INCLUDED_DEVICES="${WLAN_INCLUDED_DEVICES}${WLAN_INCLUDED_DEVICES:+","}${device}:${iface}"
			else
				if [ ! -n "$ssid_to_match" -o "$ssid" == "$ssid_to_match" ]; then
					WLAN_INCLUDED_DEVICES="${WLAN_INCLUDED_DEVICES}${WLAN_INCLUDED_DEVICES:+","}${device}:${iface}"
					WLAN_INCLUDED_IFACES="${WLAN_INCLUDED_IFACES}${WLAN_INCLUDED_IFACES:+","}${iface}"
					return
				fi
			fi
		fi
	fi
}
__whc_get_wlan_excluded() {
	local config="$1"
	local ifaces_to_match="$2"
	config_get device "$config" device
	config_get iface "$config" ifname
	config_get disabled "$config" disabled '0'
	config_get mode "$config" mode
	config_get ssid "$config" ssid
	config_get network "$config" network

	local iface_array=$(echo $ifaces_to_match | tr ',' "\n")
	if [ -n "$iface" -a "$disabled" -eq 0 ]; then
		if [ "$mode" == "ap" -o "$mode" == "wrap" ]; then
			for i in $iface_array
			do
				if [ ! -n "$i" -o "$iface" == "$i" ]; then
					return
				fi
			done
				WLAN_EXCLUDE="${WLAN_EXCLUDE}${WLAN_EXCLUDE:+","}${device}:${iface}"
		fi
	fi
}

# whc_get_wlan_ifaces()
# input:  $1 The desired SSID. If it is null string, then get all WLAN
#	  $4 The disired network name. Only the interfaces with matching network name included
# output: $2 List of all WLAN interfaces matching the SSID provided and the network name
#            if no matching ssid, only the network name will be checked
#	  $3 the matching SSID returned back to the caller
whc_get_wlan_ifaces() {
	config_load 'repacd'
	config_get guest_network repacd NetworkGuest 'guest'
	config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
	config_get traffic_separation_active repacd TrafficSeparationActive '0'

	config_load wireless
	config_foreach __whc_get_wlan_ifaces wifi-iface "$1" "$4"

	eval "$2='${WLAN_INCLUDED_DEVICES}'"
	eval "$3='$1'"
}

# return the EXCLUDE interface list. This should be called after the interface list is created
whc_get_wlan_ifaces_excl()
{
	config_load wireless
	config_foreach __whc_get_wlan_excluded wifi-iface $WLAN_INCLUDED_IFACES
	eval "$1='${WLAN_EXCLUDE}'"
}

# clean the global variables. This should be called before create the new lists
whc_init_wlan_interface_list()
{
	WLAN_EXCLUDE=""
	WLAN_INCLUDED_DEVICES=""
}

# Check whether atleast one of the available wireless interface is enabled in CFG mode
# input : $1 config: the name of the interface config section
# output: $2 Returns 1 if atleast one of the wireless interface is enabled
#            in CFG and returns 0 otherwise

__whc_check_wlan_cfg_mode() {
    local config="$1"
    local type
    config_get type "$config" type

    if [ "$type" = "qcawificfg80211" ]; then
          eval "$2=1"
          break
    fi
}
