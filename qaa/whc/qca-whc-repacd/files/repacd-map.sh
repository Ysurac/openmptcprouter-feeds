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

map_primary_nw='' map_backhaul_nw=''
map_country=0
map_primary_vlan=0
map_bsta_max_preference=0
anqp_ele="272:34108cfdf0020df1f7000000733000030101"
repacdPID=$(ps | grep repacd-run.sh | grep -v grep | awk '{print$1}')

# DPP config
map_dpp_enabled=0
dpp_sta_found=0
dpp_sta_iface=''
dpp_config_key=0
dpp_key_len=0
map_num_radio=0

#Increasing MAP_MAX_ADDITIONA_VAP needs changes also in all scheme template file
MAP_MAX_ADDITIONA_VAP=3

. /lib/functions/repacd-cmn.sh

#Check if interface is ethernet interface
#input:$1 interface name
#return 1 if ethernet interface else 0
__repacd_is_eth_interface() {
    local iface_name=$1
    local ifaces_eth

    ifaces_eth=$(ifconfig 2>&1 | grep eth)
    ifaces=$(echo "$ifaces_eth" | cut -d ' ' -f1)
    for iface in $ifaces; do
        if [ "$iface" = "$iface_name" ]; then
            return 1
        fi
    done

    return 0
}

# Set egress and ingress priority map per VLAN interface
__repacd_map_set_egress_ingress_per_intf() {
    local ifname="$1"
    local vlan_id="$2"

    vconfig set_egress_map "$ifname.$vlan_id" 0 0
    vconfig set_egress_map "$ifname.$vlan_id" 1 1
    vconfig set_egress_map "$ifname.$vlan_id" 2 2
    vconfig set_egress_map "$ifname.$vlan_id" 3 3
    vconfig set_egress_map "$ifname.$vlan_id" 4 4
    vconfig set_egress_map "$ifname.$vlan_id" 5 5
    vconfig set_egress_map "$ifname.$vlan_id" 6 6
    vconfig set_egress_map "$ifname.$vlan_id" 7 7
    vconfig set_ingress_map "$ifname.$vlan_id" 0 0
    vconfig set_ingress_map "$ifname.$vlan_id" 1 1
    vconfig set_ingress_map "$ifname.$vlan_id" 2 2
    vconfig set_ingress_map "$ifname.$vlan_id" 3 3
    vconfig set_ingress_map "$ifname.$vlan_id" 4 4
    vconfig set_ingress_map "$ifname.$vlan_id" 5 5
    vconfig set_ingress_map "$ifname.$vlan_id" 6 6
    vconfig set_ingress_map "$ifname.$vlan_id" 7 7
}

# Create necessary VLAN interfaces for the backhaul vaps and add the
# created VLAN interfaces to the given network.
# VLAN interfaces are created by concatenating interface name and vlan id.
# input: $1 config
# input: $2 network name
# input: $3 VLAN id
__repacd_map_add_vlan_backhaul() {
    local config="$1"
    local nw_name="$2"
    local vlan_id="$3"
    local iface network disabled device

    config_get ifname "$config" ifname
    config_get network "$config" network
    config_get disabled "$config" disabled '0'
    config_get mode "$config" mode
    config_get MapBSSType "$config" MapBSSType '0'

    if [ -n "$ifname" -a "$disabled" -eq 0 -a "$network" = "$map_backhaul_nw" \
            -a "$mode" = "ap" ]; then
        # if r2 STA Assoc DisAllowed do not create vlan
        if [ $(($((MapBSSType&4)) >> 2)) -eq 1 ]; then
            return
        fi

        if [ "$map_single_r1r2_bh" -eq 1 ]; then
            if [ "$nw_name" = "$map_primary_nw" ]; then
                __repacd_add_interface "$nw_name" "$ifname"
            fi
        fi

        __repacd_echo "Apply Vlan $ifname $vlan_id br-$nw_name"
        __repacd_add_interface "$nw_name" "$ifname.$vlan_id"
    fi
}

# Set ingress and egress priorty maps on necessary VLAN interfaces for the backhaul vaps
# to the given network.
# We get VLAN interfaces by concatenating interface name and vlan id.
# input: $1 config
# input: $2 network name
# input: $3 VLAN id
__repacd_map_set_egress_ingress_backhaul() {
    local config="$1"
    local nw_name="$2"
    local vlan_id="$3"
    local iface network disabled device

    config_get ifname "$config" ifname
    config_get network "$config" network
    config_get disabled "$config" disabled '0'
    config_get mode "$config" mode
    config_get MapBSSType "$config" MapBSSType '0'

    if [ -n "$ifname" -a "$disabled" -eq 0 -a "$network" = "$map_backhaul_nw" \
            -a "$mode" = "ap" ]; then
        # if r2 STA Assoc DisAllowed do not set.
        if [ $(($((MapBSSType&4)) >> 2)) -eq 1 ]; then
            return
        fi

        __repacd_echo "Set egress/ingress port for $ifname $vlan_id br-$nw_name"
        __repacd_map_set_egress_ingress_per_intf $ifname $vlan_id
    fi
}

# Create necessary VLAN interfaces for ethernet interfaces and add the
# created VLAN interfaces to the given network.
# VLAN interfaces are created by concatenating interface name and vlan id.
# input: $1 network name
# input: $2 VLAN id
__repacd_map_add_vlan_ethernet() {
    local network="$1"
    local vlan_id="$2"

    iface_list=$(uci get "network.$map_primary_nw.ifname")
    for ifname in $iface_list; do
        __repacd_is_eth_interface $ifname
        is_eth_iface=$?
        if [ "$is_eth_iface" -eq 0 ]; then
            continue
        fi

        __repacd_echo "Apply Vlan $ifname $vlan_id br-$network"
        __repacd_add_interface "$network" "$ifname.$vlan_id"

        swconfig dev switch0 vlan $vlan_id set ports "0t 1t 2t 3t 4t"
        swconfig dev switch0 vlan $vlan_id set ports "0t 1t 2t 3t 4t"
        swconfig dev switch0 set apply
    done
}

# Set egress and ingress priorty maps on necessary VLAN interfaces for the ethernet ports
# to the given network.
# We get VLAN interfaces by concatenating interface name and vlan id.
# input: $1 network name
# input: $2 VLAN id
__repacd_map_set_egress_ingress_ports_ethernet() {
    local network="$1"
    local vlan_id="$2"

    iface_list=$(uci get "network.$map_primary_nw.ifname")
    for ifname in $iface_list; do
        __repacd_is_eth_interface $ifname
        is_eth_iface=$?
        if [ "$is_eth_iface" -eq 0 ]; then
            continue
        fi

        __repacd_echo "Set egress/ingress priority map for $ifname $vlan_id br-$network"
        __repacd_map_set_egress_ingress_per_intf $ifname $vlan_id
    done
}

# Create necessary VLAN interfaces for Easy Mesh
__repacd_map_apply_vlan_config() {
    __repacd_echo "Enable Easy Mesh Traffic Separation"
    local num_vlan=$num_vlan_supported

    # Create new bridge based on num Vlan configured by user
    config_load network
    for i in Primary One Two Three; do
        config_get nw_name MAPConfig "VlanNetwork"$i '0'
        config_get vlan_id MAPConfig "VlanIDNw"$i '0'

        if [ "$num_vlan" -eq 0 ]; then
            break
        fi

        if [ "$vlan_id" -eq 0 ]; then
            return
        fi

        # Configure backHaul BSS with VLAN for primary and secondary networks
        config_load wireless
        config_foreach __repacd_map_add_vlan_backhaul wifi-iface $nw_name $vlan_id

        # Configure ethernet interface with VLAN for secondary networks
        if [ "$i" != "Primary" ]; then
            __repacd_map_add_vlan_ethernet $nw_name $vlan_id
        fi

        num_vlan=$((num_vlan-1))
    done
}

# Set engress/ingress priorty maps
__repacd_map_set_egress_ingress_ports() {
    __repacd_echo "Setting egress and ingress priority map"
    local num_vlan=$num_vlan_supported

    config_load network
    for i in Primary One Two Three; do
        config_get nw_name MAPConfig "VlanNetwork"$i '0'
        config_get vlan_id MAPConfig "VlanIDNw"$i '0'

        if [ "$num_vlan" -eq 0 ]; then
            break
        fi

        if [ "$vlan_id" -eq 0 ]; then
            return
        fi

        # Configure egress ingress priority maps for backHaul BSS
        # with VLAN for primary and secondary networks
        config_load wireless
        config_foreach __repacd_map_set_egress_ingress_backhaul wifi-iface $nw_name $vlan_id

        # Configure egress ingress priority maps for ethernet interface
        # with VLAN for secondary networks
        if [ "$i" != "Primary" ]; then
            __repacd_map_set_egress_ingress_ports_ethernet $nw_name $vlan_id
        fi

        num_vlan=$((num_vlan-1))
    done
}

# Create firewall rules for the given network if the rule does not exist.
# input: $1 nw_index network index
__repacd_set_firewall_dhcp_rules_map() {
    local nw_index=$1
    local network no_rule
    local dhcp_key dhcp_value dhcp_setting

    config_load repacd
    config_get network MAPConfig "VlanNetwork"$nw_index '0'
    config_get dhcp_setting MAPConfig "dhcpSettingsNw"$nw_index '0'

    # Set firewall rules for network
    __repacd_set_firewall_rules $network

    no_rule=$(uci show dhcp | grep zone | grep "$network")
    if [ -z "$no_rule" ]; then
        # DHCP Settings
        uci set dhcp.$network=dhcp
        uci set dhcp.$network.interface=$network
        uci set dhcp.$network.dhcpv6=server
        uci set dhcp.$network.ra=server

        for setting in $dhcp_setting
        do
            dhcp_key=$(echo "$setting" | cut -d '=' -f1)
            dhcp_value=$(echo "$setting" | cut -d '=' -f2)
            uci set dhcp.$network.$dhcp_key=$dhcp_value
        done

        uci_commit dhcp
    fi
}

# Delete guest bridges, firewall and DHCP settings for guest networks
__repacd_map_delete_traffic_sep_config() {
    local is_controller=$1
    local bridges dhcp_uci br nw
    local ifaces_eth iface_wan ifaces

    # On reset delete all network configurations other than
    # primary
    bridges=$(uci show network | grep bridge)
    for br in $bridges; do
        nw=$(echo $br | cut -d "." -f 2)
        if [ "$map_primary_nw" != "$nw" ]; then
            uci delete network.$nw
        fi
    done

    # Clean Primary ifname list so any vlan configuration will
    # be erased and add ethernet interface to ifname
    uci_set network "$map_primary_nw" ifname ' '
    ifaces_eth=$(ifconfig -a 2>&1 | grep eth)
    iface_wan=$(uci get network.wan.ifname)
    ifaces=$(echo "$ifaces_eth" | cut -d ' ' -f1)
    for iface in $ifaces; do
        # Delete interface that is vlan configured
        echo "$iface" | grep '\.' >/dev/null 2>&1
        if [ "$?" -eq "0" ]; then
            continue
        fi

        # Add ethernet lan interface to primary ifname if link is detected
        if [ "$iface" != "$iface_wan" ]; then
            __repacd_add_interface $map_primary_nw $iface
        fi
    done

    # Reset Firewall and DHCP Settings on Controller
    if [ "$is_controller" -eq 1 ]; then
        # Copy default firewall config
        cp /rom/etc/config/firewall /etc/config/firewall

       # On reset delete all dhcp configurations other than
       # primary
       dhcp_uci=$(uci show dhcp | grep interface)
       for br in $dhcp_uci; do
           nw=$(echo $br | cut -d "." -f 2)
           if [ "$map_primary_nw" != "$nw" -a "wan" != "$nw" ]; then
               uci delete dhcp.$nw
           fi
       done
    fi

    if [ "$map_ts_enabled" -eq 0 ]; then
        __repacd_echo "Easy Mesh Traffic Separation Disabled"
        uci_set repacd MAPConfig 'MapTrafficSeparationActive' 0
        uci_set $MAP MultiAP 'NumberOfVLANSupported' 0
        uci_set $MAP MultiAP 'Map2TrafficSepEnabled' 0
        uci_set wsplcd config 'NumberOfVLANSupported' 0
        uci_set wsplcd config 'Map2TrafficSepEnabled' 0
        uci_set $MAP MultiAP 'Map8021QPCP' 0
        uci_set $MAP MultiAP 'FronthaulSSIDPrimary' ''
        uci_set $MAP MultiAP 'VlanIDNwPrimary' 0
        uci_set $MAP MultiAP 'FronthaulSSIDNwOne' ''
        uci_set $MAP MultiAP 'VlanIDNwOne' 0
        uci_set $MAP MultiAP 'FronthaulSSIDNwTwo' ''
        uci_set $MAP MultiAP 'VlanIDNwTwo' 0
        uci_set $MAP MultiAP 'FronthaulSSIDNwThree' ''
        uci_set $MAP MultiAP 'VlanIDNwThree' 0
        uci_set $MAP MultiAP 'AdditionalFH' ''
    fi
}

