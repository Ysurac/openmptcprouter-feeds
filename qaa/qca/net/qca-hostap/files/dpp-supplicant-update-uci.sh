#!/bin/sh
#
# Copyright (c) 2019 Qualcomm Technologies, Inc.
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
pairwise=
map=

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

get_map_config() {
	local config="$1"
	local ifname
	config_get ifname "$config" ifname
	[ "${ifname}" = "$2" ] && config_get map "$config" map 0
}

is_map_config() {
	config_load wireless
	config_foreach get_map_config wifi-iface $1
}

get_pairwise() {
	if [ -f /sys/class/net/$parent/ciphercaps ]
	then
		cat /sys/class/net/$parent/ciphercaps | grep -i "gcmp"
		if [ $? -eq 0 ]
		then
			pairwise="CCMP CCMP-256 GCMP GCMP-256"
		else
			pairwise="CCMP"
		fi
	fi
}

case "$CMD" in
	DPP-CONF-RECEIVED)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME remove_network all
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME add_network
		get_pairwise
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 pairwise $pairwise
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 group "CCMP"
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 proto "RSN"
		;;
	DPP-CONFOBJ-AKM)
		encryption=
		sae=
		dpp=
		sae_require_mfp=
		ieee80211w=
		key_mgmt=
		is_map_config $IFNAME
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 multi_ap_profile $map
		if [ $map -gt 0 ]
		then
			wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 multi_ap_backhaul_sta 1
		fi
		case "$CONFIG" in
			dpp+psk+sae)
				key_mgmt="DPP SAE WPA-PSK"
				encryption="psk2+ccmp"
				sae=1
				dpp=1
				ieee80211w=1
				sae_require_mfp=1
				;;
			dpp+sae)
				key_mgmt="DPP SAE"
				encryption="ccmp"
				sae=1
				ieee80211w=2
				dpp=1
				;;
			dpp)
				key_mgmt="DPP"
				encryption="dpp"
				ieee80211w=1
				dpp=1
				sae=0
				;;
			sae)
				key_mgmt="SAE"
				encryption="ccmp"
				sae=1
				ieee80211w=2
				dpp=0
				;;
			psk+sae)
				key_mgmt="SAE WPA-PSK"
				encryption="psk2+ccmp"
				sae=1
				ieee80211w=1
				sae_require_mfp=1
				dpp=0
				;;
			psk)
				key_mgmt="WPA-PSK"
				encryption="psk2"
				ieee80211w=1
				dpp=0
				sae=0
				;;
		esac
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 ieee80211w $ieee80211w
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 key_mgmt $key_mgmt

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
		uci set wireless.${sect}.sae_require_mfp=$sae_require_mfp
		uci set wireless.${sect}.dpp=$dpp
		uci set wireless.${sect}.ieee80211w=$ieee80211w
		uci commit wireless
		;;
	DPP-CONFOBJ-SSID)
		network_ids=
		i=0
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME list_network | wc -l  > /tmp/count_network_list.txt
		read network_ids < /tmp/count_network_list.txt

		while [ $i -lt $network_ids ]
		do
			wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network $i ssid \""$SSID"\"
			i=$(expr $i + 1)
		done

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
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_connector $CONFIG
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 dpp_connector \"${CONFIG}\"

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
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_1905_connector $CONFIG

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
		network_ids=
		i=0

		PASS_STR=$(hex2string $PASS)
		get_pairwise
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME list_network | wc -l  > /tmp/count_network_list.txt
		read network_ids < /tmp/count_network_list.txt

		while [ $i -lt $network_ids ]
		do
			wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network $i psk \"${PASS_STR}\"
			wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network $i pairwise $pairwise
			i=$(expr $i + 1)
		done

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

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME dpp_bootstrap_remove \*
		i=0
		while [ $i -lt $network_ids ]
		do
			wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME enable_network $i
			wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME save_config
			i=$(expr $i + 1)
		done
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME disable
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME enable
		;;
	DPP-CONFOBJ-PSK)
		network_ids=
		i=0

		PASS_STR=$(hex2string "$CONFIG")
		get_pairwise
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME list_network | wc -l  > /tmp/count_network_list.txt
		read network_ids < /tmp/count_network_list.txt

		while [ $i -lt $network_ids ]
		do
			wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network $i psk $PASS_STR
			wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network $i pairwise $pairwise
			i=$(expr $i + 1)
		done

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

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME dpp_bootstrap_remove \*
		i=0
		while [ $i -lt $network_ids ]
		do
			wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME enable_network $i
			wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME save_config
			i=$(expr $i + 1)
		done
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME disable
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME enable
		;;
	DPP-C-SIGN-KEY)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_csign $CONFIG
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 dpp_csign $CONFIG

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
		network_ids=
		i=0
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME list_network | wc -l  > /tmp/count_network_list.txt
		read network_ids < /tmp/count_network_list.txt

		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set dpp_netaccesskey $CONFIG
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME set_network 0 dpp_netaccesskey $CONFIG

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

		while [ $i -lt $network_ids ]
		do
			wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME enable_network $i
			wpa_cli -i$IFNAME -p /var/run/wpa_supplicant-$IFNAME save_config
			i=$(expr $i + 1)
		done
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME disable
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME enable
		;;
esac
