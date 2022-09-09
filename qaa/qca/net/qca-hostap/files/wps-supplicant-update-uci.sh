#!/bin/sh
#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
# Copyright (c) 2014, The Linux Foundation. All rights reserved.
#

IFNAME=$1
CMD=$2

if [ $CMD = "CONNECTED" ]; then
	ker_ver=`uname -r |cut -d. -f1`
	if [ $ker_ver == 5 ]; then
		. /sbin/wifi config
	else
		. /sbin/wifi detect
	fi
fi

parent=$(cat /sys/class/net/${IFNAME}/parent)

is_section_ifname() {
	local config=$1
	local ifname
	config_get ifname "$config" ifname
	[ "${ifname}" = "$2" ] && eval "$3=$config"
}

# Obtain the named configuration value in the supplicant config file,
# stripping off any double quotes.
#
# Return the value in the config_val global variable.
get_config_val() {
	local conf=$1
	local key=$2

	# This finds the last key in the supplicant config and strips off leading
	# and trailing quotes (if it has them).
	#
	# Note that it uses a leading space to ensure that only an exact match
	# on the key is used.
	config_val=$(awk "BEGIN{FS=\"=\"} /[[:space:]]${key}=/ {print \$0}" $conf |grep "${key}=" |tail -n 1 | cut -f 2 -d= | sed -e 's/^"\(.*\)"/\1/')
}

get_ssid() {
	local conf=$1

	get_config_val $conf 'ssid'
	ssid=${config_val}
}

get_wpa_version() {
	local conf=$1

	local proto_key_str
	get_config_val $conf 'proto'
	proto_key_str="${config_val}"

	get_config_val $conf 'key_mgmt'
	proto_key_str="${proto_key_str} ${config_val}"

	case "${proto_key_str}" in
		"RSN WPA-PSK")
			wpa_version="WPA2-PSK"
			;;

		"WPA WPA-PSK")
			wpa_version="WPA-PSK"
			;;

		"RSN WPA-PSK SAE")
			wpa_version="WPA3-PSK"
			;;

		"RSN SAE")
			wpa_version="WPA3-SAE"
			;;

		# Since the proto key does not appear when no encryption
		# is being used, we need to match against all possible
		# combinations since the proto might have been extracted
		# from a previous network section.
		" NONE"|"RSN NONE"|"WPA NONE")
			wpa_version="NONE"
			;;
	esac
}

get_psk() {
	local conf=$1

	get_config_val $conf 'psk'
	psk=${config_val}
}

wps_pbc_enhc_get_clone_config() {
	if [ -r $wps_pbc_enhc_file ]; then
		local overwrite_ap_all=$(awk "/\-:overwrite_ap_settings_all/ {print;exit}" $wps_pbc_enhc_file | sed "s/\-://")
		local overwrite_sta_all=$(awk "/\-:overwrite_sta_settings_all/ {print;exit}" $wps_pbc_enhc_file | sed "s/\-://")
		local overwrite_ap=$(awk "/$parent:overwrite_ap_settings/ {print;exit}" $wps_pbc_enhc_file | sed "s/$parent://")

		[ -n "$overwrite_ap_all" ] && \
			IFNAME_OVERWRITE_AP=$(awk "/:[0-9\-]*:[0-9\-]*:.*:clone/" $wps_pbc_enhc_file | cut -f1 -d:)

		[ -n "$overwrite_sta_all" ] && \
			IFNAME_OVERWRITE_STA=$(awk "/:[0-9\-]*:[0-9\-]*:.*:clone/" $wps_pbc_enhc_file | cut -f1 -d:)

		[ -z "$overwrite_ap_all" -a -n "$overwrite_ap" ] && \
			IFNAME_OVERWRITE_AP=$(awk "/:[0-9\-]*:[0-9\-]*:$parent:clone/" $wps_pbc_enhc_file | cut -f1 -d:)
	fi
}

