#
# Copyright (c) 2010, 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# 2014 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

. /lib/functions.sh

check_qwrap_enabled() {
	local device=$1
    config_get disabled "$device" disabled 0
    config_get qwrap_enable "$device" qwrap_enable 0

    [[ "$disabled" -eq 0  && "$qwrap_enable" -gt 0 ]] || return

    start_qwrap=1
}

qwrap_setup_wifi() {
	local device=$1
    local wrapd_vma_conf="NONE"
    wrapd_global_ctrl_iface="/var/run/wrapdglobal"

    config_get wrapd_vma $device wrapd_vma 0
    if [ "$wrapd_vma" -ne 0 ]; then
        wrapd_vma_conf="/etc/ath/wrap-vma-$device.conf"
    fi

	config_get disabled "$device" disabled 0
	config_get qwrap_enable "$device" qwrap_enable 0

   [[ "$disabled" -eq 0  && "$qwrap_enable" -gt 0 ]] || return

    wrapd -S -g $wrapd_global_ctrl_iface wifi_add $device $wrapd_vma_conf
}

qwrap_parse_ap() {
	local device=$1
	local radioidx=${device#wifi}
    conf="OPEN"
	local cmd_type="INIT"

	config_get disabled "$device" disabled 0
	config_get qwrap_enable "$device" qwrap_enable 0

	[ "$disabled" -eq 0 ] || return

	config_get vifs $device vifs

	for vif in $vifs; do
		local vifname

		config_get vifname "$vif" ifname

        config_get enc "$vif" encryption "none"

        case "$enc" in
            mixed*|psk*|wpa*|8021x|none|wep*|ccmp*|gcmp*)
                conf="/var/run/hostapd-$vifname.conf"
                ;;
        esac

		config_get mode "$vif" mode

		case "$mode" in
			wrap|ap)
                config_get extender_device "$vif" extender_device $device
                [ -z "$extender_device" ] || {
                   wrapd -S -g $wrapd_global_ctrl_iface ap_add $extender_device $vifname $conf $cmd_type
                }
			;;
		esac
	done

	config_get_bool ap_isolation_enabled $device ap_isolation_enabled 0

	if [ $ap_isolation_enabled -ne 0 ]; then
		iso="-I"
		echo '1 1' > /proc/wrap$radioidx
	fi

}

qwrap_parse_sta() {
	local device=$1
	local radioidx=${device#wifi}
	local sta_vap=0
	local cmd_type="INIT"

	config_get disabled "$device" disabled 0
	config_get qwrap_enable "$device" qwrap_enable 0

	[ "$disabled" -eq 0 ] || return

	config_get vifs $device vifs

	for vif in $vifs; do
		local vifname

		config_get vifname "$vif" ifname

		config_get mode "$vif" mode

		case "$mode" in
			sta)
				[ "$qwrap_enable" -gt 0 ] || continue
                                echo "sta_vap is there for " $device
                                sta_vap=1

				wrap_sta_macaddr="$(cat /sys/class/net/${vifname}/address)"

				config_load network
				net_cfg="$(find_net_config "$vif")"
				config_set "$net_cfg" macaddr "$wrap_sta_macaddr"

				[ -z "$net_cfg" ] || {
                                        if [ $sta_mac_set_to_bridge -eq 0 ]; then
                                                echo "QWRAP-Adding mac address to bridge sta_mac" $wrap_sta_macaddr
                                                sta_mac_set_to_bridge=1
                                                bridge="$(bridge_interface "$net_cfg")"
                                                ifconfig "$bridge" hw ether "$wrap_sta_macaddr"
                                        else
                                                echo "QWRAP-Already bridge mac is set ignoring mac" $wrap_sta_macaddr
                                        fi
				}
                tmp_conf_file=$(cat "/tmp/qwrap_conf_filename-$vifname.conf")
                wrapd -S -g $wrapd_global_ctrl_iface sta_add $device $vifname $tmp_conf_file $cmd_type
			;;
		esac
	done
}