# Add or remove bridges based on user configuration. If traffic separation is
# enabled create bridge with network name, IP address and proto as specified
# by user. Add interface and vlanID for secondary bridge based on primary lan
# ifname list. If traffic separation is disabled remove all bridges except primary
# bridge
__repacd_map_reset_default_bridge_config() {
    local is_controller=$1
    local num_vlan=$num_vlan_supported

    __repacd_map_delete_traffic_sep_config $is_controller

    if [ "$map_ts_enabled" -eq 0 ]; then
        __repacd_echo "Easy Mesh Traffic Separation Disabled"
        return
    fi

    # Create new bridge based on num Vlan configured by user
    config_load network
    for i in One Two Three; do
        if [ "$num_vlan" -eq 0 -o "$num_vlan" -eq 1 ]; then
            break
        fi

        config_get nw_name MAPConfig "VlanNetwork"$i '0'
        config_get br_proto MAPConfig "BridgeProtoNw"$i '0'
        config_get br_ip MAPConfig "BridgeIPAddressNw"$i '0'

        __repacd_echo "Creating Bridge : br-$nw_name"
        __repacd_echo "Bridge Proto : $br_proto"
        __repacd_echo "Bridge IP : $br_ip"

        uci set network.$nw_name=interface
        uci_set network "$nw_name" type "bridge"
        uci_set network "$nw_name" proto $br_proto
        if [ "$br_proto" = "static" ]; then
            uci_set network "$nw_name" ipaddr $br_ip
        fi
        uci_set network "$nw_name" netmask "255.255.255.0"
        uci_set network "$nw_name" force_link 1
        uci_set network "$nw_name" family ipv4
        uci_set network "$nw_name" ifname ' '
        uci_set network "$nw_name" bridge_empty 1

        # Set firewall settings on controller for guest nw
        if [ "$is_controller" -eq 1 ]; then
            __repacd_set_firewall_dhcp_rules_map $i
        fi

        uci_commit network
        num_vlan=$((num_vlan-1))
    done

    # set bridge MAC
    __repacd_map_set_bridge_mac
}

# Set bridge MAC
__repacd_map_set_bridge_mac() {
    local num_vlan=$num_vlan_supported
    local ifaces_eth iface_wan ifaces
    local nw_name br_mac sameMAC

    config_get nw_name MAPConfig "VlanNetworkPrimary" '0'
    config_get sameMAC MAPConfig "TSUseSameBridgeMAC" '0'

    br_mac=$(ifconfig eth0 | grep HWaddr | awk '{print $5}')
    uci_set network "$nw_name" macaddr $br_mac
    ifconfig br-$nw_name hw ether "$br_mac"

    # Create new bridge based on num Vlan configured by user
    config_load network
    for i in One Two Three; do
        if [ "$num_vlan" -eq 0 -o "$num_vlan" -eq 1 ]; then
            break
        fi

        config_get nw_name MAPConfig "VlanNetwork"$i '0'
        if [ "$i" = "One" -a "$sameMAC" -eq 0 ]; then
            br_mac=$(ifconfig eth1 | grep HWaddr | awk '{print $5}')
        fi

        # Wifi Interface should be up by now
        if [ "$i" = "Two" -a "$sameMAC" -eq 0 ]; then
            br_mac=$(uci show wireless | grep macaddr | grep wifi0 | cut -d '=' -f2 |
                         sed 's/^.\(.*\).$/\1/')
        fi

        if [ "$i" = "Three" -a "$sameMAC" -eq 0 ]; then
            br_mac=$(uci show wireless | grep macaddr | grep wifi1 | cut -d '=' -f2 |
                         sed 's/^.\(.*\).$/\1/')
        fi

        uci_set network "$nw_name" macaddr $br_mac
        ifconfig br-$nw_name hw ether "$br_mac"
        uci_commit network
        num_vlan=$((num_vlan-1))
    done
}

# Delete all managed VAPs and re-create them according to the current
# configuration.
#
# Unlike the above, this is destructive in that all VAPs not marked as
# repacd_security_unmanaged will be deleted. If this is not desired, set the
# FirstConfigRequired flag to 0 to prevent this step from taking place. In
# this case, the VAPs must be created manually in a manner that matches the
# expectations of this script.
#
# input: $1 - is_controller: whether this device is acting as the controller
__repacd_reset_map_default_config() {
    local is_controller=$1

    local fronthaul_ssid fronthaul_key backhaul_ssid backhaul_key
    local backhaul_suffix smartmonitor_ssid
    local fh_vap_count vlan_id nw_name num_vlan
    local map_r1_sta_assoc_disallow map_r2_sta_assoc_disallow
    local vap_bh_bss_type
    local disable_steer ad_vap_index
    # Default values
    vlan_id=0 map_r1_sta_assoc_disallow=0 map_r2_sta_assoc_disallow=0
    vap_bh_bss_type=$((map_r1_sta_assoc_disallow|map_r2_sta_assoc_disallow))
    fh_vap_count=1 nw_name="lan" disable_steer=0

    config_load repacd
    config_get fronthaul_ssid MAPConfig 'FronthaulSSID' ''
    config_get fronthaul_key MAPConfig 'FronthaulKey' ''
    config_get fronthual_authtype MAPConfig 'FronthaulAuthType' 0
    config_get additional_vaps MAPConfig 'AdditionalFH' ''
    config_get backhaul_ssid MAPConfig 'BackhaulSSID' ''
    config_get backhaul_key MAPConfig 'BackhaulKey' ''
    config_get backhaul_suffix MAPConfig 'BackhaulSuffix' ''
    config_get backhual_authtype MAPConfig 'BackhaulAuthType' 0

    config_get smartmonitor_ssid MAPConfig 'SmartMonitorSSID' 'ap_smart_monitor'

    if [ "$map_version" -gt 1 ]; then
        config_get map_r1_sta_assoc_disallow MAPConfig 'R1AgentAssocDisAllowed' '0'
        config_get map_r2_sta_assoc_disallow MAPConfig 'R2AgentAssocDisAllowed' '0'
        vap_bh_bss_type=$(($((map_r1_sta_assoc_disallow<<3))|$((map_r2_sta_assoc_disallow<<2))))
        if [ "$map_ts_enabled" -gt 0 ]; then
            config_get map_primary_vlan MAPConfig 'VlanIDNwPrimary' '0'
            nw_name=$map_primary_nw
        fi
    fi

    config_load wireless
    config_foreach __repacd_delete_managed_vaps wifi-iface $managed_network
    uci_commit wireless

    # Clear out the environment of all CONFIG_ variables. Seems like there
    # should be some way to do this in UCI.
    unset $(set | grep '^CONFIG_' | awk -F'=' '{print $1}')

    # Reload to reset our variable state after the deletion
    config_load wireless

    if [ -z "$fronthaul_ssid" ]; then
        local ssid_suffix
        __repacd_generate_ssid_suffix ssid_suffix
        fronthaul_ssid="mapsig-${ssid_suffix}"
        __repacd_generate_psk fronthaul_key
    fi

    if [ -z "$backhaul_ssid" ]; then
        backhaul_ssid="${fronthaul_ssid}${backhaul_suffix}"

        if [ "$fronthaul_ssid" = "$backhaul_ssid" ]; then
            backhaul_key=$fronthaul_key
        else
            __repacd_generate_psk backhaul_key
        fi
    fi

    __repacd_create_vaps_map "$is_controller" "$fronthaul_ssid" "$fronthaul_key" \
                             "$backhaul_ssid" "$backhaul_key" "$smartmonitor_ssid" \
                             "$fh_vap_count" "$vap_bh_bss_type" "$map_primary_vlan" "$nw_name" \
                             "$fronthual_authtype" "$backhual_authtype" "$disable_steer"

   disable_steer=1
   ad_vap_index=1
   while [ $ad_vap_index -le $MAP_MAX_ADDITIONA_VAP ]; do
       ad_vap=$(eval "echo $additional_vaps | awk 'BEGIN { FS = \",\" }; { print \$$ad_vap_index }'")
       if [ -z $ad_vap ]; then
          break;
       fi
       fronthaul_ssid=$(eval "echo $ad_vap | awk 'BEGIN { FS = \":\" }; { print \$1 }'")
       fronthaul_key=$(eval "echo $ad_vap | awk 'BEGIN { FS = \":\" }; { print \$2 }'")
       fronthual_authtype=$(eval "echo $ad_vap | awk 'BEGIN { FS = \":\" }; { print \$3 }'")
       ad_vap_index=$((ad_vap_index+1))
       fh_vap_count=$((fh_vap_count+1))
        __repacd_create_vaps_map "$is_controller" "$fronthaul_ssid" "$fronthaul_key" \
                                 "$backhaul_ssid" "$backhaul_key" "$smartmonitor_ssid" \
                                 "$fh_vap_count" "$vap_bh_bss_type" "$map_primary_vlan" "$nw_name" \
                                 "$fronthual_authtype" "$backhual_authtype" "$disable_steer"
    done
    disable_steer=0

    if [ "$map_version" -gt 1 -a "$map_ts_enabled" -gt 0 -a "$is_controller" -gt 0 ]; then
        num_vlan=$num_vlan_supported
        for i in One Two Three; do
            # if 1 then VLAN is configured on Primary VLAN
            if [ "$num_vlan" -eq 0 -o "$num_vlan" -eq 1 ]; then
                break
            fi

            config_get fronthaul_ssid MAPConfig "FronthaulSSIDNw"$i ''
            config_get fronthaul_key MAPConfig "FronthaulKeyNw"$i ''
            config_get fronthual_authtype MAPConfig "FronthaulAuthTypeNw"$i 0
            config_get vlan_id MAPConfig "VlanIDNw"$i '0'
            config_get nw_name MAPConfig "VlanNetwork"$i ''

            if [ -z "$fronthaul_ssid" ]; then
                local ssid_suffix
                __repacd_generate_ssid_suffix ssid_suffix
                fronthaul_ssid="mapsig-${ssid_suffix}-$i"
                __repacd_generate_psk fronthaul_key
            fi

            __repacd_echo "Fronthaul SSID Network $i : $fronthaul_ssid"
            __repacd_echo "Fronthaul Key Network $i : $fronthaul_key"
            __repacd_echo "Fronthaul AuthType $i: $fronthual_authtype"
            __repacd_echo "Fronthaul Vlan ID $i : $vlan_id"
            __repacd_echo "Fronthaul Network$i Name : $nw_name"

            fh_vap_count=$((fh_vap_count+1))
            __repacd_create_vaps_map "$is_controller" "$fronthaul_ssid" "$fronthaul_key" \
                                     "$backhaul_ssid" "$backhaul_key" "$smartmonitor_ssid" \
                                     "$fh_vap_count" "$vap_bh_bss_type" "$vlan_id" "$nw_name" \
                                     "$fronthual_authtype" "$backhual_authtype" "$disable_steer"

            num_vlan=$((num_vlan-1))
        done
    fi
}

# Delete all of the VAPs for the given network that are marked as unmanaged.
#
# input: $1 config: section being considered
# input: $2 network: managed network name
__repacd_delete_managed_vaps() {
    local config="$1"
    local network repacd_security_unmanaged mode
    local vlan_nw_name backhaul_nw_name

    config_get network "$config" network
    config_get mode "$config" mode
    config_get_bool repacd_security_unmanaged "$config" repacd_security_unmanaged '0'

    if [ "$2" = "$network" ] && [ "$repacd_security_unmanaged" -eq 0 ]; then
        uci delete "wireless.$config"
    fi

    if [ $mode = "ap_smart_monitor" ]; then
        uci delete "wireless.$config"
    fi

    if [ "$map_version" -gt 1 ]; then
        for i in One Two Three; do
            config_get vlan_nw_name MAPConfig "VlanNetwork"$i ''
            if [ "$vlan_nw_name" = "$network" ] && [ "$repacd_security_unmanaged" -eq 0 ]; then
                uci delete "wireless.$config"
            fi
        done

        config_get backhaul_nw_name MAPConfig "VlanNetworkBackHaul" ''
        if [ "$backhaul_nw_name" = "$network" ] && [ "$repacd_security_unmanaged" -eq 0 ]; then
            uci delete "wireless.$config"
        fi
    fi
}

# For Traffic Separation on EasyMesh Device we do not support combined
# Profile-1 and Profile-2 backhaul. Check if Profile-1 or Profile-2 STA
# Assoc is DisAllowed and create backHaul BSS accordingly.

