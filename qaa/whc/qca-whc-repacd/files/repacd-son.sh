#!/bin/sh /etc/rc.common
# Copyright (c) 2015, 2017-2019, 2021 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# 2015 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.

RE_DEFAULT_RATE_ESTIMATE_SCALING_FACTOR='70'
RE_ROOT_AP_DISTANCE_INVALID='255'

vap_defconf=1
resolved_ssid='' resolved_enc='' resolved_key=''
resolved_sae_pass='' resolved_sae_group='' resolved_owe_group=''
guest_backhaul_iface=
network_backhaul="backhaul"
backhaul_ssid='' backhaul_key='' backhaul_enc=''
backhaul_sae_pass='' backhaul_sae_group='' backhaul_owe_group=''
def_backhaul_ssid="Backhaul" def_backhaul_key="1234567890" def_backhaul_enc="psk2+ccmp"
guest_ssid='' guest_enc='' guest_key=''
def_guest_ssid="Guest" def_guest_enc="none" def_guest_key=""
traffic_separation_active='' create_sta=0
manage_vap_ind=0
lan_vid=100 guest_vid=102
capsnr=0
Manage_front_and_back_hauls_ind=0

eth_iface_wan="eth0"
eth_iface_lan="eth1"
eth_iface_wan_port=5
eth_iface_lan_port1=4
eth_iface_lan_port2=3

. /lib/functions/repacd-cmn.sh

config_load 'repacd'
config_get def_backhaul_ssid repacd BackhaulSSID $def_backhaul_ssid

# Set bridge_empty option for the given network.
# This option allows to create empty_bridge.
#
# input: $1 network name
__repacd_set_bridge_empty() {
    local name="$1"
    local bridge_empty

    config_load network

    config_get bridge_empty "$name" 'bridge_empty' 0
    if [ "$bridge_empty" -eq 0 ]; then
        uci_set network "$name" bridge_empty '1'
    fi

    uci_commit network
}

# Determine if additional network exist.
# Currently looking out for only guest network.
#
# input: $1 network name
# return: 0 if exist; otherwise non-zero
__repacd_check_additional_network_exist() {
    config_load network

    if [ -n "$network_guest" ]; then
        if __repacd_network_exist $network_guest; then
            return 0
        fi
    fi

    return 1
}

# Get backhaul interfaces for ethernet.
# output: $1 - variable into which we populate interface(eth0.102 or eth1.102).
__repacd_get_backhaul_ifaces_eth_guest() {
    local ifaces
    local ifaces_guest_intf
    ifaces=$(ifconfig 2>&1 | grep eth | grep $guest_vid)
    ifaces_guest_intf=$(echo "$ifaces" | cut -d ' ' -f1)
    eval "$1='$ifaces_guest_intf'"
}

# Delete VLAN interfaces of backhaul vaps.
# input: $1 name of the interface config section
# input: $2 network name
# input: $3 VLAN id
# input: $4 mode 'sta' or 'ap'
# input-output: $5 change counter
__repacd_delete_vlan_interfaces() {
    local config=$1
    local id=$3
    local changed="$5"
    local ifname vlan_ifname
    local disabled mode bssid device hwmode

    config_get network "$config" network
    config_get ifname "$config" ifname
    config_get disabled "$config" disabled '0'
    config_get mode "$config" mode
    config_get device "$config" device
    config_get hwmode "$device" hwmode

    if [ "$hwmode" != "11ad" ]; then
        if [ "$network" = "$network_backhaul" ] && [ -n "$ifname" ] && \
            [ "$disabled" -eq 0 ]; then
            vlan_ifname=$(iwconfig 2>&1 | grep -o "$ifname.$id")
            if [ -n "$vlan_ifname" ]; then
               if __repacd_is_matching_mode "$4" "$mode"; then
                   vconfig rem "$ifname.$id"
                   brctl delif "br-$2" "$ifname.$id"
                   __repacd_delete_interface "$2" "$ifname.$id"
                   changed=$((changed + 1))
                   eval "$5='$changed'"
               fi
            fi
        fi
    fi
}

#Create Back haul interface for ethernet guest network and
#add it to the respective bridge
#input:$1 guest network name
#input-output:$2 change counter
__repacd_add_ethernet_vlan_interfaces() {
    local backhaul_ifaces_eth
    local network=$1
    local changed="$2"

    __repacd_get_backhaul_ifaces_eth_guest  backhaul_ifaces_eth
    if [ -n "$backhaul_ifaces_eth" ]; then
         __repacd_echo "Add VLAN ifaces for ethernet guest network support"
        if [ "$backhaul_ifaces_eth" = "$eth_iface_wan.$guest_vid" ] && [ "$network" = 'guest' ];then
             swconfig dev switch0 vlan $guest_vid set ports "0t ${eth_iface_wan_port}t ${eth_iface_lan_port1}t"
             swconfig dev switch0 set apply
             brctl addif "br-$network" "$backhaul_ifaces_eth"
             ifconfig "$backhaul_ifaces_eth" up
          __repacd_add_interface "$network" "$backhaul_ifaces_eth"
    elif [ "$backhaul_ifaces_eth" = "$eth_iface_lan.$guest_vid" ] && [ "$network" = 'guest' ];then
             swconfig dev switch0 vlan $guest_vid set ports "0t ${eth_iface_lan_port1}t ${eth_iface_lan_port2}t"
             swconfig dev switch0 set apply
             brctl addif "br-$network" "$backhaul_ifaces_eth"
             ifconfig "$backhaul_ifaces_eth" up
         __repacd_add_interface "$network" "$backhaul_ifaces_eth"
    else
             __repacd_echo "For Home network all the traffic is untagged,no vlan"
    fi
    #Do we really need to restart? revisit this
    changed=$((changed + 1))
    eval "$2='$changed'"
    fi

}

# Restart firewall.
__repacd_restart_firewall() {
    /etc/init.d/firewall restart
}

# Restart dnsmasq.
__repacd_restart_dnsmasq() {
    /etc/init.d/dnsmasq restart
}

# Check whether the given interface is the backhaul AP interface on
# the desired network and update the band specific interface names.
#
# input: $1 - config: the name of the interface config section
# input: $2 - network: the name of the network to which the AP interface
#                      must belong to be matched
# output: $3 - iface: the resolved backhaul AP interface name on 2.4 GHz (if found)
# output: $4 - iface: the resolved backhaul AP interface name on 5 GHz (if found)
# output: $5 - iface: the resolved backhaul AP interface name on 6 GHz (if found)
__repacd_wifi_check_and_get_backhaul_ap_iface() {
    local config="$1"
    local network_to_match="$2"
    local iface disabled mode device hwmode backhaul_ap

    config_get network "$config" network
    config_get iface "$config" ifname
    config_get disabled "$config" disabled '0'
    config_get mode "$config" mode
    config_get device "$config" device
    config_get backhaul_ap "$config" backhaul_ap '0'
    config_get hwmode "$device" hwmode
    config_get band "$device" band
    local band_freq=`iwlist $iface 2>&1 channel | grep "Current Frequency" | awk -F':' '{print $2}' | awk -F" " '{print $1}' | sed 's/\.//g' | sed -e "s/\<\([0-9]\{1,4\}\)\>/\10000/; s/\([0-9]\{4\}\)/\1/" | awk '{ print $1; }' | sed -n 's/\([0-9]\{4\}\).*/\1/p' `

    if [ "$hwmode" != "11ad" ]; then
        if [ "$network" = "$network_to_match" ] && [ -n "$iface" ] && [ "$mode" = "ap" ] \
            && [ "$backhaul_ap" -gt 0 ] && [ "$disabled" -eq 0 ]; then
            if [ "$hwmode" = "11axa" ] || [ "$hwmode" = "11ac" ] || [ "$hwmode" = "11na" ] || [ "$hwmode" = "11a" ]; then
                if [ "$band_freq" -gt 5950 ] && [ "$band_freq" -lt 7130 ]; then
                    eval "$5=$iface"
                fi
                if [ "$band_freq" -gt 5175 ] && [ "$band_freq" -lt 5900 ]; then
                    eval "$4=$iface"
                fi
            else
                eval "$3=$iface"
            fi
        fi
    fi
}

