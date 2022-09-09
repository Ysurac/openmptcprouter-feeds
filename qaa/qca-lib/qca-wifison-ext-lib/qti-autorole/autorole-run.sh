#!/bin/sh
# Copyright (c) 2021 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.

AUTOROLE_DEBUG_OUTOUT=0
GATEWAY_CHECK_PERIOD=60
CONTROLLER_CHECK_PERIOD=60
EXTERNAL_PING_IP=
ETHERNET_INTERFACES=eth

DYNAMIC_ROLE_SHARE_FILE=/tmp/nb_share_file

# Constants. Don't Modify it.
TRUE=0
FALSE=1

. /lib/functions.sh

# Emit a log message
# input: $1 - level: the symbolic log level
# input: $2 - msg: the message to log
__autorole_log() {
    local stderr=''
    if [ "$AUTOROLE_DEBUG_OUTOUT" -gt 0 ]; then
        stderr='-s'
    fi

    logger $stderr -t autorole -p "user.$1" "$*"
}

# Emit a log message at debug level
# input: $1 - msg: the message to log
__autorole_debug() {
    __autorole_log 'debug' "$1"
}

# Emit a log message at info level
# input: $1 - msg: the message to log
__autorole_info() {
    __autorole_log 'info' "$1"
}

# Emit a log message at warning level
# input: $1 - msg: the message to log
__autorole_warn() {
    __autorole_log 'warn' "$1"
}

__autorole_die() {
    if [ $2 -eq 0 ]; then
        __autorole_info "$1"
    else
        __autorole_warn "$1"
    fi
    exit $2
}

resolve_gw_ip() {
    local iface=$1
    local _resolved_ip=''

    _resolved_ip=$(route -n | grep ^0.0.0.0 | grep "$iface" | awk '{print $2}')
    if [ -n "$_resolved_ip" ]; then
        eval "$2=$_resolved_ip"
    else
        __autorole_debug "Failed to resolve GW IP for $iface"
    fi
}

get_ip() {
    local iface=$1
    local _ip=''

    _ip=$(ifconfig $iface | awk -F ':'  '/inet addr/{print $2}' | awk '{print $1}')
    if [ -n "$_ip" ]; then
        eval "$2=$_ip"
    else
        __autorole_debug "Failed to get IP address for $iface"
    fi
}

get_macaddress() {
    local iface=$1
    local _tmp_mac=''

    _tmp_mac=$(ifconfig $iface | awk '/HWaddr/{print $5}' | tr 'A-Z' 'a-z') #use lowercase letters
    if [ -n "$_tmp_mac" ]; then
        eval "$2=$_tmp_mac"
    else
        __autorole_debug "Failed to get MAC address for $iface"
    fi
}

check_gateway() {
    local network=$1
    local gw_ip pingip

    [ -z "$network" ] && __autorole_die "Bad parameter" 1

    ifconfig $network > /dev/null || return $FALSE # the network might have not been created

    resolve_gw_ip "$network" gw_ip
    [ -z "$gw_ip" ] && return $FALSE

    if ping -W 2 "$gw_ip" -c1 2> /dev/null; then
        [ -z "$EXTERNAL_PING_IP" ] ||
            ping -W 2 "$EXTERNAL_PING_IP" -c1 > /dev/null ||
                return $FALSE

        # check the gateway is from the Ethernet interfaces.
        gw_mac=$(grep "$gw_ip\>" /proc/net/arp | grep -v 00:00:00:00:00:00 | awk '{print $4}')

        [ -z "$gw_mac" ] && {
            __autorole_debug "Failed to get MAC address for $gw_ip in ARP table"
            return $FALSE
        }
        eth_macs=$(ifconfig | grep $ETHERNET_INTERFACES | awk '/HWaddr/{print $5}' | tr 'A-Z' 'a-z')

        for mac in $eth_macs; do
            eth_port=$(brctl showmacs $network | grep "$mac.*yes" |awk '{print $1}')
            gw_port=$(brctl showmacs $network | grep "$gw_mac" |awk '{print $1}')

            [ $eth_port == $gw_port ] && return $TRUE
        done
    fi

    return $FALSE
}

fill_vendor_buffer() {
    local _mac=''
    local _role _payload _len _type _subtype _buff

    get_macaddress $g_interface _mac
    [ -z "$_mac" ] && __autorole_die "Unable to get MAC address" 1

    _role=0
    _type=0007

    _payload=${_mac//:/}$_role
    _subtype=65
    _buff=$(printf "%s%s%02x%s" $_type $_subtype ${#_payload} $_payload)
    #<Vendor Buffer IE> will contain following:
    #Type: Message Type where this TLV is going to get added
    #Length: Length of the buffer in bytes
    #Value: Data includes Vendor-SubType + Length in bytes + Actual Data in bytes
    __autorole_debug "buff is $_buff"

    eval "$1=$_buff"
}

fn_count_radio() {
    radionum=$(($radionum + 1))
}

parse_wireless_config() {
    config_load wireless

    radionum=0
    config_foreach fn_count_radio wifi-device

    g_radio=''
    a_radio1=''
    for i in $(seq 0 $(($radionum-1))); do
        config_get hwmode "wifi$i" hwmode auto
        case "$hwmode" in
            *b|*g)
                g_radio="wifi$i";;
            *ac|*a)
                [ -z "$a_radio1" ] && a_radio1="wifi$i" || a_radio2="wifi$i"
                ;;
            *) __autorole_die "Unknown hwmode $hwmode for wifi$i" 1 ;;
        esac
    done
}