# If Profile-1 Assoc is DisAllowed create 1 backhaul BSS and update MapBSSType
# for Profiel-1 Assoc DisAllowed
# If Profile-2 Assoc is DisAllowed create 1 backhaul BSS and update MapBSSType
# for Profiel-2 Assoc DisAllowed
# If both Profile-1 and Profile-2 Assoc is allowed then create 2 backhaul BSS
# Mark one as Profile-1 Assoc Disallowed and the other as Profile-2 Assoc DisAllowed
# If Fronthaul and backHaul are on the same VAP then split such a VAP to 1 frontaul
# and 2 backhaul VAP with above configuration
#
# input: $1 name: Current VAP config
# input: $2 device: the radio to which the VAP belongs
# input: $3 backhaul_ssid: the SSID to use on all backhaul VAPs
# input: $4 backhaul_key: the PSK for the backhaul, or the empty string
#                         for open mode
# input: $5 encryption: encryption
# input: $6 vap_bss_type: current vap attribute
# input: $7 vap_bh_bss_type: carries backhaul BSS attribute
# input: $8 backhual_authtype: backhaul authentication type
__reapcd_create_additional_backhaul_map() {
    local name=$1
    local device=$2
    local backhaul_ssid=$3
    local backhaul_key=$4
    local backhaul_encryption=$5
    local vap_bss_type=$6
    local vap_bh_bss_type=$7
    local backhual_authtype=$8

    local bss_attribute

    # Split shared vap into 1 FH and 2 BH VAPs
    if [ "$vap_bss_type" -eq 96 ]; then
        # Mark VAP as fronthaul
        __repacd_update_vap_param "$name" 'MapBSSType' 32
        __repacd_update_vap_param "$name" 'network' $map_primary_nw

        # Add new backhaul VAP
        name=$(uci add wireless wifi-iface)
        config_changed=1

        __repacd_init_vap "$name" $device 'ap' "$backhaul_ssid" \
                          $backhaul_encryption "$backhaul_key" '0'
        __repacd_update_vap_param "$name" 'map' 1
        __repacd_update_vap_param "$name" 'MapBSSType' 64
        __repacd_update_vap_param "$name" 'wps_pbc' 0

        if [ $backhual_authtype -gt 0 ]; then
            __repacd_update_vap_param "$name" 'sae' 1
        fi
    fi

    # update backhaul BSS based on DisAllow Bit
    if [ "$vap_bh_bss_type" -eq 8 ]; then
        # vap_bh_bss_type 8, Profile-1 Backhaul STA association disallowed
        bss_attribute=$((vap_bh_bss_type|64))
        __repacd_update_vap_param "$name" 'MapBSSType' $bss_attribute
        if [ "$map_primary_vlan" -gt 0 ]; then
            __repacd_update_vap_param "$name" 'network' $map_backhaul_nw
            __repacd_update_vap_param "$name" 'map8021qvlan' $map_primary_vlan
            __repacd_update_vap_param "$name" 'vlan_bridge' "br-$map_primary_nw"
        fi
    elif [ "$vap_bh_bss_type" -eq 4 ]; then
        # vap_bh_bss_type 4, Profile-2 Backhaul STA association disallowed
        bss_attribute=$((vap_bh_bss_type|64))
        __repacd_update_vap_param "$name" 'MapBSSType' $bss_attribute
        __repacd_update_vap_param "$name" 'network' $map_primary_nw

        # Disable the SAE authentication for R1 Agent BH BSS
        if [ $backhual_authtype -eq 1 ]; then
            __repacd_update_vap_param "$name" 'sae' 0
            __repacd_update_vap_param "$name" 'encryption' "psk2+ccmp"
        fi

        if [ "$map_primary_vlan" -gt 0 ]; then
            __repacd_update_vap_param "$name" 'map8021qvlan' $map_primary_vlan
        fi
    elif [ "$vap_bh_bss_type" -eq 0 ]; then
        if [ "$vap_bss_type" -eq 96 -a "$map_single_r1r2_bh" -eq 1 -a "$vlan_id" -gt 0 ]; then
            __repacd_update_vap_param "$name" 'network' $map_backhaul_nw
            __repacd_update_vap_param "$name" 'map8021qvlan' $map_primary_vlan
            __repacd_update_vap_param "$name" 'vlan_bridge' "br-$map_primary_nw"
            return
        fi

        # Update current bhBSS for r2 Agent assoc disallowed
        bss_attribute=$((vap_bh_bss_type|64|4))
        __repacd_update_vap_param "$name" 'MapBSSType' $bss_attribute
        __repacd_update_vap_param "$name" 'network' $map_primary_nw

        # Disable the SAE authentication for R1 Agent BH BSS
        if [ $backhual_authtype -eq 1 ]; then
            __repacd_update_vap_param "$name" 'sae' 0
            __repacd_update_vap_param "$name" 'encryption' "psk2+ccmp"
        fi

        # Create One More bhBSS for r2 Agents
        name=$(uci add wireless wifi-iface)
        config_changed=1

        __repacd_init_vap "$name" $device 'ap' "$backhaul_ssid" \
                          $backhaul_encryption "$backhaul_key" '0'
        __repacd_update_vap_param "$name" 'map' 2
        # Update current bhBSS for r1 Agent assoc disallowed
        bss_attribute=$((vap_bh_bss_type|64|8))
        __repacd_update_vap_param "$name" 'MapBSSType' $bss_attribute
        __repacd_update_vap_param "$name" 'wps_pbc' 0
        if [ "$map_primary_vlan" -gt 0 ]; then
            __repacd_update_vap_param "$name" 'network' $map_backhaul_nw
            __repacd_update_vap_param "$name" 'map8021qvlan' $map_primary_vlan
            __repacd_update_vap_param "$name" 'vlan_bridge' "br-$map_primary_nw"
        fi

        if [ $backhual_authtype -eq 1 ]; then
            __repacd_update_vap_param "$name" 'sae' 1
        fi

    fi
}

# Create the VAPs needed for Multi-AP SIG Topology Optimization with them all
# initially disabled.
#
# input: $1 is_controller: whether this device is acting as the controller
# input: $2 fronthaul_ssid: the SSID to use on all fronthaul VAPs
# input: $3 fronthaul_key: the PSK for the fronthaul, or the empty string
#                          for open mode
# input: $4 backhaul_ssid: the SSID to use on all backhaul VAPs
# input: $5 backhaul_key: the PSK for the backhaul, or the empty string
#                         for open mode
# input: $6 smartmonitor_ssid: the SSID to use on all smart monitor VAPs
# input: $7 fh_vap_count: the count of Fronthaul VAPs that are created on a radio
# input: $8 vap_bh_bss_type: carries backhaul BSS attribute
# input: $9 vlan_id: fronthaul vlan ID
# input: $10 nw_name: network to which the fronthaul belongs to
# input: $11 fronthaul_authtype: the authentication type used for fronthaul
# input: $12 backhaul_authtype: the authentication type used for backhaul
__repacd_create_vaps_map() {
    local is_controller=$1
    local fronthaul_ssid=$2
    local fronthaul_key=$3
    local backhaul_ssid=$4
    local backhaul_key=$5
    local smartmonitor_ssid=$6
    local fh_vap_count=$7
    local vap_bh_bss_type=$8
    local vlan_id=$9
    local nw_name=$10
    local fronthaul_authtype=$11
    local backhaul_authtype=$12
    local disable_steer=$13

    local fronthaul_encryption backhaul_encryption
    local smartmonitor_encryption='none'
    local enable_smart_monitor_mode
    local bss_attribute

    # Whether the same VAP is used for fronthaul and backhaul or not.
    local shared_vaps=0
    if [ "$fronthaul_ssid" = "$backhaul_ssid" ]; then
        shared_vaps=1
    fi

    if [ -n "$fronthaul_key" ]; then
        fronthaul_encryption='psk2+ccmp'
    else
        fronthaul_encryption='none'
    fi

    if [ -n "$backhaul_key" ]; then
        backhaul_encryption='psk2+ccmp'
        #Enable SAE only mode for pure bakchaul BSS
        if [ "$map_version" -gt 1 ] && [ "$is_controller" -gt 0 ] && \
              [ "$shared_vaps" -eq 0 ] && [ "$backhual_authtype" -eq 1 ]; then
            backhaul_encryption='ccmp'
        fi
    else
        backhaul_encryption='none'
    fi

    local DEVICES=
    __repacd_get_devices DEVICES

    for device in $DEVICES; do
        local repacd_auto_create_vaps repacd_create_bsta repacd_bsta_pref
        local create_ctrl_fbss create_ctrl_bbss neighbourfilter set_monrxfilter
        local disable wsplcd_unmanaged repacd_security_unmanaged
        local no_vlan_val
        config_get_bool repacd_auto_create_vaps "$device" repacd_auto_create_vaps '1'
        config_get_bool repacd_create_bsta "$device" repacd_create_bsta '1'
        config_get repacd_bsta_pref "$device" repacd_map_bsta_preference '0'
        config_get_bool create_ctrl_fbss "$device" repacd_create_ctrl_fbss '1'
        config_get_bool create_ctrl_bbss "$device" repacd_create_ctrl_bbss '1'
        uci_set wireless $device disabled '0'

        if [ "$map_version" -gt 1 -a "$map_ts_enabled" -gt 0 ]; then
            config_get no_vlan_val $device no_vlan '0'
            if [ "$no_vlan_val" -eq 0 ]; then
                uci_set wireless $device no_vlan '1'
            fi
        fi

        # Create one bSTA per radio
        if [ "$fh_vap_count" -eq 1 ] && [ "$repacd_auto_create_vaps" -gt 0 ] && \
               [ "$repacd_create_bsta" -gt 0 ] && ! whc_is_5g_radio "$device"; then
            # Create a bSTA interface
            name=$(uci add wireless wifi-iface)
            config_changed=1

            __repacd_init_vap "$name" $device 'sta' "$backhaul_ssid" \
                              $backhaul_encryption "$backhaul_key" '0'
            __repacd_update_vap_param "$name" 'map' 1
            __repacd_update_vap_param "$name" 'MapBSSType' 128
            __repacd_update_vap_param "$name" 'wps_state' 1
            __repacd_update_vap_param "$name" 'wps_pbc_skip' 1
            if [ "$map_dpp_enabled" -eq 1 ]; then
                __repacd_update_vap_param "$name" 'dpp' 1
                __repacd_update_vap_param "$name" 'dpp_map' 1
                __repacd_update_vap_param "$name" 'disablecoext' 1
            fi

            # Enable 802.11k support so that the controller can ask for
            # beacon measurements from the bSTA
            __repacd_update_vap_param "$name" 'rrm' 1
            __repacd_update_vap_param "$name" 'rrm_capie' 1

            # update network name if traffic separation is enabled
            if [ "$map_version" -gt 1 ]; then
                __repacd_update_vap_param "$name" 'map' $map_version
                __repacd_update_vap_param "$name" 'network' $map_primary_nw
                if [ "$map_ts_enabled" -gt 0 -a "$is_controller" -eq 1 -a "$vlan_id" -gt 0 ]; then
                    __repacd_update_vap_param "$name" 'network' $map_backhaul_nw
                fi
            fi

            # For initial onboarding, 2.4 GHz is the selected bSTA radio
            # (unless it is given a preference value of 0, in which case
            # no radio is marked as selected and we let the preference values
            # determine it entirely).
            if whc_is_5g_vap "$name" || [ "$repacd_bsta_pref" -eq 0 ]; then
                uci_set wireless $device repacd_map_bsta_selected '0'
            else
                uci_set wireless $device repacd_map_bsta_selected '1'
            fi
        fi

        # If not acting as the controller, we will let the Multi-AP
        # Configuration procedure create the BSSes. However, due to
        # limitations in wsplcd, we have to create a BSS on each radio to
        # ensure AP Auto-Config takes place. If this is removed, then repacd
        # can be updated to only do this on the controller again.
        if [ "$repacd_auto_create_vaps" -gt 0 ]; then
            # Only create the fBSS on agents (to ensure wsplcd works) or on
            # the controller if so configured.
            if [ "$is_controller" -eq 0 ] || [ "$create_ctrl_fbss" -gt 0 ]; then
                # Create the fBSS (which may also be a bBSS)
                name=$(uci add wireless wifi-iface)
                config_changed=1

                __repacd_init_vap "$name" $device 'ap' "$fronthaul_ssid" \
                                  $fronthaul_encryption "$fronthaul_key" '0'
                __repacd_update_vap_param "$name" 'map' 1

                if [ "$disable_steer" -gt 0 ]; then
                     __repacd_update_vap_param "$name" 'SteeringDisabled' 1
                fi

                if [ "$map_version" -gt 1 ]; then
                    __repacd_update_vap_param "$name" 'map' $map_version
                    __repacd_update_vap_param "$name" 'network' $map_primary_nw

                    if [ "$is_controller" -gt 0 ] && [ "$fronthual_authtype" -gt 0 ]; then
                        __repacd_update_vap_param "$name" 'sae' 1
                    fi

                    # Enable wps_pbc only on one fronthaul
                    if [ "$fh_vap_count" -gt 1 ]; then
                        __repacd_update_vap_param "$name" 'wps_pbc' 0
                    fi

                    if [ "$map_ts_enabled" -gt 0 -a "$is_controller" -eq 1 ]; then
                        __repacd_update_vap_param "$name" 'network' $nw_name
                        __repacd_update_vap_param "$name" 'mapVlanID' $vlan_id
                        __repacd_update_vap_param "$name" 'map8021qvlan' $map_primary_vlan
                    fi

                    if [ "$map_dpp_enabled" -eq 1 ]; then
                        __repacd_update_vap_param "$name" 'dpp_map' 1
                        __repacd_update_vap_param "$name" 'dpp_configurator_connectivity' 1
                        __repacd_update_vap_param "$name" 'disablecoext' 1
                    fi
                fi

                if [ "$shared_vaps" -gt 0 ]; then
                    # fBSS uses same VAP as bBSS
                    __repacd_update_vap_param "$name" 'MapBSSType' 96
                    if [ "$map_ts_enabled" -gt 0 -a "$is_controller" -eq 1 ]; then
                        __reapcd_create_additional_backhaul_map "$name $device" \
                                                                "$fronthaul_ssid" "$fronthaul_key" \
                                                                "$fronthaul_encryption" "96" \
                                                                "$vap_bh_bss_type" "$fronthual_authtype"
                    fi
                else
                    # Distinct VAPs for backhaul and fronthaul
                    __repacd_update_vap_param "$name" 'MapBSSType' 32
                fi

                # Create smart monitor VAP per each radio on the agent and for
                # every fronthaul BSS on the controller
                # Check if smart monitor mode is enabled
                config_load 'repacd'
                config_get_bool enable_smart_monitor_mode MAPConfig 'EnableSmartMonitorMode' '0'
                if [ "$enable_smart_monitor_mode" -eq 1 ] && [ "$fh_vap_count" -eq 1 ]; then
                    name=$(uci add wireless wifi-iface)
                    config_changed=1

                    __repacd_init_vap "$name" $device 'ap_smart_monitor' "$smartmonitor_ssid" \
                                       $smartmonitor_encryption '0'
                    __repacd_update_vap_param "$name" 'neighbourfilter' 1
                    __repacd_update_vap_param "$name" 'set_monrxfilter' 1
                    __repacd_update_vap_param "$name" 'disable' 0
                    __repacd_update_vap_param "$name" 'wsplcd_unmanaged' 1
                    __repacd_update_vap_param "$name" 'repacd_security_unmanaged' 1
                    __repacd_update_vap_param "$name" 'wps_pbc' 0
                fi
            fi

            # Now create the bBSS, but only on the controller if configured (and
            # only if it is meant to be a unique BSS). The agent will have any
            # bBSSes created via the AP Auto-Configuration process.
            if [ "$is_controller" -gt 0 ] && [ "$create_ctrl_bbss" -gt 0 ] && \
                [ "$shared_vaps" -eq 0 ] && [ "$fh_vap_count" -eq 1 ]; then
                name=$(uci add wireless wifi-iface)
                config_changed=1

                __repacd_init_vap "$name" $device 'ap' "$backhaul_ssid" \
                                  $backhaul_encryption "$backhaul_key" '0'
                __repacd_update_vap_param "$name" 'map' 1
                __repacd_update_vap_param "$name" 'MapBSSType' 64
                # Need to force this disabled per the Multi-AP SIG spec
                __repacd_update_vap_param "$name" 'wps_pbc' 0

                if [ "$map_version" -gt 1 ]; then
                    __repacd_update_vap_param "$name" 'map' $map_version
                    __repacd_update_vap_param "$name" 'network' $map_primary_nw

                    if [ "$map_dpp_enabled" -eq 1 ]; then
                        __repacd_update_vap_param "$name" 'dpp_map' 1
                        __repacd_update_vap_param "$name" 'dpp_configurator_connectivity' 1
                        __repacd_update_vap_param "$name" 'disablecoext' 1
                    fi

                    if [ $backhual_authtype -eq 1 ]; then
                        __repacd_update_vap_param "$name" 'sae' 1
                    fi

                    if [ "$map_ts_enabled" -gt 0 -a "$vlan_id" -gt 0 ]; then
                        if [ "$map_single_r1r2_bh" -eq 1 ]; then
                            bss_attribute=$((vap_bh_bss_type|64))
                            __repacd_update_vap_param "$name" 'MapBSSType' $bss_attribute
                            if [ "$map_primary_vlan" -gt 0 ]; then
                                __repacd_update_vap_param "$name" 'network' $map_backhaul_nw
                                __repacd_update_vap_param "$name" 'map8021qvlan' $map_primary_vlan
                                __repacd_update_vap_param "$name" 'vlan_bridge' "br-$map_primary_nw"
                            fi
                        else
                            __reapcd_create_additional_backhaul_map "$name" "$device" \
                                                                    "$backhaul_ssid" "$backhaul_key" \
                                                                    "$backhaul_encryption" "64" \
                                                                    "$vap_bh_bss_type" "$backhual_authtype"
                        fi
                    fi
                fi
            fi
        fi
    done
    uci_commit wireless
}