# Configure the otherband BSSIDs for both backhaul APs
# input: $1 - network: the name of the network to which the AP interface
#                      must belong to be matched
# output: None
__repacd_wifi_set_otherband_bssids() {
    local otherband_bssid24g1 otherband_bssid24g2 bssid_5g bssid_24g bssid_6g
    local otherband_bssid5g1 otherband_bssid5g2 otherband_bssid6g1 otherband_bssid6g2
    local backhaul_ap_iface_24g backhaul_ap_iface_5g backhaul_ap_iface_6g success=0 loop_count=30

    while [ "$success" -eq 0 ] && [ "$loop_count" -gt 0 ]; do
        config_load wireless
        config_foreach __repacd_wifi_check_and_get_backhaul_ap_iface wifi-iface "$1" \
            backhaul_ap_iface_24g backhaul_ap_iface_5g backhaul_ap_iface_6g
        if [ -n "$backhaul_ap_iface_5g" ] || [ -n "$backhaul_ap_iface_6g" ]; then
            if [ -n "$backhaul_ap_iface_5g" ] && [ -n "$backhaul_ap_iface_24g" ]; then
                bssid_5g=$(ifconfig "$backhaul_ap_iface_5g" | grep "HWaddr" | awk -F" " '{print $5}')
                bssid_24g=$(ifconfig "$backhaul_ap_iface_24g" | grep "HWaddr" | awk -F" " '{print $5}')
                otherband_bssid5g1=$(echo "$bssid_5g" | sed -e "s/://g" | cut -b 1-8)
                otherband_bssid5g2=$(echo "$bssid_5g" | sed -e "s/://g" | cut -b 9-12)
                otherband_bssid24g1=$(echo "$bssid_24g" | sed -e "s/://g" | cut -b 1-8)
                otherband_bssid24g2=$(echo "$bssid_24g" | sed -e "s/://g" | cut -b 9-12)
                cfg80211tool $backhaul_ap_iface_24g otherband_bssid 0x$otherband_bssid5g1 0x$otherband_bssid5g2
                cfg80211tool $backhaul_ap_iface_5g otherband_bssid 0x$otherband_bssid24g1 0x$otherband_bssid24g2
            fi
            if [ -n "$backhaul_ap_iface_6g" ]; then
                bssid_6g=$(ifconfig "$backhaul_ap_iface_6g" | grep "HWaddr" | awk -F" " '{print $5}')
                bssid_24g=$(ifconfig "$backhaul_ap_iface_24g" | grep "HWaddr" | awk -F" " '{print $5}')
                otherband_bssid6g1=$(echo "$bssid_5g" | sed -e "s/://g" | cut -b 1-8)
                otherband_bssid6g2=$(echo "$bssid_5g" | sed -e "s/://g" | cut -b 9-12)
                otherband_bssid24g1=$(echo "$bssid_24g" | sed -e "s/://g" | cut -b 1-8)
                otherband_bssid24g2=$(echo "$bssid_24g" | sed -e "s/://g" | cut -b 9-12)
                cfg80211tool $backhaul_ap_iface_6g otherband_bssid 0x$otherband_bssid24g1 0x$otherband_bssid24g2
                if [ -z "$backhaul_ap_iface_5g" ]; then
                cfg80211tool $backhaul_ap_iface_24g otherband_bssid 0x$otherband_bssid6g1 0x$otherband_bssid6g2
                fi
             fi
            success=1
        else
            sleep 1
            loop_count=$((loop_count - 1))
        fi
    done
}

# Enumerate all of the wifi interfaces and append
# only station devices to the variable provided.
# output: $1 devices: variable to populate with the station devices
__repacd_get_sta_devices() {
    local devices=$1

    config_cb() {
        local type="$1"
        local section="$2"

        case "$type" in
            wifi-iface)
                config_get mode "$section" mode
                config_get device "$section" device
                if [ "$mode" = 'sta' ];then
                    eval append $devices "$device"
                fi
            ;;
        esac
    }
    config_load wireless
}

# Configure the vap independent parameter for given wifi interface.
#
# input: $1 - config: interface config name to configure.
# input: $2 - devices: list of devices to match with provided interface.
__repacd_config_vap_ind() {
    local config=$1
    local devices=$2
    local match_found=0
    local device

    config_load wireless
    config_get device "$config" device

    for device_to_match in $devices; do
        if [ "$device" = "$device_to_match" ]; then
            if __repacd_is_son_mode; then
                # If in SON mode, STA vaps may be forced down based on
                # link strength so configure the VAPs in independent mode.
                # This will be used in conjunction with the other feature
                # that monitors the backhaul links and brings down the AP VAPs
                # if there is no backhaul for a sustained period of time.
                __repacd_update_vap_param "$config" 'athnewind' 1
            else
                __repacd_update_vap_param "$config" 'athnewind' 0
            fi
            match_found=1
        fi
    done

    # If the feature Manage Front-Haul VAPs independently based on
    # CAP's reachability is enabled, then set athnewind value to 1.
    if [ "$Manage_front_and_back_hauls_ind" -gt 0 ]; then
        __repacd_update_vap_param "$config" 'athnewind' 1

    # This is mainly for wsplcd optimization: if wsplcd detects athnewind
    # is set to 0, it will not restart VAP; otherwise it will bring down
    # the VAP, set athnewind to 0 and bring the VAP back up
    elif [ "$match_found" -eq 0 ]; then
        __repacd_update_vap_param "$config" 'athnewind' 0
    fi
}

# Configure the vap independent parameter for all VAPs
# only if repacd is allowed to configure this parameter.
# input: None
__repacd_config_independent_vaps() {
    local sta_devices=

    if [ "$manage_vap_ind" -gt 0 ]; then
        __repacd_get_sta_devices sta_devices
        __repacd_echo "Station device list = $sta_devices"

        config_foreach __repacd_config_vap_ind wifi-iface "$sta_devices"
    else
        # Pass empty device list, so that all vaps set to athnewind=0.
        config_foreach __repacd_config_vap_ind wifi-iface "$sta_devices"
    fi
}

# Get the configured Rate scaling factor.
# Gives default value in case of configuration miss or invalid value.
#
# output: $1 - rate_scaling_factor
__repacd_get_rate_scaling_factor() {
    local scaling_factor

    config_load 'repacd'
    config_get scaling_factor WiFiLink 'RateScalingFactor' $RE_DEFAULT_RATE_ESTIMATE_SCALING_FACTOR

    # If scaling factor out of limits, return the default value "70".
    if [ "$scaling_factor" -lt '1' ] || \
        [ "$scaling_factor" -gt '100' ]; then
        scaling_factor=$RE_DEFAULT_RATE_ESTIMATE_SCALING_FACTOR
    fi

    eval "$1=$scaling_factor"
}

# check vap is in default configuration by comparing ssid as OpenWrt
# and encryption as none,for now any one VAP with this configuration
# is enough for marking configuration as default configuration.
# Internal driver currently does not support 11ad so ignoring
# 11ad enabled devices for now.
# input: $1 config: section to update
# input: $2 network: Global variable vap_defconf.
# input-output:$2 is set to '0' in case we have any VAP
# with default config.

__repacd_check_default_vaps() {
    local config="$1"

    config_get device "$config" device
    config_get ssid  "$config" ssid
    config_get encryption "$config" encryption
    config_get hwmode "$device" hwmode
    config_get type "$device" type
    config_get_bool repacd_security_unmanaged "$config" repacd_security_unmanaged '0'

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ] ;then
        return
    fi

    if [ "$repacd_security_unmanaged" -eq 1 ] ; then
        return
    fi

    if [ "$ssid" = "OpenWrt" ] && [ "$encryption" = "none" ] ;then
        eval "$2='0'"
    fi
}

# Determine if the VAPs are in the default configuration.
# For now this is defined simply as any VAP having the default SSID and no
# security enabled or that there are no VAPs whatsoever.
#
# return: 0 if in the default configuration; otherwise non-zero
__repacd_vaps_in_default_config() {
    local no_vaps

    # If there is no entry, uci will give an error message. We detect this
    # by looking for the string in the output.
    no_vaps=$(uci show wireless.@wifi-iface[-1] 2>&1 | grep 'Entry not found')
    [ -n "$no_vaps" ] && return 0

    config_load wireless
    config_foreach __repacd_check_default_vaps wifi-iface vap_defconf

    return $vap_defconf
}

# Reconfigure all managed VAPs and create new ones as appropriate. This is
# non-destructive in that all configuration parameters for a VAP that are not
# directly controlled by this script will not be modified.
#
# This should generally only be called when starting with a fresh
# configuration (eg. at first boot or due to a user request), as it will
# generate an SSID and passphrase. See __repacd_reset_existing_config() for
# the function used when the SSID and passphrase configured are to be
# preserved.
__repacd_reset_default_config() {
    config_load wireless
    config_foreach __repacd_resolve_vaps wifi-iface $managed_network

    # Use last three bytes of the MAC address to help make the SSID unique.
    local ssid_suffix
    __repacd_generate_ssid_suffix ssid_suffix

    # Generate a random password (which will likely be changed either through
    # cloning or by the end user).
    local random_psk
    __repacd_generate_psk random_psk

    __repacd_create_vaps "whc-$ssid_suffix" 'psk2+ccmp' "$random_psk"
    uci_commit wireless
}

# Enable all Wi-Fi devices
__repacd_enable_wifi() {
    local DEVICES=
    local device changed=0

    __repacd_get_devices DEVICES

    for device in $DEVICES; do
        config_get_bool disabled $device disabled
        [ -z "$disabled" ] && continue
        [ "$disabled" -eq 0 ] && continue

        uci_set wireless $device disabled '0'
        changed=1
    done

    if [ "$changed" -gt 0 ]; then
        uci_commit wireless
        config_changed=1
    fi
}