set_controller() {

    wifi detect > /etc/config/wireless
    for i in $(seq 1 $radionum); do
        local wifi=wifi$(($i-1))
        uci set wireless.$wifi.disabled=0
        uci del wireless.$wifi.repacd_map_bsta_preference 2>/dev/null

        uci set wireless.$wifi.repacd_create_ctrl_fbss=1
        uci set wireless.$wifi.repacd_create_ctrl_bbss=1
    done

    uci set wireless.qcawifi=qcawifi
    uci set wireless.qcawifi.samessid_disable=1
    uci commit wireless

    uci add network.wan=interface
    uci commit network
    /etc/init.d/network restart

    uci set wsplcd.config.EnableNBTLV=1
    uci del wsplcd.config.NBTLVbuff 2> /dev/null
    uci commit wsplcd

    uci set repacd.repacd.Enable=1
    uci set repacd.repacd.GatewayConnectedMode='Controller'
    uci set repacd.repacd.ConfigREMode='son'
    uci set repacd.MAPConfig.Enable=1
    uci set repacd.MAPConfig.FirstConfigRequired=1
    uci set repacd.repacd.Ezmesh='1'

    uci set repacd.MAPConfig.BSSInstantiationTemplate="$g_scheme"
    uci set repacd.MAPConfig.FronthaulSSID="$g_fh_ssid"
    uci set repacd.MAPConfig.FronthaulKey="$g_fh_key"
    uci set repacd.MAPConfig.BackhaulSSID="$g_bh_ssid"
    uci set repacd.MAPConfig.BackhaulKey="$g_bh_key"
    uci commit repacd

    /etc/init.d/repacd restart
}

set_agent() {
    local NBTLVbuff
    fill_vendor_buffer NBTLVbuff

    wifi detect > /etc/config/wireless
    for i in $(seq 1 $radionum); do
        local wifi=wifi$(($i-1))
        uci set wireless.$wifi.disabled=0
        uci set wireless.$wifi.repacd_map_bsta_preference=$i

        uci del wireless.$wifi.repacd_create_ctrl_fbss 2>/dev/null
        uci del wireless.$wifi.repacd_create_ctrl_bbss 2>/dev/null
    done

    uci set wireless.qcawifi=qcawifi
    uci set wireless.qcawifi.samessid_disable=1
    uci commit wireless

    uci del network.wan 2>/dev/null
    uci commit network
    /etc/init.d/network restart

    uci set wsplcd.config.EnableNBTLV=1
    uci set wsplcd.config.NBTLVbuff=$NBTLVbuff
    uci set wsplcd.config.MapMaxBss=2
    uci set wsplcd.config.MapEnable=1
    uci set wsplcd.config.HyFiSecurity=1
    uci commit wsplcd

    uci set lbd.Estimator_Adv.EnableRcpiTypeClassification=0
    uci commit lbd

    uci set repacd.repacd.Enable=1
    uci del repacd.repacd.GatewayConnectedMode 2>/dev/null
    uci set repacd.repacd.ConfigREMode='son'
    uci set repacd.MAPConfig.FirstConfigRequired=1
    uci set repacd.MAPConfig.Enable=1
    uci set repacd.repacd.Ezmesh=1
    uci commit repacd
    /etc/init.d/repacd restart
}

set_role() {
    local role=$1

    parse_wireless_config
    wifimeshconfig map

    __autorole_debug "Set role to $role"
    if [ "$role" = 'Controller' ]; then
        set_controller
    else
        set_agent
    fi
}