# Determine the radio on which the bSTA should be allocated.
#
# If a radio is marked as selected (using the repacd_map_bsta_selected config
# option), it will be used. If instead none is marked, the radio with the
# highest repacd_map_bsta_pref value will be used.
#
# input: $1 config: section name
# output: $2 selected_radio: the radio that is marked as selected
# output: $3 preferred_radio: the radio with the highest preference
__repacd_resolve_bsta_radio() {
    local config="$1"

    local bsta_selected='' bsta_preference=''
    config_get bsta_selected "$config" repacd_map_bsta_selected 0
    config_get bsta_preference "$config" repacd_map_bsta_preference

    if [ "$bsta_selected" -gt 0 ]; then
        eval "$2=$config"
    fi

    # Radios with no preference set are ignored. This is meant to indicate
    # the OEM never wants to use that radio.
    if [ -n "$bsta_preference" ]; then
        if [ "$bsta_preference" -gt "$map_bsta_max_preference" ]; then
            eval "$3=$config"
            map_bsta_max_preference="$bsta_preference"
        fi
    fi
}

# Update the radio on which the bSTA VAP is allocated based on the setting
# at the radio level.
#
# input: $1 config: section name
# input: $2 selected_radio: name of the radio on which to run the bSTA
# input: $3 network: network for which to update VAPs
# input-output: $4 change counter
__repacd_update_map_bsta_radio() {
    local config="$1"
    local selected_radio="$2"
    local changed="$4"

    local device hwmode type
    config_get device "$config" device
    config_get hwmode "$device" hwmode
    config_get type "$device" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ] ;then
        return
    fi

    local mode network disabled bssid
    config_get mode "$config" mode
    config_get network "$config" network
    config_get disabled "$config" disabled 0
    config_get bssid "$config" bssid

    if [ "$3" = "$network" ] && __repacd_is_matching_mode "sta" "$mode"; then
        if [ ! "$device" = "$selected_radio" ]; then
            uci_set wireless "$config" device "$selected_radio"
            changed=$((changed + 1))
            eval "$4='$changed'"
            __repacd_echo "Set VAP $config to device=$selected_radio"

            if [ -n "$bssid" ]; then
                uci delete "wireless.${config}.bssid"
                __repacd_echo "Removed BSSID from VAP $config due to radio change"
            fi
        fi

        if [ "$disabled" -eq 1 ]; then
            uci_set wireless "$config" disabled 0
            changed=$((changed + 1))
            eval "$4='$changed'"
            __repacd_echo "Set VAP $config to Disabled=0"
        fi
    fi
}

# Change the hyd running mode based on the value provided.
#
# input: $1 map_version: value to set hyd run mode to based on version
# input: $2 is_controller: device mode
__repacd_configure_hyd_map() {
    local version=$map_version
    local is_controller=$is_controller

    if [ "$version" -ge 1 ]; then
        # Set Forwarding Mode to SINGLE to disable HA, HD
        uci_set $MAP hy 'ForwardingMode' 'SINGLE'
        uci_set $MAP MultiAP 'MapVersion' $version

        if [ "$map_ts_enabled" -gt 0 ]; then
            uci_set repacd MAPConfig 'MapTrafficSeparationActive' 1
            uci_set $MAP MultiAP 'Map2TrafficSepEnabled' 1
            uci_set $MAP MultiAP 'NumberOfVLANSupported' $num_vlan_supported
            uci_set $MAP MultiAP 'CombinedR1R2Backhaul' $map_single_r1r2_bh
            uci_set $MAP MultiAP 'VlanNetworkPrimary' $map_primary_nw

            if [ "$is_controller" -gt 0 ]; then
                config_get fronthaul_ssid MAPConfig FronthaulSSID
                config_get primary_vlan_id MAPConfig 'VlanIDNwPrimary' '0'
                config_get pcp MAPConfig 'Map8021QPCP' '0'
                config_get additional_fh MAPConfig AdditionalFH

                uci_set $MAP MultiAP 'FronthaulSSIDPrimary' $fronthaul_ssid
                uci_set $MAP MultiAP 'Map8021QPCP' $pcp
                uci_set $MAP MultiAP 'VlanIDNwPrimary' $primary_vlan_id
                uci_set $MAP MultiAP 'AdditionalFH' $additional_fh

                local num_vlan=$num_vlan_supported
                for i in One Two Three; do
                    config_get fronthaul_ssid MAPConfig "FronthaulSSIDNw"$i ''
                    config_get vlan_id MAPConfig "VlanIDNw"$i '0'

                    if [ "$num_vlan" -eq 0 -o "$num_vlan" -eq 1 ]; then
                        break
                    fi

                    uci_set $MAP MultiAP 'FronthaulSSIDNw'$i $fronthaul_ssid
                    uci_set $MAP MultiAP 'VlanIDNw'$i $vlan_id

                    num_vlan=$((num_vlan-1))
                done
            fi
        fi
    fi

    uci_commit $MAP
}

# Set the country
#
# input: $1 config: section to update
# input: $2 country to update
__repacd_config_set_device_country() {
    local config="$1"
    local country="$2"
    config_get hwmode "$config" hwmode
    config_get type "$config" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ]; then
        return
    fi

    uci_set wireless "$config" country "$country"
    uci_commit wireless
    __repacd_echo "Set radio $config to country=$country"
}

# Enable Radio
#
# input: $1 config: section to update
__repacd_config_set_radio_enable() {
    local config="$1"
    local country="$2"
    config_get hwmode "$config" hwmode
    config_get type "$config" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ]; then
        return
    fi

    uci_set wireless "$config" disabled 0
    uci_commit wireless

    map_num_radio=$((map_num_radio + 1))
}

# Change the configuration on the wifi-iface object to match what is desired.
# This function is for Multi-AP mode.
#
# input: $1 config: section to update
# input: $2 network: only update if network matches this value
# input: $3 block_dfs_chan: 1 - block DFS channels, 0 - do not block them
# input-output: $4 change counter
__repacd_config_iface_map() {
    local config=$1
    local enable_wds=1 qwrap_ap=0 extap=0 enable_rrm=1 re_scalingfactor=0
    local default_root_dist=0 cap_snr=0

    __repacd_config_iface "$1" "$2" $enable_wds $qwrap_ap $extap "$3" $enable_rrm \
                          $re_scalingfactor $default_root_dist $cap_snr "$4"

    if [ "$map_version" -ge 2 ]; then
        config_get mode "$config" mode

        config_load 'wsplcd'
        config_get map2SetMboOcePmf config 'Map2EnableMboOcePmf'

        # These should only be set on AP interfaces.
        if __repacd_is_matching_mode 'ap' "$mode"; then
            # Set Mbo, Oce and PMF
            if [ "$map2SetMboOcePmf" -eq 1 ]; then
                uci_set wireless "$config" mbo 1
                uci_set wireless "$config" oce 1
                uci_set wireless "$config" ieee80211w 1
            fi

            # Set Interworking and ANQP
            uci_set wireless "$config" interworking 1
            uci del_list wireless."$config".anqp_elem="$anqp_ele"
            uci add_list wireless."$config".anqp_elem="$anqp_ele"
        fi

        # Update config when Traffic Separation is enabled
        if [ "$map_ts_enabled" -eq 1 ]; then
            config_load network
            for i in Primary One Two Three; do
                config_get nw_name MAPConfig "VlanNetwork"$i '0'
                __repacd_config_iface "$1" "$nw_name" $enable_wds $qwrap_ap $extap "$3" \
                                      $enable_rrm $re_scalingfactor $default_root_dist \
                                      $cap_snr "$4"
            done
            __repacd_config_iface "$1" "$map_backhaul_nw" $enable_wds $qwrap_ap $extap "$3" \
                                  $enable_rrm $re_scalingfactor $default_root_dist $cap_snr "$4"
        fi
    fi
}