# Initialise all the additional that we created to support multi ssid traffic
# separation.
# input: $1 name: section name
# input: $2 device: name of the radio
# input: $3 mode: whether to act as a STA or AP
# input: $4 hwmode: radio hardware mode
# input: $5 network: desired network for this VAP
# input: $6 ssid: the desired SSID for this VAP
# input: $7 encryption: the desired encryption mode for this VAP
# input: $8 key: the desired passphrase for this VAP
__repacd_init_additional_vap() {
    local name=$1 device=$2 mode=$3 hwmode=$4 network=$5
    local ssid=$6 encryption=$7 key=$8
    local cur_mode repacd_security_unmanaged auto_create_vaps
    local enable_wds enable_rrm enable_qwrap_ap enable_extap block_dfs
    local rate_scaling_factor=0
    local num_changes=0
    local cur_key
    local is_owe

    __repacd_update_vap_param "$name" 'device' "$device"
    __repacd_update_vap_param "$name" 'network' "$network"

    config_get_bool repacd_security_unmanaged  "$name" repacd_security_unmanaged '0'
    if [ "$repacd_security_unmanaged" -eq 0 ] ; then
        __repacd_update_vap_param "$name" 'ssid' "$ssid"
        __repacd_update_vap_param "$name" 'encryption' "$encryption"

        config_get is_owe $name owe '0'
        # in mixed backhaul encryption eth unplug at RE will set the resolved encryption to
        # all repacd managed VAPs. There is a posibility for WPA2 VAP gets reconfigured to WPA3
        # so set sae if resolved encryption type is ccmp
        if [ "$encryption" = "ccmp" ] && [ "$is_owe" -eq 0 ]; then
            __repacd_update_vap_param "$name" 'sae' '1'
        fi

        config_get cur_key "$name" 'key'
        if [ ! "$cur_key" = "$key" ]; then
            __repacd_update_vap_param "$name" 'key' "$key"
        fi
    fi

    # using SON mode related settings to config backhaul VAPs.
    config_get_bool auto_create_vaps "$device" repacd_auto_create_vaps '1'
    if [ "$network" = "$network_backhaul" ] && [ "$auto_create_vaps" -eq 1 ]; then
        __repacd_update_vap_param "$name" 'wps_pbc_noclone' '0'
        __repacd_update_vap_param "$name" 'wps_pbc_enable' '1'
        __repacd_update_vap_param "$name" 'wps_pbc' '1'
        __repacd_update_vap_param "$name" 'wps_pbc_start_time' '61'
        __repacd_update_vap_param "$name" 'wps_pbc_duration' '120'
        __repacd_update_vap_param "$name" 'wds' '1'
        __repacd_update_vap_param "$name" 'extap' '0'
        config_load $MAP
        config_get hyfi_mode 'config' 'Mode' 'HYROUTER'
        if [ "$hyfi_mode" = "HYCLIENT" ]; then
            __repacd_update_vap_param "$name" 'root_distance' '255'
        fi
        if __repacd_is_matching_mode 'ap' "$mode"; then
            __repacd_update_vap_param "$name" 'qwrap_ap' '0'
            __repacd_update_vap_param "$name" 'rrm' '1'
            __repacd_update_vap_param "$name" 'hidden' '0'
            if __repacd_is_block_dfs; then
                __repacd_update_vap_param "$name" 'blockdfschan' '1'
            else
                __repacd_update_vap_param "$name" 'blockdfschan' '0'
            fi
        fi
    else
        __repacd_echo "Auto create VAPs disabled"
    fi
    if [ "$network" = "$network_guest" ] && [ "$auto_create_vaps" -eq 1 ]; then
        __repacd_update_vap_param "$name" 'rrm' '1'
    fi

    # Mode needs to be handled separately. If the device is already in one
    # of the AP modes and the init is requesting an AP mode, we leave it as
    # is. If it is already in the STA mode, we also leave it as is.
    config_get cur_mode "$name" 'mode'
    if ! __repacd_is_matching_mode "$mode" "$cur_mode"; then
        uci_set wireless "$name" 'mode' "$mode"
        config_changed=1
    fi
}

# Create the 4 VAPs needed (1 STA and 1 AP for each radio), with them all
# initially disabled. Three radio platforms are not currently handled.
#
# Note that if the VAPs already exist, they will be reconfigured as
# appropriate. Existing VAP section names are given by ${device}_ap and
# ${device}_sta global variables.
#
# input: $1 ssid: the SSID to use on all VAPs
# input: $2 encryption: the encryption mode to use on all VAPs
# input: $3 key: the pre-shared key to use on all VAPs
__repacd_create_vaps() {
    local ssid=$1
    local encryption=$2
    local key=$3
    local DEVICES=
    local backhaul_selected=0
    local additional_fh
    local repacd_security_unmanaged
    local is_owe
    local is_sae

    config_load $MAP
    config_load repacd

    config_get hyfi_mode 'config' 'Mode' 'HYROUTER'
    config_get additional_fh repacd 'AdditionalFHCount' '0'

    __repacd_get_devices DEVICES

    for device in $DEVICES; do
        local addi_vap=0
        if whc_is_5g_radio $device && [ "$backhaul_selected" -eq 0 ]; then
            # 5 GHz and we do not have a backhaul interface yet, so select
            # this one as the backhaul interface.
            #
            # @todo Consider which 5 GHz radio should be used for backhaul if
            #       there is more than one.
            backhaul_selected=1
        fi

        config_get_bool repacd_auto_create_vaps "$device" repacd_auto_create_vaps '1'
        uci_set wireless $device disabled '0'

        local name
        name=$(eval "echo \$${device}_ap")
        if [ -z "$name" ] && [ "$repacd_auto_create_vaps" -eq 1 ]; then
            # No existing entry; create a new one.
            name=$(uci add wireless wifi-iface)
            config_changed=1
        fi

        if [ -n "$name" ]; then
            # In case of auto config, this will be the fronthaul+backhaul AP VAP
            # However in manual config, this can be the fronthaul VAP
            # In manual cofig user sets this flag
            # We use repacd_auto_create_vaps to distinguish the two cases
            if [ "$repacd_auto_create_vaps" -eq 1 -a $traffic_separation_enabled -eq 0 ]; then
                uci_set wireless "$name" backhaul_ap '1'

                # wps_cred_add_sae parameter is needed for host wps enhc to
                # take care of overwriting credentials to Backhaul AP VAP
                if [ "$hyfi_mode" = "HYCLIENT" ]; then
                    __repacd_update_vap_param "$name" wps_cred_add_sae '1'
                fi
            fi

            __repacd_init_vap "$name" $device 'ap' "$ssid" "$encryption" "$key" "$addi_vap"

            config_get is_owe $name owe '0'
            config_get is_sae $name sae '0'
            config_get_bool repacd_security_unmanaged "$name" repacd_security_unmanaged '0'
            # in mixed backhaul encryption eth unplug at RE will set the resolved encryption to
            # all repacd managed VAPs. There is a posibility for WPA2 VAP gets reconfigured to WPA3
            # so set sae if resolved encryption type is ccmp
            if [ "$repacd_security_unmanaged" -eq 0 ] && [ "$encryption" = "ccmp" ] && [ "$is_owe" -eq 0 ]; then
                __repacd_update_vap_param "$name" 'sae' '1'
            fi
        fi

        addi_vap=1
        while [ $addi_vap -le $additional_fh ]; do
            name=$(eval "echo \$${device}_ap${addi_vap}")
            if [ -z "$name" ] && [ "$repacd_auto_create_vaps" -eq 1 ]; then
                # No existing entry; create a new one.
                name=$(uci add wireless wifi-iface)
                config_changed=1
                if [ -z "$encryption" ] || [ -z "$ssid" ]; then
                    local ssid_suffix
                    __repacd_generate_ssid_suffix ssid_suffix
                    __repacd_init_vap "$name" $device 'ap' "whc-${ssid_suffix}_${addi_vap}" "none" "$key" "$addi_vap"
                else
                    __repacd_init_vap "$name" $device 'ap' "${ssid}_${addi_vap}" "$encryption" "$key" "$addi_vap"
                fi

                __repacd_update_vap_param "$name" 'SteeringDisabled' 1
                # Additional/Extra VAPs encryption is set based on 1st VAPs encryption
                if [ "$repacd_security_unmanaged" -eq 0 ] && [ "$encryption" = "ccmp" ] || [ "$is_sae" -eq 1 ]; then
                    if [ -n "$ssid" ] && [ -n "$encryption" ]; then
                        if [ "$is_owe" -eq 0 ] && [ "$is_sae" -eq 1 ] && [ -n "$resolved_sae_pass" ]; then
                            __repacd_update_vap_param "$name" 'sae' '1'
                            uci add_list wireless."$name".sae_groups="$resolved_sae_group"
                            uci add_list wireless."$name".sae_password="$resolved_sae_pass"
                        else
                            __repacd_update_vap_param "$name" 'owe' '1'
                            uci add_list wireless."$name".owe_groups="$resolved_owe_group"
                        fi
                    fi
                fi
            fi
        addi_vap=$((addi_vap+1));
        done

        name=$(eval "echo \$${device}_sta")
        if [ -z "$name" ] && [ "$repacd_auto_create_vaps" -eq 1 ] && \
           [ "$traffic_separation_active" -eq 0 ] && [ "$hyfi_mode" = "HYCLIENT" ]; then
            # No existing entry; create a new one.
            name=$(uci add wireless wifi-iface)
            config_changed=1
        fi

        if [ -n "$name" ] && [ "$hyfi_mode" = "HYCLIENT" ]; then
            __repacd_init_vap "$name" $device 'sta' "$ssid" "$encryption" "$key" '0'

            config_get_bool repacd_security_unmanaged "$name" repacd_security_unmanaged '0'
            if [ "$repacd_security_unmanaged" -eq 0 ]; then
                uci delete wireless."$name".owe
                uci delete wireless."$name".owe_groups
                if [ "$encryption" = "ccmp" ]; then
                    uci delete wireless."$name".sae_groups
                    uci delete wireless."$name".sae_password
                    uci delete wireless."$name".key
                    if [ -n "$resolved_sae_pass" ] && [ -n "$resolved_sae_group" ]; then
                        uci_set wireless "$name" sae '1'
                        uci add_list wireless."$name".sae_groups="$resolved_sae_group"
                        uci add_list wireless."$name".sae_password="$resolved_sae_pass"
                    elif [ -n "$resolved_owe_group" ]; then
                        uci delete wireless."$name".sae
                        uci_set wireless "$name" owe '1'
                        uci add_list wireless."$name".owe_groups="$resolved_owe_group"
                    fi
                fi
            fi
        fi
    done
    uci_commit wireless
}

