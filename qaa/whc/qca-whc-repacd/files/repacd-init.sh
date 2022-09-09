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


# shellcheck disable=SC2034
START=97  # needs to be after LED init

# shellcheck disable=SC2034
SERVICE_WRITE_PID=1

# shellcheck disable=SC2034
SERVICE_DAEMONIZE=1

#SERVICE_DEBUG=1
NETWORK_RESTART=0
SERVICE_DEBUG_OUTPUT=0

# These restart_in_*_mode commands are only intended to be used by
# repacd-run.sh.
#
# - restart_in_cap_mode is used when the device has a direct connection to the
#   the gateway via ethernet. This will result in only the AP interfaces being
#   enabled.
# - restart_in_noncap_mode is used when the device no longer has a direct
#   connection to the gateway via ethernet. When this is done, the device will
#   either have both its AP and STA interfaces enabled (if its primary purpose
#   is as a standalone RE) or just its STA interface enabled (if its primary
#   purpose is as a client device).
# - restart_in_re_mode is used when a device that is intended to primarily
#   act as a client actually has sufficient link quality to act as a range
#   extender. It will enable both the STA and AP interfaces.
EXTRA_COMMANDS="restart_in_cap_mode restart_in_noncap_mode restart_in_re_mode"
EXTRA_HELP=<<EOF
        restart_in_cap_mode Reconfigure the system into Central AP mode
        restart_in_noncap_mode Reconfigure the system into Non Central AP mode
        restart_in_re_mode Reconfigure the system into Range Extender mode
EOF

. /lib/functions/repacd-cmn.sh

#Creating a tmp file to identify the first boot of repacd
echo 1 > /tmp/firstboot

#check repacd config to enable/disable cfg80211
config_load 'repacd'
config_get_bool map_enabled MAPConfig 'Enable' '0'
config_get_bool repacd_enabled repacd 'Enable' '0'
    if [ "$map_enabled" -eq 1 ]; then
         . /lib/functions/repacd-map.sh
    elif [ "$repacd_enabled" -eq 1 ]; then
         . /lib/functions/repacd-son.sh
    fi

# Determine whether the Multi-AP Topology Optimization algorithm is enabled.
#
# return: 0 if the algorithm is enabled; otherwise 1
__repacd_is_map_enabled() {
    local map_enabled

    config_load 'repacd'
    config_get_bool map_enabled MAPConfig 'Enable' '0'

    [ "$map_enabled" -gt 0 ]
    return $?
}

# Determine whether the Multi-AP Lite Mode is enabled.
#
# return: 0 if enabled; otherwise 1
__repacd_is_map_lite_enabled() {
    config_load 'repacd'
    config_get_bool map_lite_enabled MAPConfig 'EnableLiteMode' '0'

    [ "$map_lite_enabled" -gt 0 ]
    return $?
}

# Script entry point: Perform configuration and start the daemon
start() {
    local enabled

    config_load 'repacd'
    config_get_bool enabled repacd 'Enable' '0'

    [ "$enabled" -gt 0 ] || {
        return 1
    }

    if __repacd_is_map_enabled; then

        if __repacd_is_map_lite_enabled; then
            __start_map_lite
            return $?
        fi

        __repacd_map_reset_5g_attempts

        local ether_gwcon=0 start_role='init' autoconf=0
        __start_map $ether_gwcon $start_role $autoconf
        return $?
    else
        __start_son
        return $?
    fi
}

# Script entry point: Stop the daemon
stop() {
    __stop_repacd_run
}

# Script entry point: Reconfigure and restart the daemon
restart() {
    stop

    config_load 'repacd'
    config_get_bool enabled repacd 'Enable' '0'

    [ "$enabled" -gt 0 ] || {
            return 1
    }

    start
}

# Force a restart into CAP mode.
#
# This is used when the gateway detection logic detects a gateway on
# ethernet when running in a pure bridge mode.
restart_in_cap_mode() {
    if __repacd_is_map_enabled; then
        __restart_in_cap_mode_map
        return $?
    else
        __restart_in_cap_mode_son
        return $?
    fi
}

# Force a restart into NonCAP mode.
#
# This is used when the gateway detection logic detects that there is no
# longer a gateway connected over ethernet.
restart_in_noncap_mode() {
    if __repacd_is_map_enabled; then
        __restart_in_noncap_mode_map
        return $?
    else
        __restart_in_noncap_mode_son
        return $?
    fi
}

# Force a restart into Range Extender (RE) mode.
#
# This is used when the Wi-Fi link monitoring logic determines that the
# link is in the sweet spot for a device that normally acts as a client
# but is capable (from a CPU and Wi-Fi perspective) of operating as an AP
# and a STA at the same time.
restart_in_re_mode() {
    if __repacd_is_map_enabled; then
        __restart_in_re_mode_map
        return $?
    else
        __restart_in_re_mode_son
        return $?
    fi
}

