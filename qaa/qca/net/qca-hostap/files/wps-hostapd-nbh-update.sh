#!/bin/sh
#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

IFNAME=$1
CMD=$2

local parent=$(cat /sys/class/net/${IFNAME}/parent)

case "$CMD" in
	WPS-TIMEOUT)
		kill "$(cat "/var/run/hostapd-cli-$IFNAME.pid")"
		env -i ACTION="wps-timeout" INTERFACE=$IFNAME /sbin/hotplug-call iface
		;;
	WPS-SUCCESS)
		if [ -r /var/run/iface_mgr.pid ]; then
			echo $IFNAME > /var/run/son_nbh.done
			kill -SIGUSR1 "$(cat "/var/run/iface_mgr.pid")"
		fi
		kill "$(cat "/var/run/hostapd-cli-$IFNAME.pid")"
		env -i ACTION="wps-success" INTERFACE=$IFNAME /sbin/hotplug-call iface
		;;
	DISCONNECTED)
		kill "$(cat "/var/run/hostapd_cli-$IFNAME.pid")"
		;;
esac