# Create the additional vaps required for multi ssid traffic separation.
# 1 guest vap and 1 spcl vap on each radio. Currently no sta vaps created.
# spcl vap on 2.4GHz band will be disabled.
# Note that if the VAPs already exist, they will be reconfigured as
# appropriate. Existing VAP section names are given by
# ${device}_(backhaul/guest)_ap and
# ${device}_(backhaul/guest)_sta global variables.
#
# input: $1 network: network to which this vap belongs
# input: $2 ssid: the SSID to use on all VAPs for the provided network
# input: $3 encryption: the encryption mode to use on all VAPs
# input: $4 key: the pre-shared key to use on all VAPs
__repacd_create_additional_vaps() {
    local ssid=$2
    local encryption=$3
    local key=$4
    local network=$1
    local DEVICES=
    local no_vlan_val
    local hwmode marker

    if [ "$network" = "$network_backhaul" ]; then
        marker="backhaul"
    elif [ "$network" = "$network_guest" ]; then
        marker="guest"
    fi

    config_get hyfi_mode 'config' 'Mode' 'HYROUTER'

    __repacd_get_devices DEVICES

    for device in $DEVICES; do
        config_get_bool repacd_auto_create_vaps "$device" repacd_auto_create_vaps '1'
        uci_set wireless $device disabled '0'
        config_get hwmode $device hwmode
        config_get no_vlan_val $device no_vlan '0'
        if [ "$no_vlan_val" -eq 0 ]; then
            uci_set wireless $device no_vlan '1'
        fi

        local name_managed
        name_managed=$(eval "echo \$${device}_ap")
        local name
        name=$(eval "echo \$${device}_${marker}_ap")
        if [ -z "$name" ] && [ "$repacd_auto_create_vaps" -eq 1 ]; then
            # No existing entry; create a new ap.
            name=$(uci add wireless wifi-iface)
            config_changed=1
        fi

        if [ -n "$name" ]; then
            if [ "$network" = "$network_backhaul" ]; then
                uci_set wireless "$name" rept_spl '1'
                if [ "$repacd_auto_create_vaps" -eq 1 ]; then
                    uci_set wireless "$name" backhaul_ap '1'

                    # wps_cred_add_sae parameter is required for host wps enhc to
                    # take care of overwriting credentials to Backhaul AP VAP
                    if [ "$hyfi_mode" = "HYCLIENT" ]; then
                        __repacd_update_vap_param "$name" wps_cred_add_sae '1'
                    fi
                fi

                if [ -n "$name_managed" ]; then
                    uci_set wireless "$name"_managed backhaul_ap '0'
                fi
            fi

            __repacd_init_additional_vap "$name" $device 'ap' "$hwmode" "$network" \
                                        "$ssid" "$encryption" "$key"
        fi

        if [ $create_sta -eq 1 ]; then
            name=$(eval "echo \$${device}_${marker}_sta")
            if [ -z "$name" ] && [ "$repacd_auto_create_vaps" -eq 1 ]; then
                # No existing entry; create a new sta.
                name=$(uci add wireless wifi-iface)
                config_changed=1
            fi

            if [ -n "$name" ]; then
                __repacd_init_additional_vap "$name" $device 'sta' "$hwmode" "$network" \
                                            "$ssid" "$encryption" "$key"
            fi
        fi
    done
    uci_commit wireless
}

# Reconfigure the STA vaps of managed network.
# After restarting in Non CAP mode we reconfigure the sta vaps
# to be part of backhaul network. Network,ssid and credential
# are changed other configuration remains same.
#
# input: $1 config: section name
# input: $2 : current network
# input: $3 : backhaul network
# input: $4 ssid_val: backhaul ssid
# input: $5 enc_val: backhaul encryption
# input: $6 key_val: backhaul key
__repacd_reconfig_sta_vaps() {
    local config=$1
    local network
    local ssid_val="$4"
    local enc_val="$5"
    local key_val="$6"

    config_get network "$config" network
    if [ "$2" = "$network" ] || [ "$3" = "$network" ]; then
        local mode device hwmode type_val disabled repacd_security_unmanaged

        config_get mode "$config" mode
        config_get device "$config" device
        config_get hwmode "$device" hwmode
        config_get type_val "$device" type
        config_get disabled "$config" disabled 0
        config_get_bool repacd_security_unmanaged  "$config" repacd_security_unmanaged '0'

        if [ "$hwmode" = '11ad' ] && [ "$type_val" = 'mac80211' ] ;then
            return
        fi

        if [ "$mode" = "sta" ]; then
            uci_set wireless "$config" rept_spl '1'
            __repacd_init_additional_vap "$config" $device 'sta' "$hwmode" "$3" \
                                            "$ssid_val" "$enc_val" "$key_val"

            if [ "$repacd_security_unmanaged" -eq 0 ]; then
            # On Eth unplug if STA has WPA3 encryption then copy WPA3 credentials from BH AP to STA VAP
                uci delete wireless."$config".owe_groups
                uci delete wireless."$config".owe
                if [ "$enc_val" = "ccmp" ]; then
                    uci delete wireless."$config".sae_groups
                    uci delete wireless."$config".sae_password
                    uci delete wireless."$config".key
                    if [ -n "$backhaul_sae_pass" ] && [ -n "$backhaul_sae_group" ]; then
                        uci_set wireless "$config" sae '1'
                        uci add_list wireless."$config".sae_groups="$backhaul_sae_group"
                        uci add_list wireless."$config".sae_password="$backhaul_sae_pass"
                    elif [ -n "$backhaul_owe_group" ]; then
                        uci delete wireless."$config".sae
                        uci_set wireless "$config" owe '1'
                        uci add_list wireless."$config".owe_groups="$backhaul_owe_group"
                    fi
                fi
            fi
        fi
    fi
}

# Detect which VAPs are already configured and their corresponding SSID and
# passphrase.
#
# input: $1 config: section name
# input: $2 network: network for which to update VAPs
#
# Updates $resolved_ssid, $resolved_enc, and $resolved_key as appropriate.
__repacd_resolve_vaps() {
    local config="$1"
    local network
    local find_additional_ap=1
    local additional_fh
    local is_sae

    config_load repacd
    config_load wireless
    config_get network "$config" network
    config_get additional_fh repacd 'AdditionalFHCount' '0'

    if [ "$2" = "$network" ]; then
        local device mode ssid_val encryption_val key_val sae_pass sae_group

        config_get device "$config" device
        config_get mode "$config" mode
        config_get ssid_val "$config" ssid
        config_get encryption_val "$config" encryption
        config_get key_val "$config" key
        config_get disabled "$config" disabled 0
        config_get_bool repacd_security_unmanaged "$config" repacd_security_unmanaged '0'
        config_get hwmode "$device" hwmode
        config_get type "$device" type
        config_get sae_pass "$config" sae_password
        config_get sae_group "$config" sae_groups
        config_get owe_group "$config" owe_groups
        config_get is_sae "$config" sae '0'

        if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ] ;then
             return
        fi

        local default_ap
        default_ap=$(eval "echo \$${device}_ap")
        # Remember the section name for this radio in this mode.
        if __repacd_is_matching_mode 'ap' "$mode"; then
            if [ -z "$default_ap" ]; then
                eval "${device}_ap=$config"
                find_additional_ap=0
            fi
        elif [ "$mode" = "sta" ]; then
            eval "${device}_sta=$config"
            find_additional_ap=0
        fi

        if [ "$find_additional_ap" -gt 0 -a "$network" = "$managed_network" ]; then
            addi_vap=1
            while [ $addi_vap -le $additional_fh ]; do
               default_ap=$(eval "echo \$${device}_ap${addi_vap}")
               # Remember the section name for this radio in this mode.
               if __repacd_is_matching_mode 'ap' "$mode"; then
                   if [ -z "$default_ap" ]; then
                       eval "${device}_ap${addi_vap}=$config"
                       break;
                   fi
               fi
               addi_vap=$((addi_vap+1))
            done
        fi

        # Do not store the credentials of additional FH & unmanaged FH
        if [ "$repacd_security_unmanaged" -eq 1 ] || [ "$find_additional_ap" -gt 0 ]; then
            return
        fi
        # Since there is really no way to know which SSID, encryption mode, or
        # passphrase to use, we will only store the first one unless we come
        # across an enabled STA interface in which case we will prefer that.
        # The reason for this is because if WPS is used without wsplcd, only
        # the STA interface will have the correct SSID and passphrase once the
        # process completes. When switching from pure client mode to RE mode,
        # we want to propagate those values to the AP interfaces and the other
        # STA interface.

        # Above is old behavior, New changes are to copy AP vap configuration
        # to STA vap interface to handle eth plug and unplug case. Initial
        # connection sta can be done with wps and CAP will clone proper BH config.
        # to RE via wsplcd.
        if [ -n "$ssid_val" ] && [ -z "$resolved_ssid" ] || [ "$mode" = "ap" ]; then
            if [ "$disabled" -eq 0 ]; then
                resolved_ssid="$ssid_val"
            fi
        fi

        if [ -n "$encryption_val" ] && [ -z "$resolved_enc" ] || [ "$mode" = "ap" ]; then
            if [ "$disabled" -eq 0 ]; then
                resolved_enc="$encryption_val"
            fi
        fi

        if [ -z "$resolved_key" ] || [ "$mode" = "ap" ]; then
            if [ "$disabled" -eq 0 ] && [ -n "$key_val" ]; then
                resolved_key="$key_val"
            fi
        fi

        if [ "$encryption_val" = "ccmp" ] || [ "$is_sae" -eq 1 ] && [ "$mode" = "ap" ]; then
            if [ -n "$sae_pass" ] && [ -n "$sae_group" ] && [ "$disabled" -eq 0 ]; then
                resolved_sae_pass="$sae_pass"
                resolved_sae_group="$sae_group"
            fi
        fi

        if [ "$encryption_val" = "ccmp" ] && [ "$mode" = "ap" ]; then
            if [ -n "$owe_group" ] && [ "$disabled" -eq 0 ]; then
                resolved_owe_group="$owe_group"
            fi
        fi
    fi
}