# Generate the Multi-AP BSS instantiation config file for wsplcd based on
# the selected template and SSID settings.
# input-output: $1 change counter
__repacd_generate_map_bss_conf() {
    local changed="$1"

    local template_filename
    local template_path
    local fronthaul_ssid fronthaul_key
    local backhaul_ssid backhaul_key
    local fronthaul_authtype_str="0x0020" backhaul_authtype_str="0x0020"
    local backhaul_r2_authtype_str="0x0020"
    local fronthaul_authtype backhaul_authtype
    local primary_vlan_id pcp

    config_load repacd
    config_get template_filename MAPConfig BSSInstantiationTemplate
    config_get fronthaul_ssid MAPConfig FronthaulSSID
    config_get fronthaul_key MAPConfig FronthaulKey
    config_get additional_vaps MAPConfig 'AdditionalFH' ''
    config_get backhaul_ssid MAPConfig BackhaulSSID
    config_get backhaul_key MAPConfig BackhaulKey
    config_get fronthaul_authtype MAPConfig FronthaulAuthType 0
    config_get backhaul_authtype MAPConfig BackhaulAuthType 0

    if [ -z "${template_filename}" ]; then
        __repacd_echo "BSS instantiation template not specified"
        return 1
    fi

    template_path="${WSPLCD_MAP_TEMPLATE_DIR}/${template_filename}"
    if [ ! -r "${template_path}" ]; then
        __repacd_echo "BSS instantiation template ${template_path} not readable"
        return 1
    fi

    __repacd_echo "Using wsplcd BSS instantiation template: ${template_path}"

    if [ "$map_version" -ge 2 ]; then
        if [ $fronthaul_authtype -gt 0 ]; then
            fronthaul_authtype_str="0x0060"
        fi

        if [ $backhaul_authtype -eq 1 ]; then
            backhaul_authtype_str="0x0040"
        fi
    fi

    if [ -z $fronthaul_key ]; then
        fronthaul_key="NULL"
        fronthaul_authtype_str="0x0001"
    fi

    if [ -z $backhaul_key ]; then
        backhaul_key="NULL"
        backhaul_authtype_str="0x0001"
        backhaul_r2_authtype_str="0x0001"
    fi

    local tempfile
    tempfile=$(mktemp)
    cp "${template_path}" "${tempfile}"

    # Some of these replacements may not be used, but this covers all of the
    # cases of variables that need to be replaced.
    #
    # Note that in case the variable contains the sed delimeter, it needs to
    # be escaped to avoid a sed error.
    sed -i -e "s!__FH_SSID_REPLACE__!${fronthaul_ssid/!/\!}!g" \
           -e "s!__FH_KEY_REPLACE__!${fronthaul_key/!/\!}!g" \
           -e "s!__BH_SSID_REPLACE__!${backhaul_ssid/!/\!}!g" \
           -e "s!__BH_KEY_REPLACE__!${backhaul_key/!/\!}!g" \
           -e "s!__FHBH_SSID_REPLACE__!${fronthaul_ssid/!/\!}!g" \
           -e "s!__FHBH_KEY_REPLACE__!${fronthaul_key/!/\!}!g" \
           -e "s!__FH_AUTH_TYPE_REPLACE__!${fronthaul_authtype_str/!/\!}!g" \
           -e "s!__FHBH_AUTH_TYPE_REPLACE__!${fronthaul_authtype_str/!/\!}!g" \
           "${tempfile}"

   ad_vap_index=1
   while [ $ad_vap_index -le $MAP_MAX_ADDITIONA_VAP ]; do
       ad_vap=$(eval "echo $additional_vaps | awk 'BEGIN { FS = \",\" }; { print \$$ad_vap_index }'")
       if [ -z $ad_vap ]; then
          sed -i -e "s!__FHA"$ad_vap_index"_SSID_REPLACE__!"teardown"!g" "${tempfile}"    # Mark teardown for network $i and vap $ad_vap_index if config is not provided
       else
          fronthaul_ssid=$(eval "echo $ad_vap | awk 'BEGIN { FS = \":\" }; { print \$1 }'")
          fronthaul_key=$(eval "echo $ad_vap | awk 'BEGIN { FS = \":\" }; { print \$2 }'")
          authtype=$(eval "echo $ad_vap | awk 'BEGIN { FS = \":\" }; { print \$3 }'")
          __repacd_echo "BSSCONF_FILE: $ad_vap_index. ssid:$fronthaul_ssid key:$fronthaul_key auth:$authtype"

          fronthaul_authtype_str="0x0020"
          if [ "$map_version" -ge 2 ]; then
              if [ $authtype -gt 0 ]; then
                  fronthaul_authtype_str="0x0060"
              fi
          fi

          if [ -z $fronthaul_key ]; then
              fronthaul_key="NULL"
              fronthaul_authtype_str="0x0001"
          fi

          sed -i -e "s!__FHA"$ad_vap_index"_SSID_REPLACE__!${fronthaul_ssid/!/\!}!g" \
              -e "s!__FHA"$ad_vap_index"_KEY_REPLACE__!${fronthaul_key/!/\!}!g" \
              -e "s!__FHA"$ad_vap_index"_AUTH_TYPE_REPLACE__!${fronthaul_authtype_str/!/\!}!g" \
              -e "s!__FHBHA"$ad_vap_index"_SSID_REPLACE__!${fronthaul_ssid/!/\!}!g" \
              -e "s!__FHBHA"$ad_vap_index"_KEY_REPLACE__!${fronthaul_key/!/\!}!g" \
              -e "s!__FHBHA"$ad_vap_index"_AUTH_TYPE_REPLACE__!${fronthaul_authtype_str/!/\!}!g" \
              "${tempfile}"
       fi
       ad_vap_index=$((ad_vap_index+1))
   done

    if [ "$map_ts_enabled" -eq 0 ]; then
        sed -i -e "s!__BH_AUTH_TYPE_REPLACE__!${backhaul_authtype_str/!/\!}!g" \
                "${tempfile}"
    fi

    if [ "$map_version" -ge 2 ]; then
        if [ "$map_ts_enabled" -gt 0 ]; then
            config_get map_r1_sta_assoc_disallow MAPConfig 'R1AgentAssocDisAllowed' '0'
            config_get map_r2_sta_assoc_disallow MAPConfig 'R2AgentAssocDisAllowed' '0'
            config_get primary_vlan_id MAPConfig 'VlanIDNwPrimary' '0'
            config_get pcp MAPConfig 'Map8021QPCP' '0'
        fi

        if [ "$map_ts_enabled" -eq 0 ]; then
            __repacd_echo "Traffic Separation Disabled"
            __repacd_echo "Remove Vlan Config and Secondary Networks"
            map_r1_sta_assoc_disallow=0
            map_r2_sta_assoc_disallow=0
            primary_vlan_id=0
            pcp=0

            sed -i -e "s!__R1_BSTA_ASSOC_DISALLOW_BH1__!${map_r1_sta_assoc_disallow/!/\!}!g" \
                -e "s!__R2_BSTA_ASSOC_DISALLOW_BH1__!${map_r2_sta_assoc_disallow/!/\!}!g" \
                "${tempfile}"

            # Mark second backhaul config to teardown to remove
            sed -i -e "s!__BH2_SSID_REPLACE__!"teardown"!g" \
            "${tempfile}"
        elif [ "$map_r1_sta_assoc_disallow" -gt 0 -o "$map_r2_sta_assoc_disallow" -gt 0 ]; then
            sed -i -e "s!__R1_BSTA_ASSOC_DISALLOW_BH1__!${map_r1_sta_assoc_disallow/!/\!}!g" \
                -e "s!__R2_BSTA_ASSOC_DISALLOW_BH1__!${map_r2_sta_assoc_disallow/!/\!}!g" \
                "${tempfile}"

            # map_r2_sta_assoc_disallow is enabled update authtype as WPA2
            if [ "$map_r2_sta_assoc_disallow" -gt 0 ]; then
                sed -i -e "s!__BH_AUTH_TYPE_REPLACE__!${backhaul_r2_authtype_str}!}!g" \
                "${tempfile}"
            else
                sed -i -e "s!__BH_AUTH_TYPE_REPLACE__!${backhaul_authtype_str/!/\!}!g" \
                "${tempfile}"
            fi

            # Mark second backhaul config to teardown to remove
            sed -i -e "s!__BH2_SSID_REPLACE__!"teardown"!g" \
            "${tempfile}"
        elif [ "$map_r1_sta_assoc_disallow" -eq 0 -a "$map_r2_sta_assoc_disallow" -eq 0 ]; then
            # 2 backhaul are created . 1 with r1 STA assoc disAllowed another with r2
            # STA assoc disAllowed
            if [ "$map_single_r1r2_bh" -eq 1 ]; then
                sed -i -e "s!__R1_BSTA_ASSOC_DISALLOW_BH1__!0!g" \
                    -e "s!__R2_BSTA_ASSOC_DISALLOW_BH1__!0!g" \
                    -e "s!__BH_AUTH_TYPE_REPLACE__!${backhaul_authtype_str/!/\!}!g" \
                    "${tempfile}"

                # Mark second backhaul config to teardown to remove
                sed -i -e "s!__BH2_SSID_REPLACE__!"teardown"!g" \
                    "${tempfile}"
            else
                # Always update the Authtype as WPA2 for R1 agent assoc allowed backhaul BSS
                sed -i -e "s!__R1_BSTA_ASSOC_DISALLOW_BH1__!0!g" \
                    -e "s!__R2_BSTA_ASSOC_DISALLOW_BH1__!1!g" \
                    -e "s!__BH_AUTH_TYPE_REPLACE__!${backhaul_r2_authtype_str}!g" \
                    "${tempfile}"

                sed -i -e "s!__R1_BSTA_ASSOC_DISALLOW_BH2__!1!g" \
                    -e "s!__R2_BSTA_ASSOC_DISALLOW_BH2__!0!g" \
                    -e "s!__BH2_SSID_REPLACE__!${backhaul_ssid/!/\!}!g" \
                    -e "s!__BH2_AUTH_TYPE_REPLACE__!${backhaul_authtype_str/!/\!}!g" \
                    "${tempfile}"
            fi
        fi

        # Update primary information in bss.conf
        sed -i -e "s!__PRIMARY_VLAN__!${primary_vlan_id/!/\!}!g" \
            -e "s!__PCP__!${pcp/!/\!}!g" \
            "${tempfile}"

        # Create new bridge based on num Vlan configured by user
        config_load network
        local num_vlan=$num_vlan_supported
        fronthaul_authtype_str="0x0020"

        for i in One Two Three; do
            config_get fronthaul_ssid MAPConfig "FronthaulSSIDNw"$i ''
            config_get fronthaul_key MAPConfig "FronthaulKeyNw"$i ''
            config_get fronthaul_authtype MAPConfig "FronthaulAuthTypeNw"$i 0
            config_get vlan_id MAPConfig "VlanIDNw"$i '0'

            if [ $fronthaul_authtype -gt 0 ]; then
                fronthaul_authtype_str="0x0060"
            fi

            if [ -z $fronthaul_key ]; then
                fronthaul_key="NULL"
                fronthaul_authtype_str="0x0001"
            fi

            if [ -z "$fronthaul_ssid" -o "$num_vlan" -eq 0 -o "$num_vlan" -eq 1 ]; then
                fronthaul_ssid="teardown"
            fi

            if [ "$map_ts_enabled" -eq 0 ]; then
                fronthaul_ssid="teardown"
            fi

            sed -i -e "s!__FH_SSID_REPLACE_NW_"$i"__!${fronthaul_ssid/!/\!}!g" \
                -e "s!__FH_KEY_REPLACE_NW_"$i"__!${fronthaul_key/!/\!}!g" \
                -e "s!__FH_AUTH_TYPE_REPLACE_NW_"$i"__!${fronthaul_authtype_str/!/\!}!g" \
                -e "s!__VLAN_ID_NW_"$i"__!${vlan_id/!/\!}!g" \
                "${tempfile}"

            num_vlan=$((num_vlan-1))
        done
    fi

    # Get short hand name from config file and remove unused profiles
    config_SHN=$(cat ${tempfile} | grep teardown | awk '{print $2}' \
                     | cut -d "," -f1 | awk '{$1=$1};1')
    for shName in $config_SHN; do
        sed -i -e "s/,${shName}//g" "${tempfile}"
    done
    # Remove config marked as teardown
    sed -i '/teardown/d' "${tempfile}"

    if [ ! -r "${WSPLCD_MAP_BSS_POLICY_PATH}" ] || \
        ! cmp -s "${tempfile}" "${WSPLCD_MAP_BSS_POLICY_PATH}"; then
        # New file differs from old. Move it into place and update
        # the change count.
        mv -f "${tempfile}" "${WSPLCD_MAP_BSS_POLICY_PATH}"
        changed=$((changed + 1))
        eval "$1='$changed'"
    else
        # No change, so just remove the temporary file
        rm -f "${tempfile}"
    fi

    return 0
}

