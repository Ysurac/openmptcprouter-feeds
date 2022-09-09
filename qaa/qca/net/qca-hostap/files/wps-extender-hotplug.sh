#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
# Copyright (c) 2015, The Linux Foundation. All rights reserved.
#

if [ "$ACTION" = "pressed" -a "$BUTTON" = "wps" ]; then
	if [ -r /var/run/son.conf ] ||
		[ -r /var/run/son_active ]; then
		exit 0
	fi
	[ -r /var/run/wifi-wps-enhc-extn.conf ] || exit 0
	echo "" > /dev/console
	echo "WPS PUSH BUTTON EVENT DETECTED" > /dev/console

	num=`grep -w "RADIO" /var/run/wifi-wps-enhc-extn.conf | wc -l`

	if [ -r /var/run/wifi-wps-enhc-extn.pid ]; then
		kill "$(cat "/var/run/wifi-wps-enhc-extn.pid")"
		sleep 1
	fi

	if [ -r /var/run/wifi-wps-enhc-extn.pid ]; then
		rm -f /var/run/wifi-wps-enhc-extn.pid
		exit 0
	fi

	echo "START APP TO HANDLE WPS PUSH BUTTON EVENT" > /dev/console
	/usr/sbin/wps_enhc -b /var/run/wifi-wps-enhc-extn.pid -n $num \
				-d 128 -l /var/run/wifi-wps-enhc-extn.log
fi