# Detect which additional VAPs are already configured.
#
# input: $1 config: section name
# input: $2 network: network for which to update VAPs
__repacd_resolve_additional_vaps() {
    local config="$1"
    local network marker
    local sae_pass sae_group

    config_get network "$config" network
    if [ "$2" = "$network" ]; then
        local device mode hwmode type_val encryption_val key_val

        if [ "$network" = "$network_backhaul" ]; then
            marker="backhaul"
        elif [ "$network" = "$network_guest" ]; then
            marker="guest"
        fi

        config_get device "$config" device
        config_get mode "$config" mode
        config_get ssid_val "$config" ssid
        config_get encryption_val "$config" encryption
        config_get key_val "$config" key
        config_get disabled "$config" disabled 0
        config_get hwmode "$device" hwmode
        config_get type_val "$device" type
        config_get sae_pass "$config" sae_password
        config_get sae_group "$config" sae_groups
        config_get owe_group "$config" owe_groups

        if [ "$hwmode" = '11ad' ] && [ "$type_val" = 'mac80211' ] ;then
             return
        fi

        # Remember the section name for this radio in this mode.
        if __repacd_is_matching_mode 'ap' "$mode"; then
            eval "${device}_${marker}_ap=$config"
        elif [ "$mode" = "sta" ]; then
            eval "${device}_${marker}_sta=$config"
        fi

        if [ -n "$ssid_val" ] && [ "$disabled" -eq 0 ]; then
            if [ "$network" = "$network_backhaul" ]; then
                if [ "$backhaul_ssid" = "$def_backhaul_ssid" ] || [ "$mode" = "ap" ]; then
                    backhaul_ssid="$ssid_val"
                fi
            elif [ "$network" = "$network_guest" ]; then
                if [ "$guest_ssid" = "$def_guest_ssid" ]; then
                    guest_ssid="$ssid_val"
                fi
            fi
        fi

        if [ -n "$encryption_val" ] && [ "$disabled" -eq 0 ]; then
            if [ "$network" = "$network_backhaul" ]; then
                if [ "$backhaul_enc" = "$def_backhaul_enc" ] || [ "$mode" = "ap" ]; then
                    backhaul_enc="$encryption_val"
                fi
            elif [ "$network" = "$network_guest" ]; then
                if [ "$guest_enc" = "$def_guest_enc" ]; then
                    guest_enc="$encryption_val"
                fi
            fi
        fi

        if [ -n "$key_val" ] && [ "$disabled" -eq 0 ]; then
            if [ "$network" = "$network_backhaul" ]; then
                if [ "$backhaul_key" = "$def_backhaul_key" ] || [ "$mode" = "ap" ]; then
                    backhaul_key="$key_val"
                fi
            elif [ "$network" = "$network_guest" ]; then
                if [ "$guest_key" = "$def_guest_key" ]; then
                    guest_key="$key_val"
                fi
            fi
        fi

        if [ -n "$sae_pass" ] && [ -n "$sae_group" ] && [ "$disabled" -eq 0 ] && [ "$mode" = "ap" ]; then
            if [ "$network" = "$network_backhaul" -a "$encryption_val" = "ccmp" ]; then
                backhaul_sae_pass="$sae_pass"
                backhaul_sae_group="$sae_group"
            fi
        fi

        if [ -n "$owe_group" ] && [ "$disabled" -eq 0 ] && [ "$mode" = "ap" ]; then
            if [ "$network" = "$network_backhaul" -a "$encryption_val" = "ccmp" ]; then
                backhaul_owe_group="$owe_group"
            fi
        fi
    fi
}

# Configure the additional VAPs needed to be consistent with the configuration that
# would be produced if starting from a default configuration. If any VAPs
# need to be created, use the SSID with suitable suffix, encryption mode, and passphrase
# from the managed network vaps
__repacd_reset_additional_config() {
    config_load wireless
    config_foreach __repacd_resolve_additional_vaps wifi-iface $network_guest
    config_foreach __repacd_resolve_additional_vaps wifi-iface $network_backhaul

    __repacd_create_additional_vaps $network_backhaul "$backhaul_ssid" "$backhaul_enc" \
                                   "$backhaul_key"
    __repacd_create_additional_vaps $network_guest "$guest_ssid" "$guest_enc" \
                                   "$guest_key"
}

# Configure the 4 VAPs needed to be consistent with the configuration that
# would be produced if starting from a default configuration. If any VAPs
# need to be created, carry over the SSID, encryption mode, and passphrase
# from one of the existing ones.
__repacd_reset_existing_config() {
    config_load wireless
    config_foreach __repacd_resolve_vaps wifi-iface $managed_network

    __repacd_create_vaps "$resolved_ssid" "$resolved_enc" "$resolved_key"
}

# Set invalid bssid to make sure
# when there is change in RE role
# bssid is getting reset.
__repacd_delete_bssid() {
    local config="$1"
    local mode network disabled
    local bssid="00:00:00:00:00:00"

    config_get device "$config" device
    config_get hwmode "$device" hwmode
    config_get type "$device" type

    config_get mode "$config" mode
    config_get network "$config" network
    config_get disabled "$config" disabled 0

    if [ "$mode" = "sta" ]; then
        uci_set wireless "$config" bssid "$bssid"
        __repacd_echo "Set VAP $config to bssid=$bssid"
    fi
}

# Delete the bssid entry from the given STA interface.
#
# input: $1 config: section name
# input: $2 network: network being managed
# output: $3 config_changed: number of configurations changed
__repacd_delete_bssid_entry() {
    local config="$1"
    local network_to_match="$2"
    local changed="$3"

    local device hwmode network mode bssid

    config_get device "$config" device
    config_get hwmode "$device" hwmode
    config_get network "$config" network
    config_get type "$device" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ] \
        || [ "$network" != "$network_to_match" ]; then
        return
    fi

    config_get mode "$config" mode

    if __repacd_is_matching_mode 'sta' "$mode"; then
        config_get bssid "$config" bssid ''
        if [ -n "$bssid" ]; then
            __repacd_echo "Deleting BSSID $bssid"
            uci delete "wireless.${config}.bssid"
            changed=$((changed + 1))
            eval "$3='$changed'"
        fi
    fi
}

# Change the configuration on the wifi-device object to match what is desired
# (either QWrap enabled or disabled based on the second argument).
#
# input: $1 config: section to update
# input: $2 1 - enable, 0 - disable
# input-output: $3 change counter
__repacd_config_qwrap_device() {
    local config="$1"
    local mode network
    local changed="$3"

    # @todo This will need to be updated for 3 radio configurations. The
    #       qwrap_enable should be set for the radio with the backhaul and
    #       qwrap_dbdc_enable should be set for the radios with only an AP
    #       interface.
    config_get hwmode "$config" hwmode
    config_get type "$config" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ]; then
        return
    fi

    if whc_is_5g_radio "$1"; then
        local qwrap_enable
        config_get qwrap_enable "$config" qwrap_enable
        if [ ! "$2" = "$qwrap_enable" ]; then
            uci_set wireless "$config" qwrap_enable "$2"
            changed=$((changed + 1))
            eval "$3='$changed'"
            __repacd_echo "Set radio $config to QWrap Enabled=$2"
        fi
    else   # must be 2.4 GHz
        local qwrap_dbdc_enable
        config_get qwrap_dbdc_enable "$config" qwrap_dbdc_enable
        if [ ! "$2" = "$qwrap_dbdc_enable" ]; then
            uci_set wireless "$config" qwrap_dbdc_enable "$2"
            changed=$((changed + 1))
            eval "$3='$changed'"
            __repacd_echo "Set radio $config to QWrap DBDC Enabled=$2"
        fi
    fi
}

# Enable or disable the WPS Push Button Configuration Range Extender
# enhancement based on the current configuration.
# input: $1 force_cap_mode - whether to act as gateway connected even without
#                            a WAN interface
# input-output: $2 change count
__repacd_config_wps_pbc_enhc() {
    local force_gwcon_mode=$1
    local changed="$2"
    local cur_enable

    if __repacd_gw_mode || [ "$force_gwcon_mode" -gt 0 ] || \
       __repacd_is_wds_mode || __repacd_is_son_mode; then
        if [ "$traffic_separation_enabled" -gt 0 ]; then
            enable_wps_pbc_enhc=1
        else
            enable_wps_pbc_enhc=0
        fi
    else
        # Must be QWRAP or ExtAP mode, where we want distinct SSIDs for the
        # RE interfaces.
        enable_wps_pbc_enhc=1
    fi

    config_load wireless
    config_get cur_enable qcawifi wps_pbc_extender_enhance '0'

    if [ ! "$enable_wps_pbc_enhc" = "$cur_enable" ]; then
        # Create the section if it does not exist.
        uci set wireless.qcawifi=qcawifi
        uci_set wireless qcawifi wps_pbc_extender_enhance $enable_wps_pbc_enhc

        __repacd_echo "Set qcawifi.wps_pbc_extender_enhance=$enable_wps_pbc_enhc"
        changed=$((changed + 1))
        eval "$2='$changed'"
    fi
}