wps_pbc_enhc_overwrite_ap_settings() {
	local ifname_overwrite=$1
	local ssid_overwrite=$2
	local auth_overwrite=$3
	local encr_overwrite=$4
	local key_overwrite=
	local parent_overwrite=$(cat /sys/class/net/${ifname_overwrite}/parent)
	local ssid_suffix=$(awk "/\-:overwrite_ssid_suffix:/ {print;exit}" $wps_pbc_enhc_file | \
						sed "s/\-:overwrite_ssid_suffix://")
	local ssid_band_suffix=$(awk "/$parent_overwrite:overwrite_ssid_band_suffix:/ {print;exit}" $wps_pbc_enhc_file | \
						sed "s/$parent_overwrite:overwrite_ssid_band_suffix://")

	[ "${auth_overwrite}" = "SAE" -o "${auth_overwrite}" = "WPA2PSK" -o "${auth_overwrite}" = "WPAPSK" ] && key_overwrite=$5

	if [ -r /var/run/hostapd-${parent_overwrite}/${ifname_overwrite} ]; then
		hostapd_cli -i${ifname_overwrite} -p/var/run/hostapd-${parent_overwrite} wps_config \
			${ssid_overwrite}${ssid_suffix}${ssid_band_suffix} ${auth_overwrite} ${encr_overwrite} ${key_overwrite}
	fi
}

wps_pbc_enhc_overwrite_sta_settings() {
	local ifname_overwrite=$1
	local ssid_overwrite=$2
	local auth_overwrite=$3
	local key_overwrite=
	local key_overwrite_len=
	local nw=
	local sect=
	config_foreach is_section_ifname wifi-iface $ifname_overwrite sect

	[ "${auth_overwrite}" = "WPA3-SAE" -o "${auth_overwrite}" = "WPA3-PSK" -o "${auth_overwrite}" = "WPA2-PSK" -o "${auth_overwrite}" = "WPA-PSK" ] && {
		key_overwrite=$4
		key_overwrite_len=${#key_overwrite}
	}

	if [ -r /var/run/wpa_supplicant-${ifname_overwrite} ]; then
		nw=`wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} add_network | cut -d ' ' -f 4`
		wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw ssid \"${ssid_overwrite}\"
		uci set wireless.${sect}.ssid="$ssid_overwrite"
		case $auth_overwrite in
			WPA3-SAE)
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw key_mgmt SAE
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw ieee80211w 2
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw sae 1
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw auth_alg OPEN
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw pairwise CCMP
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw proto RSN
				if [ $key_overwrite_len -eq 64 ]; then
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk ${key_overwrite}
				else
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk \"${key_overwrite}\"
				fi
				uci set wireless.${sect}.encryption='ccmp'
				uci set wireless.${sect}.sae_password=$key_overwrite
				uci set wireless.${sect}.sae=1
				uci set wireless.${sect}.key=''
			;;
                        WPA3-PSK)
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw key_mgmt WPA-PSK SAE
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw ieee80211w 1
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw sae 1
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw auth_alg OPEN
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw pairwise CCMP
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw proto RSN
				if [ $key_overwrite_len -eq 64 ]; then
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk ${key_overwrite}
				else
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk \"${key_overwrite}\"
				fi
				uci set wireless.${sect}.encryption='psk2+ccmp'
				uci set wireless.${sect}.key=$key_overwrite
				uci set wireless.${sect}.sae='1'
			;;

			WPA2-PSK)
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw key_mgmt WPA-PSK
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw auth_alg OPEN
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw pairwise CCMP
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw proto RSN
				if [ $key_overwrite_len -eq 64 ]; then
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk ${key_overwrite}
				else
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk \"${key_overwrite}\"
				fi
				uci set wireless.${sect}.encryption='psk2'
				uci set wireless.${sect}.key=$key_overwrite
			;;
			WPA-PSK)
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw key_mgmt WPA-PSK
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw auth_alg OPEN
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw pairwise TKIP
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw proto WPA
				if [ $key_overwrite_len -eq 64 ]; then
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk ${key_overwrite}
				else
					wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw psk \"${key_overwrite}\"
				fi
				uci set wireless.${sect}.encryption='psk'
				uci set wireless.${sect}.key=$key_overwrite
			;;
			NONE)
				wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} set_network $nw key_mgmt NONE
				uci set wireless.${sect}.encryption='none'
				uci set wireless.${sect}.key=''
			;;
		esac
		wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} enable_network $nw
		wpa_cli -p /var/run/wpa_supplicant-${ifname_overwrite} save_config
	fi
}

