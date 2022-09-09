#!/bin/sh
#
# Copyright (c) 2019 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

hostap_enable() {
	hostapd_cli -i $1 -p /var/run/hostapd-$2 enable
}

hostap_disable() {
	hostapd_cli -i $1 -p /var/run/hostapd-$2 disable
}

hostap_reconfig() {
	wpa_cli -g /var/run/hostapd/global raw REMOVE $1
	wpa_cli -g /var/run/hostapd/global raw ADD bss_config=$1:/var/run/hostapd-$1.conf
}

IFNAME=$1
PARENT=$(cat /sys/class/net/${IFNAME}/parent)

case "$2" in
	enable) hostap_enable $IFNAME $PARENT;;
	disable) hostap_disable $IFNAME $PARENT;;
	reconfig) hostap_reconfig $IFNAME;;
	*)  echo "Invalid arguments. USAGE: hapd <ifname> <enable/disable/reconfig>";;
esac