# Switch the device into acting as the CAP (main gateway).
# Also update the range extension mode as necessary.
#
# input: $1 is_cap: whether the device should act as the central
#                   AP or a secondary gateway connected AP
__repacd_config_gwcon_ap_mode() {
    local is_cap=$1
    local wsplcd_mode son_mode
    local rate_scaling_factor=0
    local default_root_dist=0

    # The WDS, VAP independent, and QWrap AP settings also need to be updated
    # based on the range extension mode.
    local enable_wds enable_rrm enable_qwrap_ap enable_extap
    local block_dfs enable_multi_ap disable_steering=0 config_sta=1
    local map_enable=0
    __repacd_get_config_re_mode config_re_mode
    __repacd_get_re_mode resolved_re_mode
    if __repacd_is_auto_re_mode $config_re_mode || __repacd_is_wds_mode || \
       __repacd_is_son_mode; then
        if __repacd_is_auto_re_mode $config_re_mode || \
           __repacd_is_son_mode; then
            __repacd_echo "Using SON mode for GW Connected AP"
            enable_multi_ap=1
        else   # Must be vanilla WDS
            __repacd_echo "Using WDS mode for GW Connected AP"
            enable_multi_ap=0
        fi

        enable_wds=1
        enable_rrm=1
        enable_qwrap_ap=0
        enable_extap=0

        # In WDS/SON modes, we let the OEM customize whether DFS channels
        # should be permitted.
        if __repacd_is_block_dfs; then
            block_dfs=1
        else
            block_dfs=0
        fi

        wsplcd_enabled=1
    else
        __repacd_echo "Using Non-WDS mode for GW Connected AP"
        enable_wds=0
        enable_multi_ap=0
        enable_rrm=0
        enable_qwrap_ap=0
        enable_extap=0

        # In QWrap/ExtAP mode, DFS channels should always be disallowed (as it
        # does not appear to suppor them currently). This may be able to
        # relaxed in the future.
        block_dfs=1

        # Since QWrap/ExtAP mode on the CAP is for mimicking a non-QTI AP, do
        # not run an IEEE P1905.1 registrar.
        wsplcd_enabled=0
    fi

    config_load repacd
    config_get bssid_resolve_state WiFiLink 'BSSIDResolveState' 'resolving'

    # In GW-connected AP mode, only the AP interfaces are enabled.
    local disable_24g_sta=1 disable_5g_sta=1 disable_24g_ap=0 disable_5g_ap=0
    config_load wireless
    config_foreach __repacd_disable_vap wifi-iface \
        $managed_network 'sta' $disable_24g_sta $disable_5g_sta config_changed
    config_foreach __repacd_disable_vap wifi-iface \
        $managed_network 'ap' $disable_24g_ap $disable_5g_ap config_changed

    # The QWrap parameters should always be set to 0 on the CAP.
    config_foreach __repacd_config_qwrap_device wifi-device \
        0 config_changed

    # Similarly, the DBDC repeater feature should be disabled on the
    # CAP.
    config_foreach __repacd_config_dbdc_device wifi-device \
        0 config_changed

    # If son_mode is HYCLIENT root distance whould be reest to 255
    # during restart_in_cap_mode to avoid island issue
    if [ "$is_cap" -gt 0 ]; then
        default_root_dist=0
    else
        default_root_dist=255
    fi


    # Now set up the interfaces in the right way.
    config_foreach __repacd_config_iface wifi-iface \
        $managed_network $enable_wds $enable_qwrap_ap $enable_extap \
        $block_dfs $enable_rrm $rate_scaling_factor $default_root_dist $capsnr config_changed

    if [ "$traffic_separation_active" -gt 0 ]; then
        config_foreach __repacd_config_iface wifi-iface \
            $network_backhaul $enable_wds $enable_qwrap_ap $enable_extap \
            $block_dfs $enable_rrm $rate_scaling_factor $default_root_dist $capsnr config_changed

        config_foreach __repacd_config_iface wifi-iface \
            $network_guest $enable_wds $enable_qwrap_ap $enable_extap \
            $block_dfs $enable_rrm $rate_scaling_factor $default_root_dist $capsnr config_changed
    fi

    uci_commit wireless

    uci_set repacd repacd Role 'CAP'
    uci_commit repacd

    if [ "$is_cap" -gt 0 ]; then
        wsplcd_mode='REGISTRAR'
        son_mode='HYROUTER'
    else
        wsplcd_mode='ENROLLEE'
        son_mode='HYCLIENT'
    fi

    # Deep cloning is not relevant in registrar mode, but we set it to 1
    # anyways (since that is the default).
    __repacd_configure_wsplcd $wsplcd_mode 1 0 $config_sta $map_enable \
                              config_changed

    __repacd_configure_son $enable_wds $disable_steering $enable_multi_ap \
        $son_mode config_changed
}

# Switch the device to act in one of the NonCAP configurations.
# input: $1 disable_ap - whether to disable the AP interfaces
# input: $2 deep_clone - whether to use deep cloning in wsplcd
# input: $3 deep_clone_no_bssid - whether to use deep cloning without BSSID cloning in wsplcd
__repacd_config_noncap_mode() {
    local disable_ap=$1
    local deep_clone=$2
    local deep_clone_no_bssid=$3

    # The WDS and QWrap AP settings also need to be updated based on the
    # range extension mode.
    local enable_wds enable_qwrap_ap enable_extap enable_dbdc_repeater
    local block_dfs enable_rrm enable_multi_ap disable_steering=0 config_sta=1
    local map_enable=0
    local rate_scaling_factor=$RE_DEFAULT_RATE_ESTIMATE_SCALING_FACTOR
    local default_root_dist=$RE_ROOT_AP_DISTANCE_INVALID
    local disable_24g_sta=1 disable_5g_sta=0
    local disable_24g_ap=$disable_ap disable_5g_ap=$disable_ap
    if __repacd_is_wds_mode || __repacd_is_son_mode; then
        if __repacd_is_wds_mode; then
            __repacd_echo "Using WDS mode for NonCAP"
        else  # Must be SON mode
            __repacd_echo "Using SON mode for NonCAP"
        fi

        enable_wds=1
        enable_qwrap_ap=0
        enable_extap=0

        # Even if we are not operating in fully coordinated steering mode,
        # we should enable RRM for use in the uncoordinated steering
        # environment.
        enable_rrm=1

        # In WDS mode, we let the OEM customize whether DFS channels should
        # be permitted.
        if __repacd_is_block_dfs; then
            block_dfs=1
        else
            block_dfs=0
        fi

        wsplcd_enabled=1

        __repacd_get_rate_scaling_factor rate_scaling_factor
        config_get capsnr WiFiLink 'PreferCAPSNRThreshold5G' '0'
    else
        enable_wds=0

        # Until steering can be well supported on QWRAP/ExtAP, there is no real
        # need to have RRM enabled.
        enable_rrm=0

        # wsplcd needs WDS in order to work (as it sends/receives using the
        # bridge interface MAC address). Plus, it is not too likely that the
        # main AP will be running an IEEE P1905.1 registrar.
        wsplcd_enabled=0

        if [ "$disable_ap" -eq 0 ]; then
            if __repacd_is_qwrap_mode; then
                __repacd_echo "Using QWrap mode for NonCAP"
                enable_qwrap_ap=1
                enable_extap=0

            else
                __repacd_echo "Using ExtAP mode for NonCAP"
                enable_qwrap_ap=0
                enable_extap=1
            fi

            # In QWrap/ExtAP mode, DFS channels should always be disallowed
            # (as these modes may not support them properly).
            block_dfs=1
        else  # client mode
            if __repacd_is_qwrap_mode; then
                __repacd_echo "Using QWrap mode for NonCAP"
                enable_qwrap_ap=0
                enable_extap=0

                # @todo What mode should be used here? The STA interface is not
                #       even created if it is not in QWRAP or WDS. We could
                #       potentially consider standalone Proxy STA
                #       mode, but we need details on how to configure this.
            else
                __repacd_echo "Using ExtAP mode for NonCAP"
                enable_qwrap_ap=0
                enable_extap=1
            fi

            # We'll rely on the main AP to decide on DFS or not.
            block_dfs=0
        fi
    fi

    if __repacd_is_son_mode; then
        disable_24g_sta=0
        enable_dbdc_repeater=0
        enable_multi_ap=1
    else
        enable_multi_ap=0

        # Although currently in non-SON mode we do not enable both STA
        # interfaces, just in case we do in the future, set this flag. It
        # should make no difference if only one STA interface is active.
        enable_dbdc_repeater=1
    fi

    config_load repacd
    config_get bssid_resolve_state WiFiLink 'BSSIDResolveState' 'resolving'

    config_load wireless

    if [ "$traffic_separation_active" -gt 0 ]; then
        config_foreach __repacd_disable_vap wifi-iface \
            $network_backhaul 'sta' $disable_24g_sta $disable_5g_sta config_changed
    else
        config_foreach __repacd_disable_vap wifi-iface \
            $managed_network 'sta' $disable_24g_sta $disable_5g_sta config_changed
    fi
    config_foreach __repacd_disable_vap wifi-iface \
        $managed_network 'ap' "$disable_24g_ap" "$disable_5g_ap" config_changed

    # First set the special options for QWRAP and DBDC repeaters.
    config_foreach __repacd_config_qwrap_device \
        wifi-device $enable_qwrap_ap config_changed
    config_foreach __repacd_config_dbdc_device wifi-device \
        $enable_dbdc_repeater config_changed

    config_foreach __repacd_config_iface wifi-iface \
        $managed_network $enable_wds $enable_qwrap_ap $enable_extap \
        $block_dfs $enable_rrm $rate_scaling_factor $default_root_dist $capsnr config_changed

    if [ "$traffic_separation_active" -gt 0 ]; then
        config_foreach __repacd_config_iface wifi-iface \
            $network_backhaul $enable_wds $enable_qwrap_ap $enable_extap \
            $block_dfs $enable_rrm $rate_scaling_factor $default_root_dist $capsnr config_changed

        config_foreach __repacd_config_iface wifi-iface \
            $network_guest $enable_wds $enable_qwrap_ap $enable_extap \
            $block_dfs $enable_rrm $rate_scaling_factor $default_root_dist $capsnr config_changed
    fi

    __repacd_config_independent_vaps

    uci_commit wireless

    uci_set repacd repacd Role 'NonCAP'
    uci_commit repacd

    __repacd_configure_wsplcd 'ENROLLEE' "$deep_clone" "$deep_clone_no_bssid" \
                              $config_sta $map_enable config_changed

    __repacd_configure_son $enable_wds $disable_steering $enable_multi_ap \
        'HYCLIENT' config_changed
}

# Switch the device into acting as a range extender.
# Also update the range extension mode as necessary.
__repacd_config_re_mode() {
    local disable_ap=0 deep_clone=1 deep_clone_no_bssid=0

    # We do deep cloning without BSSID for daisy chaining.
    [ "$daisy_chain" -gt 0 ] && deep_clone_no_bssid=1

    __repacd_config_noncap_mode $disable_ap $deep_clone $deep_clone_no_bssid
}