# Switch the device into acting as a gateway connected AP (no bSTA).
#
# Pre-condition: RE mode has already been checked to be SON
#
# input: $1 is_controller: whether the device should act as the controller
#                          or just a gateway connected AP
# input: $2 standalone_controller: if a controller, whether the device should
#                                  act as a standalone controller
__repacd_config_gwcon_map_ap() {
    local is_controller=$1
    local wsplcd_mode son_mode
    local rate_scaling_factor=0
    local default_root_dist=0

    # The WDS, VAP independent, and QWrap AP settings also need to be updated
    # based on the range extension mode.
    local enable_wds=1 enable_multi_ap=1 disable_steering=0
    local deep_clone=0 deep_clone_no_bssid=0 config_sta=0 map_enable=1
    local block_dfs

    __repacd_echo "Using SON mode for GW Connected AP"

    # In WDS/SON modes, we let the OEM customize whether DFS channels
    # should be permitted.
    if __repacd_is_block_dfs; then
        block_dfs=1
    else
        block_dfs=0
    fi

    wsplcd_enabled=1

    local disable_24g_sta disable_5g_sta disable_24g_ap disable_5g_ap
    if [ "$is_controller" -gt 0 ] && [ "$standalone_controller" -gt 0 ]; then
        __repacd_echo "Disabling all interfaces for standalone controller"
        disable_24g_sta=1
        disable_5g_sta=1
        disable_24g_ap=1
        disable_5g_ap=1
    else
        # In GW-connected AP mode, only the AP interfaces are enabled.
        disable_24g_sta=1
        disable_5g_sta=1
        disable_24g_ap=0
        disable_5g_ap=0
    fi
    config_load wireless
    config_foreach __repacd_disable_vap wifi-iface \
        $managed_network 'sta' $disable_24g_sta $disable_5g_sta config_changed
    config_foreach __repacd_disable_vap wifi-iface \
        $managed_network 'ap' $disable_24g_ap $disable_5g_ap config_changed

    # Now set up the interfaces in the right way.
    if [ "$standalone_controller" -eq 0 ]; then
        config_foreach __repacd_config_iface_map wifi-iface \
            $managed_network $block_dfs config_changed
    fi

    uci_commit wireless

    uci_set repacd repacd Role 'CAP'
    if [ "$is_controller" -gt 0 ]; then
        uci_set $MAP MultiAP EnableController 1

        # Standalone controller does not act as an Agent
        if [ "$standalone_controller" -gt 0 ]; then
            uci_set $MAP MultiAP EnableAgent 0
        else
            uci_set $MAP MultiAP EnableAgent 1
        fi

        # Force the remote association tracking on for the controller, as the
        # steering is centralized.
        uci_set $MAPLBD StaDB TrackRemoteAssoc 1
    else
        uci_set $MAP MultiAP EnableController 0
        uci_set $MAP MultiAP EnableAgent 1

        # For an agent, use whatever the current remote association tracking
        # setting is. There is still an advantage to tracking remote
        # associations as it allows the bridging tables to be cleaned up
        # properly when a Topology Notification is missed.
    fi

    if [ "$map_version" -ge 2 ]; then
        __repacd_configure_hyd_map $map_version $is_controller
        config_load wireless
        config_foreach __repacd_disable_vap wifi-iface \
                       $map_backhaul_nw 'sta' $disable_24g_sta $disable_5g_sta config_changed

    fi

    # This generally should nto be needed when operating in gateway connected
    # AP mode. Until there is a case where we need it, we'll leave it disabled.
    uci_set repacd FrontHaulMgr ManageFrontAndBackHaulsIndependently 0
    uci_commit repacd

    uci_commit $MAP
    uci_commit $MAPLBD

    if [ "$is_controller" -gt 0 ]; then
        wsplcd_mode='REGISTRAR'
        son_mode='HYROUTER'

        if ! __repacd_generate_map_bss_conf config_changed; then
            return 1
        fi
    else
        wsplcd_mode='ENROLLEE'
        son_mode='HYCLIENT'
    fi

    # No deep cloning with the MAP algorithms
    __repacd_configure_wsplcd $wsplcd_mode $deep_clone $deep_clone_no_bssid \
                              $config_sta $map_version config_changed

    __repacd_configure_son $enable_wds $disable_steering $enable_multi_ap \
        $son_mode config_changed

    return 0
}

# Switch the device to act as a range extender.
__repacd_config_map_re() {
    # The WDS and QWrap AP settings also need to be updated based on the
    # range extension mode.
    local enable_wds=1 block_dfs
    local enable_multi_ap=1 disable_steering=0
    local deep_clone=0 deep_clone_no_bssid=0 config_sta=0 map_enable=1

    local disable_24g_ap=0 disable_5g_ap=0

    # We let the OEM customize whether DFS channels should be permitted.
    if __repacd_is_block_dfs; then
        block_dfs=1
    else
        block_dfs=0
    fi

    # We let the daemon start wsplcd once it has a stable bSTA association.
    wsplcd_enabled=0
    wsplcd_stop=1

    config_load wireless

    # How the bSTA interface is managed is dependent on the selected and
    # preference values.
    local selected_radio='' preferred_radio=''
    map_bsta_max_preference=0
    config_foreach __repacd_resolve_bsta_radio wifi-device \
        selected_radio preferred_radio

    if [ -z "$selected_radio" ]; then
        selected_radio="$preferred_radio"
    fi

    __repacd_echo "Using $selected_radio for bSTA"
    config_foreach __repacd_update_map_bsta_radio wifi-iface \
                   $selected_radio $managed_network config_changed
    if [ "$map_version" -ge 2 -a "$map_ts_enabled" -eq 1 ]; then
        config_foreach __repacd_update_map_bsta_radio wifi-iface \
                       $selected_radio $map_backhaul_nw config_changed
    fi

    config_foreach __repacd_disable_vap wifi-iface \
        $managed_network 'ap' $disable_24g_ap $disable_5g_ap config_changed

    config_foreach __repacd_config_iface_map wifi-iface \
        $managed_network $block_dfs config_changed

    uci_commit wireless

    uci_set repacd repacd Role 'NonCAP'
    uci_set repacd FrontHaulMgr ManageFrontAndBackHaulsIndependently 1
    uci_commit repacd

    uci_set $MAP MultiAP EnableController 0
    uci_set $MAP MultiAP EnableAgent 1
    uci_commit $MAP

    if [ "$map_version" -ge 2 ]; then
        __repacd_configure_hyd_map $map_version $is_controller
    fi

    __repacd_configure_wsplcd 'ENROLLEE' $deep_clone $deep_clone_no_bssid \
                              $config_sta $map_version config_changed

    __repacd_configure_son $enable_wds $disable_steering $enable_multi_ap \
        'HYCLIENT' config_changed
}

__repacd_map_check_backhaul_vaps() {
    local config="$1"
    local iface network disabled device

    config_get iface "$config" ifname
    config_get disabled "$config" disabled '0'
    config_get mode "$config" mode
    config_get MapBSSType "$config" MapBSSType '0'
    config_get network "$config" network

    if [ -n "$iface" -a "$disabled" -eq 0 -a "$mode" = "ap" ]; then
        if [ $((MapBSSType & 0x40)) -eq 64 ]; then
            local bitRate=$(repacdcli $iface get_bitrate)
            if [ "$bitRate" -eq 0 -o -z "$bitRate" ]; then
                __repacd_echo " Iface $iface has invalid Bit Rate $bitRate"
                ifconfig $iface down
                sleep 2
                ifconfig $iface up
            fi
        fi
    fi
}

