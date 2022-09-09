#!/bin/sh
#
# Copyright (c)2013,  2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
# 2013 Qualcomm Atheros, Inc..
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

IFNAME=$1
CMD=$2

parent=$(cat /sys/class/net/${IFNAME}/parent)

is_section_ifname() {
	local config=$1
	local ifname
	config_get ifname "$config" ifname
	[ "${ifname}" = "$2" ] && eval "$3=$config"
}

case "$CMD" in
	WPS-NEW-AP-SETTINGS)
		sleep 1
		ssid=$(hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent get_config | grep ^ssid= | cut -f2- -d =)
		wpa=$(hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent get_config | grep ^wpa= | cut -f2- -d=)
		psk=$(hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent get_config | grep ^passphrase= | cut -f2- -d=)
		wps_state=$(hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent get_config | grep ^wps_state= | cut -f2- -d=)
		key_mgmt=$(hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent get_config | grep ^key_mgmt= | cut -f2- -d=)

		hostapd_cli -i ${IFNAME} -p /var/run/hostapd-$parent disable
		hostapd_cli -i ${IFNAME} -p /var/run/hostapd-$parent enable
		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi

		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect

		[ -n "$psk" ] || psk=$(hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent get_config | grep ^psk= | cut -f2- -d=)

		case "$wps_state" in
			configured*)
				uci set wireless.${sect}.wps_state=2
				;;
			"not configured"*)
				uci set wireless.${sect}.wps_state=1
				;;
			*)
				uci set wireless.${sect}.wps_state=0
		esac

		case "$wpa" in
			3)
				uci set wireless.${sect}.encryption='mixed-psk'
				uci set wireless.${sect}.key=$psk
				;;
			2)
				case "$key_mgmt" in
					"SAE")
						uci set wireless.${sect}.sae=1
						uci set wireless.${sect}.encryption='ccmp'
						uci add_list wireless.${sect}.sae_password=$psk
						uci set wireless.${sect}.key=''
					;;
					"WPA-PSK SAE")
						uci set wireless.${sect}.sae=1
						uci set wireless.${sect}.key=$psk
						uci set wireless.${sect}.encryption='psk2+ccmp'
					;;
					*)
						uci set wireless.${sect}.encryption='psk2'
						uci set wireless.${sect}.key=$psk
					;;
                                esac
				;;
			1)
				uci set wireless.${sect}.encryption='psk'
				uci set wireless.${sect}.key=$psk
				;;
			*)
				uci set wireless.${sect}.encryption='none'
				uci set wireless.${sect}.key=''
				;;
		esac

		uci set wireless.${sect}.ssid="$ssid"
		uci commit
		if [ -r /var/run/wifi-wps-enhc-extn.pid ]; then
			echo $IFNAME > /var/run/wifi-wps-enhc-extn.done
			kill -SIGUSR1 "$(cat "/var/run/wifi-wps-enhc-extn.pid")"
		fi
		kill "$(cat "/var/run/hostapd-cli-$IFNAME.pid")"
		#post hotplug event to whom take care of
		env -i ACTION="wps-configured" INTERFACE=$IFNAME /sbin/hotplug-call iface
		;;
	WPS-TIMEOUT)
		kill "$(cat "/var/run/hostapd-cli-$IFNAME.pid")"
		env -i ACTION="wps-timeout" INTERFACE=$IFNAME /sbin/hotplug-call iface
		;;
	WPS-SUCCESS)
		if [ -r /var/run/wifi-wps-enhc-extn.pid ]; then
			echo $IFNAME > /var/run/wifi-wps-enhc-extn.done
			kill -SIGUSR1 "$(cat "/var/run/wifi-wps-enhc-extn.pid")"
		fi
		kill "$(cat "/var/run/hostapd-cli-$IFNAME.pid")"
		env -i ACTION="wps-success" INTERFACE=$IFNAME /sbin/hotplug-call iface
		;;
	DISCONNECTED)
		kill "$(cat "/var/run/hostapd_cli-$IFNAME.pid")"
		;;
esac