# Switch the device into acting as a pure client device (no AP interfaces
# enabled).
__repacd_config_client_mode() {
    local disable_ap=1 deep_clone=0
    __repacd_config_noncap_mode $disable_ap $deep_clone 0
}

# Perform the startup actions when operating in the original Wi-Fi SON mode
# (no Multi-AP SIG support).
__start_son() {
    local enabled map_enabled device_type
    local mode activate_ts
    local eth_mon_enabled

    config_changed=0
    net_config_changed=0
    activate_ts=0

    config_load 'repacd'
    config_get_bool enabled repacd 'Enable' '0'
    config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
    config_get traffic_separation_active repacd TrafficSeparationActive '0'
    config_get daisy_chain WiFiLink DaisyChain '0'
    config_get backhaul_ssid repacd BackhaulSSID $def_backhaul_ssid
    config_get backhaul_enc repacd BackhaulEnc $def_backhaul_enc
    config_get backhaul_key repacd BackhaulKey $def_backhaul_key
    config_get network_guest repacd NetworkGuest 'guest'
    config_get guest_ssid repacd GuestSSID $def_guest_ssid
    config_get guest_enc repacd GuestEnc $def_guest_enc
    config_get guest_key repacd GuestKey $def_guest_key
    config_get guest_backhaul_iface repacd NetworkGuestBackhaulInterface 'both'
    config_get eth_mon_enabled repacd 'EnableEthernetMonitoring' '0'
    config_get manage_vap_ind WiFiLink 'ManageVAPInd' '0'
    config_get Manage_front_and_back_hauls_ind 'FrontHaulMgr' 'ManageFrontAndBackHaulsIndependently' '0'
    __repacd_get_config_re_mode config_re_mode

    [ "$enabled" -gt 0 ] || {
        return 1
    }

    __repacd_echo "starting WHC auto-configuration"

    # For now, we can only manage a single network.
    config_get managed_network repacd ManagedNetwork 'lan'
    __repacd_echo "Managed network: $managed_network"

    config_get device_type repacd DeviceType 'RE'
    __repacd_echo "Device type: $device_type"

    # Grab a lock to prevent any updates from being made by the daemon.
    whc_wifi_config_lock

    __repacd_config_wps_pbc_enhc 0 config_changed

    # Config_changed is not being gracefully handled in MIPS.
    # so commiting the change if wps_pbc_enhn is set
    if [ "$config_changed" -gt 0 ]; then
        uci_commit wireless
        config_changed=0
    fi

    if __repacd_vaps_in_default_config; then
        __repacd_reset_default_config
        config_changed=1
        __repacd_echo "Reset $managed_network VAPs"
    else
        # Need to massage the configuration to make it consistent with the
        # expectations of repacd.
        __repacd_reset_existing_config
        __repacd_echo "Initialized $managed_network VAPs"
    fi

    __repacd_enable_wifi

    # create additional vaps if traffic separation enabled
    if __repacd_gw_mode || [ "$device_type" = 'RE' ] && [ "$gwcon_mode" != "CAP" ]; then
        if [ "$traffic_separation_enabled" -gt 0 ]; then
            if __repacd_is_qwrap_mode || \
               __repacd_is_son_mode; then
                if __repacd_check_additional_network_exist; then
                    __repacd_set_bridge_empty $network_guest
                    __repacd_set_firewall_rules $network_guest

                    __repacd_reset_additional_config

                    if ! __repacd_gw_mode && __repacd_is_qwrap_mode && \
                       [ "$traffic_separation_active" -eq 0 ]; then
                        local disable_24g_ap=1 disable_5g_ap=1

                        config_load wireless
                        config_foreach __repacd_disable_vap wifi-iface \
                            $network_backhaul 'ap' $disable_24g_ap $disable_5g_ap config_changed
                        config_foreach __repacd_disable_vap wifi-iface \
                            $network_guest 'ap' $disable_24g_ap $disable_5g_ap config_changed
                        uci_commit wireless
                    fi

                    uci_set repacd repacd NetworkBackhaul $network_backhaul
                    uci_commit repacd
                    activate_ts=1
                fi
            fi
        fi
    fi

    if __repacd_gw_mode; then
        # WAN group not empty; this device will act as CAP regardless of
        # the GatewayConnectedMode setting
        __repacd_config_gwcon_ap_mode 1
    elif [ "$device_type" = 'RE' ]; then
        # WAN group empty or non-existent
        # Switch to range extender mode

        # Clear the BSSIDs on fresh restart
        config_load wireless
        if [ "$traffic_separation_active" -gt 0 ]; then
            config_foreach __repacd_delete_bssid_entry wifi-iface $network_backhaul config_changed
        else
            config_foreach __repacd_delete_bssid_entry wifi-iface $managed_network config_changed
        fi
        uci_set repacd WiFiLink BSSIDResolveState 'resolving'
        uci_commit wireless
        uci_commit repacd
        __repacd_config_re_mode

        if [ "$activate_ts" -eq 1 ]; then
                config_load wireless
                config_foreach __repacd_reconfig_sta_vaps wifi-iface $managed_network $network_backhaul \
                    "$backhaul_ssid" "$backhaul_enc" "$backhaul_key"
                uci_commit wireless
        fi
    else
        # Must be a client device (that can opportunistically act as an RE).
        __repacd_config_client_mode
    fi


    whc_wifi_config_unlock

    __repacd_restart_dependencies
   if [ "$traffic_separation_enabled" -gt 0 ]; then
        __repacd_wifi_set_otherband_bssids $network_backhaul
   else
        __repacd_wifi_set_otherband_bssids $managed_network
   fi

    # create vlan interfaces required for traffic separation.
    if [ "$activate_ts" -eq 1 ]; then
            config_load network
            config_load wireless
            config_foreach __repacd_add_vlan_interfaces wifi-iface \
                $managed_network $lan_vid 'both' net_config_changed
            config_foreach __repacd_add_vlan_interfaces wifi-iface \
                $network_guest $guest_vid $guest_backhaul_iface net_config_changed
            uci_commit wireless

            __repacd_add_ethernet_vlan_interfaces $network_guest net_config_changed
            uci_commit network

            __repacd_restart_firewall

            uci_set repacd repacd TrafficSeparationActive '1'
            uci_commit repacd

            # stop/start hyd only if there is any change in netwrok config
            # due to addition of VLAN interfaces. If required VLAN iface already
            # present then we can avoid hyd stop/start. This will save some time
            # and avoid any delays after repacd restart.
            if [ "$net_config_changed" -gt 0 ] || [ "$config_changed" -gt 0 ]; then
                config_changed=0
                hyd_stop=1
                hyd_start=1
                wsplcd_stop=1
                wsplcd_start=1
                __repacd_restart_dependencies
            fi
    fi

    if [ "$eth_mon_enabled" -eq 1 ]; then
        # Make sure lldpd listens on wan and lan interfaces
        for int in wan lan; do
            if ! uci get lldpd.config.interface | grep $int > /dev/null; then
                uci add_list lldpd.config.interface=$int
            fi
        done
        __repacd_echo "Starting lldpd"
        repacd_netdet_lldpd_init start
    fi

    if ! __repacd_gw_mode || [ "$eth_mon_enabled" -eq 1 ]; then
        __stop_repacd_run

        # Start the script that monitors the link state.
        #
        # When in NonCAP mode, it will keep checking whether there is a link
        # to the gateway over ethernet. When in CAP mode, it will keep
        # checking the WAN/LAN ifaces.
        __repacd_echo "Starting  RE Placement and Auto-config Daemon"
        start-stop-daemon -S -x /usr/sbin/repacd-run.sh -b -- \
            "son" init $config_re_mode $resolved_re_mode $resolved_re_submode
    fi
}