qwrap_setup() {

    local start_qwrap=0
    local sta_mac_set_to_bridge=0
    local aprim=""
    local qwrap_eth_list=""
    local driver_mode=""
    config_load wireless
    local enable_cfg80211=`uci show qcacfg80211.config.enable |grep "qcacfg80211.config.enable='1'"`
    local wrapd_psta_config=0

    config_foreach check_qwrap_enabled wifi-device

    if [ "$start_qwrap" -eq 0 ]; then
        return 1
    fi
	wpa_supplicant_global_ctrl_iface="/var/run/wpa_supplicantglobal"
    hostapd_global_ctrl_iface="/var/run/hostapd/global"
    wrapd_global_ctrl_iface="/var/run/wrapdglobal"
    config_get alwaysprimary qcawifi alwaysprimary 0
	config_get qwrap_br_name qcawifi qwrap_br_name "br-lan"
	config_get qwrap_sta_limit qcawifi qwrap_sta_limit 20
	config_get qwrap_poll_timer qcawifi qwrap_poll_timer 1
	config_get qwrap_eth_sta_del_en qcawifi qwrap_eth_sta_del_en 1
	config_get qwrap_eth_sta_add_en qcawifi qwrap_eth_sta_add_en 1
	config_get qwrap_eth_name qcawifi qwrap_eth_name "eth1"
	config_get qwrap_dbglvl qcawifi qwrap_dbglvl 0
	config_get qwrap_dbglvl_high qcawifi qwrap_dbglvl_high 0
	[ -n "$enable_cfg80211" ] && driver_mode="-m"

    for eth in $qwrap_eth_name; do
        append qwrap_eth_list "-i $eth "
    done

    bridge_conf_file="-b $qwrap_br_name $qwrap_eth_list
        -l $qwrap_sta_limit -t $qwrap_poll_timer
        -e $qwrap_eth_sta_add_en -r $qwrap_eth_sta_del_en"

    qwrap_debug="-F l:$qwrap_dbglvl -F h:$qwrap_dbglvl_high"

    if [ "$alwaysprimary" -eq 0 ]; then
        wrapd_psta_config=0
    fi
    if [ "$alwaysprimary" -eq 1 ]; then
        wrapd_psta_config=2
    fi
        aprim="-a $wrapd_psta_config"

	wrapd_pid="/var/run/wrapd-global.pid"
	if [ -f "/var/run/wrapd-global.pid" ] && [ -e /proc/$(cat "/var/run/wrapd-global.pid") ]; then
		echo "Not starting 2nd wrapd since process is already running"
		return 1
	fi
	wrapd ${iso} -P $wrapd_pid -g $wrapd_global_ctrl_iface -H $hostapd_global_ctrl_iface -w $wpa_supplicant_global_ctrl_iface $bridge_conf_file $qwrap_debug $aprim $driver_mode > /dev/console 2>&1 &

    config_foreach qwrap_setup_wifi wifi-device
	config_foreach qwrap_parse_sta wifi-device
    config_load wireless
	config_foreach qwrap_parse_ap wifi-device

	return 1
}

qwrap_unconfig() {
	local device=$1
	local radioidx=${device#wifi}

	config_get vifs $device vifs

	for vif in $vifs; do
		local vifname

		config_get vifname "$vif" ifname

		config_get mode "$vif" mode

		case "$mode" in
			sta)
				config_load network
				net_cfg="$(find_net_config "$vif")"

				[ -z "$net_cfg" ] || {

					bridge="$(bridge_interface "$net_cfg")"
					cd /sys/class/net/${bridge}/brif

					for eth in $(ls -d eth* 2>&-); do
						br_macaddr="$(cat /sys/class/net/${eth}/address)"
						[ -n "$br_macaddr" ] && break
					done

					ifconfig "$bridge" hw ether "$br_macaddr"
				}
	                        [ -f "/tmp/qwrap_conf_filename-$vifname.conf" ] &&
		                        rm /tmp/qwrap_conf_filename-$vifname.conf
			;;
		esac
	done
}

qwrap_teardown() {
    config_load wireless
    if [ -f "/var/run/wrapd-global.pid" ] && [ -e /proc/$(cat "/var/run/wrapd-global.pid") ]; then
        kill "$(cat "/var/run/wrapd-global.pid")"
        rm -rf /var/run/wrapd-global.pid
        rm -rf $wrapd_global_ctrl_iface
        config_foreach qwrap_unconfig wifi-device
    fi
}
