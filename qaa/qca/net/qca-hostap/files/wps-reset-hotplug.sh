#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
#
# Copyright (c) 2014, The Linux Foundation. All rights reserved.
#

if [ "$ACTION" = "released" -a "$BUTTON" = "wps" ]; then
	default_hold=3
	if [ -f /var/run/plchost.pid ]
	then
		default_hold=12
	fi
	if [ "$SEEN" -gt $default_hold ]; then
		echo "" > /dev/console
		echo "RESET TO FACTORY SETTING EVENT DETECTED" > /dev/console
		echo "PLEASE WAIT WHILE REBOOTING THE DEVICE..." > /dev/console
		rm -rf /overlay/*
		reboot
	fi
fi