# Force a restart into CAP mode using the SON algorithms.
#
# @see restart_in_cap_mode
__restart_in_cap_mode_son() {
    local gwcon_mode device_type activate_ts
    config_load repacd
    config_get managed_network repacd ManagedNetwork 'lan'
    config_get gwcon_mode repacd GatewayConnectedMode 'AP'
    config_get device_type repacd DeviceType 'RE'
    config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
    config_get traffic_separation_active repacd TrafficSeparationActive '0'
    config_get daisy_chain WiFiLink DaisyChain '0'
    config_get backhaul_ssid repacd BackhaulSSID $def_backhaul_ssid
    config_get backhaul_enc repacd BackhaulEnc $def_backhaul_enc
    config_get backhaul_key repacd BackhaulKey $def_backhaul_key
    config_get network_guest repacd NetworkGuest 'guest'
    config_get guest_ssid repacd GuestSSID $def_guest_ssid
    config_get guest_enc repacd GuestEnc $def_guest_enc
    config_get guest_key repacd GuestKey $def_guest_key
    config_get guest_backhaul_iface repacd NetworkGuestBackhaulInterface 'both'
    config_get manage_vap_ind WiFiLink 'ManageVAPInd' '0'
    __repacd_get_config_re_mode config_re_mode
    activate_ts=0
    net_config_changed=0

    __stop_repacd_run

    if [ "$gwcon_mode" = "CAP" ]; then
        # Explicitly being forced into CAP mode while gateway connected.
        # This could be a case where a device is being used as a pure bridge
        # due to another device acting as the gateway.
        __repacd_config_wps_pbc_enhc 1 config_changed
        __repacd_config_gwcon_ap_mode 1
    else
        # Operate just as a standalone AP. This assumes there is another
        # device in the network that operates as CAP.
        __repacd_config_wps_pbc_enhc 0 config_changed
        __repacd_config_gwcon_ap_mode 0
    fi

    __repacd_reset_existing_config

    if [ "$traffic_separation_active" -gt 0 ]; then
        config_foreach __repacd_delete_bssid wifi-iface \
            $network_backhaul
    else
        config_foreach __repacd_delete_bssid wifi-iface \
            $managed_network
    fi

    if [ "$device_type" = 'RE' ] && [ "$gwcon_mode" != "CAP" ]; then
        if [ "$traffic_separation_enabled" -gt 0 ] && \
           __repacd_is_son_mode; then
            if __repacd_check_additional_network_exist; then
                # reset additional vaps if traffic separation enabled
                local disable_24g_ap=0 disable_5g_ap=0
                local disable_24g_sta=1 disable_5g_sta=1

                config_load network
                config_load wireless
                config_foreach __repacd_disable_vap wifi-iface \
                    $network_backhaul 'ap' $disable_24g_ap $disable_5g_ap config_changed
                config_foreach __repacd_disable_vap wifi-iface \
                    $network_guest 'ap' $disable_24g_ap $disable_5g_ap config_changed

                if [ "$traffic_separation_active" -eq 1 ]; then
                    config_foreach __repacd_delete_vlan_interfaces wifi-iface \
                        $managed_network $lan_vid 'ap' net_config_changed
                    config_foreach __repacd_delete_vlan_interfaces wifi-iface \
                        $network_guest $guest_vid 'ap' net_config_changed
                    config_foreach __repacd_delete_vlan_interfaces wifi-iface \
                        $managed_network $lan_vid 'sta' net_config_changed
                    config_foreach __repacd_delete_vlan_interfaces wifi-iface \
                        $network_guest $guest_vid 'sta' net_config_changed
                    config_foreach __repacd_disable_vap wifi-iface \
                        $network_backhaul 'sta' $disable_24g_sta $disable_5g_sta config_changed
                fi
                uci_commit wireless
                uci_commit network

                __repacd_reset_additional_config
                activate_ts=1
            fi
        fi
    fi

    if [ "$wsplcd_enabled" -gt 0 ]; then
        wsplcd_restart=1
    fi

    __repacd_restart_dependencies
   if [ "$traffic_separation_enabled" -gt 0 ]; then
        __repacd_wifi_set_otherband_bssids $network_backhaul
   else
        __repacd_wifi_set_otherband_bssids $managed_network
   fi

   if [ "$activate_ts" -eq 1 ]; then
        config_load network
        config_load wireless
        config_foreach __repacd_add_vlan_interfaces wifi-iface \
            $managed_network $lan_vid 'both' net_config_changed
        config_foreach __repacd_add_vlan_interfaces wifi-iface \
            $network_guest $guest_vid $guest_backhaul_iface net_config_changed
        uci_commit wireless

        __repacd_add_ethernet_vlan_interfaces $network_guest net_config_changed
        uci_commit network

        __repacd_restart_firewall

        uci_set repacd repacd TrafficSeparationActive '1'
        uci_commit repacd

        if [ "$net_config_changed" -gt 0 ] || [ "$config_changed" -gt 0 ]; then
            config_changed=0
            hyd_stop=1
            hyd_start=1
            wsplcd_stop=1
            wsplcd_start=1
            __repacd_restart_dependencies
        fi
    fi

    if ! __repacd_gw_mode; then
        # Start the daemon that monitors link status in CAP mode, telling
        # the daemon that it is an auto config-triggered restart.
        #
        # In this mode, it will just keep checking that the link to the
        # gateway is still present on ethernet.
        start-stop-daemon -S -x /usr/sbin/repacd-run.sh -b -- \
            "son" CAP $config_re_mode $resolved_re_mode $resolved_re_submode \
            autoconf
    fi
}

# Force a restart into NonCAP mode using the SON algorithms.
#
# @see restart_in_noncap_mode
__restart_in_noncap_mode_son() {
    local device_type activate_ts
    config_load repacd
    config_get managed_network repacd ManagedNetwork 'lan'
    config_get device_type repacd DeviceType 'RE'
    config_get gwcon_mode repacd GatewayConnectedMode 'AP'
    config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
    config_get traffic_separation_active repacd TrafficSeparationActive '0'
    config_get daisy_chain WiFiLink DaisyChain '0'
    config_get backhaul_ssid repacd BackhaulSSID $def_backhaul_ssid
    config_get backhaul_enc repacd BackhaulEnc $def_backhaul_enc
    config_get backhaul_key repacd BackhaulKey $def_backhaul_key
    config_get network_guest repacd NetworkGuest 'guest'
    config_get guest_ssid repacd GuestSSID $def_guest_ssid
    config_get guest_enc repacd GuestEnc $def_guest_enc
    config_get guest_key repacd GuestKey $def_guest_key
    config_get guest_backhaul_iface repacd NetworkGuestBackhaulInterface 'both'
    config_get manage_vap_ind WiFiLink 'ManageVAPInd' '0'
    __repacd_get_config_re_mode config_re_mode
    activate_ts=0

    __stop_repacd_run

    net_config_changed=0

    # Apply the SSID and passphrase to all interfaces to ensure that if we are
    # switching into a SON mode where there are two STA interfaces, they all
    # have the right credentials. For the non-SON and WDS modes, this is
    # subject to the RE WPS enhancement rules.
    __repacd_config_wps_pbc_enhc 0 config_changed

    __repacd_reset_existing_config

    # Need to resolve the generic NonCAP role to the actual configuration.
    if [ "$device_type" = 'RE' ]; then
        __repacd_config_re_mode

        if [ "$gwcon_mode" != "CAP" ]; then
            if [ "$traffic_separation_enabled" -gt 0 ] && \
               __repacd_is_son_mode; then
               if __repacd_check_additional_network_exist; then
                    # reset additional vaps if traffic separation enabled
                    local disable_24g_ap=0 disable_5g_ap=0

                    config_load wireless
                    # Enable spcl AP VAPs on NON-CAP only if daisy chain is enabled.
                    # They are for multi hop support. We don't need them if daisy
                    # chain is disabled.
                    if [ "$daisy_chain" -gt 0 ]; then
                        config_foreach __repacd_disable_vap wifi-iface \
                            $network_backhaul 'ap' $disable_24g_ap $disable_5g_ap config_changed
                    fi
                    config_foreach __repacd_disable_vap wifi-iface \
                        $network_guest 'ap' $disable_24g_ap $disable_5g_ap config_changed
                    uci_commit wireless

                    __repacd_reset_additional_config

                    config_load wireless
                    config_foreach __repacd_reconfig_sta_vaps wifi-iface $managed_network $network_backhaul \
                        "$backhaul_ssid" "$backhaul_enc" "$backhaul_key"
                    uci_commit wireless
                    activate_ts=1
               fi
            fi
        fi
    else
        __repacd_config_client_mode
    fi

    if [ "$wsplcd_enabled" -gt 0 ]; then
        wsplcd_restart=1
    fi

    __repacd_restart_dependencies
   if [ "$traffic_separation_enabled" -gt 0 ]; then
        __repacd_wifi_set_otherband_bssids $network_backhaul
   else
        __repacd_wifi_set_otherband_bssids $managed_network
   fi

    # create vlan interfaces required for traffic separation.
    if [ "$activate_ts" -eq 1 ]; then
        config_load network
        config_load wireless
        config_foreach __repacd_add_vlan_interfaces wifi-iface \
            $managed_network $lan_vid 'both' net_config_changed
        config_foreach __repacd_add_vlan_interfaces wifi-iface \
            $network_guest $guest_vid $guest_backhaul_iface net_config_changed
        uci_commit wireless

        __repacd_add_ethernet_vlan_interfaces $network_guest net_config_changed
        uci_commit network

        __repacd_restart_firewall

        uci_set repacd repacd TrafficSeparationActive '1'
        uci_commit repacd

        # stop/start hyd only if there is any change in netwrok config
        # due to addition of VLAN interfaces. If required VLAN iface already
        # present then we can avoid hyd stop/start. This will save some time
        # and avoid any unnecessary delays after repacd restart.
        if [ "$net_config_changed" -gt 0 ] || [ "$config_changed" -gt 0 ]; then
            config_changed=0
            hyd_stop=1
            hyd_start=1
            wsplcd_stop=1
            wsplcd_start=1
            __repacd_restart_dependencies
        fi
    fi

    if ! __repacd_gw_mode; then
        # Start the script that monitors the link state, telling the daemon that
        # it is an auto config-triggered restart.
        #
        # In this NonCAP mode, it will keep checking whether there is a link
        # to the gateway over ethernet.
        start-stop-daemon -S -x /usr/sbin/repacd-run.sh -b -- \
            "son" NonCAP $config_re_mode $resolved_re_mode \
            $resolved_re_submode autoconf
    fi
}

# Force a restart into Range Extender (RE) mode with the SON algorithms.
#
# @see restart_in_re_mode
__restart_in_re_mode_son() {
    config_load repacd
    config_get managed_network repacd ManagedNetwork 'lan'

    __stop_repacd_run

    # By resetting the configuration, this will apply the same SSID and
    # passphrase to all interfaces. Then enable the interfaces as appropriate
    # for RE mode.
    __repacd_config_wps_pbc_enhc 0 config_changed
    __repacd_reset_existing_config
    __repacd_config_re_mode

    if [ "$wsplcd_enabled" -gt 0 ]; then
        wsplcd_restart=1
    fi

    __repacd_restart_dependencies
    __repacd_wifi_set_otherband_bssids $managed_network

    if ! __repacd_gw_mode; then
        # Start the script that monitors the link state, telling the daemon
        # that it is an auto config-triggered restart.
        #
        # In this Range Extender mode, it will keep checking whether there is
        # a link to the gateway over ethernet and that the Wi-Fi link is
        # sufficient to continue operating as an RE.
        start-stop-daemon -S -x /usr/sbin/repacd-run.sh -b -- \
            "son" RE $config_re_mode $resolved_re_mode $resolved_re_submode \
            autoconf
    fi
}