# Perform the startup actions when operating with Multi-AP SIG Topology
# Optimization.
#
# Pre-condition: repacd has already been determined to be enabled and in
#                MAP mode
#
# input: $1 - ether_gwcon: whether the device has been determined to be
#                          connected to the gateway via Ethernet
# input: $2 - start_role: the startup role for the device
# input: $3 - autoconf: boolean indicating whether this was a start
#                       initiated due to an auto config change
__start_map() {
    local ether_gwcon=$1
    local start_role=$2
    local autoconf=$3

    local enabled gwcon_mode first_config_required manage_mcsd
    local traffic_separation_enabled ethernet_monitoring_enabled
    local enable_steering standalone_controller

    config_changed=0
    map_dpp_enabled=0
    dpp_sta_found=0

    config_load 'repacd'
    config_get_bool enabled repacd 'Enable' '0'
    config_get gwcon_mode repacd GatewayConnectedMode 'AP'
    config_get_bool first_config_required MAPConfig 'FirstConfigRequired' '0'
    config_get_bool manage_mcsd repacd 'ManageMCSD' 1
    config_get_bool standalone_controller MAPConfig 'StandaloneController' '0'
    config_get map_country MAPConfig 'MapCountry'
    config_get map_single_r1r2_bh MAPConfig 'CombinedR1R2Backhaul'

    # Certain features are not supported with Multi-AP (at least not yet)
    config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
    config_get ethernet_monitoring_enabled repacd EnableEthernetMonitoring '0'
    config_get enable_steering repacd EnableSteering '1'

    # Config required for EasyMesh Rev2 Traffic Separation
    config_get map_version MAPConfig 'MapVersionEnabled' '1'
    config_get num_vlan_supported MAPConfig 'NumberOfVLANSupported' '0'
    config_get map_ts_enabled MAPConfig 'MapTrafficSeparationEnable' '0'
    config_get map_primary_nw MAPConfig 'VlanNetworkPrimary' ''
    config_get map_backhaul_nw MAPConfig 'VlanNetworkBackHaul' ''

    # Config Required for DPP
    config_get onboarding_type MAPConfig 'OnboardingType'
    config_get dump_security_logs MAPConfig 'DPPDumpSecurityLog' '0'

    if [ "$onboarding_type" == "dpp" ]; then
        map_dpp_enabled=1
    else
        map_dpp_enabled=0

        config_load $MAP
        uci_set $MAP MAPConfigSettings 'EnableConfigService' 0
        uci_set $MAP MultiAP 'Enable1905Security' 1
        uci_set $MAP MAPConfigSettings 'MapOnboardingType' 'none'
        uci_set $MAP MAPConfigSettings 'MapConfigDumpToFile' 0
        uci_set $MAP MAPConfigSettings 'DebugLevel' 0
        uci_commit $MAP
    fi

    if ! __repacd_is_son_mode; then
        __repacd_echo "Multi-AP SIG algorithms must use 'son' RE mode"
        return 1
    fi

    if [ "$traffic_separation_enabled" -gt 0 ]; then
        __repacd_echo "Traffic separation not supported with Multi-AP SIG" \
                      "Topology Optimization"
        return 1
    fi

    if [ "$ethernet_monitoring_enabled" -gt 0 ]; then
        __repacd_echo "Ethernet monitoring not supported with Multi-AP SIG" \
                      "Topology Optimization"
        return 1
    fi

    if [ "$enable_steering" -eq 0 ]; then
        __repacd_echo "Steering must be enabled with Multi-AP SIG" \
                      "Topology Optimization"
        return 1
    fi

    __repacd_echo "Starting Multi-AP SIG auto-configuration"
    __repacd_echo "Ethernet connection to GW=$ether_gwcon"
    __repacd_echo "GW Connected Mode=$gwcon_mode"
    __repacd_echo "MAP Version: $map_version"
    __repacd_echo "Num VLAN Supported: $num_vlan_supported"
    __repacd_echo "Combined R1 and R2 backhaul: $map_single_r1r2_bh"
    __repacd_echo "Onboarding Type : $onboarding_type"
    __repacd_echo "Dump Hostapd , supplicant and config service debug logs : $dump_security_logs"

    if [ "$onboarding_type" == "dpp" -a "$dump_security_logs" -eq 1 \
                            -a "$first_config_required" -gt 0 ]; then
        rm /tmp/hostapd.log
        rm /tmp/supplicant.log

        uci_set $MAP hy 'breakPadEnabled' '1'
        hostapdPID=$(ps | grep hostapd/global | grep -v grep | awk '{print$1}')
        suppPID=$(ps | grep wpa_supplicantglobal | grep -v grep | awk '{print$1}')
        kill $hostapdPID
        kill $suppPID
        wpa_supplicant -g /var/run/wpa_supplicantglobal -ddddK -f /tmp/supplicant.log &
        hostapd -g /var/run/hostapd/global -P /var/run/hostapd-global.pid \
                -ddddK -f /tmp/hostapd.log &
    fi

    # For now, we can only manage a single network.
    config_get managed_network repacd ManagedNetwork 'lan'
    __repacd_echo "Managed network: $managed_network"

    local is_controller=0
    if __repacd_gw_mode || [ "$gwcon_mode" = 'Controller' ]; then
        # WAN group not empty; this device will act as controller regardless of
        # the GatewayConnectedMode setting
        is_controller=1
    fi

    # Grab a lock to prevent any updates from being made by the daemon.
    whc_wifi_config_lock

    # Since the controller could tear down all AP interfaces, we need to
    # allow hyd to run with no interfaces.
    uci_set $MAPLBD config_Adv 'AllowZeroAPInterfaces' 1

    # Also disable IAS on both bands, as we do not yet have the messaging
    # support for it & set the Forwading mode by default to SINGLE for MAP.
    uci_set $MAPLBD IAS 'Enable_W2' 0
    uci_set $MAPLBD IAS 'Enable_W5' 0
    uci_set $MAP hy 'ForwardingMode' 'SINGLE'
    uci_commit $MAPLBD
    uci_commit $MAP

    uci_set $MAP MultiAP 'MapVersion' $map_version
    uci_commit $MAP
    # Disable the DBDC repeater feature on all devices, as there will only
    # ever be a single backhaul STA interface.
    config_load wireless
    config_foreach __repacd_config_dbdc_device wifi-device \
                   0 config_changed

    if [ "$map_version" -ge 2 ]; then
        # Stop instance of repacd that is already running
        __stop_repacd_run
        __repacd_map_reset_default_bridge_config $is_controller
    fi

    # Set country to global on all devices
    config_load wireless
    config_foreach __repacd_config_set_device_country wifi-device $map_country

    # Skip auto config for standalone controller, which must be manually configured
    if [ "$first_config_required" -gt 0 ] && [ "$standalone_controller" -eq 0 ]; then
        __repacd_reset_map_default_config $is_controller
        config_changed=1
        uci_set repacd MAPConfig 'FirstConfigRequired' 0

        __repacd_echo "Performed initial config on $managed_network VAPs"
    fi

    if __repacd_gw_mode || [ "$ether_gwcon" -gt 0 ]; then
        if !  __repacd_config_gwcon_map_ap $is_controller $standalone_controller; then
            return 1
        fi
    else
        # WAN group empty or non-existent
        # Switch to agent mode
        __repacd_config_map_re
    fi

    local enable_son=1
    __repacd_config_mcsd "$manage_mcsd" "$enable_son"

    whc_wifi_config_unlock

    __repacd_restart_dependencies

    if [ "$map_version" -ge 2 ]; then
        if [ "$map_ts_enabled" -gt 0 ]; then
            if [ "$is_controller" -gt 0 ]; then
                __repacd_map_apply_vlan_config
            fi

            # Set bridge MAC
            __repacd_map_set_bridge_mac
            ubus call network reload

            # Set egress/ingress priorty maps for Controller
            if [ "$is_controller" -gt 0 -a "$map_version" -ge 3 ]; then
                sleep 2
                __repacd_map_set_egress_ingress_ports
            fi

            if [ "$is_controller" -gt 0 ]; then
                config_load wireless
                config_foreach __repacd_map_check_backhaul_vaps wifi-iface
            fi
        fi

        if [ "$map_version" -ge 3 -a "$map_dpp_enabled" -eq 1 ]; then
            # Delete temp files
            rm /tmp/map_key_info.tmp
            rm /tmp/mapConfig.log

            # Get Configurator key if already present
            dpp_config_key=$(cat /etc/map_dpp_key)
            dpp_key_len=${#dpp_config_key}

            if [ "$is_controller" -eq 1 ]; then
                __repacd_set_map_dpp_config $is_controller $start_role
            fi

            if [ "$is_controller" -eq 0 ]; then
                config_load wireless
                config_foreach __repacd_get_map_sta_iface wifi-iface

                __repacd_set_map_dpp_config $is_controller $start_role
            fi
        fi

        # stop/start hyd only if there is any change in network config
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

    if ! __repacd_gw_mode; then
        __stop_repacd_run

        # Transform the boolean value into what the daemon expects
        if [ "$autoconf" -gt 0 ]; then
            autoconf='autoconf'
        else
            autoconf=''
        fi

        # Start the script that monitors the link state.
        #
        # In this NonCAP mode, it will keep checking whether there is a link
        # to the gateway over ethernet.
        __repacd_echo "Starting  RE Placement and Auto-config Daemon"
        start-stop-daemon -S -x /usr/sbin/repacd-run.sh -b -- \
            "map" "$start_role" $config_re_mode $resolved_re_mode \
            $resolved_re_submode $autoconf
    fi
}

# Get STA iface
__repacd_get_map_sta_iface() {
    local config="$1"
    local iface disabled mode my_bootstrap sta_iface

    config_load repacd
    config_get iface "$config" ifname
    config_get disabled "$config" disabled '0'
    config_get mode "$config" mode

    if [ -n "$iface" -a "$disabled" -eq 0 -a "$mode" = "sta" ]; then
        dpp_sta_iface=$iface
        dpp_sta_found=1

        if [ -z "$dpp_sta_iface" ]; then
            __repacd_echo "STA iface invalid"
        fi

        __repacd_echo "STA iface $dpp_sta_iface"
    fi
}

# Set dpp_key on iface
__repacd_set_dpp_key_iface() {
    local config="$1"
    local key="$2"
    local iface disabled mode

    config_get iface "$config" ifname
    config_get disabled "$config" disabled '0'
    config_get mode "$config" mode

    if [ -n "$iface" -a "$disabled" -eq 0 -a "$mode" = "ap" ]; then
        uci_set wireless "$config" dpp_key "$key"
        uci_commit wireless
    fi

    if [ -n "$iface" -a "$disabled" -eq 0 -a "$mode" = "sta" ]; then
        uci_set wireless "$config" dpp_key "$key"
        uci_commit wireless
    fi
}

# Setup dpp on controller and agent
# input: $1 - is_controller: whether this device is acting as the controller
# input: $2 - start_role: start role for device
__repacd_set_map_dpp_config() {
    local is_controller=$1
    local start_role=$2
    local dump_security_logs enable_cs_logs

    config_load repacd
    config_get enable_cs_logs MAPConfig 'EnableConfigServiceLogs' '0'
    config_get dump_security_logs MAPConfig 'DPPDumpSecurityLog' '0'

    __repacd_echo "DPP Key : $dpp_config_key"
    __repacd_echo "DPP Key Len: $dpp_key_len"

    uci_set $MAP MAPConfigSettings 'EnableConfigService' 1
    if [ "$start_role" == "NonCAP" -o "$start_role" == "RE" ]; then
        uci_set $MAP MAPConfigSettings 'EnableConfigService' 0
    fi
    uci_set $MAP MultiAP 'Enable1905Security' 1
    uci_set $MAP MAPConfigSettings 'MapEProfile' 'generic'
    uci_set $MAP MAPConfigSettings 'MapOnboardingType' 'dpp'
    uci_set $MAP MAPConfigSettings 'MapConfigDumpToFile' $enable_cs_logs
    uci_set $MAP MAPConfigSettings 'DebugLevel' 0

    if [ "$enable_cs_logs" -eq 1 -a "$dump_security_logs" -eq 0 ]; then
        uci_set $MAP MAPConfigSettings 'DebugLevel' 1
    fi
    if [ "$enable_cs_logs" -eq 1 -a "$dump_security_logs" -eq 1 ]; then
        uci_set $MAP MAPConfigSettings 'DebugLevel' 2
    fi

    # Start controller socket on hostapd
    hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_controller_start tcp_port=7999

    # Controller Config
    if [ "$is_controller" -eq 1 ]; then
        if [ "$dpp_key_len" -eq 0 ]; then
            # Get Key
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_remove '*'
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_add curve=P-256
            dpp_config_key=$(hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 \
                                         dpp_configurator_get_key 1)
            echo $dpp_config_key > /etc/map_dpp_key
        fi

        # Get CSIGN JWK
        hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_map_get_jwk_csign curve=P-256 \
                    key=$dpp_config_key

        uci_set $MAP MAPConfigSettings 'RoleController' 1
        uci_set $MAP MAPConfigSettings 'RoleAgent' 0
        uci_set $MAP MAPConfigSettings 'DPPConfiguratorKey' $dpp_config_key
        uci_commit $MAP
    fi

    # Agent Config
    if [ "$is_controller" -eq 0 ]; then
        __repacd_echo "Configure DPP Agent"
        if [ "$dpp_sta_found" -eq 0 ]; then
            __repacd_echo "Configure Ethernet Agent"

            if [ "$dpp_key_len" -eq 0 ]; then
                # Get Key
                hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_remove '*'
                hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_add curve=P-256
                dpp_config_key=$(hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 \
                                             dpp_configurator_get_key 1)
                echo $dpp_config_key > /etc/map_dpp_key
            fi

            # Bootstrap Gen
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_bootstrap_gen type=qrcode \
                        key=$dpp_config_key
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_bootstrap_info 1
            my_bootstrap=$(hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_bootstrap_get_uri 1)
        else
            __repacd_echo "Configure bSTA $dpp_sta_iface"
            # Get Key
            if [ "$dpp_key_len" -eq 0 ]; then
                wpa_cli -p /var/run/wpa_supplicant-$dpp_sta_iface dpp_configurator_remove '*'
                wpa_cli -p /var/run/wpa_supplicant-$dpp_sta_iface dpp_configurator_add curve=P-256
                dpp_config_key=$(wpa_cli -p /var/run/wpa_supplicant-$dpp_sta_iface \
                                         dpp_configurator_get_key 1 | grep 30770)
                echo $dpp_config_key > /etc/map_dpp_key

                __repacd_echo "DPP Key : $dpp_config_key"

                config_load wireless
                config_foreach __repacd_set_dpp_key_iface wifi-iface $dpp_config_key

                __repacd_echo "DPP Key Len 0. First time generating Key. Restart nw"
                wifi load
            fi

            # Generate BootStrap
            wpa_cli -p /var/run/wpa_supplicant-$dpp_sta_iface dpp_bootstrap_remove '*'
            wpa_cli -p /var/run/wpa_supplicant-$dpp_sta_iface dpp_bootstrap_gen type=qrcode \
                    key=$dpp_config_key
            wpa_cli -p /var/run/wpa_supplicant-$dpp_sta_iface dpp_bootstrap_info 1

            my_bootstrap=$(wpa_cli -p /var/run/wpa_supplicant-$dpp_sta_iface dpp_bootstrap_get_uri 1 \
                               | grep DPP)
        fi

        config_load wireless
        config_foreach __repacd_set_dpp_key_iface wifi-iface $dpp_config_key

        rm /tmp/map_bootstrap_info.tmp
        echo $my_bootstrap > /tmp/map_bootstrap_info.tmp
        uci_set $MAP MAPConfigSettings 'DPPConfiguratorKey' $dpp_config_key
        uci_set $MAP MAPConfigSettings 'RoleController' 0
        uci_set $MAP MAPConfigSettings 'RoleAgent' 1
        uci_commit $MAP
    fi
}

__repacd_config_set_default_maplite_vap_param() {
    local vapIdx=$1
    uci set wireless.@wifi-iface[$vapIdx].encryption='psk2+ccmp'
    uci set wireless.@wifi-iface[$vapIdx].key=maplite-123
    uci set wireless.@wifi-iface[$vapIdx].wps_pbc=1
    uci set wireless.@wifi-iface[$vapIdx].wps_pbc_enable=1
    uci set wireless.@wifi-iface[$vapIdx].wps_pbs_start_time=0
    uci set wireless.@wifi-iface[$vapIdx].wps_pbs_duration=120
    uci set wireless.@wifi-iface[$vapIdx].dpp_configurator_connectivity=1
    uci set wireless.@wifi-iface[$vapIdx].dpp_map=1
    uci set wireless.@wifi-iface[$vapIdx].map=$map_version
    uci commit wireless
}

# Delete all of the VAPs for the given network that are marked as unmanaged.
#
# input: $1 config: section being considered
# input: $2 mode: ap or sta
__repacd_delete_managed_maplite_vaps() {
    local config="$1"
    local network repacd_security_unmanaged mode

    config_get network "$config" network
    config_get mode "$config" mode
    config_get device "$config" device

    if [ $mode = "ap_smart_monitor" -o $mode = "$2" ]; then
        uci delete "wireless.$config"
    fi

    if [ "$3" = "$network" -a "$4" != "$device" ]; then
        uci delete "wireless.$config"
    fi
}

# Perform the startup actions when operating MAP Lite Mode
# (Plug Fest Mode).
__start_map_lite() {
    kill $repacdPID
    local unicast_flood_disable
    local hostapdPID suppPID
    local bh_type sta_device
    local onboarding_type
    local ezmeshFlag

    wifimeshconfig map

    __repacd_echo "Starting Multi-AP Lite Mode"
    config_get dev_reset_default MAPConfig 'MapDevResetDefault' '0'
    config_get deviceMode MAPConfig 'MapDeviceMode'
    config_get num_vlan_supported MAPConfig 'NumberOfVLANSupported' '0'
    config_get map_version MAPConfig 'MapVersionEnabled'
    config_get num_vlan_supported MAPConfig 'NumberOfVLANSupported' '0'
    config_get map_primary_nw MAPConfig 'VlanNetworkPrimary' ''
    config_get map_backhaul_nw MAPConfig 'VlanNetworkBackHaul' ''
    config_get map_single_r1r2_bh MAPConfig 'CombinedR1R2Backhaul'
    config_get map_country MAPConfig 'MapCountry'
    config_get bh_type MAPConfig 'MapBackaulType'
    config_get sta_device MAPConfig 'MapSTARadio'
    config_get my_key MAPConfig 'DPPKey'
    config_get my_bootstrap MAPConfig 'DPPMyBootstrap'
    config_get onboarding_type MAPConfig 'OnboardingType'
    config_get_bool ezmeshFlag repacd 'Ezmesh' '0'

    map_dpp_enabled=0
    map_ts_enabled=1
    unicast_flood_disable=1

    __repacd_echo "dev_reset_default: $dev_reset_default"
    __repacd_echo "MAP device Mode: $deviceMode"
    __repacd_echo "MAP Version: $map_version"
    __repacd_echo "Num VLAN Supported: $num_vlan_supported"
    __repacd_echo "DPP Enabled: $map_dpp_enabled"
    __repacd_echo "Backhaul Type: $bh_type"
    __repacd_echo "sta_device: $sta_device"
    __repacd_echo "My Bootstrap : $my_bootstrap"
    __repacd_echo "Onboarding Type : $onboarding_type"
    __repacd_echo "Ezmesh enabled : $ezmeshFlag"

    if [ "$onboarding_type" == "dpp" ]; then
        map_dpp_enabled=1
    fi

    if [ "$ezmeshFlag" -eq 1 ]; then
        /etc/init.d/hyd stop
        /etc/init.d/hyd disable
    fi

    # Set country to global on all devices
    config_load wireless
    config_foreach __repacd_config_set_device_country wifi-device $map_country

    if [ "$dev_reset_default" -eq 1 ]; then
        __repacd_map_reset_default_bridge_config

        if [ "$map_version" -ge 3 ]; then
            kill $repacdPID

            rm /tmp/hostapd.log
            rm /tmp/supplicant.log
            rm /tmp/map_bootstrap_info.tmp
            rm /tmp/map_peer_bootstrap_info.tmp
            rm /tmp/map_key_info.tmp
            rm /tmp/map_bh_info.tmp
            rm /tmp/map_fh_info.tmp
            rm /tmp/ptk.txt
            rm /tmp/pmk.txt
            rm /tmp/map_dpp_bsta_agent_info.tmp
            rm /tmp/hyd.log
            rm /tmp/mapConfig.log
            rm /tmp/map_sta_info.log
            rm /etc/map_peer_bootstrap_info.tmp
            hostapdPID=$(ps | grep hostapd/global | grep -v grep | awk '{print$1}')
            suppPID=$(ps | grep wpa_supplicantglobal | grep -v grep | awk '{print$1}')
            kill $hostapdPID
            kill $suppPID
            wpa_supplicant -g /var/run/wpa_supplicantglobal -ddddK -f /tmp/supplicant.log &
            hostapd -g /var/run/hostapd/global -P /var/run/hostapd-global.pid \
                    -ddddK -f /tmp/hostapd.log &

           # Enable Radio
           config_load wireless
           config_foreach __repacd_config_set_radio_enable wifi-device
           __repacd_echo "Num radio $map_num_radio"

           for i in 0 1 2 3 4 5; do
               if [ "$i" -lt "$map_num_radio" ]; then
                   __repacd_config_set_default_maplite_vap_param $i
               fi
           done

           # Reset Configs
           uci_set $MAP MAPConfigSettings 'EnableConfigService' 0
           uci_set $MAP MAPConfigSettings 'RoleController' 0
           uci_set $MAP MAPConfigSettings 'RoleAgent' 0
           uci_set $MAP MAPConfigSettings 'MapOnboardingType' 'legacy'
        fi

        config_load wsplcd
        config_load $MAP
        config_load mcsd

        # Common config to CAP and Agent
        uci_set $MAP MultiAP 'EnableSigmaDUT' 1
        uci_set $MAP MultiAP 'MapPFCompliant' 1
        uci_set $MAP MultiAP 'MapVersion' $map_version
        # Set Forwarding Mode to SINGLE to disable HA, HD
        uci_set $MAP hy 'ForwardingMode' 'SINGLE'

        uci_set wsplcd config 'ConfigSta' 0
        uci_set wsplcd config 'DeepClone' 0
        uci_set wsplcd config 'DebugLevel' "DUMP"
        uci_set wsplcd config 'WriteDebugLogToFile' "TRUNCATE"
        uci_set wsplcd config 'MapMaxBss' 4
        uci_set wsplcd config 'ManageVAPInd' 0
        uci_set wsplcd config 'MapPFCompliant' 1
        uci_set wsplcd config 'MapEnable' $map_version

        uci_set mcsd config 'Enable' 0

        if [ "$map_version" -ge 2 ]; then
            config_load 'repacd'
            uci_set repacd MAPConfig 'EnableMapTSLogs' '1'
            uci_set repacd MAPConfig 'MapTrafficSeparationEnable' '1'
            uci_set repacd repacd 'EnableMixedBackhaul' '1'
            uci_set repacd MAPConfig 'TSUseSameBridgeMAC' '0'

            uci_set $MAP MultiAP 'NumberOfVLANSupported' $num_vlan_supported
            uci_set $MAP MultiAP 'Map2TrafficSepEnabled' 1
            uci_set $MAP MultiAP 'CombinedR1R2Backhaul' $map_single_r1r2_bh
            uci_set $MAP MultiAP 'VlanNetworkPrimary' $map_primary_nw
            uci_set wsplcd config 'NumberOfVLANSupported' $num_vlan_supported
            uci_set wsplcd config 'Map2TrafficSepEnabled' 1
            uci_set wsplcd config 'CombinedR1R2Backhaul' $map_single_r1r2_bh
        fi

        if [ "$map_version" -ge 3 ]; then
            uci_set $MAP MAPSPSettings 'EnableSP' '1'
            uci_set $MAP MAPSPSettings 'EnableEnhancedSP' '1'
            uci_set $MAP MAPSPSettings 'MaxSPRules' '10'
            uci_set $MAP hy 'breakPadEnabled' '1'

            #ecm is disabled for now for lite mode of operation
            /etc/init.d/qca-nss-ecm stop
            sysctl -w net.bridge.bridge-nf-call-iptables=1
            ssdk_sh fdb learnctrl set disable
            ssdk_sh fdb entry flush 1
            sleep 1

            #Service prioritzation enabled
            echo 1 > /proc/sys/net/emesh-sp/enable
        fi

        if  [ "$deviceMode" = "CAP" ]; then
            # Set HYD Parameters
            uci_set $MAP config 'Mode' "HYROUTER"
            uci_set $MAP MultiAP 'EnableController' 1
            # Set WSPLCD Parameters
            uci_set wsplcd config 'RunMode' "REGISTRAR"
        else
            # Set HYD Parameters
            uci_set $MAP config 'Mode' "HYCLIENT"
            uci_set $MAP MultiAP 'EnableAgent' 1
            # Set WSPLCD Parameters
            uci_set wsplcd config 'RunMode' "ENROLLEE"
            uci_set wsplcd config 'Map2EnableMboOcePmf' '1'
            # keeping channel scan interval to R2 only as we do not need
            # it in R3
            if [ "$map_version" -eq 2 ]; then
                uci_set $MAP MultiAP 'ChanScanIntervalMin' 1
                uci_set $MAP MultiAP 'EnableBootOnlyScan' 0
            fi
        fi

        uci_commit $MAP
        uci_commit wsplcd
        uci_commit mcsd

        /etc/init.d/mcsd stop
        /etc/init.d/mcsd disable

        __repacd_map_set_bridge_mac
        /etc/init.d/hyfi-bridging start

        whc_network_restart
        sleep 2

        if  [ "$map_version" -ge 3 -a "$deviceMode" != "CAP" ]; then
            return
        fi
    fi

    if [ "$map_version" -ge 2 -a "$map_dpp_enabled" -eq 0 -a "$dev_reset_default" -eq 0 ]; then
        uci set wireless.qcawifi=qcawifi
        uci set wireless.qcawifi.dp_tx_allow_per_pkt_vdev_id_check=1
        uci commit
        wifi unload
        wifi load
    fi

    if [ "$map_version" -ge 3 -a "$map_dpp_enabled" -eq 1 ]; then
        uci_set $MAP MultiAP 'Enable1905Security' 1
        uci_set $MAP MAPConfigSettings 'EnableConfigService' 1
        uci_set $MAP MAPConfigSettings 'MapConfigDumpToFile' 1
        uci_set $MAP MAPConfigSettings 'DebugLevel' 1
        uci_set $MAP MAPConfigSettings 'MapEProfile' 'ALSpecific'
        uci_set $MAP MAPConfigSettings 'MapOnboardingType' 'dpp'
        uci_commit $MAP

        # Disable wsplcd for DPP
        /etc/init.d/wsplcd stop
        /etc/init.d/wsplcd disable

        # DPP Setting for CAP . dev reset = 2 means Setting Peer Bootstrap
        if  [ "$dev_reset_default" -eq 2 -a "$deviceMode" = "CAP" ]; then
            # Get Key
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_remove 1
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_add curve=P-256
            key=$(hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_get_key 1)

            # Get CSIGN JWK
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_map_get_jwk_csign curve=P-256 key=$key

            # Start controller socket on hostapd
            hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_controller_start tcp_port=7999

            uci_set $MAP MAPConfigSettings 'RoleController' 1
            uci_set $MAP MAPConfigSettings 'RoleAgent' 0
            uci_set $MAP MAPConfigSettings 'DPPConfiguratorKey' $key
            uci_set $MAP MAPConfigSettings 'DPPMyBootstrap' $my_bootstrap
            uci_commit $MAP
            /etc/init.d/$MAP restart
        fi

        # DPP setting for RE
        if [ "$dev_reset_default" -eq 0 -a "$deviceMode" != "CAP" ]; then
            if [ "$bh_type" = "wifi" ]; then
                config_load wireless
                config_foreach __repacd_delete_managed_maplite_vaps wifi-iface sta

                uci add wireless wifi-iface
                uci set wireless.@wifi-iface[3].device=$sta_device
                uci set wireless.@wifi-iface[3].network=lan
                uci set wireless.@wifi-iface[3].mode=sta
                uci set wireless.@wifi-iface[3].ssid=maplite
                uci set wireless.@wifi-iface[3].encryption='none'
                uci set wireless.@wifi-iface[3].dpp=1
                uci set wireless.@wifi-iface[3].wds=1
                uci set wireless.@wifi-iface[3].map=3
                uci set wireless.@wifi-iface[3].MapBSSType=128
                uci set wireless.@wifi-iface[3].dpp_key=$my_key
                uci set wireless.@wifi-iface[3].dpp_map=1
                uci commit wireless
                wifi load
            fi

            if [ "$bh_type" = "eth" ]; then
                /etc/init.d/hyfi-bridging start
                /etc/init.d/hyfi-bridging restart
                /etc/init.d/$MAP restart

                # Get Key
                hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_remove 1
                hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_add curve=P-256
                my_key=$(hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_configurator_get_key 1)

                # Start controller socket on hostapd
                hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_controller_start tcp_port=7999
                hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_bootstrap_gen type=qrcode \
                            key=$my_key
                hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_bootstrap_info 1
                my_bootstrap=$(hostapd_cli -i ath0 -p /var/run/hostapd-wifi0 dpp_bootstrap_get_uri 1)
            fi

            rm /tmp/map_bootstrap_info.tmp
            echo $my_bootstrap > /tmp/map_bootstrap_info.tmp
            uci_set $MAP MAPConfigSettings 'RoleController' 0
            uci_set $MAP MAPConfigSettings 'RoleAgent' 1
            uci_set $MAP MAPConfigSettings 'DPPConfiguratorKey' $my_key
            uci_set $MAP MAPConfigSettings 'DPPMyBootstrap' $my_bootstrap
            uci_commit $MAP
            /etc/init.d/$MAP restart
        fi
    fi

    if  [ "$deviceMode" != "CAP" ]; then
        kill $repacdPID

        # Start the script that monitors the link state.
        #
        # When in NonCAP mode, it will keep checking whether there is a link
        # to the gateway over ethernet. When in CAP mode, it will keep
        # checking the WAN/LAN ifaces.
        __repacd_echo "Starting MAP Lite RE Daemon"
        start-stop-daemon -S -x /usr/sbin/repacd-run.sh -b -- \
                          "maplite" "init" "maplite" "maplite" "maplite"

    fi
}

# Reset the count of the number of times the 5 GHz bSTA was attempted.
# This should only be invoked on boot and when switching between roles
# (eg. to CAP).
__repacd_map_reset_5g_attempts() {
    uci_set repacd 'MAPWiFiLink' '5gAttemptsCount' 0
    uci_commit repacd
}

# Force a restart into CAP mode using the Multi-AP SIG Topoology Optimization
# algorithm.
#
# @see restart_in_cap_mode
__restart_in_cap_mode_map() {
    __stop_repacd_run

    # Reset the counter here in case we switch back into NonCAP (aka. RE)
    # mode. It is easier to do it here than on the NonCAP restart since
    # the latter is also used to force a bSTA change.
    __repacd_map_reset_5g_attempts

    local ether_gwcon=1 start_role='CAP' autoconf=1
    __start_map $ether_gwcon $start_role $autoconf
}

# Force a restart in NonCAP mode using the Multi-AP SIG Topology Optimization
# algorithm.
#
# @see restart_in_noncap_mode
__restart_in_noncap_mode_map() {
    __stop_repacd_run

    local ether_gwcon=0 start_role='NonCAP' autoconf=1
    __start_map $ether_gwcon $start_role $autoconf
}

# Force a restart into Range Extender (RE) mode with the Multi-AP SIG Topology
# Optimization algorithm.
#
# @see restart_in_re_mode
__restart_in_re_mode_map() {
    __stop_repacd_run

    local ether_gwcon=0 start_role='RE' autoconf=1
    __start_map $ether_gwcon $start_role $autoconf
}