do_election() {
    local mymac tmpmac num tmpnum

    get_macaddress "$g_interface" mymac
    [ -z "$mymac" ] && __autorole_die "Unable to get MAC address" 1
    num=$(printf "%d" 0x${mymac//:/})

    [ -f $DYNAMIC_ROLE_SHARE_FILE ] || return $TRUE  # File not exist

    # determin if my mac is the lowest.
    while read line; do
        tmpmac=$(echo $line | awk -F ':' '{print $3}'| cut -b -12)
        tmpnum=$(printf "%d" 0x$tmpmac)

        [ $num -eq $tmpnum ] && __autorole_die "Same mac addresses found in the network" 1
        [ $num -gt $tmpnum ] && return $FALSE
    done < $DYNAMIC_ROLE_SHARE_FILE

    return $TRUE
}

_get_controller_addr() {
    local _role _mac
    [ -f $DYNAMIC_ROLE_SHARE_FILE ] || return  # File not exist

    while read line; do
        _role=$(echo "$line" | awk -F ':' '{print $2}')

        if [ "$_role" -eq 1 ]; then
            _mac=$(echo "$line" | awk -F ':' '{print $1}' | tr 'A-Z' 'a-z') # make sure it's lowercase
            break
        fi
    done < $DYNAMIC_ROLE_SHARE_FILE

    eval "$1=$_mac"
}

check_controller() {
    local ip ips mac network
    network=$1
    mac=$2
    ips=$(sed 's/://g' /proc/net/arp| grep "$mac.*$network" | awk '{print $1}')

    for ip in $ips $ips $ips; do # ping three times.
        ping "$ip" -c 1 -W 2 > /dev/null && return 0
    done

    [ -z "$ips" ] && __autorole_debug "Unable to find ip address for $mac in the ARP table."

    __autorole_debug "Try to check $mac in FDB table."
    local aging compare

    # Get the aging timer in the fdb table
    # For the entry with aging timer less than $CONTROLLER_CHECK_PERIOD,
    # we consider it's alive
    aging=$(brctl showmacs $network | sed 's/://g' | grep $controllerMAC | awk '{print $4'})
    [ -z "$aging" ] && {
        __autorole_debug "Unable to find entry for $mac in the fdb table."
        return 1
    }

    compare=$(awk -v num1=$aging -v num2=$CONTROLLER_CHECK_PERIOD 'BEGIN{print(num1>num2)?"1":"0"}')
    return $compare

}

init() {
    config_load autorole
    config_get g_enabled config 'Enable' '0'
    config_get g_network config 'Network' 'lan'
    config_get g_wait_time config 'WaitTime' '300'
    config_get g_role_mode config 'RunMode' ''
    config_get g_controller_check config 'ControllerCheck' '0'

    config_get g_scheme wifi 'Scheme' 'scheme-a.conf'
    config_get g_fh_ssid wifi 'FronthaulSSID' ''
    config_get g_fh_key wifi 'FronthaulKey' ''
    config_get g_bh_ssid wifi 'BackhaulSSID' ''
    config_get g_bh_key wifi 'BackhaulKey' ''

    [ "$g_enabled" -eq 0 ] && __autorole_die "Auto role selection is not enabled. Exit." 0
    [ -z "$g_fh_ssid" -o -z "$g_fh_key" -o -z "$g_bh_ssid" -o -z "$g_bh_key" ] && __autorole_die "Bad configurations." 1

    g_interface=br-$g_network
}

main() {
    init

    if [ -z "$g_role_mode" -o "$g_role_mode" = "Auto" ]; then
        local getResp controllerMAC

        until check_gateway $g_interface ; do
            __autorole_debug "Gateway is not reachable, sleep $GATEWAY_CHECK_PERIOD seconds to recheck."
            sleep $GATEWAY_CHECK_PERIOD
        done

        set_role "Agent"

        __autorole_debug "Sleep $g_wait_time seconds to wait all nodes in the network."
        sleep $g_wait_time

        config_load wsplcd
        config_get getResp config 'ResponseRcvd' '0'

        if [ "$getResp" -eq 0 ]; then
            __autorole_info "No Controller found in the network."
            do_election
            if [ "$?" -eq $TRUE ] ; then
                __autorole_info "Per the algorithm, this node is elected as Controller."
                set_role "Controller"

                exit 0
            fi
            __autorole_info "Per the algorithm, Other node in the network is elected as Controller."
        else
            __autorole_info "Found Controller in the network."
        fi

        #role is Agent
        [ "$g_controller_check" -eq 0 ] && __autorole_die "Do not check the activity of the controller. Exit." 0

        __autorole_debug "Try to get mac address of the controller and check availability."

        while true; do
            _get_controller_addr controllerMAC
            if [ -z "$controllerMAC" ]; then
                __autorole_debug "Unable to get Controller address. Wait $CONTROLLER_CHECK_PERIOD to do re-check."
            else
                check_controller $g_interface $controllerMAC
                [ $? -eq 1 ] && break # Controller is down.

                __autorole_debug "Controller address is $controllerMAC and alive. Wait $CONTROLLER_CHECK_PERIOD to do re-check."
            fi
            sleep $CONTROLLER_CHECK_PERIOD
        done

        __autorole_info "Controller is down, reboot now"
        reboot

    elif [ "$g_role_mode" = "Controller" -o  "$g_role_mode" = "Agent" ]; then
        __autorole_info "Run manual role setting to $g_role_mode"
        set_role $g_role_mode
    else
        __autorole_die "Unknown role setting: $g_role_mode" 1
    fi

}

main "$@"