psk=
ssid=
wpa_version=
IFNAME_OVERWRITE_AP=
IFNAME_OVERWRITE_STA=
wps_pbc_enhc_file=/var/run/wifi-wps-enhc-extn.conf

case "$CMD" in
	CONNECTED)
		wpa_cli -i$IFNAME -p/var/run/wpa_supplicant-$IFNAME save_config

		# Read the configuration from the file to avoid a potential
		# race where the supplicant is not in the associated state when
		# its status command is executed.
		get_ssid /var/run/wpa_supplicant-$IFNAME.conf
		get_wpa_version /var/run/wpa_supplicant-$IFNAME.conf
		get_psk /var/run/wpa_supplicant-$IFNAME.conf
		wps_pbc_enhc_get_clone_config
		sect=
		config_foreach is_section_ifname wifi-iface $IFNAME sect
		case $wpa_version in
			WPA2-PSK)
				uci set wireless.${sect}.encryption='psk2'
				uci set wireless.${sect}.key=$psk
				for intf in $IFNAME_OVERWRITE_AP; do
					wps_pbc_enhc_overwrite_ap_settings $intf $ssid WPA2PSK CCMP $psk
				done
				;;
			WPA-PSK)
				uci set wireless.${sect}.encryption='psk'
				uci set wireless.${sect}.key=$psk
				for intf in $IFNAME_OVERWRITE_AP; do
					wps_pbc_enhc_overwrite_ap_settings $intf $ssid WPAPSK TKIP $psk
				done
				;;
			WPA2-PSK-SHA256)
				uci set wireless.${sect}.encryption='psk2'
				uci set wireless.${sect}.key=$psk
				for intf in $IFNAME_OVERWRITE_AP; do
					wps_pbc_enhc_overwrite_ap_settings $intf $ssid WPA2PSK CCMP $psk
				done
				;;
			WPA3-PSK)
				uci set wireless.${sect}.encryption='psk2+ccmp'
				uci set wireless.${sect}.key=$psk
				uci set wireless.${sect}.sae='1'
				for intf in $IFNAME_OVERWRITE_AP; do
					wps_pbc_enhc_overwrite_ap_settings $intf $ssid WPA2PSK CCMP $psk
				done
				;;
			WPA3-SAE)
				uci set wireless.${sect}.encryption='ccmp'
				uci set wireless.${sect}.sae_password=$psk
				uci set wireless.${sect}.sae='1'
				uci set wireless.${sect}.key=''
				for intf in $IFNAME_OVERWRITE_AP; do
					wps_pbc_enhc_overwrite_ap_settings $intf $ssid SAE CCMP $psk
				done
				;;

			NONE)
				uci set wireless.${sect}.encryption='none'
				uci set wireless.${sect}.key=''
				for intf in $IFNAME_OVERWRITE_AP; do
					wps_pbc_enhc_overwrite_ap_settings $intf $ssid OPEN NONE
				done
				;;
		esac
		uci set wireless.${sect}.ssid="$ssid"
		for intf in $IFNAME_OVERWRITE_STA; do
			[ "$IFNAME" != "$intf" ] && wps_pbc_enhc_overwrite_sta_settings $intf $ssid $wpa_version $psk
		done
		uci commit
		if [ -r /var/run/wifi-wps-enhc-extn.pid ]; then
			echo $IFNAME > /var/run/wifi-wps-enhc-extn.done
			kill -SIGUSR1 "$(cat "/var/run/wifi-wps-enhc-extn.pid")"
		fi
		kill "$(cat "/var/run/wps-hotplug-$IFNAME.pid")"
		#post hotplug event to whom take care of
		env -i ACTION="wps-connected" INTERFACE=$IFNAME /sbin/hotplug-call iface
		;;
	WPS-TIMEOUT)
		kill "$(cat "/var/run/wps-hotplug-$IFNAME.pid")"
		env -i ACTION="wps-timeout" INTERFACE=$IFNAME /sbin/hotplug-call iface
		;;
	DISCONNECTED)
		;;
esac

