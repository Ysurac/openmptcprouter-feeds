#!/bin/sh /etc/rc.common
# Copyright (c) 2015 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.

whc_network_restart() {
    # This already grabs a lock when reconfiguring the Wi-Fi interfaces.
    # If WHC ever grows to configure more than just Wi-Fi, then we may
    # need to grab an additional lock.
    /sbin/wifi
}

# Determine  if the device provided is for 5 GHz or not
# Currently this relies on the hwmode config parameter and is meant for
# a radio tied to a specific band.
#
# The wireless configuration needs to have been loaded prior to this function
# being invoked.
#
# input: $1 device - name of the device
# return: 0 if the device operates on 5 GHz; otherwise 1
whc_is_5g_radio() {
    local hwmode
    config_get hwmode $1 hwmode '11ng'

    case "$hwmode" in
        11axa|11ac|11na|11a)
            return 0
        ;;

        *)
            return 1
        ;;
    esac
}

# Determine if the VAP provided (identified by its section name) operates
# on 5 GHz or not.
#
# See the caveat about this being intended for platforms where each radio is
# dedicated to a band as mentioned in the __repacd_is_5g_radio documentation
# above.
#
# The wireless configuration needs to have been loaded prior to this function
# being invoked.
#
# input: $1 vap - name of the wifi-iface section
# return: 0 if the VAP operates on 5 GHz; otherwise 1
whc_is_5g_vap() {
    local device
    config_get device $1 device

    whc_is_5g_radio $device
    return $?
}
