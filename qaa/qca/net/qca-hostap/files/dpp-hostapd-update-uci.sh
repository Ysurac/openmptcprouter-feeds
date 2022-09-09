#!/bin/sh
#
# Copyright (c) 2018 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

[ -e /lib/functions.sh ] && . /lib/functions.sh

IFNAME=$1
CMD=$2
CONFIG=$3
shift
shift
SSID=$@
PASS=$@

parent=$(cat /sys/class/net/${IFNAME}/parent)

is_section_ifname() {
	local config=$1
	local ifname
	config_get ifname "$config" ifname
	[ "${ifname}" = "$2" ] && eval "$3=$config"
}

hex2string()
{
	I=0
	while [ $I -lt ${#1} ];
	do
		echo -en "\x"${1:$I:2}
		let "I += 2"
	done
}


case "$CMD" in
	DPP-CONF-RECEIVED)
		rsn_pairwise=
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa 2
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_key_mgmt DPP
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set ieee80211w 1
		if [ -f /sys/class/net/$parent/ciphercaps ]
		then
			cat /sys/class/net/$parent/ciphercaps | grep -i "gcmp"
			if [ $? -eq 0 ]
			then
				rsn_pairwise="CCMP CCMP-256 GCMP GCMP-256"
			else
				rsn_pairwise="CCMP"
			fi
		fi
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set rsn_pairwise "$rsn_pairwise"
		;;
	DPP-CONFOBJ-AKM)
		encryption=
		sae=
		dpp=
		case "$CONFIG" in
			dpp)
				hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_key_mgmt "DPP"
				encryption="dpp"
				ieee80211w=1
				dpp=1
				sae=0
				;;
			sae)
				hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_key_mgmt "DPP SAE"
				encryption="ccmp"
				sae=1
				ieee80211w=2
				dpp=0
				;;
			psk+sae)
				hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_key_mgmt "DPP WPA-PSK SAE"
				encryption="psk2+ccmp"
				sae=1
				ieee80211w=1
				dpp=0
				;;
			psk)
				hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_key_mgmt "DPP WPA-PSK"
				encryption="psk2"
				ieee80211w=1
				dpp=0
				sae=0
				;;
			dpp+sae)
				hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_key_mgmt "DPP SAE"
				encryption="ccmp"
				ieee80211w=2
				dpp=1
				sae=1
				;;
			dpp+psk+sae)
				hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_key_mgmt "DPP WPA-PSK SAE"
				encryption="psk2+ccmp"
				sae=1
				ieee80211w=1
				dpp=1
				;;
		esac

		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.encryption=$encryption
		uci set wireless.${sect}.sae=$sae
		uci set wireless.${sect}.dpp=$dpp
		uci set wireless.${sect}.ieee80211w=$ieee80211w
		uci commit wireless
		;;
	DPP-CONFOBJ-SSID)
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set ssid "$SSID"

		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.ssid="$SSID"
		uci commit wireless
		;;
	DPP-CONNECTOR)
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set dpp_connector $CONFIG

		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.dpp_connector=$CONFIG
		uci commit wireless
		;;
	DPP-1905-CONNECTOR)
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set dpp_1905_connector $CONFIG
		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.dpp_1905_connector=$CONFIG
		uci commit wireless
		;;
	DPP-CONFOBJ-PASS)
		PASS_STR=$(hex2string $PASS)
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_passphrase "$PASS_STR"

		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.key="$PASS_STR"
		uci commit wireless

		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent dpp_bootstrap_remove \*
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent disable
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent enable
		;;
	DPP-CONFOBJ-PSK)
		PASS_STR=$(hex2string "$CONFIG")
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set wpa_psk $PASS_STR

		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.key=$PASS_STR
		uci commit wireless

		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent dpp_bootstrap_remove \*
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent disable
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent enable
		;;
	DPP-C-SIGN-KEY)
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set dpp_csign $CONFIG

		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.dpp_csign=$CONFIG
		uci commit wireless
		;;
	DPP-NET-ACCESS-KEY)
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent set dpp_netaccesskey $CONFIG

		ker_ver=`uname -r |cut -d. -f1`
		if [ $ker_ver == 5 ]; then
			. /sbin/wifi config
		else
			. /sbin/wifi detect
		fi
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		uci set wireless.${sect}.dpp_netaccesskey=$CONFIG
		uci commit wireless

		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent disable
		hostapd_cli -i$IFNAME -p/var/run/hostapd-$parent enable
		;;
esac
