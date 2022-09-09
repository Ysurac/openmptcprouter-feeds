#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
# Copyright (c) 2014, The Linux Foundation. All rights reserved.
#

restrict_pbc_for_sta_iface() {
	local config=$1
	local ifname
	config_get ifname "$config" ifname
	local wps_pbc_skip
	config_get wps_pbc_skip "$config" wps_pbc_skip 0
	local mode
	config_get mode "$config" mode

	config_get MapBSSType "$config" MapBSSType
	config_get map "$config" map

	# MapBSSType 128, vap is backhaul STA
	if [ $MapBSSType -eq 128 ]; then
		multi_ap=$map
	fi


	if ([ $wps_pbc_skip -eq 0 ] && [ "$dir" = "/var/run/wpa_supplicant-$ifname" ]) ||
	   ([ $mode == "sta" ] && iwconfig $ifname | head -2 | tail -1 | grep -q "Not-Associated" ); then
		wpa_cli -p "$dir" wps_pbc multi_ap=$multi_ap
		[ -f $pid ] || {
			wpa_cli -p"$dir" -a/lib/wifi/wps-supplicant-update-uci -P$pid -B
		}
	fi
}

pid=
if [ "$ACTION" = "pressed" -a "$BUTTON" = "wps" ]; then
    [ -r /var/run/son_active ] && exit 0
	if [ -r /var/run/wifi-wps-enhc-extn.conf ] &&
		[ ! -r /var/run/son.conf ]; then
		exit 0
	fi
	config_load wireless
	for dir in /var/run/wpa_supplicant-*; do
		[ -d "$dir" ] || continue
		pid=/var/run/wps-hotplug-${dir#"/var/run/wpa_supplicant-"}.pid
		config_foreach restrict_pbc_for_sta_iface wifi-iface
	done
fi
