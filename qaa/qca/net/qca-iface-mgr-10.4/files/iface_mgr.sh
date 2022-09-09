#
# Copyright (c) 2016,2018 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# 2016 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

. /lib/functions.sh

pref_uplink_idx=0
same_ssid_support=0

iface_mgr_config() {
        local device=$1
        local ifidx=0
        local group0=0
        local group1=1
        local radioidx=${device#wifi}
        local iface_mgr_op_mode=$2
        config_get disabled "$device" disabled 0

        [ "$disabled" -eq 0 ] || return

        config_get fast_lane "$device" fast_lane 0
        config_get pref_uplink "$device" pref_uplink 0

        [ "$iface_mgr_op_mode" -eq 2 ] && [ "$fast_lane" -eq 0 ] && return

        config_get vifs $device vifs

        for vif in $vifs; do
                config_get_bool vap_disabled "$vif" disabled 0
                [ $vap_disabled = 0 ] || continue

                local vifname
                exclude_flag=0
                config_get vifname "$vif" ifname

                if [ -z $vifname ]; then
                        [ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"
                fi
                config_get mode "$vif" mode

		config_get group "$vif" group 0
		config_get exclude "$vif" exclude 0
		config_get wrap "$vif" wrap 0
		config_get extap "$vif" extap 0
		config_get device "$vif" device
		config_get lp_stavap "$vif" lp_stavap 0
		config_get hp_stavap "$vif" hp_stavap 0
		[ "$exclude" -gt 0 ] && exclude_flag=1
		[ "$wrap" -gt 0 ] && exclude_flag=1
		[ "$extap" -gt 0 ] && exclude_flag=1
                [ "$fast_lane" -gt 0 ] && exclude_flag=1

                case "$mode" in
                  ap | wrap)
                                [ $iface_mgr_op_mode -eq 4 ] && { \
                                        ifidx=$(($ifidx + 1))
                                        continue
                                }

                                [ $exclude_flag -ne 1 ] && { \
                                        ap_ifname="$vifname"
                                        echo "group=$group ap_vap=$ap_ifname" >> /var/run/iface_mgr.conf
                                        echo "radio=$device" >> /var/run/iface_mgr.conf
                                }
                                if [ $exclude_flag -eq 1 ] && [ $iface_mgr_op_mode -eq 2 ]; then
                                        [ $pref_uplink -eq 1 ] && {\
                                                ap_ifname="$vifname"
                                                echo "group=$group0 ap_vap=$ap_ifname" >> /var/run/iface_mgr.conf
                                        }
                                        [ $pref_uplink -eq 0 ] && { \
                                                ap_ifname="$vifname"
                                                echo "group=$group1 ap_vap=$ap_ifname" >> /var/run/iface_mgr.conf
                                        }
                                fi
                        ;;
                        sta)
                                [ $iface_mgr_op_mode -eq 4 ] && { \
                                        sta_ifname="$vifname"
                                        echo "group=$group sta_vap=$sta_ifname" >> /var/run/iface_mgr.conf
                                        ifidx=$(($ifidx + 1))
                                        continue
                                }
                                [ $exclude_flag -ne 1 ] && { \
                                        sta_ifname="$vifname"
					priority=0
                                        [ $hp_stavap -eq 1 ] && {\
					    priority=1
                                        }
                                        [ $lp_stavap -eq 1 ] && {\
					    priority=2
                                        }
                                        [ $priority -ne 0 ] && {\
                                        echo "group=$group sta_vap=$sta_ifname priority=$priority" >> /var/run/iface_mgr.conf
                                        }
                                        [ $priority -eq 0 ] && {\
                                        echo "group=$group sta_vap=$sta_ifname" >> /var/run/iface_mgr.conf
                                        }
                                }
                                if [ $exclude_flag -eq 1 ] && [ $iface_mgr_op_mode -eq 2 ]; then
                                        [ $pref_uplink -eq 1 ] && {\
                                                sta_ifname="$vifname"
                                                echo "group=$group1 sta_vap=$sta_ifname" >> /var/run/iface_mgr.conf
                                        }
                                        [ $pref_uplink -eq 0 ] && { \
                                                sta_ifname="$vifname"
                                                echo "group=$group0 sta_vap=$sta_ifname" >> /var/run/iface_mgr.conf
                                        }
                                fi
                        ;;
                esac
                ifidx=$(($ifidx + 1))
       done
}

iface_mgr_config_mode1() {
        iface_mgr_config $1 1
}

iface_mgr_config_mode2() {
        iface_mgr_config $1 2
}

iface_mgr_config_mode4() {
        iface_mgr_config $1 4
}

