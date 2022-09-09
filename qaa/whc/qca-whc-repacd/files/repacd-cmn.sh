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


REPACD_DEBUG_OUTOUT=0

WSPLCD_MAP_DIR='/etc/wsplcd/map'
WSPLCD_MAP_BSS_POLICY_PATH="${WSPLCD_MAP_DIR}/bss-policy.conf"
WSPLCD_MAP_TEMPLATE_DIR="${WSPLCD_MAP_DIR}/templates"

managed_network='' config_changed=0
config_re_mode='' resolved_re_mode='' resolved_re_submode=''
wsplcd_enabled=0 wsplcd_start=0 wsplcd_stop=0 wsplcd_restart=0
hyd_start=0 hyd_stop=0

network_guest=
traffic_separation_enabled=''
daisy_chain=0
bssid_resolve_state="resolving"
net_config_changed=0

map_version=0 map_ts_enabled=0 num_vlan_supported=0
map_single_r1r2_bh=0

WSPLCD_INIT='/etc/init.d/wsplcd'
HYFI_BRIDGING_INIT='/etc/init.d/hyfi-bridging'

config_load 'repacd'
config_get_bool ezmesh repacd 'Ezmesh' '0'
    if [ "$ezmesh" -eq 1 ]; then
        HYD_INIT='/etc/init.d/ezmesh'
        MAP='ezmesh'
        MAPLBD='ezlbd'
    else
        HYD_INIT='/etc/init.d/hyd'
        MAP='hyd'
        MAPLBD='lbd'
    fi

LBD_INIT='/etc/init.d/lbd'
MCSD_INIT='/etc/init.d/mcsd'

. /lib/functions/whc-debug.sh
. /lib/functions/whc-iface.sh
. /lib/functions/whc-network.sh
. /lib/functions/repacd-netdet.sh

# Write the provided log message to the correct output stream.
# If REPACD_DEBUG_OUTOUT is non-zero, it will be written to the console.
# Otherwise, it will be written to stdout.
__repacd_echo() {
    if [ "$REPACD_DEBUG_OUTOUT" -gt 0 ]; then
        echo "whc (repacd): $*" > /dev/console
    else
        echo "whc (repacd): $*"
    fi
}

# Determine if the device is configured in gateway mode or not.
# Note that a device can still act as a CAP even if it is not in gateway
# mode, but this is detected later by the repacd-run.sh script.
# For WAN enabled gateway AP, check if wan interface name is configured
# For SDX-55 modem enabled gateway AP, check if wan protocol is set to 'rmnet'
# return: 0 if in gateway mode; otherwise non-zero
__repacd_gw_mode() {
    local wan_iface

    config_load network
    config_get wan_iface wan ifname
    config_get wan_proto wan proto 'dhcp'

    if [ -n "$wan_iface" ] || [ $wan_proto = "rmnet" ]; then
        return 0
    fi

    return 1
}

# Create firewall rules for the given network if the rule does not exist.
# input: $1 network name
__repacd_set_firewall_rules() {
    local network=$1
    local no_rule
    local rule_name

    no_rule=$(uci show firewall | grep zone | grep "$network")

    if [ -z "$no_rule" ]; then
        local zone
        zone=$(uci add firewall zone)
        if [ -n "$zone" ]; then
            uci_set firewall "$zone" name "$network"
            uci add_list "firewall.$zone.network=$network"
            uci_set firewall "$zone" input 'REJECT'
            uci_set firewall "$zone" output 'ACCEPT'
            uci_set firewall "$zone" forward 'REJECT'

            local fwd
            fwd=$(uci add firewall forwarding)
            if [ -n "$fwd" ]; then
                uci_set firewall "$fwd" src "$network"
                uci_set firewall "$fwd" dest 'wan'
            fi

            local rule
            rule=$(uci add firewall rule)
            if [ -n "$rule" ]; then
                uci_set firewall "$rule" name 'Allow-DHCP-request'
                uci_set firewall "$rule" src "$network"
                uci_set firewall "$rule" src_port '67-68'
                uci_set firewall "$rule" dest_port '67-68'
                uci_set firewall "$rule" proto 'udp'
                uci_set firewall "$rule" target 'ACCEPT'
            fi

            rule=$(uci add firewall rule)
            if [ -n "$rule" ]; then
                uci_set firewall "$rule" name 'Allow-DNS-queries'
                uci_set firewall "$rule" src "$network"
                uci_set firewall "$rule" dest_port '53'
                uci_set firewall "$rule" proto 'tcpudp'
                uci_set firewall "$rule" target 'ACCEPT'
            fi

            rule=$(uci add firewall rule)
            if [ -n "$rule" ]; then
                rule_name="Block-$managed_network-$network-forwarding"
                uci_set firewall "$rule" name "$rule_name"
                uci_set firewall "$rule" src $managed_network
                uci_set firewall "$rule" dest "$network"
                uci_set firewall "$rule" proto '0'
                uci_set firewall "$rule" family 'any'
                uci_set firewall "$rule" target 'REJECT'
            fi

            rule=$(uci add firewall rule)
            if [ -n "$rule" ]; then
                rule_name="Block-$network-$managed_network-forwarding"
                uci_set firewall "$rule" name "$rule_name"
                uci_set firewall "$rule" src "$network"
                uci_set firewall "$rule" dest $managed_network
                uci_set firewall "$rule" proto '0'
                uci_set firewall "$rule" family 'any'
                uci_set firewall "$rule" target 'REJECT'
            fi
        fi
    fi
    uci_commit firewall
}