iface_mgr_setup() {

        local iface_mgr_op_mode=0
        local backhaul_cnt=0
        config_load wireless
        local plc_ifname
        local enable_cfg80211=`uci show qcacfg80211.config.enable |grep "qcacfg80211.config.enable='1'"`
        local enable_repacd=`uci show repacd.repacd.Enable |grep "repacd.repacd.Enable='1'"`
        local enable_wsplcd_map=`uci show wsplcd |grep "wsplcd.config.MapEnable='1'"`

        handle_son_wps_op_mode() {
                local device=$1
                config_get vifs $device vifs

                for vif in $vifs; do
                        config_get backhaul "$vif" backhaul 0
                        if [ "$backhaul" -eq 1 ]
                        then
                                let backhaul_cnt++
                        fi
                done
        }

        config_foreach handle_son_wps_op_mode wifi-device
        handle_iface_mgr_get_ssid() {
                local device=$1
                local stavap_ssid
                local apvap_ssid

                config_get disabled "$device" disabled 0
                [ "$disabled" -eq 0 ] || continue

                config_get vifs $device vifs

                for vif in $vifs; do
                    config_get ssid "$vif" ssid
                    config_get mode "$vif" mode
                    case "$mode" in
                        ap | wrap )
                            apvap_ssid=$ssid
                            ;;
                        sta)
                            stavap_ssid=$ssid
                            ;;
                    esac
                done
                if [ "$apvap_ssid" == "$stavap_ssid" ] ; then
                    same_ssid_support=1
                fi
        }

        config_foreach handle_iface_mgr_get_ssid wifi-device

        #Disable same_ssid_support on SON mode
        [ -n "$enable_repacd" ] && {
                same_ssid_support=0
        }

        #Disable same_ssid_support on MAP mode
        [ -n "$enable_wsplcd_map" ] && {
                same_ssid_support=0
        }

        config_get samessid_disable qcawifi samessid_disable 0
        if [ "$samessid_disable" -eq 1 ] ;  then
                same_ssid_support=0
        fi

        if [ "$same_ssid_support" -eq 1 ] ;  then
                iface_mgr_op_mode=4
        fi

        if [ "$backhaul_cnt" -gt 0 ] ;  then
                iface_mgr_op_mode=3
        else
                rm /var/run/son.conf
        fi

        config_get  global_wds qcawifi global_wds 0

        [ "$global_wds" -gt 0 ] && iface_mgr_op_mode=1

        handle_iface_mgr_op_mode() {
                local device=$1
                config_get fast_lane $device fast_lane 0
                config_get pref_uplink "$device" pref_uplink 0

                [ "$fast_lane" -gt 0 ] && iface_mgr_op_mode=2
                if [ $pref_uplink -eq 1 ] && [ $iface_mgr_op_mode -eq 2 ]; then
                        pref_uplink_idx=$(($pref_uplink_idx + 1))
                fi
        }

        config_foreach handle_iface_mgr_op_mode wifi-device

        [ "$iface_mgr_op_mode" -gt 0 ] || return
        [ "$iface_mgr_op_mode" -eq 2 ] && [ "$pref_uplink_idx" -ne 1 ] && return

        config_get  discon_time qcawifi discon_time 10
        config_get  reconfig_time qcawifi reconfig_time 60
        config_get  pref_uplink_time qcawifi pref_uplink_time 60
        config_get  hp_sta_scan_time qcawifi hp_sta_scan_time 120
        config_get  hp_sta_periodic_time qcawifi hp_sta_periodic_time 600

	if [ "$iface_mgr_op_mode" -eq 1 ] ;  then
	    [ "$discon_time" -ge "$reconfig_time" ] && timeout=$discon_time
	    [ "$discon_time" -lt "$reconfig_time" ] && timeout=$reconfig_time
	else
	    if [ "$iface_mgr_op_mode" -eq 2 ] ;  then
		timeout=$pref_uplink_time
	    fi
	fi

        killall iface-mgr
        rm -rf /var/run/iface_mgr.conf

        echo "#Interface manager configuration file should strictly meet below template" >> /var/run/iface_mgr.conf
        echo "#mode=x">> /var/run/iface_mgr.conf
        echo "#timeout=xx" >> /var/run/iface_mgr.conf
        echo "#radio=wifix" >> /var/run/iface_mgr.conf
        echo "#group=x ap_vap=athx" >> /var/run/iface_mgr.conf
        echo "#group=x sta_vap=athx" >> /var/run/iface_mgr.conf
        echo "#group=x plc_iface=ethx" >> /var/run/iface_mgr.conf
        echo "#driver_mode=cfg80211" >> /var/run/iface_mgr.conf


        echo "  " >> /var/run/iface_mgr.conf
        echo "mode=$iface_mgr_op_mode" >> /var/run/iface_mgr.conf
        echo "  " >> /var/run/iface_mgr.conf
        echo "timeout=$timeout" >> /var/run/iface_mgr.conf
        echo "  " >> /var/run/iface_mgr.conf
        echo "scan_time=$hp_sta_scan_time" >> /var/run/iface_mgr.conf
        echo "  " >> /var/run/iface_mgr.conf
        echo "periodic_time=$hp_sta_periodic_time" >> /var/run/iface_mgr.conf
        echo "  " >> /var/run/iface_mgr.conf

        [ "$iface_mgr_op_mode" -eq 1 ] && {
                config_foreach iface_mgr_config_mode1 wifi-device
        }

        [ "$iface_mgr_op_mode" -eq 2 ] && {
                config_foreach iface_mgr_config_mode2 wifi-device
        }

        [ "$iface_mgr_op_mode" -eq 4 ] && {
                config_foreach iface_mgr_config_mode4 wifi-device
        }

        config_load plc
        config_get plc_ifname config PlcIfname
        config_get_bool plc_enabled config Enabled 0
        config_get group config group 0

        [ "$plc_enabled" -eq 1 ] && {
                if [ -n $plc_ifname ]; then
                        echo "  " >> /var/run/iface_mgr.conf
                        echo "group=$group plc_iface=$plc_ifname" >> /var/run/iface_mgr.conf
                fi
        }

        [ -n "$enable_cfg80211" ] && {
                echo "  " >> /var/run/iface_mgr.conf
                echo "driver_mode=cfg80211" >> /var/run/iface_mgr.conf
        }

        if [ "$same_ssid_support" -eq 1 ] ;  then
                echo "  " >> /var/run/iface_mgr.conf
                echo "enable_same_ssid = 1" >> /var/run/iface_mgr.conf
        fi

        iface-mgr > /dev/console 2>&1 &

        return 1
}