# Determine the configured RE mode, not applying any automatic mode
# switching rules.
#
# output: $1 variable in which to place the resolved mode
__repacd_get_config_re_mode() {
    local resolved_mode=$1
    local mode

    config_load 'repacd'
    config_get mode repacd 'ConfigREMode' 'auto'

    eval "$resolved_mode=$mode"
}

# Determine whether the provided mode is an automatic mode.
#
# input: $1 mode: the mode to check
# return: 0 if the mode is an auto mode; otherwise 1
__repacd_is_auto_re_mode() {
    local mode=$1

    if [ "$mode" = 'auto' ]; then
        return 0
    fi

    return 1
}

# Resolve the current mode in which to operate the range extender.
#
# This mode is either the configured mode (if it is set to a specific
# mode), the automatically derived RE mode based on association information,
# or the default range extender mode for use at startup.
#
# output: $1 - the variable into which to place the resolved mode
__repacd_get_re_mode() {
    local resolved_mode=$1
    local mode default_mode

    __repacd_get_config_re_mode config_re_mode

    if __repacd_is_auto_re_mode $config_re_mode; then
        config_get default_mode repacd 'DefaultREMode' 'qwrap'
        config_get mode repacd 'AssocDerivedREMode' "$default_mode"
    else
        mode=$config_re_mode
    fi

    # Get the Association derived sub-mode. If not derived, say "star".
    config_get resolved_re_submode repacd 'AssocDerivedRESubMode' 'star'

    eval "$resolved_mode=$mode"
}

# Determine if the range extension mode is set to WDS.
#
# return: 0 if the mode is set to WDS; otherwise 1 (meaing QWrap or ExtAP)
__repacd_is_wds_mode() {
    __repacd_get_re_mode resolved_re_mode

    case "$resolved_re_mode" in
        wds|WDS)
            return 0
        ;;

        *)
            return 1
        ;;
    esac
}

# Determine if the range extension mode is set to QWrap.
#
# return: 0 if the mode is set to QWrap; otherwise 1 (meaning WDS or ExtAP)
__repacd_is_qwrap_mode() {
    __repacd_get_re_mode resolved_re_mode
    case "$resolved_re_mode" in
        qwrap|QWRAP)
            return 0
        ;;

        *)
            return 1
    esac
}

# Determine if the range extension mode is set to SON.
# Note that if the hyd init script is missing, this will be considered as
# SON mode disabled.
#
# return: 0 if the mode is set to SON; otherwise 1 (meaing WDS or an
#         interoperable range extension mode)
__repacd_is_son_mode() {
    if [ ! -f $HYD_INIT ]; then
        return 1
    fi

    __repacd_get_re_mode resolved_re_mode
    case "$resolved_re_mode" in
        son|SON)
            return 0
        ;;

        *)
            return 1
        ;;
    esac
}

# Determine if DFS channels are to be blocked even for WDS mode.
#
# return: 0 if DFS channels should not be used; otherwise 1 (meaning they may
#         be used)
__repacd_is_block_dfs() {
    local block_dfs

    config_load 'repacd'
    config_get block_dfs repacd 'BlockDFSChannels' '0'

    if [ "$block_dfs" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Generate a suffix for the SSID using the last 3 bytes of the MAC address
# on the bridge that is being managed.
#
# output: $1 - variable into which to write the SSID suffix
__repacd_generate_ssid_suffix() {
    local generated_suffix
    generated_suffix=$(ifconfig br-$managed_network | grep HWaddr | awk '{print $5}' | awk -F":" '{print $4$5$6}')
    eval "$1=$generated_suffix"
}

# Generate a random pre-shared key for use with WPA2
#
# output: $1 - variable into which to write the PSK
__repacd_generate_psk() {
    local generated_key
    generated_key=$(dd if=/dev/urandom bs=1 count=8 2> /dev/null | base64)
    eval "$1=$generated_key"
}

# Determine if the mode on the interface is a match.
# This does fuzzy matching in that multiple actual modes are said to match
# a given general mode.
#
# input: $1 general_mode: one of 'sta' or 'ap'
# input: $2 cur_mode: the currently configured mode
# return: 0 on a match; otherwise non-zero
__repacd_is_matching_mode() {
    local general_mode=$1
    local cur_mode=$2

    if [ "$general_mode" = 'sta' ]; then
        if [ "$cur_mode" = 'sta' ]; then
            return 0
        else
            return 1
        fi
    else
        if [ "$cur_mode" = 'ap' ] || [ "$cur_mode" = 'wrap' ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Enumerate all of the devices and append them to the variable provided.
# input: $1 devices: variable to populate with the devices
__repacd_get_devices() {
    local devices=$1

    config_cb() {
        local type="$1"
        local section="$2"

        case "$type" in
            wifi-device)
        config_get hwmode "$section" hwmode
        config_get type "$section" type
        if [ "$type" != 'mac80211' ] && [ "$hwmode" != '11ad' ];then
            eval append $devices "$section"
        fi
                ;;
        esac
    }
    config_load wireless
}

# Set the parameter in the wireless configuration section provided, recording
# if it actually needed to be changed.
# input: $1 iface_name: section name
# input: $2 param_name: the name of the parameter being set
# input: $3 param_val: the new value for the parameter
__repacd_update_vap_param() {
    local iface_name=$1 param_name=$2 param_val=$3
    local cur_val

    config_get cur_val "$iface_name" "$param_name"
    if [ -z "$cur_val" ] || [ ! "$cur_val" = "$param_val" ]; then
        uci_set wireless "$iface_name" "$param_name" "$param_val"
        config_changed=1
    fi
}

# Determine the SSID to apply to a specific VAP based on the current
# configuration of the WPS Push Button Configuration enhancement.
# input: $1 name: section name
# input: $2 device: name of the radio
# input: $3 base_ssid: the SSID from which to derive other ones
# input: $4 vap_count: additional vap count created in Device
__repacd_init_vap_set_ssid_and_pbc() {
    local name=$1 device=$2 base_ssid=$3 vap_count=$4
    local mode
    local enable_wps_re_enhc global_suffix='' radio_suffix=''
    local start_time duration
    local auto_create_vaps

    # Grab the overall enable first
    config_get enable_wps_re_enhc qcawifi wps_pbc_extender_enhance '0'

    # Now VAP specific parameters
    config_get mode "$name" mode
    config_get start_time "$name" wps_pbc_start_time
    config_get duration "$name" wps_pbc_duration
    config_get_bool repacd_security_unmanaged  "$name" repacd_security_unmanaged '0'
    config_get_bool auto_create_vaps "$device" repacd_auto_create_vaps '1'

    if [ "$enable_wps_re_enhc" -gt 0 ]; then
        # Only apply the SSID derivation rules on AP interfaces.
        if __repacd_is_matching_mode 'ap' $mode; then
            # Potentially two suffixes can be applied
            # First is set at the overall AP level.
            config_get global_suffix qcawifi wps_pbc_overwrite_ssid_suffix ''

            # Second is set at the radio level
            config_get radio_suffix "$device" wps_pbc_overwrite_ssid_band_suffix ''
        fi
    fi

    if [ "$repacd_security_unmanaged" -eq 0 ] ; then
        __repacd_update_vap_param "$name" 'ssid' "$base_ssid$global_suffix$radio_suffix"
    fi

    #Disabling WPS for all additional FH VAPs
    if [ "$vap_count" -eq 0 ]; then
        __repacd_update_vap_param "$name" 'wps_pbc' 1
        __repacd_update_vap_param "$name" 'wps_pbc_enable' "$enable_wps_re_enhc"
        if [ "$traffic_separation_enabled" -gt 0 ]; then
            __repacd_update_vap_param "$name" 'wps_pbc_noclone' '1'
        fi

        # Without a custom config, set all interfaces to be enabled for 2 minutes.
        if [ -z "$start_time" ]; then
            __repacd_update_vap_param "$name" 'wps_pbc_start_time' 0
        fi

        if [ -z "$duration" ]; then
            if [ "$traffic_separation_enabled" -gt 0 ] && [ "$auto_create_vaps" -eq 1 ]; then
                __repacd_update_vap_param "$name" 'wps_pbc_duration' 60
            else
                __repacd_update_vap_param "$name" 'wps_pbc_duration' 120
            fi
        fi
    fi
}

# Set all of the configuration parameters for the given VAP.
# input: $1 name: section name
# input: $2 device: name of the radio
# input: $3 mode: whether to act as a STA or AP
# input: $4 ssid: the desired SSID for this VAP
# input: $5 encryption: the desired encryption mode for this VAP
# input: $6 key: the desired passphrase for this VAP
# input: $7 vap_count: additional vap count created in Device
__repacd_init_vap() {
    local name=$1 device=$2 mode=$3 ssid=$4 encryption=$5 key=$6 vap_count=$7
    local cur_mode

    config_get_bool repacd_security_unmanaged "$name" repacd_security_unmanaged '0'
    __repacd_update_vap_param "$name" 'device' "$device"
    __repacd_update_vap_param "$name" 'network' $managed_network
    __repacd_init_vap_set_ssid_and_pbc "$name" "$device" "$ssid" "$vap_count"

    if [ "$repacd_security_unmanaged" -eq 0 ] ; then
        __repacd_update_vap_param "$name" 'encryption' "$encryption"
        __repacd_update_vap_param "$name" 'key' "$key"
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

# Set all VAPs for the given network and mode to disabled or enabled (per
# the parameters).
#
# input: $1 config: section name
# input: $2 network: network for which to update VAPs
# input: $3 mode: sta or ap
# input: $4 disable_24g: 1 - disable, 0 - enable
# input: $5 disable_5g: 1 - disable, 0 - enable
# input-output: $6 change counter
__repacd_disable_vap() {
    local config="$1"
    local disable_24g="$4"
    local disable_5g="$5"
    local mode network disabled
    local changed="$6"

    config_get device "$config" device
    config_get hwmode "$device" hwmode
    config_get type "$device" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ] ;then
        return
    fi
    config_get mode "$config" mode
    config_get network "$config" network
    config_get disabled "$config" disabled 0

    if [ "$2" = "$network" ] && __repacd_is_matching_mode "$3" "$mode"; then
        local desired_val
        if whc_is_5g_vap "$config"; then
            desired_val=$disable_5g
        else
            desired_val=$disable_24g
        fi

        if [ ! "$desired_val" = "$disabled" ]; then
            uci_set wireless "$config" disabled "$desired_val"
            changed=$((changed + 1))
            eval "$6='$changed'"
            __repacd_echo "Set VAP $config to Disabled=$desired_val"
        fi
    fi
}

# Change the wsplcd running mode based on the value provided.
#
# input: $1 new_mode: value to set wsplcd run mode to
# input: $2 new_deep_clone: whether to enable deep cloning (which copies the
#                       channel and locks the association to the CAP)
# input: $3 new_deep_clone_no_bssid: deep cloning without BSSID cloning
# input: $4 config_sta: whether to use the extension to configure a STA
#                       interface during cloning
# input: $5 map_enable: revision of MAP specification code is currently operating on
# input-output: $6 changed: count of the changes
__repacd_configure_wsplcd() {
    local new_mode=$1
    local new_deep_clone=$2
    local new_deep_clone_no_bssid=$3
    local new_config_sta=$4
    local new_map_enable=$5
    local changed="$6"
    local mode deep_clone deep_clone_no_bssid manage_vapind enabled
    local map_bss_conf

    if [ -f $WSPLCD_INIT ]; then
        config_load wsplcd
        config_get mode config 'RunMode'
        config_get deep_clone config 'DeepClone'
        config_get deep_clone_no_bssid config 'DeepCloneNoBSSID'
        config_get config_sta config 'ConfigSta'
        config_get map_enable config 'MapEnable'
        config_get map_bss_conf config 'MapGenericPolicyFile'
        config_get manage_vapind config 'ManageVAPInd'
        config_get_bool enabled config 'HyFiSecurity' 0

        if [ ! "$mode" = "$new_mode" ]; then
            uci_set wsplcd config 'RunMode' "$new_mode"
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd
            __repacd_echo "Set wsplcd to $new_mode mode"
            wsplcd_restart=1
        fi

        if [ ! "$deep_clone" = "$new_deep_clone" ]; then
            uci_set wsplcd config 'DeepClone' "$new_deep_clone"
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd
            __repacd_echo "Set wsplcd DeepClone=$new_deep_clone"
            wsplcd_restart=1
        fi

        if [ ! "$deep_clone_no_bssid" = "$new_deep_clone_no_bssid" ]; then
            uci_set wsplcd config 'DeepCloneNoBSSID' "$new_deep_clone_no_bssid"
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd
            __repacd_echo "Set wsplcd DeepCloneNoBSSID=$new_deep_clone_no_bssid"
            wsplcd_restart=1
        fi

        if [ ! "$config_sta" = "$new_config_sta" ]; then
            uci_set wsplcd config 'ConfigSta' "$new_config_sta"
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd
            __repacd_echo "Set wsplcd ConfigSta=$new_config_sta"
            wsplcd_restart=1
        fi

        if [ ! "$map_enable" = "$new_map_enable" ]; then
            uci_set wsplcd config 'MapEnable' "$new_map_enable"
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd
            __repacd_echo "Set wsplcd MapEnable=$new_map_enable"
            wsplcd_restart=1
        fi

        if [ "$new_map_enable" -gt 0 ] && \
            [ ! "$map_bss_conf" = "$WSPLCD_MAP_BSS_POLICY_PATH" ]; then
            uci_set wsplcd config 'MapGenericPolicyFile' "$WSPLCD_MAP_BSS_POLICY_PATH"
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd
            __repacd_echo "Set wsplcd MapGenericPolicyFile=$WSPLCD_MAP_BSS_POLICY_PATH"
            wsplcd_restart=1
        fi

        if [ ! "$manage_vapind" = "0" ]; then
            uci_set wsplcd config 'ManageVAPInd' "0"
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd
            __repacd_echo "Set wsplcd ManageVAPInd=0"
            wsplcd_restart=1
        fi

        if [ ! "$enabled" -eq "$wsplcd_enabled" ]; then
            uci_set wsplcd config 'HyFiSecurity' $wsplcd_enabled
            changed=$((changed + 1))
            eval "$6='$changed'"
            uci_commit wsplcd

            __repacd_echo "Set wsplcd HyFiSecurity=$wsplcd_enabled"
            if [ "$wsplcd_enabled" -gt 0 ]; then
                __repacd_echo "Enabled security and configuration"
                wsplcd_start=1
            else
                __repacd_echo "Disabled security and configuration"
                wsplcd_stop=1
            fi
        fi

        if [ "$map_version" -gt 1 ]; then
            uci_set wsplcd config 'MapEnable' $map_version
            __repacd_echo "Set wsplcd MapEnable=$map_version"
            if [ "$map_ts_enabled" -gt 0 ]; then
                uci_set wsplcd config 'NumberOfVLANSupported' $num_vlan_supported
                uci_set wsplcd config 'Map2TrafficSepEnabled' $map_ts_enabled
                uci_set wsplcd config 'CombinedR1R2Backhaul' $map_single_r1r2_bh
            fi
        fi
    fi
}

# Change whether mcsd is enabled and running or not
#
# input: $1 manage_mcsd: whether repacd is to manage the state of mcsd
# input: $2 enable_son: whether SON mode is enabled or not (where this could
#                       include MAP)
__repacd_config_mcsd() {
    local manage_mcsd=$1
    local enable_son=$2

    if [ "$manage_mcsd" -gt 0 ] && [ -f "$MCSD_INIT" ]; then
        if [ "$enable_son" -gt 0 ]; then
            uci_set mcsd config 'Enable' 0
            uci_commit mcsd
            # Stop mcsd and keep attempting to stop it in case it
            # is being restarted by a hotplug event.
            while pgrep mcsd;
            do
                /etc/init.d/mcsd stop
                sleep 2
            done
        else  # switching to non-SON mode, so enable mcsd
            uci_set mcsd config 'Enable' 1
            uci_commit mcsd
            /etc/init.d/mcsd start
        fi
    fi
}

# Change the hyd and/or lbd configuration based on the parameters provided
# and the allowed feature settings.
#
# input: $1 enable_steering: 1 - AP interfaces support steering;
#                            0 - they do not
# input: $2 disable_ap_steering: 1 - disable AP steering feature
# input: $3 enable_son: 1 - multi-AP SON mode should be enabled (so
#                           long as it is not prohibited by config);
#                       0 - multi-AP SON mode should not be enabled
# input: $4 son_mode: one of HYROUTER or HYCLIENT; only relevant if enable_son
#                     is 1 and SON mode is not prohibited by the config
# input-output: $5 changed: count of the changes
__repacd_configure_son() {
    local enable_steering=$1
    local disable_ap_steering=$2
    local enable_son=$3
    local son_mode="$4"
    local changed="$5"

    local enable_steering_mask enable_son_mask manage_mcsd
    config_load repacd
    config_get_bool enable_steering_mask repacd 'EnableSteering' 1
    config_get_bool enable_son_mask repacd 'EnableSON' 1
    config_get_bool manage_mcsd repacd 'ManageMCSD' 1

    # If the config does not permit steering or multi AP logic, force it
    # off.
    if [ "$enable_steering_mask" -eq 0 ]; then
        enable_steering=0
    fi

    if [ "$enable_son_mask" -eq 0 ]; then
        enable_son=0
    fi

    # If the package is not even installed, then we will fall back to
    # the uncoordinated steering mode (if enabled).
    if [ -f $HYD_INIT  ]; then
        local cur_mode hyd_enabled
        config_load $MAP
        config_get cur_mode config 'Mode'
        config_get hyd_enabled config 'Enable'
        config_get disable_steering config 'DisableSteering'

        if [ ! "$cur_mode" = "$son_mode" ]; then
            uci_set $MAP config 'Mode' "$son_mode"
            changed=$((changed + 1))
            eval "$5='$changed'"
            uci_commit $MAP
            __repacd_echo "Set hyd Mode=$son_mode"
        fi

        if [ ! "$disable_steering" = "$disable_ap_steering" ]; then
            uci_set $MAP config 'DisableSteering' "$disable_ap_steering"
            changed=$((changed + 1))
            eval "$5='$changed'"
            uci_commit $MAP
            __repacd_echo "Set hyd DisableSteering=$disable_ap_steering"
        fi

        if [ ! "$hyd_enabled" = "$enable_son" ]; then
            uci_set $MAP config 'Enable' "$enable_son"
            changed=$((changed + 1))
            eval "$5='$changed'"
            uci_commit $MAP

            /etc/init.d/qrfs disable
            /etc/init.d/qrfs stop

            __repacd_config_mcsd "$manage_mcsd" "$enable_son"

            # hyd should be started/stopped based on the hotplug hooks
            # it has installed.
            if [ "$enable_son" -gt 0 ]; then
                __repacd_echo "Enabled Wi-Fi SON mode"
                hyd_start=1
            else
                __repacd_echo "Disabled Wi-Fi SON mode"
                hyd_stop=1
            fi
        fi

        if [ "$enable_son" -gt 0 ]; then
            enable_steering=0
        fi
    fi

    if [ -f $LBD_INIT ]; then
        local lbd_enabled
        config_load $MAPLBD
        config_get lbd_enabled config 'Enable'

        if [ ! "$lbd_enabled" = "$enable_steering" ]; then
            uci_set $MAPLBD config 'Enable' "$enable_steering"
            changed=$((changed + 1))
            eval "$5='$changed'"
            uci_commit $MAPLBD

            # Start/stop is handled when Wi-Fi interfaces are reconfigured.
            if [ "$enable_steering" -gt 0 ]; then
                __repacd_echo "Enabled Wi-Fi steering"
            else
                __repacd_echo "Disabled Wi-Fi steering"
            fi
        fi
    fi
}

# Set the option that indicates whether the DBDC repeater feature should be
# enabled or not.
#
# input: $1 config: section to update
# input: $2 1 - enable, 0 - disable
# input-output: $3 change counter
__repacd_config_dbdc_device() {
    local config="$1"
    local changed="$3"

    local dbdc_enable
    config_get hwmode "$config" hwmode
    config_get type "$config" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ]; then
        return
    fi

    config_get dbdc_enable "$config" dbdc_enable 1
    if [ ! "$2" = "$dbdc_enable" ]; then
        uci_set wireless "$config" dbdc_enable "$2"
        changed=$((changed + 1))
        eval "$3='$changed'"
        __repacd_echo "Set radio $config to DBDC Enabled=$2"
    fi
}

# Change the configuration on the wifi-iface object to match what is desired.
# The values provided are determined by the caller based on the desired
# mode of operation (eg. QWrap/ExtAP or not).
#
# input: $1 config: section to update
# input: $2 network: only update if network matches this value
# input: $3 enable_wds: 1 - enable, 0 - disable
# input: $4 qwrap_ap: 1 - enable, 0 - disable
# input: $5 extap: 1 - enable, 0 disable
# input: $6 block_dfs_chan: 1 - block DFS channels, 0 - do not block them
# input: $7 enable_rrm: 1 - enable, 0 disable
# input: $8 re_scalingfactor: 0 - ignore, 1 to 100 valid for sta
# input: $9 default_root_dist: 0 - ignore, 255 - invalid root distance
# input: $10 cap_snr: 0 - disabled, 1-100 valid
# input-output: $11 change counter
__repacd_config_iface() {
    local config="$1"
    local device mode network enable_wds qwrap_ap extap block_dfs enable_rrm
    local re_scalingfactor root_distance cap_snr wps_pbc_skip
    local bssid="00:00:00:00:00:00"
    local num_changes=0
    local changed="${11}"

    config_get device "$config" device
    config_get hwmode "$device" hwmode
    config_get type "$device" type

    if [ "$hwmode" = '11ad' ] && [ "$type" = 'mac80211' ] ;then
       return
    fi

    config_get mode "$config" mode
    config_get network "$config" network
    config_get enable_wds "$config" wds '0'
    config_get qwrap_ap "$config" qwrap_ap '0'
    config_get extap "$config" extap '0'
    config_get block_dfs "$config" blockdfschan '0'
    config_get enable_rrm "$config" rrm '0'
    config_get re_scalingfactor "$config" re_scalingfactor '0'
    config_get root_distance "$config" root_distance '0'
    config_get cap_snr "$config" caprssi '0'
    config_get wps_pbc_skip "$config" wps_pbc_skip '0'

    if [ "$2" = "$network" ]; then
        if [ ! "$3" = "$enable_wds" ]; then
            uci_set wireless "$config" wds "$3"
            num_changes=$((num_changes + 1))
            __repacd_echo "Set iface $config to WDS=$3"
        fi

        # When operating in WDS/SON mode (since we do not use the repeater
        # enhancement), set the option to skip activating WPS PBC on a
        # connected STA interface. This allows the WPS button to be pressed on
        # an RE without causing it to disconnect from its upstream device.
        if [ "$mode" = 'sta' ]; then
            if [ ! "$3" = "$wps_pbc_skip" ]; then
                uci_set wireless "$config" wps_pbc_skip "$3"
                num_changes=$((num_changes + 1))
                __repacd_echo "Set iface $config to wps_pbc_skip=$3"
            fi
        fi

        # These should only be set on AP interfaces.
        if __repacd_is_matching_mode 'ap' "$mode"; then
            if [ ! "$4" = "$qwrap_ap" ]; then
                uci_set wireless "$config" qwrap_ap "$4"
                num_changes=$((num_changes + 1))
                __repacd_echo "Set iface $config to QWrapAP=$4"
            fi

            # @todo If there are multiple 5 GHz radios, will need to figure
            #       out which can act as the backhaul.

            # Set the interface into wrap or vanilla AP mode as appropriate
            if whc_is_5g_radio $device; then
                if [ "$4" -gt 0 ]; then
                    if [ ! "$mode" = 'wrap' ]; then
                        uci_set wireless "$config" mode 'wrap'
                        num_changes=$((num_changes + 1))
                        __repacd_echo "Set iface $config mode to wrap"
                    fi
                else  # WDS or ExtAP mode
                    if [ ! "$mode" = 'ap' ]; then
                        uci_set wireless "$config" mode 'ap'
                        num_changes=$((num_changes + 1))
                        __repacd_echo "Set iface $config mode to ap"
                    fi
                fi
            fi

            if [ ! "$6" = "$block_dfs" ]; then
                uci_set wireless "$config" blockdfschan "$6"
                num_changes=$((num_changes + 1))
                __repacd_echo "Set iface $config to BlockDFSChan=$6"
            fi

            if [ ! "$7" = "$enable_rrm" ]; then
                uci_set wireless "$config" rrm "$7"
                num_changes=$((num_changes + 1))
                __repacd_echo "Set iface $config to RRM=$7"
            fi
        fi

        if [ ! "$5" = "$extap" ]; then
            uci_set wireless "$config" extap "$5"
            num_changes=$((num_changes + 1))
            __repacd_echo "Set iface $config to ExtAP=$5"
        fi

        if [ "$daisy_chain" -gt 0 ] && \
            __repacd_is_matching_mode 'sta' "$mode"; then

            # Need to resolve 2.4G & 5G BSSID, So until then configure invalid BSSID
            # to avoid association on 2.4G & 5G interface at bootup.
            # Check if bssid updated by wifimon/daisychain, needs restart
            if [ "$bssid_resolve_state" = "resolving" ]; then
                uci_set wireless "$config" bssid "$bssid"
                num_changes=$((num_changes + 1))
                __repacd_echo "Set iface $config to BSSID=$bssid"
            fi

            if [ ! "$8" = "$re_scalingfactor" ]; then
                uci_set wireless "$config" re_scalingfactor "$8"
                num_changes=$((num_changes + 1))
                __repacd_echo "Set iface $config to RE_ScalingFactor=$8"
            fi

            if [ ! "${10}" = "$cap_snr" ]; then
                uci_set wireless "$config" caprssi "${10}"
                num_changes=$((num_changes + 1))
                __repacd_echo "Set iface $config to caprssi=${10}"
            fi
        fi

            uci_set wireless "$config" root_distance "$9"
            num_changes=$((num_changes + 1))
            __repacd_echo "Set iface $config to RootDistance=$9"

        if [ "$num_changes" -gt 0 ]; then
            changed=$((changed + 1))
            eval "${11}='$changed'"
        fi
    fi
}

# Restart wsplcd and the Wi-Fi interfaces based on configuration changes.
__repacd_restart_dependencies() {
    if [ "$wsplcd_stop" -gt 0 ]; then
        $WSPLCD_INIT stop
    fi

    if [ "$hyd_stop" -gt 0 ]; then
        $HYD_INIT stop
        $HYFI_BRIDGING_INIT stop
    fi

    # When hyd is being started, start the bridging hooks prior to restarting
    # the network to ensure any temporary loops are prevented.
    if [ "$hyd_start" -gt 0 ]; then
        $HYFI_BRIDGING_INIT start
    fi

    if [ "$config_changed" -gt 0 ]; then
        __repacd_echo "Restarting network stack..."
        whc_network_restart
    else
        __repacd_echo "No changes; not restarting network stack..."
        config_load repacd
        config_get traffic_separation_enabled repacd TrafficSeparationEnabled '0'
        config_get network_guest repacd NetworkGuest 'guest'
        config_get network_guestmac repacd GuestMac 'ath0'
        if [ "$traffic_separation_enabled" -gt 0 ]; then
            brguest=`ifconfig $network_guestmac | grep HWaddr | awk '{print $5}'`
            ifconfig br-$network_guest hw ether "$brguest"
        fi
    fi

    if [ "$wsplcd_start" -gt 0 ]; then
        __repacd_echo "Starting wsplcd"
        $WSPLCD_INIT start
    elif [ "$wsplcd_restart" -gt 0 ]; then
        __repacd_echo "Restarting wsplcd"
        $WSPLCD_INIT restart
    fi

    if [ "$hyd_start" -gt 0 ]; then
        __repacd_echo "Starting $MAP"
        $HYD_INIT start
    fi
}

__stop_repacd_run() {
    PID=$(ps | grep repacd-run | grep -v grep | awk '{print $1}')
    if [ -n "$PID" ]; then
        kill -s SIGTERM $PID
        __repacd_echo "stopped repacd-run process $PID"
    fi
}


