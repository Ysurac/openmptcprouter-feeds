#
# Copyright (c) 2017-2021 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
#!/bin/sh
#
# Copyright (c) 2014, 2016, The Linux Foundation. All rights reserved.
#
append DRIVERS "qcawificfg80211"
log_file="/tmp/qcawificfg80211_commands.txt"
g_qdss_tracing=0
g_daemon=0
g_cold_boot_support=0
fw_ini_file=""
board_name=""
board_name_prefix=""
daemon_features_default_string=""
cnssdaemon_log_file=""
print_rl_set=0

sysctl_cmd() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo "sysctl -w $1=$2" >> $log_file
	sysctl -w $1=$2 >/dev/null 2>/dev/null
}

echo_cmd() {
	if [[ $# == 3 ]] ; then
		[ -n "${CFG80211_UPDATE_FILE}" ] && echo "echo $1 $2 > $3" >> $log_file
		echo $1 $2 > $3
	else
		[ -n "${CFG80211_UPDATE_FILE}" ] && echo "echo $1 > $2" >> $log_file
		echo $1 > $2
	fi
}

insmod_cmd() {
	if [[ $# == 2 ]] ; then
		[ -n "${CFG80211_UPDATE_FILE}" ] && echo "insmod $1 $2" >> $log_file
		insmod $1 $2
	else
		[ -n "${CFG80211_UPDATE_FILE}" ] && echo "insmod $1" >> $log_file
		insmod $1
	fi
}

rmmod_cmd() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo "rmmod $1" >> $log_file
	rmmod $1
}

update_global_daemon_coldboot_qdss_support_variables() {
	local board_prefix=""
	local version=0
	local custom_ini_file=""
	local default_ini_file=""

	if [ -e /sys/firmware/devicetree/base/MP_512 ]
	then
		custom_ini_file=/ini/firmware_rdp_feature_512P.ini
		default_ini_file=/lib/firmware/firmware_rdp_feature_512P.ini
	elif [ -e /sys/firmware/devicetree/base/MP_256 ]
	then
		# 256MB profile will use the same file as 512MB profile,
		# but coldboot calibration support will be skipped.
		custom_ini_file=/ini/firmware_rdp_feature_512P.ini
		default_ini_file=/lib/firmware/firmware_rdp_feature_512P.ini
	else
		custom_ini_file=/ini/firmware_rdp_feature.ini
		default_ini_file=/lib/firmware/firmware_rdp_feature.ini
	fi

	if [ -f $custom_ini_file ]
	then
		fw_ini_file=$custom_ini_file
	elif [ -f $default_ini_file ]
	then
		fw_ini_file=$default_ini_file
	else
		echo "******FW ini file not found******" > /dev/console
		return
	fi

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	[ -z "$board_name"  ] && {
		echo "******Unable to find board name******" > /dev/console
		return
	}

	#INI file has strings with the below format
	#  <board_name>_<feature>=0/1   or
	#  <board_name>_<PCI_device_id>_<PCI_Slot_number>_<feature>=0/1
	# Append a "_" to the board_name here so that grep would be able to
	# differentiate boards with similar names like ap-mp03.1 and
	# ap-mp03.1-c2
	board_name_prefix=${board_name}_

	board_prefix=$(echo $board_name | sed 's/[0-9].*//g')

	case "$board_name" in
	ap-hk*)
		[ -f /sys/firmware/devicetree/base/soc_version_major ] && {
			version="$(cat /sys/module/cnss2/parameters/soc_version_major)"
		}

		daemon_features_default_string=$board_prefix"_v"$version"_default"
		;;
	*)
		daemon_features_default_string=$board_prefix"_default"
		;;
	esac

	#Grep the board_name_prefix in the fw_ini_file, if its not found, use the
	#default string
	boardname_grep_result=`grep -ci $board_name_prefix $fw_ini_file`
	default_grep_result=`grep -ci $daemon_features_default_string $fw_ini_file`

	if [ $boardname_grep_result != 0 ]
	then
		g_daemon=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | awk -F '=' '{print $2}' | grep -c 1`
		g_cold_boot_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_cold_boot_support" | awk -F '=' '{print $2}' | grep -c 1`
		g_qdss_tracing=`grep -i $board_name_prefix $fw_ini_file | grep "enable_qdss_tracing" | awk -F '=' '{print $2}' | grep -c 1`
		g_qdss_tracing=$(($g_qdss_tracing && $g_daemon))
	elif [ $default_grep_result != 0 ]
	then
		g_daemon=`grep -i $daemon_features_default_string $fw_ini_file | grep "enable_daemon_support" | awk -F'=' '{print $2}' | cut -c 1`
		g_cold_boot_support=`grep -i $daemon_features_default_string $fw_ini_file | grep "enable_cold_boot_support" | awk -F'=' '{print $2}' | cut -c 1`
		g_qdss_tracing=`grep -i $daemon_features_default_string $fw_ini_file | grep "enable_qdss_tracing" | awk -F'=' '{print $2}' | cut -c 1`
		g_qdss_tracing=$(($g_qdss_tracing && $g_daemon))
	else
		echo "***** No coldboot or daemon support for $board_name******" > /dev/console
	fi

	# Force disable Coldboot Calibration for 256MB profile.
	# Daemon support and QDSS are only supported.
	[ -e /sys/firmware/devicetree/base/MP_256 ] && {
		g_cold_boot_support=0
	}
}

iw() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo iw "$@" >> $log_file
	/usr/sbin/iw "$@"
}

wlanconfig() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo wlanconfig "$@" >> $log_file
	/usr/sbin/wlanconfig "$@"
}

iwconfig() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo iwconfig "$@" >> $log_file
	/usr/sbin/iwconfig "$@"
}

iwpriv() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo iwpriv "$@" >> $log_file
	/usr/sbin/iwpriv "$@"
}

cfg80211tool() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo cfg80211tool "$@" >> $log_file
	/usr/sbin/cfg80211tool "$@"
}

ifconfig() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo ifconfig "$@" >> $log_file
	/sbin/ifconfig "$@"
}

wpa_cli() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo wpa_cli "$@" >> $log_file
	/usr/sbin/wpa_cli "$@"
}

hostapd() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo hostapd "$@" >> $log_file
	/usr/sbin/hostapd "$@"
}

hostapd_cli() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo hostapd_cli "$@" >> $log_file
	/usr/sbin/hostapd_cli "$@"
}

retrieve_current_hw_mode() {
    local primary_if=$1
    if [[ "$primary_if" != "wifi0" && "$primary_if" != "wifi2" ]]; then
        primary_if="wifi0"
    fi
    local device=$primary_if
    config_get device_if "$device" device_if "cfg80211tool"
    current_hwmode=`$device_if $device get_hw_mode | awk -F'hw_mode:' '{print $2}'`
    echo "$current_hwmode"
}

switch_hw_mode() {
    local hwmode=$1
    local primary_if=$2
    if [[ "$primary_if" != "wifi0" && "$primary_if" != "wifi2" ]]; then
        primary_if="wifi0"
    fi
    local device=$primary_if
    config_get device_if "$device" device_if "cfg80211tool"
    `$device_if $device hw_mode $hwmode`
}

start_recovery_daemon() {
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo starting recovery daemon > /dev/console
	killall acfg_tool
	/usr/sbin/acfg_tool -e -s > /dev/console &
}

find_qcawifi_phy() {
	local device="$1"

	local macaddr="$(config_get "$device" macaddr | tr 'A-Z' 'a-z')"
	config_get phy "$device" phy
	[ -z "$phy" -a -n "$macaddr" ] && {
		cd /sys/class/net
		for phy in $(ls -d wifi* 2>&-); do
			[ "$macaddr" = "$(cat /sys/class/net/${phy}/address)" ] || continue
			config_set "$device" phy "$phy"
			break
		done
		config_get phy "$device" phy
	}
	[ -n "$phy" -a -d "/sys/class/net/$phy" ] || {
		echo "phy for wifi device $1 not found"
		return 1
	}
	[ -z "$macaddr" ] && {
		config_set "$device" macaddr "$(cat /sys/class/net/${phy}/address)"
	}
	return 0
}

enable_qdss_tracing() {
	local qdss_tracing=0
	local interface_arg=""

	[ $g_qdss_tracing = 0 ] && {
		return
	}

	#***************** QCN9000*****************#
	for slot in pci0 pci1
	do
		qdss_tracing=`grep -i $board_name_prefix $fw_ini_file | grep "enable_qdss_tracing" | grep -i "qcn9000" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		[ $qdss_tracing = 1 ] && {
			echo "****** Starting QDSS for qcn9000 $slot ********" > /dev/console
			cnsscli -i $slot --qdss_start > /dev/null
		}
	done

	#***************** QCN6122**********************************#
	# qcn6122 connected on pci0 is treated as integrated radio1 #
	# qcn6122 connected on pci1 is treated as integrated radio2 #
	#***********************************************************#
	for slot in pci0 pci1
	do
		qdss_tracing=`grep -i $board_name_prefix $fw_ini_file | grep "enable_qdss_tracing" | grep -i "qcn6122" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		[ $qdss_tracing = 1 ] && {
			if [ "$slot" == "pci0" ] ; then
				interface_arg="integrated1"
			elif [ "$slot" == "pci1" ] ; then
				interface_arg="integrated2"
			fi
			echo "****** Starting QDSS for qcn6122 $slot ********" > /dev/console
			cnsscli -i $interface_arg --qdss_start > /dev/null
		}
	done

	#For Integrated Radio
	qdss_tracing=`grep -i $board_name_prefix $fw_ini_file | grep "enable_qdss_tracing" | grep -v pci | awk -F'=' '{print $2}' | cut -c 1`
	[ -z $qdss_tracing ] && {
		qdss_tracing=`grep -i $daemon_features_default_string $fw_ini_file | grep "enable_qdss_tracing" | awk -F'=' '{print $2}' | grep -c 1`
	}

	[ $qdss_tracing = 1 ] && {
		[ ! -f /tmp/qdss_sink_config_done ] && {
			echo_cmd "q6mem" /sys/bus/coresight/devices/coresight-tmc-etr/out_mode
			echo_cmd 1 /sys/bus/coresight/devices/coresight-tmc-etr/curr_sink
			echo_cmd 5 /sys/bus/coresight/devices/coresight-funnel-mm/funnel_ctrl
			case "$board_name" in
			ap-mp*)
				echo_cmd 7 /sys/bus/coresight/devices/coresight-funnel-in0/funnel_ctrl
				;;
			*)
				echo_cmd 6 /sys/bus/coresight/devices/coresight-funnel-in0/funnel_ctrl
				;;
			esac
			echo_cmd 1 /sys/bus/coresight/devices/coresight-stm/enable
			echo "***** QDSS Tracing Configuration completed *******" > /dev/console
		}
		echo "****** Starting QDSS for Integrated ********" > /dev/console
		cnsscli -i integrated --qdss_start > /dev/null
		touch /tmp/qdss_sink_config_done
	}
}

start_cnssdaemon() {
	args=""
	local daemon=0

	# Check if cnssdaemon is already running
	cnssd_pid=$(pgrep cnssdaemon)
	[ ! -z "$cnssd_pid" ] && {
		return
	}

	#Daemon User Socket uses loopback interface, make sure it is up
	ifconfig lo up

	#For Integrated Radio
	daemon=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | grep -v pci | awk -F'=' '{print $2}' | grep -c 1`
	if [ $daemon != 0 ]
	then
		args=" -i integrated"
	fi

	#***************** QCN9000*****************#
	for slot in pci0 pci1
	do
		daemon=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | grep -i "qcn9000" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		if [ $daemon != 0 ]
		then
			args="$args -i $slot"
		fi
	done

	#***************** QCN6122**********************************#
	# qcn6122 connected on pci0 is treated as integrated radio1 #
	# qcn6122 connected on pci1 is treated as integrated radio2 #
	#***********************************************************#
	for slot in pci0 pci1
	do
		daemon=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | grep -i "qcn6122" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		if [ $daemon != 0 ]
		then
			if [ "$slot" == "pci0" ] ; then
				args="$args -i integrated1"
			elif [ "$slot" == "pci1" ] ; then
				args="$args -i integrated2"
			fi
		fi
	done

	# If args is empty here, then INI parsing has gone to default string
	# In this case, overwrite daemon args to connect to integrated radio
	[ -z "$args" ] && {
		args=" -i integrated"
	}

	# To enable cnssdaemon in debug mode, log file name should be defined
	# at the top of this file in "cnssdaemon_log_file"
	[ ! -z "$cnssdaemon_log_file" ] && {
		args="$args -dddd -f $cnssdaemon_log_file"
	}

	echo "***** starting cnssdaemon $args *****" > /dev/console
	/usr/bin/cnssdaemon -s $args > /dev/null &

	# cnssdaemon opens up sockets which is required for cnsscli.
	# sleep here is to ensure the sockets are open before cnsscli is used.
	sleep 1
	cnssd_pid=$(pgrep cnssdaemon)
	[ ! -z "$cnssd_pid" ] && {
		echo_cmd -1000 "/proc/$cnssd_pid/oom_score_adj"
		echo "*****cnssdaemon pid=$cnssd_pid*********" > /dev/console
	}
	[ -n "${CFG80211_UPDATE_FILE}"  ] && echo "/usr/bin/cnssdaemon $args" >> $log_file
}

update_daemon_cold_boot_support_to_plat_priv() {
	local daemon_support=0
	local cold_boot_support=0
	local interface_arg=""

	# Update daemon_support flag for PCI targets
	#***************** QCN9000*****************#
	for slot in pci0 pci1
	do
		daemon_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | grep -i "qcn9000" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		[ $daemon_support = 1 ] && {
			cnsscli -i $slot --enable_daemon_support $daemon_support > /dev/null
		}
	done

	#***************** QCN6122**********************************#
	# qcn6122 connected on pci0 is treated as integrated radio1 #
	# qcn6122 connected on pci1 is treated as integrated radio2 #
	#***********************************************************#
	for slot in pci0 pci1
	do
		daemon_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | grep -i "qcn6122" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		if [ "$slot" == "pci0" ] ; then
			interface_arg="integrated1"
		elif [ "$slot" == "pci1" ] ; then
			interface_arg="integrated2"
		fi
		[ $daemon_support = 1 ] && {
			cnsscli -i $interface_arg --enable_daemon_support $daemon_support > /dev/null
		}
	done

	# Update daemon_support flag for Integrated Radio
	daemon_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | grep -v pci | awk -F'=' '{print $2}' | cut -c 1`
	[ -z $daemon_support ] && {
		daemon_support=`grep -i $daemon_features_default_string $fw_ini_file | grep "enable_daemon_support" | awk -F'=' '{print $2}' | grep -c 1`
	}

	[ $daemon_support = 1 ] && {
		cnsscli -i integrated --enable_daemon_support $daemon_support > /dev/null
	}

	# 256MB profile does not support Coldboot Calibration, return here
	[ -e /sys/firmware/devicetree/base/MP_256 ] && {
		return
	}

	# Update cold_boot_support flag for PCI targets
	#***************** QCN9000*****************#
	for slot in pci0 pci1
	do
		cold_boot_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_cold_boot_support" | grep -i "qcn9000" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		[ $cold_boot_support = 1 ] && {
			cnsscli -i $slot --enable_cold_boot_support $cold_boot_support > /dev/null
		}
	done

	#***************** QCN6122**********************************#
	# qcn6122 connected on pci0 is treated as integrated radio1 #
	# qcn6122 connected on pci1 is treated as integrated radio2 #
	#***********************************************************#
	for slot in pci0 pci1
	do
		cold_boot_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_cold_boot_support" | grep -i "qcn6122" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
		if [ "$slot" == "pci0" ] ; then
			interface_arg="integrated1"
		elif [ "$slot" == "pci1" ] ; then
			interface_arg="integrated2"
		fi
		[ $cold_boot_support = 1 ] && {
			cnsscli -i $interface_arg --enable_cold_boot_support $cold_boot_support > /dev/null
		}
	done

	# Update cold_boot_support flag for Integrated Radio
	cold_boot_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_cold_boot_support" | grep -v pci | awk -F'=' '{print $2}' | cut -c 1`
	[ -z $cold_boot_support ] && {
		cold_boot_support=`grep -i $daemon_features_default_string $fw_ini_file | grep "enable_cold_boot_support" | awk -F'=' '{print $2}' | grep -c 1`
	}

	[ $cold_boot_support = 1 ] && {
		cnsscli -i integrated --enable_cold_boot_support $cold_boot_support > /dev/null
	}
}

do_cold_boot_calibration_qcawificfg80211() {
	local ker_ver=`uname -r |cut -d. -f1`

	#Update the daemon, coldboot and qdss support variables from FW INI
	update_global_daemon_coldboot_qdss_support_variables

	#Daemon needs to be started if enabled from ini, even if coldboot is
	#disabled, it might be used by QDSS
	[ $g_daemon != 0  ] && {
		start_cnssdaemon
		update_daemon_cold_boot_support_to_plat_priv
	}

	[ $g_cold_boot_support = 0 ] && {
		echo "******No cold_boot_support*****"  > /dev/console
		return 0
	}

	[ -f /tmp/cold_boot_done ] && {
		echo "******Not the first boot. Skip coldboot calibration*****"  > /dev/console
		return 0
	}

	echo "*********initiating cold boot calibration*************" > /dev/console
	coldbootmode=7
	#Set Cold boot mode to 10 for FTM Mode, 7 otherwise
	is_ftm="$(grep wifi_ftm_mode /proc/cmdline | wc -l)"
	[ $is_ftm = 1  ] && {
		coldbootmode=10
		echo "*****FTM Coldboot mode set to 10*****" > /dev/console
	}

	#Set driver_mode as coldboot to the kernel
	echo $coldbootmode > /sys/module/cnss2/parameters/driver_mode

	#From 5.4 based kernel, kmodloader would do the insmod of the wifi kos
	#driver_mode from CNSS2 would be used by the wifi driver to enter into
	#coldboot calibration mode and then rmmod flow would be internally
	#taken care without actually removing the modules. The driver mode would
	#be internally reset to 0 and insmod in MISSION mode would happen from
	#kmodloader context itself
	if [ $ker_ver -lt 5 ]; then
		insmod_cmd qca_ol testmode=$coldbootmode
		# insmod and rmmod wifi_3_0 kernel object in addition to qca_ol
		# as wifi_3_0 initiates and shuts down driver.
		insmod_cmd wifi_3_0
		rmmod_cmd wifi_3_0
		rmmod_cmd qca_ol
		#Reset driver_mode to 0 for mission mode
		echo 0 > /sys/module/cnss2/parameters/driver_mode
	fi
	sync
	touch /tmp/cold_boot_done
}

is_son_enabled()
{
	local son_is_enabled=""
	local is_son_hyd_enabled=""
	local is_son_lbd_enabled=""

	config_load lbd
	config_get is_son_lbd_enabled config "Enable" 0

	config_load hyd
	config_get is_son_hyd_enabled config "Enable" 0

	config_load repacd
	config_get is_repacd_enabled repacd "Enable" 0

	if [ $is_son_hyd_enabled = "1" ] ||
		[ $is_son_lbd_enabled = "1" ] || [ $is_repacd_enabled = "1" ]
	then
		son_is_enabled=1
		echo $son_is_enabled
	else
		son_is_enabled=0
		echo $son_is_enabled
	fi
}

get_vif() {
	[ -e /lib/functions.sh ] && . /lib/functions.sh
	wifi_dev=$1
	DEVICES=
		config_cb() {
			local type="$1"
			local section="$2"

			config_get device1 "$CONFIG_SECTION" device
			# Make sure each vif for $wifi_dev is processed only once
			if [ "$device1" == "$wifi_dev" ] && [ "$config_bkp" != "$CONFIG_SECTION" ]; then
				config_get TYPE "$CONFIG_SECTION" TYPE
				case "$TYPE" in
					wifi-iface)
						append vifs1 "$CONFIG_SECTION"
						vif=$vifs1
					;;
				esac
			# Hold the config item that has been processed
			config_bkp=$CONFIG_SECTION
			fi
		}
	config_load wireless
}

scan_qcawificfg80211() {
	local device="$1"
	local wds
	local adhoc sta ap monitor lite_monitor ap_monitor ap_smart_monitor mesh ap_lp_iot disabled
	local versn_name

	config_get vifs "$device" vifs
	for vif in $vifs; do {
		config_get ifname "$vif" ifname
		[ ${ifname//[0-9]} = "ath" ] && config_set "$vif" ifname ""
	}; done

	# Ap in dynamic mode means 3 radios will always be present
	# If in DBS mode then wifi2 should not be using cfg80211tool functions
	dynamic_hw_mode=`grep "dynamic_hw_mode" /ini/internal/global_i.ini | grep -m1 -v "^[#]" | awk -F'=' '{print $2}'`
	if [ "$dynamic_hw_mode" = "1" ]; then
		if [ $device = "wifi2" ]; then
			hw_mode_id=`retrieve_current_hw_mode`
			if [ $hw_mode_id -eq 1 ]; then
				return 0
			fi
		fi
	fi

	[ ${device%[0-9]} = "wifi" ] && config_set "$device" phy "$device"

	local ifidx=0
	local radioidx=${device#wifi}
	local son_enabled=""

	son_enabled=$( is_son_enabled )

	# Openwrt v19.07 needs differet handling while fetching vifs
	versn_name=`cat /etc/openwrt_release | grep 'RELEASE'`
	case $versn_name in
		*19.07*)
			get_vif $device
			config_set "$device" vifs "$vif"
			config_get vifs "$device" vifs
		;;
		*)
			config_get vifs "$device" vifs
		;;
	esac
	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		local vifname
		local ifname

		[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"

		if [ $son_enabled = "1" ]
		then
			config_set "$vif" ifname $vifname
		else
			config_get ifname "$vif" ifname "$vifname"
			config_set "$vif" ifname $ifname
		fi

		config_get mode "$vif" mode
		case "$mode" in
			adhoc|sta|ap|monitor|lite_monitor|wrap|ap_monitor|ap_smart_monitor|mesh|ap_lp_iot)
				append "$mode" "$vif"
			;;
			wds)
				config_get ssid "$vif" ssid
				[ -z "$ssid" ] && continue

				config_set "$vif" wds 1
				config_set "$vif" mode sta
				mode="sta"
				addr="$ssid"
				${addr:+append "$mode" "$vif"}
			;;
			*) echo "$device($vif): Invalid mode, ignored."; continue;;
		esac

		ifidx=$(($ifidx + 1))
	done

	case "${adhoc:+1}:${sta:+1}:${ap:+1}" in
		# valid mode combinations
		1::) wds="";;
		1::1);;
		:1:1)config_set "$device" nosbeacon 1;; # AP+STA, can't use beacon timers for STA
		:1:);;
		::1);;
		::);;
		*) echo "$device: Invalid mode combination in config"; return 1;;
	esac

	config_set "$device" vifs "${ap:+$ap }${ap_monitor:+$ap_monitor }${mesh:+$mesh }${ap_smart_monitor:+$ap_smart_monitor }${wrap:+$wrap }${sta:+$sta }${adhoc:+$adhoc }${wds:+$wds }${monitor:+$monitor}${lite_monitor:+$lite_monitor }${ap_lp_iot:+$ap_lp_iot}"
}

# The country ID is set at the radio level. When the driver attaches the radio,
# it sets the default country ID to 840 (US STA). This is because the desired
# VAP modes are not known at radio attach time, and STA functionality is the
# common unit of 802.11 operation.
# If the user desires any of the VAPs to be in AP mode, then we set a new
# default of 840 (US AP with TDWR) from this script. Even if any of the other
# VAPs are in non-AP modes like STA or Monitor, the stricter default of 840
# will apply.
# No action is required here if none of the VAPs are in AP mode.
set_default_country() {
	local device="$1"
	local mode

        config_get device_if "$device" device_if "cfg80211tool"
	find_qcawifi_phy "$device" || return 1
	config_get phy "$device" phy

	config_get vifs "$device" vifs
	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		config_get mode "$vif" mode
		case "$mode" in
			ap|wrap|ap_monitor|ap_smart_monitor|ap_lp_iot)
				"$device_if" "$phy" setCountryID 840
				return 0;
			;;
		*) ;;
		esac
	done

	return 0
}

config_low_targ_clkspeed() {
        local board_name
        [ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
        }

        case "$board_name" in
                ap147 | ap151)
                   echo "true"
                ;;
                *) echo "false"
                ;;
        esac
}

# configure tx queue fc_buf_max
config_tx_fc_buf() {
	local phy="$1"
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')

	case "$board_name" in
		ap-dk*)
			if [ $memtotal -le 131072 ]; then
				# 4MB tx queue max buffer size
				"$device_if" "$phy" fc_buf_max 4096
				"$device_if" "$phy" fc_q_max 512
				"$device_if" "$phy" fc_q_min 32
			elif [ $memtotal -le 256000 ]; then
				# 8MB tx queue max buffer size
				"$device_if" "$phy" fc_buf_max 8192
				"$device_if" "$phy" fc_q_max 1024
				"$device_if" "$phy" fc_q_min 64
			fi
				# default value from code memsize > 256MB
		;;

		*)
		;;
	esac
}

function update_ini_file()
{
	update_ini_cmd="grep -q $1 /ini/global.ini && sed -i '/$1=/c $1=$2' /ini/global.ini || echo $1=$2 >> /ini/global.ini"
	eval $update_ini_cmd
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo $update_ini_cmd >> $log_file
	sync
}

function update_internal_ini()
{
	update_ini_cmd="grep -q $2 /ini/internal/$1 && sed -i '/$2=/c $2=$3' /ini/internal/$1 || echo $2=$3 >> /ini/internal/$1"
	eval $update_ini_cmd
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo $update_ini_cmd >> $log_file
	sync
}

function update_ini_for_lowmem()
{
	update_internal_ini $1 dp_rxdma_monitor_buf_ring 128
	update_internal_ini $1 dp_rxdma_monitor_dst_ring 128
	update_internal_ini $1 dp_rxdma_monitor_desc_ring 4096
	update_internal_ini $1 dp_rxdma_monitor_status_ring 512
	update_internal_ini $1 num_vdevs_pdev0 9
	update_internal_ini $1 num_vdevs_pdev1 9
	update_internal_ini $1 num_vdevs_pdev2 9
	update_internal_ini $1 num_peers_pdev0 128
	update_internal_ini $1 num_peers_pdev1 128
	update_internal_ini $1 num_peers_pdev2 128
	update_internal_ini $1 num_monitor_pdev0 0
	update_internal_ini $1 num_monitor_pdev1 0
	update_internal_ini $1 num_monitor_pdev2 0
	update_internal_ini $1 full_mon_mode 0
	sync
}

function update_ini_for_hk_sbs()
{
	update_internal_ini $1 dp_tx_device_limit 49152
	sync
}

function update_ini_for_hk_dbs()
{
	update_internal_ini $1 dp_tx_device_limit 49152
	sync
}

# Update DP ring parameters for DBS on NSS offload mode
function update_ini_dp_rings_dbs_for_nss_offload()
{
	update_internal_ini QCA8074_i.ini dp_nss_tcl_data_rings 2
	update_internal_ini QCA8074_i.ini dp_nss_reo_dest_rings 2

	update_internal_ini QCA8074V2_i.ini dp_nss_tcl_data_rings 2
	update_internal_ini QCA8074V2_i.ini dp_nss_reo_dest_rings 2

	update_internal_ini QCA6018_i.ini dp_nss_tcl_data_rings 2
	update_internal_ini QCA6018_i.ini dp_nss_reo_dest_rings 2

	sync
}

# Update DP ring parameters for SBS on NSS offload mode
function update_ini_dp_rings_sbs_for_nss_offload()
{
	update_internal_ini QCA8074V2_i.ini dp_nss_tcl_data_rings 3
	update_internal_ini QCA8074V2_i.ini dp_nss_reo_dest_rings 3

	sync
}

# Update DP ring parameters for NSS offload mode
function update_ini_dp_rings_for_nss_mode()
{
	local num_radios
	local lithium_hw_mode

	# Iterate through soc list to find HKv2 and update ini
	cd /sys/class/net
	for soc in $(ls -d soc* 2>&-); do
		if [ -f ${soc}/ini_file ]; then
			ini_file=$(cat ${soc}/ini_file)
			if [ $ini_file == "QCA8074V2_i.ini" ]; then
				if [ -f ${soc}/hw_modes ]; then
					hw_modes=$(cat ${soc}/hw_modes)
					case "${hw_modes}" in
						*2G_PHYB:*)
							num_radios=1;;
						*DBS_SBS:*)
							num_radios=3;;
						*DBS:*)
							num_radios=2;;
						*DBS_OR_SBS:*)
							num_radios=2;;
						*SINGLE:*)
							num_radios=1;;
					esac
				fi

				dynamic_hw_mode=`grep "dynamic_hw_mode" /ini/internal/global_i.ini | grep -m1 -v "^[#]" | awk -F'=' '{print $2}'`

				# If dynamic mode is enabled or if the number of radios are
				# more than 2, the configure parameters for SBS mode
				if [ $num_radios -gt 2 ] || [ $dynamic_hw_mode -ne "0" ]; then
					update_ini_dp_rings_sbs_for_nss_offload
				else
					update_ini_dp_rings_dbs_for_nss_offload
				fi

				break
			fi
		fi
	done

	sync
}

function update_ini_nss_info()
{
	[ -f /lib/wifi/wifi_nss_hk_olnum ] && { \
		local hk_ol_num="$(cat /lib/wifi/wifi_nss_hk_olnum)"
		if [ -e /sys/firmware/devicetree/base/MP_256 ]; then
			update_internal_ini QCA8074V2_i.ini dp_nss_comp_ring_size 0x2000
			update_internal_ini QCN9000_i.ini dp_nss_comp_ring_size 0x2000
			update_internal_ini QCA5018_i.ini dp_nss_comp_ring_size 0x2000
			update_internal_ini QCN6122_i.ini dp_nss_comp_ring_size 0x2000
			update_internal_ini QCA6018_i.ini dp_nss_comp_ring_size 0x2000
		elif [ -e /sys/firmware/devicetree/base/MP_512 ]; then
			if [ $hk_ol_num -eq 3 ]; then
				update_internal_ini QCA8074V2_i.ini dp_nss_comp_ring_size 0x3000
				update_internal_ini QCA6018_i.ini dp_nss_comp_ring_size 0x3000
			else
				update_internal_ini QCA8074V2_i.ini dp_nss_comp_ring_size 0x4000
				update_internal_ini QCA6018_i.ini dp_nss_comp_ring_size 0x4000
			fi
		else
			if [ $hk_ol_num -eq 3 ]; then
				update_internal_ini QCA8074V2_i.ini dp_nss_comp_ring_size 0x8000
			else
				update_internal_ini QCA8074V2_i.ini dp_nss_comp_ring_size 0x8000
			fi
		fi
	}
	sync
}

function update_ini_reo_remap()
{
	local board_name

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	case "$board_name" in
	ap-hk14* | ap-hk01-c6*)
		[ -f /ini/internal/QCN9000_i.ini ] && {
			update_internal_ini QCN9000_i.ini dp_reo_rings_map 0x8
		}
		;;
	esac
}

function update_ini_target_dp_rx_hash_reset()
{
	local board_name

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	case "$board_name" in
	ap-hk14* | ap-hk01-c6*)
		[ -f /ini/internal/QCA8074V2_i.ini ] && {
			update_internal_ini QCA8074V2_i.ini dp_rx_hash 0
		}
		;;
	esac
}

function update_ini_target_dp_default_reo_reset()
{
	local board_name
	local nss_wifi_olcfg

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	config_get nss_wifi_olcfg qcawifi nss_wifi_olcfg

	# on RDP 430 ( Four Radio RDP restrict both 5G interfaces from 8074V2 to single REO
	case "$board_name" in
	ap-hk01-c6*)
		[ -f /ini/internal/QCA8074V2_i.ini ] && {
		if [ -n "$nss_wifi_olcfg" ] && [ "$nss_wifi_olcfg" == "0" ]; then
			update_internal_ini QCA8074V2_i.ini dp_rx_radio0_default_reo 2
			update_internal_ini QCA8074V2_i.ini dp_rx_radio1_default_reo 1
			update_internal_ini QCA8074V2_i.ini dp_rx_radio2_default_reo 3
		else
			update_internal_ini QCA8074V2_i.ini dp_rx_radio0_default_reo 1
			update_internal_ini QCA8074V2_i.ini dp_rx_radio1_default_reo 2
			update_internal_ini QCA8074V2_i.ini dp_rx_radio2_default_reo 3
		fi
		}
		;;
	esac
}

function update_ini_for_512MP_dp_tx_desc()
{
	local board_name

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	if [ $1 == "QCN9000_i.ini" ] || [ $1 == "QCN6122_i.ini" ]; then
		update_internal_ini $1 dp_tx_desc 0x2000
		update_internal_ini $1 dp_tx_desc_limit_0 8192
	else
		# For RDPs that have QCN9000, internal radio config in 512M
		# profile is on par with 256M profile values
		case "$board_name" in
		ap-cp01-c3|ap-hk10*|ap-hk14*)
			update_internal_ini $1 dp_tx_desc 0x2000
			update_internal_ini $1 dp_tx_desc_limit_0 4096
			update_internal_ini $1 dp_tx_desc_limit_1 4096
			update_internal_ini $1 dp_tx_desc_limit_2 4096
			;;
		*)
			update_internal_ini $1 dp_tx_desc 0x4000
			update_internal_ini $1 dp_tx_desc_limit_0 8192
			update_internal_ini $1 dp_tx_desc_limit_1 8192
			update_internal_ini $1 dp_tx_desc_limit_2 8192
			;;
		esac
	fi
	sync
}

function update_ini_for_512MP_P_build()
{
	local board_name

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	update_internal_ini $1 dp_rxdma_monitor_buf_ring 128
	update_internal_ini $1 dp_rxdma_monitor_dst_ring 128
	update_internal_ini $1 dp_rxdma_monitor_desc_ring 4096

	if [ $1 == "QCN9000_i.ini" ] || [ $1 == "QCN6122_i.ini" ]; then
		update_internal_ini $1 dp_rxdma_monitor_status_ring 1024
		update_internal_ini $1 num_vdevs_pdev0 9
		update_internal_ini $1 num_peers_pdev0 128
		update_internal_ini $1 num_monitor_pdev0 0
	else
		case "$board_name" in
		ap-cp*|ap-mp*)
			update_internal_ini $1 dp_rxdma_monitor_status_ring 1024
			;;
		*)
			update_internal_ini $1 dp_rxdma_monitor_status_ring 512
			;;
		esac
		update_internal_ini $1 num_vdevs_pdev0 9
		update_internal_ini $1 num_vdevs_pdev1 9
		update_internal_ini $1 num_vdevs_pdev2 9
		update_internal_ini $1 num_peers_pdev0 128
		update_internal_ini $1 num_peers_pdev1 128
		update_internal_ini $1 num_peers_pdev2 128
		update_internal_ini $1 num_monitor_pdev0 0
		update_internal_ini $1 num_monitor_pdev1 0
		update_internal_ini $1 num_monitor_pdev2 0
	fi
	sync
}

function update_ini_for_512MP_E_build()
{
	update_internal_ini $1 num_vdevs_pdev0 8
	update_internal_ini $1 num_vdevs_pdev1 8
	update_internal_ini $1 num_vdevs_pdev2 8
	update_internal_ini $1 num_peers_pdev0 128
	update_internal_ini $1 num_peers_pdev1 128
	update_internal_ini $1 num_peers_pdev2 128
	update_internal_ini $1 num_monitor_pdev0 1
	update_internal_ini $1 num_monitor_pdev1 1
	update_internal_ini $1 num_monitor_pdev2 1
	sync
}

function update_ini_for_monitor_buf_ring()
{
	update_internal_ini $1 dp_rxdma_monitor_buf_ring 4096
	update_internal_ini $1 dp_rxdma_monitor_dst_ring 4096
	update_internal_ini $1 dp_rxdma_monitor_desc_ring 4096
	update_internal_ini $1 dp_rxdma_monitor_status_ring 1024
	sync
}

function update_ini_for_mon_buf_ring_chainmask_2()
{
	update_internal_ini $1 dp_rxdma_monitor_buf_ring 2048
	update_internal_ini $1 dp_rxdma_monitor_dst_ring 2048
	update_internal_ini $1 dp_rxdma_monitor_desc_ring 2048
	update_internal_ini $1 dp_rxdma_monitor_status_ring 1024
	sync
}

is_cnss_diag_logging_enabled()
{
	local cnss_diag_log=""

	config_load cnss_diag
	config_get_bool cnss_logging_enable global enable 0

	if [ -n "$cnss_logging_enable" ] && [ "$cnss_logging_enable" != "0" ]
	then
		cnss_diag_log=1
		echo $cnss_diag_log
	else
		cnss_diag_log=0
		echo $cnss_diag_log
	fi
}

function update_ini_for_tx_vdev_id_check()
{
	config_get dp_tx_allow_per_pkt_vdev_id_check qcawifi dp_tx_allow_per_pkt_vdev_id_check
	if [ -n "$dp_tx_allow_per_pkt_vdev_id_check" ]; then
		update_internal_ini QCA8074_i.ini dp_tx_allow_per_pkt_vdev_id_check "$dp_tx_allow_per_pkt_vdev_id_check"
		update_internal_ini QCA8074V2_i.ini dp_tx_allow_per_pkt_vdev_id_check "$dp_tx_allow_per_pkt_vdev_id_check"
		update_internal_ini QCA6018_i.ini dp_tx_allow_per_pkt_vdev_id_check "$dp_tx_allow_per_pkt_vdev_id_check"
		update_internal_ini QCA5018_i.ini dp_tx_allow_per_pkt_vdev_id_check "$dp_tx_allow_per_pkt_vdev_id_check"
		update_internal_ini QCN9000_i.ini dp_tx_allow_per_pkt_vdev_id_check "$dp_tx_allow_per_pkt_vdev_id_check"
	else
		update_internal_ini QCA8074_i.ini dp_tx_allow_per_pkt_vdev_id_check 0
		update_internal_ini QCA8074V2_i.ini dp_tx_allow_per_pkt_vdev_id_check 0
		update_internal_ini QCA6018_i.ini dp_tx_allow_per_pkt_vdev_id_check 0
		update_internal_ini QCA5018_i.ini dp_tx_allow_per_pkt_vdev_id_check 0
		update_internal_ini QCN9000_i.ini dp_tx_allow_per_pkt_vdev_id_check 0
	fi
}

#Each radio is mapped to 4 bit priority. Higher value has high priority.
#Based on number of radios in board, priority is aggregated and
#populated into global ini.
#Eg: Board ap-hk10-c2 - 0x01. First radio is higher priority than second.
config_nss_wifi_radio_pri_map()
{
	local board_name="$1"
	local nss_wifi_radio_pri_map=0

	case "$board_name" in
		ap-hk10-c1) nss_wifi_radio_pri_map=$((0x110));;
		ap-hk10-c2) nss_wifi_radio_pri_map=$((0x01));;
		ap-hk14) nss_wifi_radio_pri_map=$((0x101));;
		ap-cp01-c3) nss_wifi_radio_pri_map=$((0x101));;
		ap-mp*) nss_wifi_radio_pri_map=$((0x1101));;
		*) nss_wifi_radio_pri_map=$((0x1101));;
	esac
	update_internal_ini global_i.ini nss_wifi_radio_pri_map $nss_wifi_radio_pri_map
}


backup_module_params_to_ini()
{
	qca_ol_params="$1"
	qdf_params="$2"
	umac_params="$3"
	file_name="/ini/wifi_module_param.ini"

	# Redirecting into a file as this will be written afresh.
	echo "" > "$file_name"

	# Following command execution writes one module param per line.
	[ -n "$qdf_params" ] && echo -e ${qdf_params// /\\n}  >>  "$file_name"
	[ -n "$qca_ol_params" ] && echo -e ${qca_ol_params// /\\n} >>  "$file_name"
	[ -n "$umac_params" ] && echo -e ${umac_params// /\\n} >>  "$file_name"

	# a. The file /ini/wifi_module_param_backup.ini will be used during pre-init
	#    to avoid file (file_name) overwrite due to consecutive reboot.
	# b. Module params which are not set through uci set routine are stored in
	#    /ini/wifi_module_param_backup.ini
	# c. Also this file has following default module params
	#    mem_debug_disabled=1 and enable_pktlog_support=1

	cp  "$file_name" /ini/wifi_module_param_backup.ini

	sync
}


load_qcawificfg80211() {
	local umac_args
	local qdf_args
	local ol_args
	local cfg_low_targ_clkspeed
	local qca_da_needed=0
	local device
	local board_name
	local def_pktlog_support=1
	local hk_ol_num=0
	local def_iot_sim=0
	local cnssd_log=""
	local load_ol_mod=0
	local wmi_dir
	local recover=$1
	local versn_name
	local ker_ver=`uname -r |cut -d. -f1`

	versn_name=`cat /etc/openwrt_release | grep 'RELEASE'`
	case $versn_name in
		*19.07*)
			versn_name=19
		;;
		*)
			versn_name=0
		;;
	esac
	echo_cmd -n "/ini" /sys/module/firmware_class/parameters/path
	is_wal=`grep waltest_mode /proc/cmdline | wc -l`
	[ $is_wal = 1 ] && waltest_qcawificfg80211 $recover && return

	if [ ! -d "/cfg/default" ]; then
		mkdir -p /cfg/default
		cp -rf /ini/ /cfg/default/
	fi

	# Reset the global ini on wifi load. All relevent params will get updated via update_ini_file [config items] [value]
	cp /cfg/default/ini/global.ini  /ini/global.ini

	local enable_cfg80211=`uci show qcacfg80211.config.enable |grep "qcacfg80211.config.enable='0'"`
	[ -n "$enable_cfg80211" ] && echo "qcawificfg80211 configuration is disable" > /dev/console && return 1;

	# Making sure all the radio types are 'qcawificfg80211'
        local check_qcawifi=`cat /etc/config/wireless | grep -Eo "\s*option\s*type\s*['\\s]*qcawifi['\\s]*$"`
        [ -n "$check_qcawifi" ] && sed -ie "s/\\soption\\stype.*$/\\toption type 'qcawificfg80211'/" /etc/config/wireless

	if [ "$recover" != "1" ]; then
		lock /var/run/wifilock
	fi
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')

	case "$board_name" in
		ap-dk01.1-c1 | ap-dk01.1-c2 | ap-dk04.1-c1 | ap-dk04.1-c2 | ap-dk04.1-c3)
			if [ $memtotal -le 131072 ]; then
				echo_cmd 1 /proc/net/skb_recycler/max_skbs
				echo_cmd 1 /proc/net/skb_recycler/max_spare_skbs
				update_ini_file low_mem_system 1
			fi
		;;
		ap152 | ap147 | ap151 | ap135 | ap137)
			if [ $memtotal -le 66560 ]; then
				def_pktlog_support=0
			fi
		;;
	esac

	update_ini_file cfg80211_config "1"
	config_get_bool testmode qcawifi testmode
	[ -n "$testmode" ] && append ol_args "testmode=$testmode"

	config_get vow_config qcawifi vow_config
	[ -n "$vow_config" ] && update_ini_file vow_config "$vow_config"

	config_get dpd_support qcawifi dpd_support
	[ -n "$dpd_support" ] && update_ini_file dpd_support "$dpd_support"

	config_get carrier_vow_config qcawifi carrier_vow_config
	[ -n "$carrier_vow_config" ] && update_ini_file carrier_vow_config "$carrier_vow_config"

	config_get fw_vow_stats_enable qcawifi fw_vow_stats_enable
	[ -n "$fw_vow_stats_enable" ] && update_ini_file fw_vow_stats_enable "$fw_vow_stats_enable"

	config_get ol_bk_min_free qcawifi ol_bk_min_free
	[ -n "$ol_bk_min_free" ] && update_ini_file OL_ACBKMinfree "$ol_bk_min_free"

	config_get ol_be_min_free qcawifi ol_be_min_free
	[ -n "$ol_be_min_free" ] && update_ini_file OL_ACBEMinfree "$ol_be_min_free"

	update_ini_for_tx_vdev_id_check

	config_get ol_vi_min_free qcawifi ol_vi_min_free
	[ -n "$ol_vi_min_free" ] && update_ini_file OL_ACVIMinfree "$ol_vi_min_free"

	config_get ol_vo_min_free qcawifi ol_vo_min_free
	[ -n "$ol_vo_min_free" ] && update_ini_file OL_ACVOMinfree "$ol_vo_min_free"

	config_get_bool ar900b_emu qcawifi ar900b_emu
	[ -n "$ar900b_emu" ] && append ol_args "ar900b_emu=$ar900b_emu"

	config_get frac qcawifi frac
	[ -n "$frac" ] && append ol_args "frac=$frac"

	config_get intval qcawifi intval
	[ -n "$intval" ] && append ol_args "intval=$intval"

	config_get atf_mode qcawifi atf_mode
	[ -n "$atf_mode" ] && append umac_args "atf_mode=$atf_mode"

        config_get atf_msdu_desc qcawifi atf_msdu_desc
        [ -n "$atf_msdu_desc" ] && append umac_args "atf_msdu_desc=$atf_msdu_desc"

        config_get atf_peers qcawifi atf_peers
        [ -n "$atf_peers" ] && append umac_args "atf_peers=$atf_peers"


        config_get atf_max_vdevs qcawifi atf_max_vdevs
        [ -n "$atf_max_vdevs" ] && append umac_args "atf_max_vdevs=$atf_max_vdevs"

	config_get fw_dump_options qcawifi fw_dump_options
	[ -n "$fw_dump_options" ] && update_ini_file fw_dump_options "$fw_dump_options"

	config_get enableuartprint qcawifi enableuartprint
	[ -n "$enableuartprint" ] && update_ini_file enableuartprint "$enableuartprint"

	config_get ar900b_20_targ_clk qcawifi ar900b_20_targ_clk
	[ -n "$ar900b_20_targ_clk" ] && append ol_args "ar900b_20_targ_clk=$ar900b_20_targ_clk"

	config_get qca9888_20_targ_clk qcawifi qca9888_20_targ_clk
	[ -n "$qca9888_20_targ_clk" ] && append ol_args "qca9888_20_targ_clk=$qca9888_20_targ_clk"

        cfg_low_targ_clkspeed=$(config_low_targ_clkspeed)
        [ -z "$qca9888_20_targ_clk" ] && [ $cfg_low_targ_clkspeed = "true" ] && append ol_args "qca9888_20_targ_clk=300000000"

	config_get max_descs qcawifi max_descs
	[ -n "$max_descs" ] && update_ini_file max_descs "$max_descs"

	config_get max_peers qcawifi max_peers
	if [ -n "$max_peers" ]; then
		update_ini_file max_peers "$max_peers"
	else
		update_ini_file max_peers 0
	fi

	config_get cce_disable qcawifi cce_disable
	[ -n "$cce_disable" ] && update_ini_file cce_disable "$cce_disable"

	config_get qwrap_enable qcawifi qwrap_enable 0
	[ -n "$qwrap_enable" ] && update_ini_file qwrap_enable "$qwrap_enable"

	config_get wds_ext qcawifi wds_ext 0
	case "$wds_ext" in
		1|on|enabled)	wds_ext=1
			;;
		*)	wds_ext=0
			;;
	esac
	update_ini_file wds_ext "$wds_ext" >/dev/null 2>&1

	config_get otp_mod_param qcawifi otp_mod_param
	[ -n "$otp_mod_param" ] && update_ini_file otp_mod_param "$otp_mod_param"

	config_get max_active_peers qcawifi max_active_peers
	[ -n "$max_active_peers" ] && update_ini_file max_active_peers "$max_active_peers"

	config_get enable_smart_antenna qcawifi enable_smart_antenna
	[ -n "$enable_smart_antenna" ] && update_ini_file enable_smart_antenna "$enable_smart_antenna"

	config_get sa_validate_sw qcawifi sa_validate_sw
	[ -n "$sa_validate_sw" ] && update_ini_file sa_validate_sw "$sa_validate_sw"

	config_get peer_ext_stats qcawifi peer_ext_stats
	[ -n "$peer_ext_stats" ] && update_ini_file peer_ext_stats "$peer_ext_stats"

	# Enable the radio scheme flag
	update_ini_file nss_wifi_radio_scheme_enable 1

	[ -e /sys/firmware/devicetree/base/MP_256 ] && {
		# Force all the radios in NSS offload mode on 256M profile
		case "$board_name" in
		ap-hk*|ap-ac*|ap-oa*|ap-cp*|ap-mp*)
			[ ! -f /lib/wifi/wifi_nss_olcfg ] && {
				echo_cmd 7 /lib/wifi/wifi_nss_olcfg
			}
			;;
		esac
	}

	config_get nss_wifi_olcfg qcawifi nss_wifi_olcfg
	if [ -n "$nss_wifi_olcfg" ]; then
		[ -e /sys/firmware/devicetree/base/MP_256 ] && {
			if [ $nss_wifi_olcfg = 0 ]; then
				echo "****** HOST mode not supported in low memory profile ******" > /dev/console
				if [ "$recover" != "1" ]; then
					lock -u /var/run/wifilock
				fi
				return
			fi
		}
		update_ini_file nss_wifi_olcfg "$nss_wifi_olcfg"
		if [ $nss_wifi_olcfg != 0 ]; then
			update_ini_file dp_rx_hash 0
		else
			update_ini_file dp_rx_hash 1
		fi
		config_get nss_wifi_nxthop_cfg qcawifi nss_wifi_nxthop_cfg
		if [ -n "$nss_wifi_nxthop_cfg" ]; then
		    update_ini_file nss_wifi_nxthop_cfg "$nss_wifi_nxthop_cfg"
		fi
	elif [ -f /lib/wifi/wifi_nss_olcfg ]; then
		nss_wifi_olcfg="$(cat /lib/wifi/wifi_nss_olcfg)"

		if [ $nss_wifi_olcfg != 0 ]; then
			if [ -f /lib/wifi/wifi_nss_override ] && [ $(cat /lib/wifi/wifi_nss_override) = 1 ]; then
				echo "NSS offload disabled due to unsupported config" >&2
				update_ini_file nss_wifi_olcfg 0
				update_ini_file dp_rx_hash 1
			else
				update_ini_file nss_wifi_olcfg "$nss_wifi_olcfg"
				update_ini_file dp_rx_hash 0
			fi
		else
			update_ini_file nss_wifi_olcfg 0
			update_ini_file dp_rx_hash 1
		fi
	fi

	config_get max_clients qcawifi max_clients
	[ -n "$max_clients" ] && update_ini_file max_clients "$max_clients"

	config_get enable_rdk_stats qcawifi enable_rdk_stats
	[ -n "$enable_rdk_stats" ] && update_ini_file enable_rdk_stats "$enable_rdk_stats"

	config_get max_vaps qcawifi max_vaps
	[ -n "$max_vaps" ] && update_ini_file max_vaps "$max_vaps"

	config_get enable_smart_antenna_da qcawifi enable_smart_antenna_da
	[ -n "$enable_smart_antenna_da" ] && update_ini_file enable_smart_antenna_da "$enable_smart_antenna_da"

	config_get prealloc_disabled qcawifi prealloc_disabled
	[ -n "$prealloc_disabled" ] && append qdf_args "prealloc_disabled=$prealloc_disabled"

	config_get mem_debug_disabled qcawifi mem_debug_disabled
	if [ -n "$mem_debug_disabled" ]; then
		append qdf_args "mem_debug_disabled=$mem_debug_disabled"
	else
		append qdf_args "mem_debug_disabled=1"
	fi

	cnssd_log=$( is_cnss_diag_logging_enabled )
	config_get dump_at_kernel_enable qcawifi dump_at_kernel_enable

	if [ $cnssd_log = "1" ]
	then
		if [ -n "$dump_at_kernel_enable" ]; then
			append qdf_args "qdf_log_dump_at_kernel_enable=$dump_at_kernel_enable"
		else
			append qdf_args "qdf_log_dump_at_kernel_enable=0"
		fi
	fi

	config_get flush_timer_period qcawifi flush_timer_period
	if [ $cnssd_log = "1" ]
	then
		if [ -n "$flush_timer_period" ]; then
			append qdf_args "qdf_log_flush_timer_period=$flush_timer_period"
		else
			append qdf_args "qdf_log_flush_timer_period=50"
		fi
	fi

	config_get logger_enable_mask qcawifi logger_enable_mask
	if [ $cnssd_log = "1" ]
	then
		if [ -n "$logger_enable_mask" ]; then
			update_ini_file logger_enable_mask "$logger_enable_mask"
		else
			update_ini_file logger_enable_mask "14"
		fi
	else
		update_ini_file logger_enable_mask "0"
	fi

	update_ini_dp_rings_for_nss_mode

	if [ -n "$nss_wifi_olcfg" ] && [ "$nss_wifi_olcfg" != "0" ]; then
	local mp_256="$(ls /proc/device-tree/ | grep -rw "MP_256")"
	local mp_512="$(ls /proc/device-tree/ | grep -rw "MP_512")"
	sysctl dev.nss.n2hcfg.n2h_high_water_core0 >/dev/null 2>/dev/null
	[ -n "${CFG80211_UPDATE_FILE}" ] && echo "sysctl dev.nss.n2hcfg.n2h_high_water_core0" >> $log_file
	#update the ini nss info
	update_ini_nss_info

	#If this is a first time load, then remove the one radio up file
	if [ ! -d /sys/module/qca_ol ] && [ -f /tmp/wifi_nss_up_one_radio ]; then
		rm /tmp/wifi_nss_up_one_radio
	fi

	if [ "$mp_256" == "MP_256" ]; then
	case "$board_name" in
	ap-mp*)
		#extra pbuf core0 = (high_water_core0 - (NSS + OCM buffers)) * pbuf_size
		#where NSS+OCM buffers = 11720 and pbuf_size = 160 bytes
		#total pbuf size is 160 bytes,allocate memory for 4616 pbufs
		sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 800000
		sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 16336
		sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
	;;
	*)	sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 1400000
		sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 20432
		sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
	;;
	esac
	elif [ "$mp_512" == "MP_512" ]; then
		if [ $versn_name -eq 19 -o ! -d /sys/module/qca_ol ]; then
			hk_ol_num="$(cat /lib/wifi/wifi_nss_hk_olnum)"
			if [ $hk_ol_num -eq 3 ]; then
				#total pbuf size is 160 bytes,allocate memory for 19928 pbufs
				sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 3200000
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 31648
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
			else
				#total pbuf size is 160 bytes,allocate memory for 18904 pbufs
				sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 3100000
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 30624
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 8192
			fi
		fi
	else
	case "$board_name" in
	ap-hk09*)
			local soc_version_major="$(cat /sys/module/cnss2/parameters/soc_version_major)"

			if [ $soc_version_major = 2 ];then
				if [ $versn_name -eq 19 -o ! -d /sys/module/qca_ol ]; then
					#total pbuf size is 160 bytes,allocate memory for 55672 pbufs
					sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 9000000
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 67392
					#initially after init 4k buf for 5G and 4k for 2G will be allocated, later range will be configured
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 40960
				fi
			else
				#total pbuf size is 160 bytes,allocate memory for 57184 pbufs
				sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 9200000
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 68904
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 32768
			fi
	;;
	ap-ac01)
		#total pbuf size is 160 bytes,allocate memory for 14712 pbufs
		sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 2400000
		sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 26432
		sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
	;;
	ap-ac02)
		#total pbuf size is 160 bytes,allocate memory for 18808 pbufs
		sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 3100000
		sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 30528
		sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 4096
	;;
	ap-hk* | ap-oak*)
		hk_ol_num="$(cat /lib/wifi/wifi_nss_hk_olnum)"
		if [ $versn_name -eq 19 -o ! -d /sys/module/qca_ol ]; then
			if [ $hk_ol_num -eq 3 ]; then
				#total pbuf size is 160 bytes,allocate memory for 93560 pbufs
				#NSS general payload(8000),Rx Buffer per radio(4k),Tx queue buffer per radio(1k), intial TX allocation per radio(4k)
				#Radio     TxDescRange0   TxDescRange1     TxDescRange2        TxDescRange3
				#           (<=64 clients) (<=128 clients) (<=256 clients)    (>256 clients)
				#5G-Hi        24k          24k                  24k                  32k
				#2G           16k          16k                  16k                  16k
				#5G-Low       24k          24k                  24k                  32k
				#Absolute high water=NSS payloads + Rx buf per radio + Tx queue per radio + TxDescRange3(5g-low/5g-hi/2g)
				#wifi pool buff = Min(Total tx desc at range 3, device_limit) - total intial tx allocation
				#extra pbuf core0 = (high_water_core0 - (NSS + OCM buffers)) * pbuf_size
				#       where NSS+OCM buffers = 11720 and pbuf_size = 160
				sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 10000000
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 72512
				#initially after init 4k buf for 5G and 4k for 2G will be allocated, then range will be configured
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 36864
			else
				#total pbuf size is 160 bytes,allocate memory for 55672 pbufs
				sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 9000000
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 67392
				#initially after init 4k buf for 5G and 4k for 2G will be allocated, then range will be configured
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 40960
			fi
		fi
	;;
	ap-cp*|ap-mp*)
		if [ $versn_name -eq 19 -o ! -d /sys/module/qca_ol ]; then
			#total pbuf size is 160 bytes,allocate memory for 18808 pbufs
			sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 3100000
			sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 30528
			sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 4096
		fi
	;;
	*)
		#total pbuf size is 160 bytes,allocate memory for 48456 pbufs
		sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 7800000
		sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 60176
		sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 35840
	;;
	esac
	fi
	fi

	config_get lteu_support qcawifi lteu_support
	[ -n "$lteu_support" ] && update_ini_file lteu_support "$lteu_support"

        config_get tgt_sched_params qcawifi tgt_sched_params
        [ -n "$tgt_sched_params" ] && update_ini_file tgt_sched_params "$tgt_sched_params"

	config_get enable_mesh_support qcawifi enable_mesh_support
	[ -n "$enable_mesh_support" ] && update_ini_file mesh_support "$enable_mesh_support"

        config_get enable_eapol_minrate qcawifi enable_eapol_minrate
	[ -n "$enable_eapol_minrate" ] && update_ini_file eapol_minrate_set "$enable_eapol_minrate"

        config_get set_eapol_minrate_ac qcawifi set_eapol_minrate_ac
	[ -n "$set_eapol_minrate_ac" ] && update_ini_file eapol_minrate_ac_set "$set_eapol_minrate_ac"

    if [ -n "$enable_mesh_support" ]
    then
        config_get enable_mesh_peer_cap_update qcawifi enable_mesh_peer_cap_update
        [ -n "$enable_mesh_peer_cap_update" ] && append umac_args "enable_mesh_peer_cap_update=$enable_mesh_peer_cap_update"
    fi

	config_get enable_pktlog_support qcawifi enable_pktlog_support $def_pktlog_support
	[ -n "$enable_pktlog_support" ] && append umac_args "enable_pktlog_support=$enable_pktlog_support"

	config_get g_unicast_deauth_on_stop qcawifi g_unicast_deauth_on_stop $g_unicast_deauth_on_stop
	[ -n "$g_unicast_deauth_on_stop" ] && append umac_args "g_unicast_deauth_on_stop=$g_unicast_deauth_on_stop"

	config_get qld_max_list qcawifi qld_max_list $qld_max_list
	[ -n "$qld_max_list" ] && append umac_args "qld_max_list=$qld_max_list"

	config_get beacon_offload_disable qcawifi beacon_offload_disable
	[ -n "$beacon_offload_disable" ] && update_ini_file beacon_offload_disable "$beacon_offload_disable"

	config_get spectral_disable qcawifi spectral_disable
	[ -n "$spectral_disable" ] && update_ini_file spectral_disable "$spectral_disable"

	config_get twt_enable qcawifi twt_enable
	[ -n "$twt_enable" ] && update_ini_file twt_enable "$twt_enable"

	config_get b_twt_enable qcawifi b_twt_enable
	[ -n "$b_twt_enable" ] && update_ini_file b_twt_enable "$b_twt_enable"

	config_get poison_spectral_bufs qcawifi poison_spectral_bufs
	[ -n "$poison_spectral_bufs" ] && update_ini_file poison_spectral_bufs "$poison_spectral_bufs"

	config_get mbss_ie_enable qcawifi mbss_ie_enable
	[ -n "$mbss_ie_enable" ] && update_ini_file mbss_ie_enable "$mbss_ie_enable"

	config_get disable_6ghz_mbssid qcawifi disable_6ghz_mbssid
	[ -n "$disable_6ghz_mbssid" ] && update_ini_file disable_6ghz_mbssid "$disable_6ghz_mbssid"

	config_get ema_ap_vendor_ie_size_low qcawifi ema_ap_vendor_ie_size_low
	[ -n "$ema_ap_vendor_ie_size_low" ] && update_ini_file ema_ap_vendor_ie_size_low "$ema_ap_vendor_ie_size_low"

	config_get ema_ap_vendor_ie_size_high qcawifi ema_ap_vendor_ie_size_high
	[ -n "$ema_ap_vendor_ie_size_high" ] && update_ini_file ema_ap_vendor_ie_size_high "$ema_ap_vendor_ie_size_high"

	config_get ema_ap_num_max_vaps qcawifi ema_ap_num_max_vaps
	[ -n "$ema_ap_num_max_vaps" ] && update_ini_file ema_ap_num_max_vaps "$ema_ap_num_max_vaps"

	config_get ema_ap_beacon_common_part_size qcawifi ema_ap_beacon_common_part_size
	[ -n "$ema_ap_beacon_common_part_size" ] && update_ini_file ema_ap_beacon_common_part_size "$ema_ap_beacon_common_part_size"

	config_get ema_ap_support_wps_in_6ghz qcawifi ema_ap_support_wps_in_6ghz
	[ -n "$ema_ap_support_wps_in_6ghz" ] && update_ini_file ema_ap_support_wps_in_6ghz "$ema_ap_support_wps_in_6ghz"

	config_get ema_ap_optional_ie_size qcawifi ema_ap_optional_ie_size
	[ -n "$ema_ap_optional_ie_size" ] && update_ini_file ema_ap_optional_ie_size "$ema_ap_optional_ie_size"

	config_get enable_ema_ap_ext qcawifi enable_ema_ap_ext
	[ -n "$enable_ema_ap_ext" ] && update_ini_file enable_ema_ap_ext "$enable_ema_ap_ext"

	config_get ema_ap_rnr_field_size_limit qcawifi ema_ap_rnr_field_size_limit
	[ -n "$ema_ap_rnr_field_size_limit" ] && update_ini_file ema_ap_rnr_field_size_limit "$ema_ap_rnr_field_size_limit"

	config_get ap_bss_color_collision_detection qcawifi ap_bss_color_collision_detection
	[ -n "$ap_bss_color_collision_detection" ] && update_ini_file ap_bss_color_collision_detection "$ap_bss_color_collision_detection"

	config_get spatial_reuse_enable qcawifi spatial_reuse_enable
	[ -n "$spatial_reuse_enable" ] && update_ini_file spatial_reuse_enable "$spatial_reuse_enable"

	config_get srp_non_srg_self_obss_pd_enable qcawifi srp_non_srg_self_obss_pd_enable
	[ -n "$srp_non_srg_self_obss_pd_enable" ] && update_ini_file srp_non_srg_self_obss_pd_enable "$srp_non_srg_self_obss_pd_enable"

	config_get allow_mon_vaps_in_sr qcawifi allow_mon_vaps_in_sr
	[ -n "$allow_mon_vaps_in_sr" ] && update_ini_file allow_mon_vaps_in_sr  "$allow_mon_vaps_in_sr"

	config_get rnr_6ghz_driver_override qcawifi rnr_6ghz_driver_override
	[ -n "$rnr_6ghz_driver_override" ] && update_ini_file rnr_6ghz_driver_override "$rnr_6ghz_driver_override"

	config_get rnr_selective_nontx_add qcawifi rnr_selective_nontx_add
	[ -n "$rnr_selective_nontx_add" ] && update_ini_file rnr_selective_nontx_add "$rnr_selective_nontx_add"

	config_get max_rnr_ie_allowed qcawifi max_rnr_ie_allowed
	[ -n "$max_rnr_ie_allowed" ] && update_ini_file max_rnr_ie_allowed "$max_rnr_ie_allowed"

	config_get re_ul_resp qcawifi re_ul_resp
	[ -n "$re_ul_resp" ] && update_ini_file re_ul_resp "$re_ul_resp"

	config_get_bool icm_enable icm enable 0
	if [ $icm_enable -ne 0 ]
	then
		update_ini_file externalacs_enable 1
	else
		update_ini_file externalacs_enable 0
	fi

	config_get iot_sim qcawifi iot_sim $def_iot_sim

	if [ -f "/lib/modules/qca-whunt-modules" ]; then
		load_qcawhunt
	fi

	if [ $ker_ver == 5 ]; then
		backup_module_params_to_ini "$ol_args" "$qdf_args" "$umac_args"
	fi

	config_get load_rawsimulation_mod qcawifi load_rawsimulation_mod 0

	config_get carrier_vow_optimization qcawifi carrier_vow_optimization
	[ -n "$carrier_vow_optimization" ] && update_ini_file carrier_vow_optimization "$carrier_vow_optimization"

	for mod in $(cat /lib/wifi/qca-wifi-modules); do
		case ${mod} in
			umac) [ -d /sys/module/${mod} ] || { \

				insmod_cmd ${mod} "${umac_args}" || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawificfg80211 $recover
					return 1
				}
			};;

			qdf) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} "${qdf_args}" || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawificfg80211 $recover
					return 1
				}
			};;

			qca_ol) [ -d /sys/module/${mod} ] || { \
				load_ol_mod=1
				do_cold_boot_calibration_qcawificfg80211
				insmod_cmd ${mod} ${ol_args} || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawificfg80211 $recover
					return 1
				}
			};;

			qca_da|ath_dev|hst_tx99|ath_rate_atheros|ath_hal) [ -f /tmp/no_qca_da ] || { \
				[ -d /sys/module/${mod} ] || { \
					insmod_cmd ${mod} || { \
						if [ "$recover" != "1" ]; then
							lock -u /var/run/wifilock
						fi
						unload_qcawificfg80211 $recover
						return 1
					}
				}
			};;

			ath_pktlog) [ $enable_pktlog_support -eq 0 ] || { \
				[ -d /sys/module/${mod} ] || { \
					insmod_cmd ${mod} || { \
						if [ "$recover" != "1" ]; then
							lock -u /var/run/wifilock
						fi
						unload_qcawificfg80211 $recover
						return 1
					}
				}
			};;

			wifi_3_0_sim0) [ -d /sys/module/${mod} ] || { \
				insmod ${mod} "${qdf_args}" "${umac_args}" "${ol_args}" || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawificfg80211 $recover
					return 1
				}
			};;

			wifi_3_0_sim1) [ -d /sys/module/${mod} ] || { \
				insmod ${mod} netlink_ath_ssid_event=30 netlink_band_steering_event=22 netlink_acfg=27 "${qdf_args}" "${umac_args}" "${ol_args}" || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawificfg80211 $recover
					return 1
				}
			};;


			wifi_3_0_sim2) [ -d /sys/module/${mod} ] || { \
				insmod ${mod} netlink_ath_ssid_event=28 netlink_band_steering_event=23 netlink_acfg=26 "${qdf_args}" "${umac_args}" "${ol_args}" || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawificfg80211 $recover
					return 1
				}
			};;

			qca_iot_sim) [ $iot_sim -eq 1 ] && { \
				[ -d /sys/module/${mod} ] || { \
					insmod_cmd ${mod} || { \
						lock -u /var/run/wifilock
						unload_qcawificfg80211
						return 1
					}
				}
			};;

			rawmode_sim) [ $load_rawsimulation_mod -ne 0 ] && { \
				[ -d /sys/module/${mod} ] || { \
					insmod_cmd ${mod} || { \
						if [ "$recover" != "1" ]; then
							lock -u /var/run/wifilock
						fi
						unload_qcawificfg80211 $recover
						return 1
					}
				}
			};;

			*) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawificfg80211 $recover
					return 1
				}
			};;

		esac
	done

	if [ $load_ol_mod -eq 1 ]; then
		for wmi_dir in /sys/kernel/debug/WMI_SOC*;do
			case "$board_name" in
				ap-hk*|ap-ac*|ap-cp*|ap-oak*|ap-mp*)
				if [ -f $wmi_dir/filtered_wmi_cmds ]; then
					echo 0x5002 > $wmi_dir/filtered_wmi_cmds
					echo 0x5003 > $wmi_dir/filtered_wmi_cmds
					echo 0x5004 > $wmi_dir/filtered_wmi_cmds
					echo 0x5006 > $wmi_dir/filtered_wmi_cmds
					echo 0x5007 > $wmi_dir/filtered_wmi_cmds
					echo 0x5024 > $wmi_dir/filtered_wmi_cmds
					echo 0x4028 > $wmi_dir/filtered_wmi_cmds
				fi
				if [ -f $wmi_dir/filtered_wmi_evts ]; then
					echo 0x5001 > $wmi_dir/filtered_wmi_evts
					echo 0x5002 > $wmi_dir/filtered_wmi_evts
					echo 0x5006 > $wmi_dir/filtered_wmi_evts
					echo 0x5012 > $wmi_dir/filtered_wmi_evts
					echo 0x4023 > $wmi_dir/filtered_wmi_evts
				fi
				;;
				*)
				if [ -f $wmi_dir/filtered_wmi_cmds ]; then
					echo 0x9014 > $wmi_dir/filtered_wmi_cmds
					echo 0x9015 > $wmi_dir/filtered_wmi_cmds
					echo 0x9016 > $wmi_dir/filtered_wmi_cmds
					echo 0x9018 > $wmi_dir/filtered_wmi_cmds
					echo 0x9019 > $wmi_dir/filtered_wmi_cmds
					echo 0x9084 > $wmi_dir/filtered_wmi_cmds
					echo 0x9085 > $wmi_dir/filtered_wmi_cmds
				fi
				if [ -f $wmi_dir/filtered_wmi_evts ]; then
					echo 0x9004 > $wmi_dir/filtered_wmi_evts
					echo 0x9007 > $wmi_dir/filtered_wmi_evts
					echo 0x9047 > $wmi_dir/filtered_wmi_evts
					echo 0x9048 > $wmi_dir/filtered_wmi_evts
				fi
				;;
			esac

		done
	fi

       # Remove DA modules, if no DA chipset found
	for device in $(ls -d /sys/class/net/wifi* 2>&-); do
		[[ -f $device/is_offload ]] || {
			qca_da_needed=1
			break
		}
	done

	if [ $qca_da_needed -eq 0 ]; then
		if [ ! -f /tmp/no_qca_da ]; then
			echo "No Direct-Attach chipsets found." >/dev/console
			rmmod qca_da > /dev/null 2> /dev/null
			rmmod ath_dev > /dev/null 2> /dev/null
			rmmod hst_tx99 > /dev/null 2> /dev/null
			rmmod ath_rate_atheros > /dev/null 2> /dev/null
			rmmod ath_hal > /dev/null 2> /dev/null
			echo 1 > /tmp/no_qca_da
		fi
	fi

	if [ -f "/lib/update_smp_affinity.sh" ]; then
		. /lib/update_smp_affinity.sh
		config_foreach enable_smp_affinity_wifi wifi-device
	fi

	if [ "$recover" != "1" ]; then
		lock -u /var/run/wifilock
	fi

	update_ini_target_dp_default_reo_reset
}

load_qcawhunt() {

	mkdir -p /tmp/sysinfo/
	echo "Qualcomm Technologies, Inc. IPQ807x/AP-HK09" > /tmp/sysinfo/model
	echo "ap-hk09" > /tmp/sysinfo/board_name
	avail_entropy=$(cat /proc/sys/kernel/random/entropy_avail)

	while [ $avail_entropy -eq 0 ]; do
		avail_entropy=$(cat /proc/sys/kernel/random/entropy_avail)
		echo " Generating entropy using rngd daemon !!!" >/dev/console
		rngd -b -r /dev/urandom
		sleep 1
		echo " Stopping rngd daemon !!!" >/dev/console
		killall rngd
	done

	# Load whunt modules if the modules list is present
	if [ -f "/lib/modules/qca-whunt-modules" ]; then
	    if [ -S /vendor/whunt/whunt_wcd_socket ]; then
            echo " wcd already enabled !!!" >/dev/console
        else
            echo " starting wcd !!!" >/dev/console
            /usr/sbin/wcd  -s /vendor/whunt/whunt_wcd_socket &
        fi
		for mod in $(cat /lib/modules/qca-whunt-modules); do
			case ${mod} in
				whunt_utils) [ -d /sys/module/${mod} ] || { \
					insmod ${mod}  || { \
						unload_qcawhunt
						return 1
					}
				};;
				whunt_core) [ -d /sys/module/${mod} ] || { \
					 modprobe ${mod}  || { \
						unload_qcawhunt
						return 1
					}
				};;

			esac
		done
	sleep 3
	fi
}
unload_qcawhunt() {
	for mod in $(cat /lib/modules/qca-whunt-modules | sed '1!G;h;$!d'); do
		case ${mod} in
			mem_manager) continue;
		esac
	[ -d /sys/module/${mod} ] && rmmod_cmd ${mod}
	done
	killall wcd
	rm /vendor/whunt/whunt_wcd_socket
}

unload_qcawificfg80211() {
	local recover=$1
	config_load wireless
	config_foreach disable_qcawifi wifi-device

	eval "type qwrap_teardown" >/dev/null 2>&1 && qwrap_teardown

	rm -f /var/run/iface_mgr.conf
	[ -r /var/run/iface_mgr.pid ] && kill "$(cat "/var/run/iface_mgr.pid")"
	rm -f /var/run/iface_mgr.pid
	if [ `eval pgrep qldtool` ]; then
		killall qldtool >/dev/null 2>&1
	fi

	eval "type lowi_teardown" >/dev/null 2>&1 && lowi_teardown
	sleep 3
	killall cfr_test_app
	if [ "$recover" != "1" ]; then
		lock /var/run/wifilock
	fi
	for mod in $(cat /lib/wifi/qca-wifi-modules | sed '1!G;h;$!d'); do
        case ${mod} in
            mem_manager) continue;
            esac
		[ -d /sys/module/${mod} ] && rmmod_cmd ${mod}
	done
	if [ -f "/lib/modules/qca-whunt-modules" ]; then
		unload_qcawhunt
	fi
	if [ "$recover" != "1" ]; then
		lock -u /var/run/wifilock
	fi

}


set_vifs_down() {
	local device=$1
	local vif_name=$2
	local vif vifs
	config_get vifs "$device" vifs
	for vif in $vifs; do
		config_get ifname "$vif" ifname
		if [ "$ifname" = "$vif_name" ]; then
			uci_revert_state wireless "$vif"
			break;
		else
			continue;
		fi
	done
}

disable_recover_qcawificfg80211() {
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	disable_qcawificfg80211 1 $@
	[ -e /sys/firmware/devicetree/base/AUTO_MOUNT ] && {
		case "$board_name" in
			ap-mp*)
				touch /tmp/.crashed_$@
			;;
			*)
			;;
		esac
	}
}

enable_recover_qcawificfg80211() {
	local numcrashed
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	enable_qcawificfg80211 1 $@
	mbss_tx_vdev_config $@ 1

	[ -e /sys/firmware/devicetree/base/AUTO_MOUNT ] && {
		numcrashed=`ls /tmp/.crashed* | wc -l`
		case "$board_name" in
			ap-mp*)
			[ $numcrashed == 1 ] && {
				. /etc/init.d/wifi_fw_mount
				stop_wifi_fw "IPQ5018"
			}
			;;
			*)
			;;
		esac
		rm -f /tmp/.crashed_$@
	}
}

_disable_qcawificfg80211() {
	local device="$1"
	local vifs_name="$2"
	local parent=
	local retval=0
	local recover=0

	if [ "$1" = "1" ]; then
		device="$2"
		vifs_name="$3"
		recover="$1"
	fi

	#Invoked from wifi_hw_mode script
	if [ "$3" = "1" ]; then
		vifs_name=
	fi

	# Ap in dynamic mode means 3 radios will always be present
	# If in DBS mode then wifi2 should not be using cfg80211tool functions
	dynamic_hw_mode=`grep "dynamic_hw_mode" /ini/internal/global_i.ini | grep -m1 -v "^[#]" | awk -F'=' '{print $2}'`
	if [ "$dynamic_hw_mode" = "1" ]; then
		if [ $device = "wifi2" ]; then
			hw_mode_id=`retrieve_current_hw_mode`
			if [ $hw_mode_id -eq 1 ]; then
				return 0
			fi
		fi
	fi

	echo "$DRIVERS disable radio $device" >/dev/console

	find_qcawifi_phy "$device" >/dev/null || return 1

	# If qrfs is disabled in enable_qcawifi(),need to enable it
	if [ -f /var/qrfs_disabled_by_wifi ] && [ $(cat /var/qrfs_disabled_by_wifi) == 1 ]; then
		echo_cmd "1" /proc/qrfs/enable
		echo_cmd "0" /var/qrfs_disabled_by_wifi
	fi

	# disable_qcawifi also gets called for disabled radio during wifi up. Don't
	# remove the files if it gets from disabled radio.
	config_get disabled "$device" disabled
	if [ -f /tmp/wifi_nss_up_one_radio ] && [ "$disabled" = "0" ]; then
		rm /tmp/wifi_nss_up_one_radio
	fi
	config_get phy "$device" phy

	if [ -z $vifs_name ]; then
		set_wifi_down "$device"
	else
		set_vifs_down $device $vifs_name
	fi

	# in MBSS case, send notification to allow deletion of transmitting VAP
	config_get device_if "$device" device_if "cfg80211tool"
	config_get mbss_ie_enable qcawifi mbss_ie_enable
	if [ -n "$mbss_ie_enable" ]; then
		if [ "$mbss_ie_enable" != "0" ] && [ "$mbss_ie_enable" != "0x0" ]; then
		$device_if $device wifi_down_ind 1
		fi
	fi

	include /lib/network
	cd /sys/class/net
	for dev in *; do
		if [ ! -z "$vifs_name" -a "$dev" != "$vifs_name" ]; then
			continue
		fi

		[ -f /sys/class/net/${dev}/parent ] && { \
			local parent=$(cat /sys/class/net/${dev}/parent)
			[ -n "$parent" -a "$parent" = "$device" ] && { \
				[ -f "/var/run/hostapd-${dev}.lock" ] && { \
					wpa_cli -g /var/run/hostapd/global raw REMOVE ${dev}
					rm /var/run/hostapd-${dev}.lock
				}
				[ -f "/var/run/wpa_supplicant-${dev}.lock" ] && { \
					wpa_cli -g /var/run/wpa_supplicantglobal  interface_remove  ${dev}
					rm /var/run/wpa_supplicant-${dev}.lock
				}
				[ -f "/var/run/wapid-${dev}.conf" ] && { \
					kill "$(cat "/var/run/wifi-${dev}.pid")"
				}

				ifconfig "$dev" down
				unbridge "$dev"
				if [ -z "$recover" ] || [ "$recover" -eq "0" ]; then
				    iw "$dev" del
				fi
			}
			[ -f /var/run/hostapd_cred_${device}.bin ] && { \
				rm /var/run/hostapd_cred_${device}.bin
			}
		}

		if [ ! -z $vifs_name ]; then
			break
		fi
	done

	return 0
}

destroy_vap() {
	local ifname="$1"
	ifconfig $ifname down
	wlanconfig $ifname destroy
}

disable_qcawificfg80211() {
	if [ "$1" = "1" ]; then   #wifi_hw_mode only
        	_disable_qcawificfg80211 $@
	else
        	lock /var/run/wifilock
        	_disable_qcawificfg80211 $@
        	lock -u /var/run/wifilock
	fi
}

enable_qcawificfg80211() {
	local device="$1"
	local count=0
	local vifs_name="$2"
	local recover=0
	local wifi_hwm_script

	if [ "$1" = "1" ]; then
		device="$2"
		vifs_name="$3"
		recover="$1"
	fi

        #Invoked from wifi_hw_mode script
	if [ "$3" = "1" ]; then
		vifs_name=
		wifi_hwm_script="$3"
	fi

	if [ ! -z $vifs_name ]; then
		if [ "$recover" != "1" ]; then
			lock /var/run/wifilock
		fi
		enable_vifs_qcawificfg80211 $recover $device $vifs_name
		if [ "$recover" != "1" ]; then
			lock -u /var/run/wifilock
		fi
		return 0
	fi

	# Ap in dynamic mode means 3 radios will always be present
	# If in DBS mode then wifi2 should not be using cfg80211tool functions
	dynamic_hw_mode=`grep "dynamic_hw_mode" /ini/internal/global_i.ini | grep -m1 -v "^[#]" | awk -F'=' '{print $2}'`
	if [ "$dynamic_hw_mode" = "1" ]; then
		if [ $device = "wifi2" ]; then
			hw_mode_id=`retrieve_current_hw_mode`
			if [ $hw_mode_id -eq 1 ]; then
				return 0
			fi
		fi
	fi

	echo "$DRIVERS: enable radio $1" >/dev/console
	local num_radio_instamode=0
	local hk_ol_num=0
	local edge_ch_dep_applicable
	local hwcaps
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	load_qcawificfg80211 $recover

	find_qcawifi_phy "$device" || return 1

	if [ ! -f /lib/wifi/wifi_nss_override ]; then
		if [ -f /lib/wifi/wifi_nss_olcfg ] && [ $(cat /lib/wifi/wifi_nss_olcfg) != 0 ]; then
			touch /lib/wifi/wifi_nss_override
			echo_cmd 0 /lib/wifi/wifi_nss_override
		fi
	fi

	if [ -f /lib/wifi/wifi_nss_override ]; then
		cd /sys/class/net
		for all_device in $(ls -d wifi* 2>&-); do
			config_get_bool disabled "$all_device" disabled 0
			[ $disabled = 0 ] || continue
			config_get vifs "$all_device" vifs

			for vif in $vifs; do
				config_get mode "$vif" mode
				if [ $mode = "sta" ]; then
					num_radio_instamode=$(($num_radio_instamode + 1))
					break
				fi
			done
			if [ $num_radio_instamode = "0" ]; then
				break
			fi
		done

		# HK variants supports 3 radio sta configuration with fast lane enabled.
		# NSS WiFi Offload needs to be enabled for HK when 3 sta configured.
		nss_override="$(cat /lib/wifi/wifi_nss_override)"
		if [ $num_radio_instamode = "3" ]; then
			case "$board_name" in
				ap-dk*| ap152 | ap147 | ap151 | ap135 | ap137 | ap161)
				config_get nss_wifi_olcfg qcawifi nss_wifi_olcfg
				if [ -n "$nss_wifi_olcfg" ] && [ $nss_wifi_olcfg != 0 ]; then
					echo " Invalid Configuration: 3 stations in offload not supported"
					return 1
				fi
				if [ $nss_override = "0" ]; then
					echo_cmd 1 /lib/wifi/wifi_nss_override
					unload_qcawificfg80211 $recover
					device=$1
					load_qcawificfg80211 $recover
				fi
				;;
				*)
				;;
			esac
		else
			if [ $nss_override != "0" ]; then
				echo_cmd 0 /lib/wifi/wifi_nss_override
				unload_qcawificfg80211 $recover
				device=$1
				load_qcawificfg80211 $recover
			fi
		fi
	fi

	if [ "$recover" != "1" ]; then
		lock /var/run/wifilock
	fi

	config_get phy "$device" phy
	config_get device_if "$device" device_if "cfg80211tool"

	config_get enable_ema "$device" enable_ema
	[ -n "$enable_ema" ] && "$device_if" "$phy" enable_ema "$enable_ema"

	config_get interCACChan "$device" interCACChan
	[ -n "$interCACChan" ] && "$device_if" "$phy" interCACChan "$interCACChan"

	config_get country "$device" country
	if [ -z "$country" ]; then
		if ! set_default_country $device; then
			if [ "$recover" != "1" ]; then
				lock -u /var/run/wifilock
			fi
			return 1
		fi
	else
		# If the country parameter is a number (either hex or decimal), we
		# assume it's a regulatory domain - i.e. we use "$device_if" setCountryID.
		# Else we assume it's a country code - i.e. we use "$device_if" setCountry.
		case "$country" in
			[0-9]*)
				"$device_if" "$phy" setCountryID "$country"
			;;
			*)
				[ -n "$country" ] && "$device_if" "$phy" setCountry "$country"
			;;
		esac
	fi

	config_get chan_coex_disable "$device" chan_coex_disable
	[ -n "$chan_coex_disable" ] && "$device_if" "$phy" chan_coex_disable "$chan_coex_disable"

	config_get bsta_fixed_idmask "$device" bsta_fixed_idmask 255
	[ -n "$bsta_fixed_idmask" ] && "$device_if" "$phy" bsta_fixed_idmask "$bsta_fixed_idmask"


	config_get channel "$device" channel 0
	config_get vifs "$device" vifs
	config_get txpower "$device" txpower
	config_get htmode "$device" htmode auto
	config_get band "$device" band 0
	config_get edge_channel_deprioritize "$device" edge_channel_deprioritize 1
	[ auto = "$channel" ] && channel=0
	[ AUTO = "$channel" ] && channel=0

	# WAR to not use chan 36 as primary channel, when using higher BW.
	if { [ $band -eq 0 ] || [ $band -eq 2 ]; } && [ $channel -eq 36 ]; then
		if [ -f /sys/class/net/${device}/edge_ch_dep_applicable ]; then
			edge_ch_dep_applicable=$(cat /sys/class/net/${device}/edge_ch_dep_applicable)
			if [ $edge_ch_dep_applicable == "1" -a $edge_channel_deprioritize -eq 1 ]; then
				[ HT20 != "$htmode" ] && channel=40 && echo " Primary channel is changed to 40"
				[ HT40+ = "$htmode" ] && htmode=HT40- && echo " Mode changed to HT40MINUS with channel 40"
			fi
		fi
	fi

	config_get_bool antdiv "$device" diversity
	config_get antrx "$device" rxantenna
	config_get anttx "$device" txantenna
	config_get_bool softled "$device" softled
	config_get antenna "$device" antenna
	config_get distance "$device" distance

	[ -n "$antdiv" ] && echo "antdiv option not supported on this driver"
	[ -n "$antrx" ] && echo "antrx option not supported on this driver"
	[ -n "$anttx" ] && echo "anttx option not supported on this driver"
	[ -n "$softled" ] && echo "softled option not supported on this driver"
	[ -n "$antenna" ] && echo "antenna option not supported on this driver"
	[ -n "$distance" ] && echo "distance option not supported on this driver"

	# Advanced QCA wifi per-radio parameters configuration
	config_get txchainmask "$device" txchainmask
	[ -n "$txchainmask" ] && "$device_if" "$phy" txchainmask "$txchainmask"

	config_get rxchainmask "$device" rxchainmask
	[ -n "$rxchainmask" ] && "$device_if" "$phy" rxchainmask "$rxchainmask"

        config_get regdomain "$device" regdomain
        [ -n "$regdomain" ] && "$device_if" "$phy" setRegdomain "$regdomain"

	config_get preCACEn "$device" preCACEn
	[ -n "$preCACEn" ] && "$device_if" "$phy" preCACEn "$preCACEn"

	config_get upload_pktlog "$device" upload_pktlog
	[ -n "$upload_pktlog" ] && "$device_if" "$phy" upload_pktlog "$upload_pktlog"

	config_get rpt_max_phy "$device" rpt_max_phy
	[ -n "$rpt_max_phy" ] && "$device_if" "$phy" rpt_max_phy "$rpt_max_phy"

	config_get pCACTimeout "$device" pCACTimeout
	[ -n "$pCACTimeout" ] && "$device_if" "$phy" pCACTimeout "$pCACTimeout"

	config_get rCACEn "$device" rCACEn
	[ -n "$rCACEn" ] && "$device_if" "$phy" rCACEn "$rCACEn"

	config_get rCAC_freq "$device" rCAC_freq
	[ -n "$rCAC_freq" ] && "$device_if" "$phy" rCAC_freq "$rCAC_freq"

	config_get he_bsscolor "$device" he_bsscolor
	[ -n "$he_bsscolor" ] && "$device_if" "$phy" he_bsscolor ${he_bsscolor}

	config_get arp_protocol_tag "$device" rx_protocol_arp_type_tag
        [ -n "$arp_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 0 $arp_protocol_tag

        config_get dhcpv4_protocol_tag "$device" rx_protocol_dhcpv4_type_tag
        [ -n "$dhcpv4_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 4 $dhcpv4_protocol_tag

        config_get dhcpv6_protocol_tag "$device" rx_protocol_dhcpv6_type_tag
        [ -n "$dhcpv6_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 5 $dhcpv6_protocol_tag

        config_get dns_tcpv4_protocol_tag "$device" rx_protocol_dns_tcpv4_type_tag
        [ -n "$dns_tcpv4_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 6 $dns_tcpv4_protocol_tag

        config_get dns_tcpv6_protocol_tag "$device" rx_protocol_dns_tcpv6_type_tag
        [ -n "$dns_tcpv6_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 7 $dns_tcpv6_protocol_tag

        config_get dns_udpv4_protocol_tag "$device" rx_protocol_dns_udpv4_type_tag
        [ -n "$dns_udpv4_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 8 $dns_udpv4_protocol_tag

        config_get dns_udpv6_protocol_tag "$device" rx_protocol_dns_udpv6_type_tag
        [ -n "$dns_tcpv6_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 9 $dns_udpv6_protocol_tag

        config_get icmpv4_protocol_tag "$device" rx_protocol_icmpv4_type_tag
        [ -n "$icmpv4_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 10 $icmpv4_protocol_tag

        config_get icmpv6_protocol_tag "$device" rx_protocol_icmpv6_type_tag
        [ -n "$icmpv6_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 11 $icmpv6_protocol_tag

        config_get tcpv4_protocol_tag "$device" rx_protocol_tcpv4_type_tag
        [ -n "$tcpv4_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 12 $tcpv4_protocol_tag

        config_get tcpv6_protocol_tag "$device" rx_protocol_tcpv6_type_tag
        [ -n "$tcpv6_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 13 $tcpv6_protocol_tag

        config_get udpv4_protocol_tag "$device" rx_protocol_udpv4_type_tag
        [ -n "$udpv4_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 14 $udpv4_protocol_tag

        config_get udpv6_protocol_tag "$device" rx_protocol_udpv6_type_tag
        [ -n "$udpv6_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 15 $udpv6_protocol_tag

        config_get ipv4_protocol_tag "$device" rx_protocol_ipv4_type_tag
        [ -n "$ipv4_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 16 $ipv4_protocol_tag

        config_get ipv6_protocol_tag "$device" rx_protocol_ipv6_type_tag
        [ -n "$ipv6_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 17 $ipv6_protocol_tag

        config_get eap_protocol_tag "$device" rx_protocol_eap_type_tag
        [ -n "$eap_protocol_tag" ] && "$device_if" "$phy" set_rxProtocolTag 0 18 $eap_protocol_tag

	config_get mbss_auto "$device" mbss_auto
	[ -n "$mbss_auto" ] && "$device_if" "$phy" mbss_auto "$mbss_auto"

	config_get AMPDU "$device" AMPDU
	[ -n "$AMPDU" ] && "$device_if" "$phy" AMPDU "$AMPDU"

	config_get ampdudensity "$device" ampdudensity
	[ -n "$ampdudensity" ] && "$device_if" "$phy" ampdudensity "$ampdudensity"

	config_get_bool AMSDU "$device" AMSDU
	[ -n "$AMSDU" ] && "$device_if" "$phy" AMSDU "$AMSDU"

	config_get AMPDULim "$device" AMPDULim
	[ -n "$AMPDULim" ] && "$device_if" "$phy" AMPDULim "$AMPDULim"

	config_get AMPDUFrames "$device" AMPDUFrames
	[ -n "$AMPDUFrames" ] && "$device_if" "$phy" AMPDUFrames "$AMPDUFrames"

	config_get AMPDURxBsize "$device" AMPDURxBsize
	[ -n "$AMPDURxBsize" ] && "$device_if" "$phy" AMPDURxBsize "$AMPDURxBsize"

	config_get_bool bcnburst "$device" bcnburst 1
	[ -n "$bcnburst" ] && "$device_if" "$phy" set_bcnburst "$bcnburst"

	config_get set_smart_antenna "$device" set_smart_antenna
	[ -n "$set_smart_antenna" ] && "$device_if" "$phy" setSmartAntenna "$set_smart_antenna"

	config_get current_ant "$device" current_ant
	[ -n  "$current_ant" ] && "$device_if" "$phy" current_ant "$current_ant"

	config_get default_ant "$device" default_ant
	[ -n "$default_ant" ] && "$device_if" "$phy" default_ant "$default_ant"

	config_get ant_retrain "$device" ant_retrain
	[ -n "$ant_retrain" ] && "$device_if" "$phy" ant_retrain "$ant_retrain"

	config_get retrain_interval "$device" retrain_interval
	[ -n "$retrain_interval" ] && "$device_if" "$phy" retrain_interval "$retrain_interval"

	config_get retrain_drop "$device" retrain_drop
	[ -n "$retrain_drop" ] && "$device_if" "$phy" retrain_drop "$retrain_drop"

	config_get ant_train "$device" ant_train
	[ -n "$ant_train" ] && "$device_if" "$phy" ant_train "$ant_train"

	config_get ant_trainmode "$device" ant_trainmode
	[ -n "$ant_trainmode" ] && "$device_if" "$phy" ant_trainmode "$ant_trainmode"

	config_get ant_traintype "$device" ant_traintype
	[ -n "$ant_traintype" ] && "$device_if" "$phy" ant_traintype "$ant_traintype"

	config_get ant_pktlen "$device" ant_pktlen
	[ -n "$ant_pktlen" ] && "$device_if" "$phy" ant_pktlen "$ant_pktlen"

	config_get ant_numpkts "$device" ant_numpkts
	[ -n "$ant_numpkts" ] && "$device_if" "$phy" ant_numpkts "$ant_numpkts"

	config_get ant_numitr "$device" ant_numitr
	[ -n "$ant_numitr" ] && "$device_if" "$phy" ant_numitr "$ant_numitr"

	config_get ant_train_thres "$device" ant_train_thres
	[ -n "$ant_train_thres" ] && "$device_if" "$phy" train_threshold "$ant_train_thres"

	config_get ant_train_min_thres "$device" ant_train_min_thres
	[ -n "$ant_train_min_thres" ] && "$device_if" "$phy" train_threshold "$ant_train_min_thres"

	config_get ant_traffic_timer "$device" ant_traffic_timer
	[ -n "$ant_traffic_timer" ] && "$device_if" "$phy" traffic_timer "$ant_traffic_timer"

	config_get dcs_enable "$device" dcs_enable
	[ -n "$dcs_enable" ] && "$device_if" "$phy" dcs_enable "$dcs_enable"

	config_get dcs_coch_int "$device" dcs_coch_int
	[ -n "$dcs_coch_int" ] && "$device_if" "$phy" set_dcs_coch_int "$dcs_coch_int"

	config_get dcs_errth "$device" dcs_errth
	[ -n "$dcs_errth" ] && "$device_if" "$phy" set_dcs_errth "$dcs_errth"

	config_get dcs_phyerrth "$device" dcs_phyerrth
	[ -n "$dcs_phyerrth" ] && "$device_if" "$phy" set_dcs_phyerrth "$dcs_phyerrth"

	config_get dcs_usermaxc "$device" dcs_usermaxc
	[ -n "$dcs_usermaxc" ] && "$device_if" "$phy" set_dcs_usermaxc "$dcs_usermaxc"

	config_get dcs_debug "$device" dcs_debug
	[ -n "$dcs_debug" ] && "$device_if" "$phy" set_dcs_debug "$dcs_debug"

	config_get_bool ce_debug_stats "$device" ce_debug_stats
	if [ -n "$ce_debug_stats" ]; then
		"$device_if" "$phy" ce_debug_stats "$ce_debug_stats"
	else
	case "$board_name" in
		ap-hk*|ap-ac*|ap-cp*|ap-oak*)
		"$device_if" "$phy" ce_debug_stats 1
		;;
		esac
	fi

	config_get set_ch_144 "$device" set_ch_144
	[ -n "$set_ch_144" ] && "$device_if" "$phy" setCH144 "$set_ch_144"

	config_get eppovrd_ch_144 "$device" eppovrd_ch_144
	[ -n "$eppovrd_ch_144" ] && "$device_if" "$phy" setCH144EppOvrd "$eppovrd_ch_144"

	config_get_bool ani_enable "$device" ani_enable
	[ -n "$ani_enable" ] && "$device_if" "$phy" ani_enable "$ani_enable"

	config_get_bool acs_bkscanen "$device" acs_bkscanen
	[ -n "$acs_bkscanen" ] && "$device_if" "$phy" acs_bkscanen "$acs_bkscanen"

	config_get acs_scanintvl "$device" acs_scanintvl
	[ -n "$acs_scanintvl" ] && "$device_if" "$phy" acs_scanintvl "$acs_scanintvl"

	config_get acs_rssivar "$device" acs_rssivar
	[ -n "$acs_rssivar" ] && "$device_if" "$phy" acs_rssivar "$acs_rssivar"

	config_get acs_chloadvar "$device" acs_chloadvar
	[ -n "$acs_chloadvar" ] && "$device_if" "$phy" acs_chloadvar "$acs_chloadvar"

	config_get acs_lmtobss "$device" acs_lmtobss
	[ -n "$acs_lmtobss" ] && "$device_if" "$phy" acs_lmtobss "$acs_lmtobss"

	config_get acs_ctrlflags "$device" acs_ctrlflags
	[ -n "$acs_ctrlflags" ] && "$device_if" "$phy" acs_ctrlflags "$acs_ctrlflags"

	config_get acs_dbgtrace "$device" acs_dbgtrace
	[ -n "$acs_dbgtrace" ] && "$device_if" "$phy" acs_dbgtrace "$acs_dbgtrace"

	config_get_bool acs_pcaconly "$device" acs_pcaconly
	[ -n "$acs_pcaconly" ] && "$device_if" "$phy" acs_pcaconly "$acs_pcaconly"

	config_get_bool acs_chan_grade_algo "$device" acs_chan_grade_algo
	[ -n "$acs_chan_grade_algo" ] && "$device_if" "$phy" acs_chan_grade_algo "$acs_chan_grade_algo"

	config_get set_acs_chan_eff_var "$device" set_acs_chan_eff_var
	[ -n "$set_acs_chan_eff_var" ] && "$device_if" "$phy" set_acs_chan_eff_var "$set_acs_chan_eff_var"

	config_get set_acs_near_range_weightage "$device" set_acs_near_range_weightage
	[ -n "$set_acs_near_range_weightage" ] && "$device_if" "$phy" set_acs_near_range_weightage "$set_acs_near_range_weightage"

	config_get set_acs_mid_range_weightage "$device" set_acs_mid_range_weightage
	[ -n "$set_acs_mid_range_weightage" ] && "$device_if" "$phy" set_acs_mid_range_weightage "$set_acs_mid_range_weightage"

	config_get set_acs_far_range_weightage "$device" set_acs_far_range_weightage
	[ -n "$set_acs_far_range_weightage" ] && "$device_if" "$phy" set_acs_far_range_weightage "$set_acs_far_range_weightage"

	config_get_bool dscp_ovride "$device" dscp_ovride
	[ -n "$dscp_ovride" ] && "$device_if" "$phy" set_dscp_ovride "$dscp_ovride"

	config_get reset_dscp_map "$device" reset_dscp_map
	[ -n "$reset_dscp_map" ] && "$device_if" "$phy" reset_dscp_map "$reset_dscp_map"

	config_get dscp_tid_map "$device" dscp_tid_map
	[ -n "$dscp_tid_map" ] && "$device_if" "$phy" set_dscp_tid_map $dscp_tid_map

        #Default enable IGMP overide & TID=6
	"$device_if" "$phy" sIgmpDscpOvrid 1
	"$device_if" "$phy" sIgmpDscpTidMap 6

	config_get_bool igmp_dscp_ovride "$device" igmp_dscp_ovride
	[ -n "$igmp_dscp_ovride" ] && "$device_if" "$phy" sIgmpDscpOvrid "$igmp_dscp_ovride"

	config_get igmp_dscp_tid_map "$device" igmp_dscp_tid_map
	[ -n "$igmp_dscp_tid_map" ] && "$device_if" "$phy" sIgmpDscpTidMap "$igmp_dscp_tid_map"

	config_get_bool hmmc_dscp_ovride "$device" hmmc_dscp_ovride
	[ -n "$hmmc_dscp_ovride" ] && "$device_if" "$phy" sHmmcDscpOvrid "$hmmc_dscp_ovride"

	config_get hmmc_dscp_tid_map "$device" hmmc_dscp_tid_map
	[ -n "$hmmc_dscp_tid_map" ] && "$device_if" "$phy" sHmmcDscpTidMap "$hmmc_dscp_tid_map"

	config_get_bool blk_report_fld "$device" blk_report_fld
	[ -n "$blk_report_fld" ] && "$device_if" "$phy" setBlkReportFld "$blk_report_fld"

	config_get_bool drop_sta_query "$device" drop_sta_query
	[ -n "$drop_sta_query" ] && "$device_if" "$phy" setDropSTAQuery "$drop_sta_query"

	config_get_bool burst "$device" burst
	[ -n "$burst" ] && "$device_if" "$phy" burst "$burst"

	config_get burst_dur "$device" burst_dur
	[ -n "$burst_dur" ] && "$device_if" "$phy" burst_dur "$burst_dur"

	config_get TXPowLim2G "$device" TXPowLim2G
	[ -n "$TXPowLim2G" ] && "$device_if" "$phy" TXPowLim2G "$TXPowLim2G"

	config_get TXPowLim5G "$device" TXPowLim5G
	[ -n "$TXPowLim5G" ] && "$device_if" "$phy" TXPowLim5G "$TXPowLim5G"

	config_get cck_tx_enable "$device" cck_tx_enable
	[ -n "$cck_tx_enable" ] && "$device_if" "$phy" cck_tx_enable "$cck_tx_enable"

	case "$board_name" in
		ap-hk*|ap-ac*|ap-cp*|ap-oak*|ap-mp*)
		echo "Enable ol_stats by default for Lithium platforms"
		"$device_if" "$phy" enable_ol_stats 1
	;;
		*) echo "ol_stats is disabled for non-Lithium platforms"
	;;
	esac

	config_get_bool enable_ol_stats "$device" enable_ol_stats
	[ -n "$enable_ol_stats" ] && "$device_if" "$phy" enable_ol_stats "$enable_ol_stats"

	config_get emiwar80p80 "$device" emiwar80p80
	[ -n "$emiwar80p80" ] && "$device_if" "$phy" emiwar80p80 "$emiwar80p80"

	config_get_bool rst_tso_stats "$device" rst_tso_stats
	[ -n "$rst_tso_stats" ] && "$device_if" "$phy" rst_tso_stats "$rst_tso_stats"

	config_get_bool rst_lro_stats "$device" rst_lro_stats
	[ -n "$rst_lro_stats" ] && "$device_if" "$phy" rst_lro_stats "$rst_lro_stats"

	config_get_bool rst_sg_stats "$device" rst_sg_stats
	[ -n "$rst_sg_stats" ] && "$device_if" "$phy" rst_sg_stats "$rst_sg_stats"

	config_get_bool set_fw_recovery "$device" set_fw_recovery
	[ -n "$set_fw_recovery" ] && "$device_if" "$phy" set_fw_recovery "$set_fw_recovery"

	config_get_bool allowpromisc "$device" allowpromisc
	[ -n "$allowpromisc" ] && "$device_if" "$phy" allowpromisc "$allowpromisc"

	config_get set_sa_param "$device" set_sa_param
	[ -n "$set_sa_param" ] && "$device_if" "$phy" set_sa_param $set_sa_param

	config_get_bool aldstats "$device" aldstats
	[ -n "$aldstats" ] && "$device_if" "$phy" aldstats "$aldstats"

	config_get macaddr "$device" macaddr
	[ -n "$macaddr" ] && "$device_if" "$phy" setHwaddr "$macaddr"

	config_get promisc "$device" promisc
	[ -n "$promisc" ] && "$device_if" "$phy" promisc $promisc

	config_get mode0 "$device" mode0
	[ -n "$mode0" ] && "$device_if" "$phy" fc_buf_min 2501

	config_get mode1 "$device" mode1
	[ -n "$mode1" ] && "$device_if" "$phy" fc_buf_min 0

	handle_aggr_burst() {
		local value="$1"
		[ -n "$value" ] && "$device_if" "$phy" aggr_burst $value
	}

	config_list_foreach "$device" aggr_burst handle_aggr_burst

	config_get_bool block_interbss "$device" block_interbss
	[ -n "$block_interbss" ] && "$device_if" "$phy" block_interbss "$block_interbss"

	config_get set_pmf "$device" set_pmf
	[ -n "$set_pmf" ] && "$device_if" "$phy" set_pmf "${set_pmf}"

	config_get txbf_snd_int "$device" txbf_snd_int 100
	[ -n "$txbf_snd_int" ] && "$device_if" "$phy" txbf_snd_int "$txbf_snd_int"

	config_get mcast_echo "$device" mcast_echo
	[ -n "$mcast_echo" ] && "$device_if" "$phy" mcast_echo "${mcast_echo}"

	config_get obss_rssi_th "$device" obss_rssi_th 35
	[ -n "$obss_rssi_th" ] && "$device_if" "$phy" obss_rssi_th "${obss_rssi_th}"

	config_get obss_rxrssi_th "$device" obss_rxrssi_th 35
	[ -n "$obss_rxrssi_th" ] && "$device_if" "$phy" obss_rxrssi_th "${obss_rxrssi_th}"

        config_get acs_txpwr_opt "$device" acs_txpwr_opt
        [ -n "$acs_txpwr_opt" ] && "$device_if" "$phy" acs_tcpwr_opt "${acs_txpwr_opt}"

        config_get set_mu_ppdu_dur "$device" set_mu_ppdu_dur
        [ -n "$set_mu_ppdu_dur" ] && "$device_if" "$phy" set_mu_ppdu_dur "$set_mu_ppdu_dur"

	config_get obss_long_slot "$device" obss_long_slot
	[ -n "$obss_long_slot" ] && "$device_if" "$phy" obss_long_slot "${obss_long_slot}"

	config_get staDFSEn "$device" staDFSEn
	[ -n "$staDFSEn" ] && "$device_if" "$phy" staDFSEn "${staDFSEn}"

	config_get scan_over_cac_en "$device" scan_over_cac_en
	[ -n "$scan_over_cac_en" ] && "$device_if" "$phy" scan_over_cac_en "${scan_over_cac_en}"

        config_get dbdc_enable "$device" dbdc_enable
        [ -n "$dbdc_enable" ] && "$device_if" "$phy" dbdc_enable "${dbdc_enable}"

        config_get client_mcast "$device" client_mcast
        [ -n "$client_mcast" ] && "$device_if" "$phy" client_mcast "${client_mcast}"

        config_get pas_scanen "$device" pas_scanen
        [ -n "$pas_scanen" ] && "$device_if" "$phy" pas_scanen "${pas_scanen}"

        config_get delay_stavapup "$device" delay_stavapup
        [ -n "$delay_stavapup" ] && "$device_if" "$phy" delay_stavapup "${delay_stavapup}"

        config_get tid_override_queue_map "$device" tid_override_queue_map
        [ -n "$tid_override_queue_map" ] && "$device_if" "$phy" queue_map "${tid_override_queue_map}"

        config_get channel_block_mode "$device" channel_block_mode
        [ -n "$channel_block_mode" ] && "$device_if" "$phy" acs_bmode "${channel_block_mode}"

        config_get no_vlan "$device" no_vlan
        [ -n "$no_vlan" ] && "$device_if" "$phy" no_vlan "${no_vlan}"

        config_get setNxtRadarFreq "$device" setNxtRadarFreq
        [ -n "$setNxtRadarFreq" ] && "$device_if" "$phy" setNxtRadarFreq "${setNxtRadarFreq}"

        config_get discon_time qcawifi discon_time 10
        [ -n "$discon_time" ] && "$device_if" "$phy" discon_time "${discon_time}"

        config_get reconfig_time qcawifi reconfig_time 60
        [ -n "$reconfig_time" ] && "$device_if" "$phy" reconfig_time "${reconfig_time}"

        config_get alwaysprimary qcawifi alwaysprimary
        [ -n "$alwaysprimary" ] && "$device_if" "$phy" alwaysprimary "${alwaysprimary}"

        config_get samessid_disable qcawifi samessid_disable
        [ -n "$samessid_disable" ] && "$device_if" "$phy" samessid_disable "${samessid_disable}"

	config_get nss_wifi_olcfg qcawifi nss_wifi_olcfg
	if [ -z "$nss_wifi_olcfg" ]; then
		if [ -f /lib/wifi/wifi_nss_olcfg ]; then
			nss_wifi_olcfg="$(cat /lib/wifi/wifi_nss_olcfg)"
		fi
	fi

	if [ -n "$nss_wifi_olcfg" ] && [ "$nss_wifi_olcfg" != "0" ]; then
		local mp_256="$(ls /proc/device-tree/ | grep -rw "MP_256")"
		local mp_512="$(ls /proc/device-tree/ | grep -rw "MP_512")"
		config_get hwmode "$device" hwmode auto
		hk_ol_num="$(cat /lib/wifi/wifi_nss_hk_olnum)"
		#For 256 memory profile the range is preset in fw
		if [ "$mp_256" == "MP_256" ]; then
			:
		elif [ "$mp_512" == "MP_512" ]; then
			if [ $hk_ol_num -eq 3 ]; then
				if [ ! -f /tmp/wifi_nss_up_one_radio ]; then
					touch /tmp/wifi_nss_up_one_radio
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 31648
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
				fi
				case "$hwmode" in
				*axa | *ac)
					"$device_if" "$phy" fc_buf0_max 4096
					"$device_if" "$phy" fc_buf1_max 4096
					"$device_if" "$phy" fc_buf2_max 4096
					"$device_if" "$phy" fc_buf3_max 4096
					;;
				*)
					"$device_if" "$phy" fc_buf0_max 4096
					"$device_if" "$phy" fc_buf1_max 4096
					"$device_if" "$phy" fc_buf2_max 4096
					"$device_if" "$phy" fc_buf3_max 4096
					;;
				esac
			else
				if [ ! -f /tmp/wifi_nss_up_one_radio ]; then
					touch /tmp/wifi_nss_up_one_radio
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 30624
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 8192
				fi
				case "$hwmode" in
				*axa | *ac)
					"$device_if" "$phy" fc_buf0_max 8192
					"$device_if" "$phy" fc_buf1_max 8192
					"$device_if" "$phy" fc_buf2_max 8192
					"$device_if" "$phy" fc_buf3_max 8192
					;;
				*)
					"$device_if" "$phy" fc_buf0_max 8192
					"$device_if" "$phy" fc_buf1_max 8192
					"$device_if" "$phy" fc_buf2_max 8192
					"$device_if" "$phy" fc_buf3_max 8192
					;;
				esac
			fi
		else
		case "$board_name" in
		ap-ac01)
			;;
		ap-ac02)
			case "$hwmode" in
			*axa | *ac)
				"$device_if" "$phy" fc_buf0_max 4096
				"$device_if" "$phy" fc_buf1_max 8192
				"$device_if" "$phy" fc_buf2_max 8192
				"$device_if" "$phy" fc_buf3_max 8192
				;;
			*)
				"$device_if" "$phy" fc_buf0_max 4096
				"$device_if" "$phy" fc_buf1_max 4096
				"$device_if" "$phy" fc_buf2_max 4096
				"$device_if" "$phy" fc_buf3_max 4096
				;;
			esac
			;;
		ap-cp*|ap-mp*)
			if [ ! -f /tmp/wifi_nss_up_one_radio ]; then
				touch /tmp/wifi_nss_up_one_radio
				#reset the high water mark for NSS if range 0 value > 4096
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 30528
				#initially after init 4k buf for 5G and 4k for 2G will be allocated, later range will be configured
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 4096
			fi
			case "$hwmode" in
			*axa | *ac)
				"$device_if" "$phy" fc_buf0_max 8192
				"$device_if" "$phy" fc_buf1_max 8192
				"$device_if" "$phy" fc_buf2_max 8192
				"$device_if" "$phy" fc_buf3_max 8192
			;;
			*)
				"$device_if" "$phy" fc_buf0_max 4096
				"$device_if" "$phy" fc_buf1_max 4096
				"$device_if" "$phy" fc_buf2_max 4096
				"$device_if" "$phy" fc_buf3_max 4096
			;;
			esac
			;;
                ap-hk09*)
			local soc_version_major="$(cat /sys/module/cnss2/parameters/soc_version_major)"

			if [ $soc_version_major = 2 ];then
				if [ ! -f /tmp/wifi_nss_up_one_radio ]; then
					touch /tmp/wifi_nss_up_one_radio
					#reset the high water mark for NSS if range 0 value > 4096
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 67392
					#initially after init 4k buf for 5G and 4k for 2G will be allocated, later range will be configured
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 40960
				fi
				case "$hwmode" in
				*axa | *ac)
					"$device_if" "$phy" fc_buf0_max 32768
					"$device_if" "$phy" fc_buf1_max 32768
					"$device_if" "$phy" fc_buf2_max 32768
					"$device_if" "$phy" fc_buf3_max 32768
				;;
				*)
					"$device_if" "$phy" fc_buf0_max 16384
					"$device_if" "$phy" fc_buf1_max 16384
					"$device_if" "$phy" fc_buf2_max 16384
					"$device_if" "$phy" fc_buf3_max 32768
				;;
				esac
			else
				case "$hwmode" in
				*ac)
					#we distinguish the legacy chipset based on the hwcaps
					hwcaps=$(cat /sys/class/net/${phy}/hwcaps)
					if [ "$hwcaps" == "802.11an/ac" ]; then
						"$device_if" "$phy" fc_buf0_max 8192
						"$device_if" "$phy" fc_buf1_max 12288
						"$device_if" "$phy" fc_buf2_max 16384
					else
						"$device_if" "$phy" fc_buf0_max 4096
						"$device_if" "$phy" fc_buf1_max 8192
						"$device_if" "$phy" fc_buf2_max 12288
					fi
					"$device_if" "$phy" fc_buf3_max 16384
					;;
				*)
					"$device_if" "$phy" fc_buf0_max 4096
					"$device_if" "$phy" fc_buf1_max 8192
					"$device_if" "$phy" fc_buf2_max 12288
					"$device_if" "$phy" fc_buf3_max 16384
					;;
				esac
			fi
			;;
		ap-hk* | ap-oak*)
			if [ $hk_ol_num -eq 3 ]; then
				if [ ! -f /tmp/wifi_nss_up_one_radio ]; then
					touch /tmp/wifi_nss_up_one_radio
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 72512
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 36864
					update_ini_for_hk_sbs QCA8074V2_i.ini
				fi
				case "$hwmode" in
				*axa | *ac)
					"$device_if" "$phy" fc_buf0_max 24576
					"$device_if" "$phy" fc_buf1_max 24576
					"$device_if" "$phy" fc_buf2_max 24576
					"$device_if" "$phy" fc_buf3_max 32768
					;;
				*)
					"$device_if" "$phy" fc_buf0_max 16384
					"$device_if" "$phy" fc_buf1_max 16384
					"$device_if" "$phy" fc_buf2_max 16384
					"$device_if" "$phy" fc_buf3_max 24576
					;;
				esac
			else
				local soc_version_major="$(cat /sys/module/cnss2/parameters/soc_version_major)"

				if [ ! -f /tmp/wifi_nss_up_one_radio ]; then
					touch /tmp/wifi_nss_up_one_radio
					#reset the high water mark for NSS if range 0 value > 4096
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 67392
					#initially after init 4k buf for 5G and 4k for 2G will be allocated, later range will be configured
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 40960
					update_ini_for_hk_dbs QCA8074V2_i.ini
				fi
				case "$hwmode" in
				*axa | *ac)
					if [ $soc_version_major = 2 ];then
						"$device_if" "$phy" fc_buf0_max 32768
						"$device_if" "$phy" fc_buf1_max 32768
						"$device_if" "$phy" fc_buf2_max 32768
						"$device_if" "$phy" fc_buf3_max 32768
					else
						"$device_if" "$phy" fc_buf0_max 8192
						"$device_if" "$phy" fc_buf1_max 8192
						"$device_if" "$phy" fc_buf2_max 12288
						"$device_if" "$phy" fc_buf3_max 32768
					fi
				;;
				*)
					if [ $soc_version_major = 2 ];then
						"$device_if" "$phy" fc_buf0_max 16384
						"$device_if" "$phy" fc_buf1_max 16384
						"$device_if" "$phy" fc_buf2_max 16384
						"$device_if" "$phy" fc_buf3_max 32768
					else
						"$device_if" "$phy" fc_buf0_max 4096
						"$device_if" "$phy" fc_buf1_max 8192
						"$device_if" "$phy" fc_buf2_max 12288
						"$device_if" "$phy" fc_buf3_max 16384
					fi
				;;
				esac
			fi
			;;
		*)
			case "$hwmode" in
			*ng)
				"$device_if" "$phy" fc_buf0_max 5120
				"$device_if" "$phy" fc_buf1_max 8192
				"$device_if" "$phy" fc_buf2_max 12288
				"$device_if" "$phy" fc_buf3_max 16384
				;;
			*ac)
				"$device_if" "$phy" fc_buf0_max 8192
				"$device_if" "$phy" fc_buf1_max 16384
				"$device_if" "$phy" fc_buf2_max 24576
				"$device_if" "$phy" fc_buf3_max 32768
				;;
			*)
				"$device_if" "$phy" fc_buf0_max 5120
				"$device_if" "$phy" fc_buf1_max 8192
				"$device_if" "$phy" fc_buf2_max 12288
				"$device_if" "$phy" fc_buf3_max 16384
				;;
			esac
			;;
		esac
		fi
	else
		local mp_512="$(ls /proc/device-tree/ | grep -rw "MP_512")"
		config_get hwmode "$device" hwmode auto
		if [ "$mp_512" == "MP_512" ]; then
			case "$hwmode" in
				*axa | *ac)
					# For 128 clients
					"$device_if" "$phy" fc_buf_max 8192
					;;
				esac
		fi
	fi

	if [ $nss_wifi_olcfg == 0 ]; then
		sysctl_cmd dev.nss.n2hcfg.n2h_queue_limit_core0 2048
		sysctl_cmd dev.nss.n2hcfg.n2h_queue_limit_core1 2048
	else
		sysctl_cmd dev.nss.n2hcfg.n2h_queue_limit_core0 256
		sysctl_cmd dev.nss.n2hcfg.n2h_queue_limit_core1 256
	fi

	config_tx_fc_buf "$phy"

	# Enable RPS and disable qrfs, if rxchainmask is 15 for some platforms
	disable_qrfs_wifi=0
	enable_rps_wifi=0
	if [ $("$device_if" "$phy" get_rxchainmask | awk -F ':' '{ print $2 }') -gt 3 ]; then
		disable_qrfs_wifi=1
		enable_rps_wifi=1
	fi

	if [ "$wifi_hwm_script" = "1" ]; then
		enable_vifs_qcawificfg80211 $recover $device $wifi_hwm_script
	else
		enable_vifs_qcawificfg80211 $recover $device $vifs_name
	fi

	config_get wifi_debug_sh $device wifi_debug_sh
	[ -n "$wifi_debug_sh" -a -e "$wifi_debug_sh" ] && sh "$wifi_debug_sh"

        config_get primaryradio "$device" primaryradio
        [ -n "$primaryradio" ] && "$device_if" "$phy" primaryradio "${primaryradio}"

        config_get nobckhlradio "$device" nobckhlradio
        [ -n "$nobckhlradio" ] && "$device_if" "$phy" nobckhlradio "${nobckhlradio}"

        config_get CSwOpts "$device" CSwOpts
        [ -n "$CSwOpts" ] && "$device_if" "$phy" CSwOpts "${CSwOpts}"

	if [ $disable_qrfs_wifi == 1 ] && [ -f "/lib/update_system_params.sh" ]; then
		. /lib/update_system_params.sh
		disable_qrfs
	fi

	if [ "$recover" != "1" ]; then
		lock -u /var/run/wifilock
	fi
}

enable_vifs_qcawificfg80211() {
	local device="$2"
	local vifs_name="$3"
	local wifi_hwm_script=
	local recover="$1"
	local edge_ch_dep_applicable

	print_rl_set=0

	#Invoked from wifi_hw_mode script
	if [ "$3" = "1" ]; then
		vifs_name=
		wifi_hwm_script="$3"
	fi

	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	config_get vifs "$device" vifs
	config_get phy "$device" phy
	config_get device_if "$device" device_if "cfg80211tool"
	config_get band "$device" band 0
	config_get htmode "$device" htmode auto
	config_get channel "$device" channel 0
	config_get edge_channel_deprioritize "$device" edge_channel_deprioritize 1
	[ auto = "$channel" ] && channel=0
	[ AUTO = "$channel" ] && channel=0

	# WAR to not use chan 36 as primary channel, when using higher BW.
	if { [ $band -eq 0 ] || [ $band -eq 2 ]; } && [ $channel -eq 36 ]; then
		if [ -f /sys/class/net/${device}/edge_ch_dep_applicable ]; then
			edge_ch_dep_applicable=$(cat /sys/class/net/${device}/edge_ch_dep_applicable)
			if [ $edge_ch_dep_applicable == "1" -a $edge_channel_deprioritize -eq 1 ]; then
				[ HT20 != "$htmode" ] && channel=40 && echo " Primary channel is changed to 40"
				[ HT40+ = "$htmode" ] && htmode=HT40- && echo " Mode changed to HT40MINUS with channel 40"
			fi
		fi
	fi

	case "$board_name" in
		ap-hk*|ap-ac*|ap-cp*|ap-oak*|ap-mp*)
		echo "Enable ol_stats by default for Lithium platforms"
		"$device_if" "$phy" enable_ol_stats 1
	;;
		*) echo "ol_stats is disabled for non-Lithium platforms"
	;;
	esac

	config_get_bool enable_ol_stats "$device" enable_ol_stats
	[ -n "$enable_ol_stats" ] && "$device_if" "$phy" enable_ol_stats "$enable_ol_stats"

	config_get_bool low_latency_mode "$device" low_latency_mode
	[ -n "$low_latency_mode" ] && "$device_if" "$phy" low_latency_mode "$low_latency_mode"

	for vif in $vifs; do
		config_get ifname "$vif" ifname
		if [ ! -z "$vifs_name" -a "$ifname" != "$vifs_name" ]; then
			continue
		fi
		config_get MapBSSType "$vif" MapBSSType

		# MapBSSType 64, vap is backhaul BSS
		if [ $(($((MapBSSType&64)) >> 6)) -eq 1 ]; then
			backhaul_BSS=1 # The radio has a backhaul BSS vap configured
			config_get backhaul_ssid "$vif" ssid
			config_get backhaul_key "$vif" key
		fi

		if [ ! -z "$vifs_name" ]; then
			break
		fi
	done

	if [ -z "$vifs_name" ]; then
		ifconfig "$phy" up
	fi

	for vif in $vifs; do
		local start_hostapd=

		config_get ifname "$vif" ifname
		if [ ! -z "$vifs_name" -a "$ifname" != "$vifs_name" ]; then
			continue
		fi

		config_get mode "$vif" mode
		config_get enc "$vif" encryption "none"

		case "$enc" in
			wep*|mixed*|psk*|wpa*|8021x)
				start_hostapd=1
				config_get key "$vif" key
			;;
		esac

		case "$mode" in
			ap|wrap)
				if [ -n "$start_hostapd" ] && [ $count -lt 2 ] && eval "type hostapd_config_multi_cred" 2>/dev/null >/dev/null; then
					hostapd_config_multi_cred "$vif"
					count=$(($count + 1))
				fi
	  			;;
                esac

		if [ ! -z "$vifs_name" ]; then
			break
		fi
	done

	echo "number of vifs: $vifs" >/dev/console

	# Enable RPS and disable qrfs, if rxchainmask is 15 for some platforms
	disable_qrfs_wifi=0
	enable_rps_wifi=0
	if [ $("$device_if" "$phy" get_rxchainmask | awk -F ':' '{ print $2 }') -gt 3 ]; then
		disable_qrfs_wifi=1
		enable_rps_wifi=1
	fi

	for vif in $vifs; do
		config_get ifname "$vif" ifname
		if [ ! -z "$vifs_name" -a "$ifname" != "$vifs_name" ]; then
			continue
		fi

		local start_hostapd= vif_txpower= nosbeacon= wlanaddr=""
		local wlanmode
		local is_valid_owe_group=0
		local is_valid_sae_group=0
		config_get ifname "$vif" ifname
		config_get ppe_vp "$vif" ppe_vp 0
		config_get enc "$vif" encryption "none"
		config_get eap_type "$vif" eap_type
		config_get mode "$vif" mode
		config_get force_tkip "$vif" force_tkip 0
		wlanmode=$mode
		pmode=$mode

		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		if [ -f /sys/class/net/$device/ciphercaps ]
		then
			case "$enc" in
				*gcmp*)
					echo "enc:GCMP" >&2
					cat /sys/class/net/$device/ciphercaps | grep -i "gcmp"
					if [ $? -ne 0 ]
					then
						echo "enc:GCMP is Not Supported on Radio" >&2
						continue
					fi
					;;
				*ccmp-256*)
					echo "enc:CCMP-256" >&2
					cat /sys/class/net/$device/ciphercaps | grep -i "ccmp-256"
					if [ $? -ne 0 ]
					then
						echo "enc:CCMP-256 is Not Supported on Radio" >&2
						continue
					fi
					;;
				*tkip*)
					echo "enc:TKIP" >&2
					if [ $band -eq 3 ] && [ $force_tkip -ne 1 ]
					then
						echo "enc:TKIP is Not Supported on 6GHz Radio" >&2
						continue
					fi
					;;
			esac
		fi

		[ "$wlanmode" = "ap" ] && wlanmode="__ap"
		[ "$wlanmode" = "sta" ] && wlanmode="managed"
		[ "$wlanmode" = "lite_monitor" ] && wlanmode="monitor"
		[ "$wlanmode" = "ap_monitor" ] && wlanmode="__ap"
		[ "$wlanmode" = "ap_smart_monitor" ] && wlanmode="__ap"
		[ "$wlanmode" = "ap_lp_iot" ] && wlanmode="__ap"
		[ "$wlanmode" = "mesh" ] && wlanmode="__ap"
		[ "$wlanmode" = "wrap" ] && wlanmode="__ap"

		[ "$pmode" = "ap_monitor" ] && pmode="specialvap"
		[ "$pmode" = "ap_smart_monitor" ] && pmode="smart_monitor"
		[ "$pmode" = "ap_lp_iot" ] && pmode="lp_iot_mode"

		case "$mode" in
			sta)
				config_get_bool nosbeacon "$device" nosbeacon
				config_get qwrap_enable "$device" qwrap_enable 0
				[ $qwrap_enable -gt 0 ] && wlanaddr="00:00:00:00:00:00"
				;;
			adhoc)
				config_get_bool nosbeacon "$vif" sw_merge 1
				;;
		esac

		[ "$nosbeacon" = 1 ] || nosbeacon=""
		if [ -z "$recover" ] || [ "$recover" -eq "0" ]; then
		    wlanconfig "$ifname" create wlandev "$phy" wlanmode "$pmode" ${wlanaddr:+wlanaddr "$wlanaddr"} ${nosbeacon:+nosbeacon} -cfg80211

		    echo "cfg80211: ifname: $ifname mode: $wlanmode cfgphy: $(cat /sys/class/net/$phy/phy80211/name)" >&2
		    iw phy "$(cat /sys/class/net/$phy/phy80211/name)" interface add $ifname type $wlanmode
		    [ $? -ne 0 ] && {
			echo "enable_qcawifi($device): Failed to set up $mode vif $ifname" >&2
			continue
		    }
		    config_set "$vif" ifname "$ifname"
		fi
		if [ $nss_wifi_olcfg != 0 ] && [ $ppe_vp == 1 ]; then
		    echo "$ifname" > /proc/sys/nss/ppe_vp/create && echo "PPE VP enabled for $ifname" > /dev/console
		fi

		# Set the gloabl print ratelimiting on the first VDEV only
		if [ $print_rl_set -eq 0 ]; then
			config_get print_rl_count qcawifi print_rl_count
			config_get print_rl_time qcawifi print_rl_time

			if [ $print_rl_count -gt 0 ] && [ $print_rl_time -gt 0 ]; then
				cfg80211tool "$ifname" print_rl  $print_rl_count $print_rl_time
				echo "Setting print ratelimiting to $print_rl_count prints per $print_rl_time sec" >/dev/console
			fi

			print_rl_set=1
		fi

        #Next check is just valid when calling from wifi_hw_mode script.
        #Vaps that are appended to wireless config file for wifi2 in DBS mode
        #will not be brought up when switching to DBS_SBS mode
		if [ "$wifi_hwm_script" = "1" ]; then
			ifc_error_code=`ifconfig $ifname`
		    if [ -z "$ifc_error_code" ]; then
				if [ "$recover" != "1" ]; then
					lock -u /var/run/wifilock
				fi
				return 1
		    fi
		fi

		[ $qwrap_enable -gt 0 ] && iw "$ifname" set 4addr on >/dev/null 2>&1

		config_get hwmode "$device" hwmode auto
		pureg=0

		case "$hwmode:$htmode" in
			*na:HT40) "$device_if" "$ifname" mode 11NAHT40;;
			*ng:HT40) "$device_if" "$ifname" mode 11NGHT40;;
			*ac:HT40) "$device_if" "$ifname" mode 11ACVHT40;;
			*axg:HT40) "$device_if" "$ifname" mode 11GHE40;;
			*axa:HT40) "$device_if" "$ifname" mode 11AHE40;;
			*bg:*) "$device_if" "$ifname" mode 11G
				pureg=0
			;;
			*b:*) "$device_if" "$ifname" mode 11B
				;;
		esac

		case "$hwmode:$htmode" in
		# The parsing stops at the first match so we need to make sure
		# these are in the right orders (most generic at the end)
			*ng:HT20) hwmode=11NGHT20;;
			*ng:HT40-) hwmode=11NGHT40MINUS;;
			*ng:HT40+) hwmode=11NGHT40PLUS;;
			*ng:HT40) hwmode=11NGHT40;;
			*ng:*) hwmode=11NGHT20;;
			*na:HT20) hwmode=11NAHT20;;
			*na:HT40-) hwmode=11NAHT40MINUS;;
			*na:HT40+) hwmode=11NAHT40PLUS;;
			*na:HT40) hwmode=11NAHT40;;
			*na:*) hwmode=11NAHT40;;
			*ac:HT20) hwmode=11ACVHT20;;
			*ac:HT40+) hwmode=11ACVHT40PLUS;;
			*ac:HT40-) hwmode=11ACVHT40MINUS;;
			*ac:HT40) hwmode=11ACVHT40;;
			*ac:HT80) hwmode=11ACVHT80;;
			*ac:HT160) hwmode=11ACVHT160;;
			*ac:HT80_80) hwmode=11ACVHT80_80;;
                        *ac:*) hwmode=11ACVHT80
			       if [ -f /sys/class/net/$device/5g_maxchwidth ]; then
			           maxchwidth="$(cat /sys/class/net/$device/5g_maxchwidth)"
				   [ -n "$maxchwidth" ] && hwmode=11ACVHT$maxchwidth
			       fi
                               if [ "$mode" == "sta" ]; then
                                   cat /sys/class/net/$device/hwmodes | grep  "11AC_VHT80_80"
				   if [ $? -eq 0 ]; then
			               hwmode=11ACVHT80_80
				   fi
			       fi;;
			*axg:HT20) hwmode=11GHE20;;
			*axg:HT40-) hwmode=11GHE40MINUS;;
			*axg:HT40+) hwmode=11GHE40PLUS;;
			*axg:HT40) hwmode=11GHE40;;
			*axg:*) hwmode=11GHE20;;
			*axa:HT20) hwmode=11AHE20;;
			*axa:HT40+) hwmode=11AHE40PLUS;;
			*axa:HT40-) hwmode=11AHE40MINUS;;
			*axa:HT40) hwmode=11AHE40;;
			*axa:HT80) hwmode=11AHE80;;
			*axa:HT160) hwmode=11AHE160;;
			*axa:HT80_80) hwmode=11AHE80_80;;
			*axa:*) hwmode=11AHE80
				if [ -f /sys/class/net/$device/5g_maxchwidth ]; then
					maxchwidth="$(cat /sys/class/net/$device/5g_maxchwidth)"
					[ -n "$maxchwidth" ] && hwmode=11AHE$maxchwidth
				fi
				if [ "$mode" == "sta" ]; then
					cat /sys/class/net/$device/hwmodes | grep  "11AXA_HE80_80"
					if [ $? -eq 0 ]; then
						hwmode=11AHE80_80
					fi
				fi;;
			*b:*) hwmode=11B;;
			*bg:*) hwmode=11G;;
			*g:*) hwmode=11G; pureg=1;;
			*a:*) hwmode=11A;;
			*) hwmode=auto;;
		esac

		if [ "$pmode" = "specialvap" ] || [ "$pmode" = "smart_monitor" ] || [ "$pmode" = "monitor" ]|| [ "$pmode" = "lite_monitor" ] || [ "$pmode" = "lp_iot_mode" ]; then
			echo "HWMODE: $hwmode" > /dev/console
			"$device_if" "$ifname" mode "$hwmode"
			"$device_if" "$ifname" channel "$channel" "$band" > /dev/null 2>&1

			[ $pureg -gt 0 ] && "$device_if" "$ifname" pureg "$pureg"

			config_get ssid "$vif" ssid
			[ -n "$ssid" ] && {
				cfg80211tool "$ifname" ssid "$ssid"
			}
		fi #end of propritery modes

		[ "sta" = "$mode" ] && "$device_if" "$ifname" mode "$hwmode"
		[ 0 = "$channel" ] && "$device_if" "$ifname" mode "$hwmode"
		[ "$htmode" = "HT80_80" ] && "$device_if" "$ifname" mode "$hwmode"

		config_get map "$vif" map 0
		[ $map -gt 0 ] && "$device_if" "$ifname" map "$map"

		config_get MapBSSType "$vif" MapBSSType
		if [ ! -z $MapBSSType ]; then
			[ $MapBSSType -gt 0 ] && "$device_if" "$ifname" MapBSSType "$MapBSSType"
		fi

		config_get cfreq2 "$vif" cfreq2
		[ -n "$cfreq2" -a "$htmode" = "HT80_80" ] && "$device_if" "$ifname" cfreq2 "$cfreq2" "$band"

		#set channel; store in cfg80211 vap structures, use them while setting channels
		"$device_if" "$ifname" channel "$channel" "$band" >/dev/null 2>&1

		[ $pureg -gt 0 ] && cfg80211tool "$ifname" pureg "$pureg" #set pureg

		config_get puren "$vif" puren
		[ -n "$puren" ] && "$device_if" "$ifname" puren "$puren"

		config_get mbss_tx_vdev "$vif" mbss_tx_vdev
		[ -n "$mbss_tx_vdev" ] && "$device_if" "$ifname" mbss_tx_vdev "$mbss_tx_vdev"

		config_get_bool hidden "$vif" hidden 0
		"$device_if" "$ifname" hide_ssid "$hidden"

                config_get_bool dynamicbeacon "$vif" dynamicbeacon 0
                [ $hidden = 1 ] && "$device_if" "$ifname" dynamicbeacon "$dynamicbeacon"

                config_get db_rssi_thr "$vif" db_rssi_thr
                [ -n "$db_rssi_thr" ] && "$device_if" "$ifname" db_rssi_thr "$db_rssi_thr"

                config_get db_timeout "$vif" db_timeout
                [ -n "$db_timeout" ] && "$device_if" "$ifname" db_timeout "$db_timeout"

                config_get nrshareflag "$vif" nrshareflag
                [ -n "$nrshareflag" ] && "$device_if" "$ifname" nrshareflag "$nrshareflag"

		config_get shortgi "$vif" shortgi
		[ -n "$shortgi" ] && "$device_if" "$ifname" shortgi "${shortgi}"

		config_get_bool disablecoext "$vif" disablecoext
		[ -n "$disablecoext" ] && "$device_if" "$ifname" disablecoext "${disablecoext}"

		config_get chwidth "$vif" chwidth
		[ -n "$chwidth" ] && "$device_if" "$ifname" chwidth "${chwidth}"

		config_get multi_group_key "$vif" multi_group_key
		[ -n "$multi_group_key" ] && "$device_if" "$ifname" multi_group_key "${chwidth}"

		config_get max_group_key "$vif" max_group_key
		[ -n "$max_group_key" ] && "$device_if" "$ifname" max_group_key "${chwidth}"

		config_get wds "$vif" wds
		config_get map "$vif" map 0
		case "$wds" in
			1|on|enabled)	wds=1
				# Incase of map, wpa_supplicant enables 4-address mode after association.
				# So do not add STA interface to bridge yet.
				if [ $map -eq 0 ]; then
					iw "$ifname" set 4addr on >/dev/null 2>&1
				fi
				;;
			*)	wds=0
				;;
		esac
		"$device_if" "$ifname" wds "$wds" >/dev/null 2>&1

		config_get  backhaul "$vif" backhaul 0
                "$device_if" "$ifname" backhaul "$backhaul" >/dev/null 2>&1

		config_get TxBFCTL "$vif" TxBFCTL
		[ -n "$TxBFCTL" ] && "$device_if" "$ifname" TxBFCTL "$TxBFCTL"

		config_get bintval "$vif" bintval
		[ -n "$bintval" ] && "$device_if" "$ifname" bintval "$bintval"

		config_get_bool countryie "$vif" countryie
		[ -n "$countryie" ] && "$device_if" "$ifname" countryie "$countryie"

		config_get_bool vap_contryie "$vif" vap_contryie
		[ -n "$vap_contryie" ] && "$device_if" "$ifname" vap_contryie "$vap_contryie"

		config_get ppdu_duration "$device" ppdu_duration
		[ -n "$ppdu_duration" ] && "$device_if" "$phy" ppdu_duration "${ppdu_duration}"

		config_get he_ul_ppdu_dur "$device" he_ul_ppdu_dur
		[ -n "$he_ul_ppdu_dur" ] && "$device_if" "$phy" he_ul_ppdu_dur "${he_ul_ppdu_dur}"

		config_get own_ie_override "$vif" own_ie_override
                [ -n "$own_ie_override" ] && cfg80211tool "$ifname" rsn_override 1

		config_get_bool en_6g_sec_comp "$vif" en_6g_sec_comp 1
		"$device_if" "$ifname" en_6g_sec_comp "$en_6g_sec_comp"

		if [ $en_6g_sec_comp -eq 0 ]
		then
			config_get keymgmt_mask_6g "$vif" keymgmt_mask_6g 0x0FFFFFFF
			"$device_if" "$ifname" keymgmt_mask_6g "$keymgmt_mask_6g"
		fi

		config_get_bool sae "$vif" sae
		config_get_bool owe "$vif" owe
		config_get_bool dpp "$vif" dpp
		config_get pkex_code "$vif" pkex_code
		config_get suite_b "$vif" suite_b 0

		if [ $suite_b -eq 192 ]
		then
			cat /sys/class/net/$device/ciphercaps | grep -i "gcmp-256"
			if [ $? -ne 0 ]
			then
				echo "enc:GCMP-256 is Not Supported on Radio" > /dev/console
				destroy_vap $ifname
				continue
			fi
		elif [ $suite_b -ne 0 ]
		then
			echo "$suite_b bit security level is not supported for SUITE-B" > /dev/console
			destroy_vap $ifname
			continue
		fi

		if [ ! -z ${dpp} ]; then
			if [ "${dpp}" -eq 1 ]
			then
				cfg80211tool "$ifname" set_dpp_mode 1
				config_get dpp_type "$vif" dpp_type "qrcode"
				if [ "$dpp_type" != "qrcode" -a "$dpp_type" != "pkex" ]
				then
					echo "Invalid DPP type" > /dev/console
					destroy_vap $ifname
					continue
				elif [ "$dpp_type" == "pkex" ]
				then
					if [ -z "$pkex_code" ]
					then
						echo "pkex_code should not be NULL" > /dev/console
						destroy_vap $ifname
					fi
				fi
			fi
		fi

		check_sae_groups() {
			local force_invalid_group sae_groups=$(echo $1 | tr "," " ")
			config_get force_invalid_group "$vif" force_invalid_group 0

			# If force_invalid_group option is set, do not check for vaid SAE groups
			# WFA Negative Testcase
			if [ "${force_invalid_group}" -eq 1 ]
			then
				echo "Allowing invalid sae_groups for WFA negative testcase" > /dev/console
				return
			fi

			for sae_group_value in $sae_groups
			do
				case "$sae_group_value" in
					0|15|16|17|18|19|20|21)
					;;
					*)
						echo "Invalid sae_group: $sae_group_value" > /dev/console
						destroy_vap $ifname
						is_valid_sae_group=1
						break
				esac
			done
		}

		case "$enc" in
			none)
				# We start hostapd in open mode also
				start_hostapd=1
			;;
			wpa*|8021x|osen*)
				start_hostapd=1
			;;
			mixed*|wep*|psk*)
				start_hostapd=1
				config_get key "$vif" key
				config_get wpa_psk_file  "$vif" wpa_psk_file
				if [ -z "$key" ] && [ -z $wpa_psk_file ]
				then
					echo "Key is NULL" > /dev/console
					destroy_vap $ifname
					continue
				fi
				case "$enc" in
					*tkip*|wep*)
						if [ $sae -eq 1 ] || [ $owe -eq 1 ]
						then
							echo "With SAE/OWE enabled, tkip/wep enc is not supported" > /dev/console
							destroy_vap $ifname
							continue
						fi
					;;
				esac

				if [ $sae -eq 1 ]
				then
					pwid_exclusive=1
					pwid=0
					sae_password_count=0

					if [ "$mode" = "ap" ]
					then
						check_sae_pwid_capab() {
							local sae_password=$(echo $1)
							if [ -n "$sae_password" ]
							then
								sae_password_count=$((sae_password_count+1))

								case "$sae_password" in
									*"|id="*)
									pwid=1
									echo "pwid match" > /dev/console
									;;
									*)
									echo "pw only match" > /dev/console
									pwid_exclusive=0
									;;
								esac
							fi
						}
						config_list_foreach "$vif" sae_password check_sae_pwid_capab

						if [ -z "$$sae_password_count" ]
						then
							case "$key" in
								*"|id="*)
								pwid=1
								echo "pwid match" > /dev/console
								;;
								*)
								echo "pw only match" > /dev/console
								pwid_exclusive=0
								;;
							esac
						fi

						echo "sae password count:" $sae_password_count > /dev/console

						if [ $sae_password_count -eq 0 ] && [ -z "$key" ] && [ -z $wpa_psk_file ]
						then
							echo "key and sae_password are NULL" > /dev/console
							destroy_vap $ifname
							continue
						fi
						if [ $pwid -eq 1 ]
						then
							if [ $pwid_exclusive -eq 1 ]
							then
								"$device_if" "$ifname" en_sae_pwid 3
							else
								"$device_if" "$ifname" en_sae_pwid 1
							fi
						fi
						config_list_foreach "$vif" sae_groups check_sae_groups

					elif [ "$mode" = "sta" ]
					then
						config_get sae_password "$vif" sae_password
						if [ $sae_password -eq 0 ] && [ -z "$key" ] && [ -z $wpa_psk_file ]
						then
							echo "key and sae_password are NULL" > /dev/console
							destroy_vap $ifname
							continue
						fi
					fi
					[ $is_valid_sae_group = 1 ] && continue
				fi
			;;
			tkip*)
				if [ $sae -eq 1 ] || [ $owe -eq 1 ]
				then
					echo "With SAE/OWE enabled, tkip enc is not supported" > /dev/console
					destroy_vap $ifname
					continue
				fi
			;;
			wapi*)
				start_wapid=1
				config_get key "$vif" key
			;;
			#Needed ccmp*|gcmp* check for SAE OWE auth types
			ccmp*|gcmp*)
				start_hostapd=1
				config_get key "$vif" key
				config_get wpa_psk_file  "$vif" wpa_psk_file
				pwid_exclusive=1
				pwid=0
				sae_password_count=0
				if [ $sae -eq 1 ]
				then
					if [ "$mode" = "ap" ]
					then
						check_sae_pwid_capab() {
							local sae_password=$(echo $1)
							if [ -n "$sae_password" ]
							then
								sae_password_count=$((sae_password_count+1))

								case "$sae_password" in
									*"|id="*)
									pwid=1
									echo "pwid match" > /dev/console
									;;
									*)
									echo "pw only match" > /dev/console
									pwid_exclusive=0
									;;
								esac
							fi
						}
						config_list_foreach "$vif" sae_password check_sae_pwid_capab

						if [ -z "$$sae_password_count" ]
						then
							case "$key" in
								*"|id="*)
								pwid=1
								echo "pwid match" > /dev/console
								;;
								*)
								echo "pw only match" > /dev/console
								pwid_exclusive=0
								;;
							esac
						fi

						echo "sae password count:" $sae_password_count > /dev/console

						if [ $sae_password_count -eq 0 ] && [ -z "$key" ] && [ -z $wpa_psk_file ]
						then
							echo "key and sae_password are NULL" > /dev/console
							destroy_vap $ifname
							continue
						fi
						if [ $pwid -eq 1 ]
						then
							if [ $pwid_exclusive -eq 1 ]
							then
								"$device_if" "$ifname" en_sae_pwid 3
							else
								"$device_if" "$ifname" en_sae_pwid 1
							fi
						fi
						config_list_foreach "$vif" sae_groups check_sae_groups

					elif [ "$mode" = "sta" ]
					then
						config_get sae_password "$vif" sae_password
						if [ $sae_password -eq 0 ] && [ -z "$key" ] && [ -z $wpa_psk_file ]
						then
							echo "key and sae_password are NULL" > /dev/console
							destroy_vap $ifname
							continue
						fi
					fi
					[ $is_valid_sae_group = 1 ] && continue
				fi
				if [ $owe -eq 1 ]
				then
					if [ "$mode" = "ap" ]
					then
						check_owe_groups() {
							local owe_groups=$(echo $1 | tr "," " ")
							for owe_group_value in $owe_groups
							do
								case "$owe_group_value" in
									0|19|20|21)
									;;
									*)
										echo "Invalid owe_group: $owe_group_value" > /dev/console
										destroy_vap $ifname
										is_valid_owe_group=1
										break
								esac
							done
						}
						config_list_foreach "$vif" owe_groups check_owe_groups
					elif [ "$mode" = "sta" ]
                                        then
                                                config_get owe_group "$vif" owe_group 0
						case "$owe_group" in
							0|19|20|21)
							;;
							*)
								echo "Invalid owe_group: $owe_group" > /dev/console
								destroy_vap $ifname
								is_valid_owe_group=1
								break
						esac
                                        fi

					[ $is_valid_owe_group = 1 ] && continue
				fi
			;;
			sae*|dpp|psk2)
				start_hostapd=1
			;;
		esac

		case "$mode" in
			sta|adhoc)
				config_get addr "$vif" bssid
				[ -z "$addr" ] || {
#TODO
					iwconfig "$ifname" ap "$addr"
				}
			;;
		esac

		config_get_bool uapsd "$vif" uapsd 1
		"$device_if" "$ifname" uapsd "$uapsd"

		config_get powersave "$vif" powersave
		[ -n "$powersave" ] && "$device_if" "$ifname" powersave "${powersave}"

		config_get ant_ps_on "$vif" ant_ps_on
		[ -n "$ant_ps_on" ] && "$device_if" "$ifname" ant_ps_on "${ant_ps_on}"

		config_get ps_timeout "$vif" ps_timeout
		[ -n "$ps_timeout" ] && "$device_if" "$ifname" ps_timeout "${ps_timeout}"

		config_get mcastenhance "$vif" mcastenhance
		[ -n "$mcastenhance" ] && "$device_if" "$ifname" mcastenhance "${mcastenhance}"

		config_get disable11nmcs "$vif" disable11nmcs
		[ -n "$disable11nmcs" ] && "$device_if" "$ifname" disable11nmcs "${disable11nmcs}"

		config_get conf_11acmcs "$vif" conf_11acmcs
		[ -n "$conf_11acmcs" ] && "$device_if" "$ifname" conf_11acmcs "${conf_11acmcs}"

		config_get metimer "$vif" metimer
		[ -n "$metimer" ] && "$device_if" "$ifname" metimer "${metimer}"

		config_get metimeout "$vif" metimeout
		[ -n "$metimeout" ] && "$device_if" "$ifname" metimeout "${metimeout}"

		config_get_bool medropmcast "$vif" medropmcast
		[ -n "$medropmcast" ] && "$device_if" "$ifname" medropmcast "${medropmcast}"

		config_get me_adddeny "$vif" me_adddeny
		[ -n "$me_adddeny" ] && "$device_if" "$ifname" me_adddeny ${me_adddeny}

		#support independent repeater mode
		config_get vap_ind "$vif" vap_ind
		[ -n "$vap_ind" ] && "$device_if" "$ifname" vap_ind "${vap_ind}"

		#support extender ap & STA
		config_get extap "$vif" extap
		[ -n "$extap" ] && "$device_if" "$ifname" extap "${extap}"
		[ -n "$extap" ] && iw "$ifname" set 4addr on >/dev/null 2>&1

		config_get scanband "$vif" scanband
		[ -n "$scanband" ] && "$device_if" "$ifname" scanband "${scanband}"

		config_get periodicScan "$vif" periodicScan
		[ -n "$periodicScan" ] && "$device_if" "$ifname" periodicScan "${periodicScan}"

		config_get cwmin "$vif" cwmin
		[ -n "$cwmin" ] && "$device_if" "$ifname" cwmin ${cwmin}

		config_get cwmax "$vif" cwmax
		[ -n "$cwmax" ] && "$device_if" "$ifname" cwmax ${cwmax}

		config_get aifs "$vif" aifs
		[ -n "$aifs" ] && "$device_if" "$ifname" aifs ${aifs}

		config_get txoplimit "$vif" txoplimit
		[ -n "$txoplimit" ] && "$device_if" "$ifname" txoplimit ${txoplimit}

		config_get noackpolicy "$vif" noackpolicy
		[ -n "$noackpolicy" ] && "$device_if" "$ifname" noackpolicy ${noackpolicy}

		config_get_bool wmm "$vif" wmm
		[ -n "$wmm" ] && "$device_if" "$ifname" wmm "$wmm"

		config_get_bool doth "$vif" doth
		[ -n "$doth" ] && "$device_if" "$ifname" doth "$doth"

		config_get doth_chanswitch "$vif" doth_chanswitch
		[ -n "$doth_chanswitch" ] && "$device_if" "$ifname" doth_chanswitch ${doth_chanswitch}

		config_get quiet "$vif" quiet
		[ -n "$quiet" ] && "$device_if" "$ifname" quiet "$quiet"

		config_get mfptest "$vif" mfptest
		[ -n "$mfptest" ] && "$device_if" "$ifname" mfptest "$mfptest"

		config_get dtim_period "$vif" dtim_period
		[ -n "$dtim_period" ] && "$device_if" "$ifname" dtim_period "$dtim_period"

		config_get noedgech "$vif" noedgech
		[ -n "$noedgech" ] && "$device_if" "$ifname" noedgech "$noedgech"

		config_get ps_on_time "$vif" ps_on_time
		[ -n "$ps_on_time" ] && "$device_if" "$ifname" ps_on_time "$ps_on_time"

		config_get inact "$vif" inact
		[ -n "$inact" ] && "$device_if" "$ifname" inact "$inact"

		config_get wnm "$vif" wnm
		[ -n "$wnm" ] && "$device_if" "$ifname" wnm "$wnm"

		config_get ampdu "$vif" ampdu
		[ -n "$ampdu" ] && "$device_if" "$ifname" ampdu "$ampdu"

		config_get amsdu "$vif" amsdu
		[ -n "$amsdu" ] && "$device_if" "$ifname" amsdu "$amsdu"

		config_get maxampdu "$vif" maxampdu
		[ -n "$maxampdu" ] && "$device_if" "$ifname" maxampdu "$maxampdu"

		config_get vhtmaxampdu "$vif" vhtmaxampdu
		[ -n "$vhtmaxampdu" ] && "$device_if" "$ifname" vhtmaxampdu "$vhtmaxampdu"

		config_get setaddbaoper "$vif" setaddbaoper
		[ -n "$setaddbaoper" ] && "$device_if" "$ifname" setaddbaoper "$setaddbaoper"

		config_get addbaresp "$vif" addbaresp
		[ -n "$addbaresp" ] && "$device_if" "$ifname" $addbaresp

		config_get addba "$vif" addba
		[ -n "$addba" ] && "$device_if" "$ifname" addba $addba

		config_get delba "$vif" delba
		[ -n "$delba" ] && "$device_if" "$ifname" delba $delba

		config_get_bool stafwd "$vif" stafwd 0
		[ -n "$stafwd" ] && "$device_if" "$ifname" stafwd "$stafwd"

		config_get maclist "$vif" maclist
		[ -n "$maclist" ] && {
			# flush MAC list
			"$device_if" "$ifname" maccmd 3
			for mac in $maclist; do
				"$device_if" "$ifname" addmac "$mac"
			done
		}

		config_get macfilter "$vif" macfilter
		case "$macfilter" in
			allow)
				"$device_if" "$ifname" maccmd 1
			;;
			deny)
				"$device_if" "$ifname" maccmd 2
			;;
			*)
				# default deny policy if mac list exists
				[ -n "$maclist" ] && "$device_if" "$ifname" maccmd 2
			;;
		esac

		config_get nss "$vif" nss
		[ -n "$nss" ] && "$device_if" "$ifname" nss "$nss"

		config_get set_vdev_peer_prot_count "$vif" set_vdev_peer_prot_count
		[ -n "$set_vdev_peer_prot_count" ] && "$device_if" "$ifname" set_vdev_peer_prot_count "$set_vdev_peer_prot_count"

		config_get set_vdev_peer_prot_dropmask "$vif" set_vdev_peer_prot_dropmask
		[ -n "$set_vdev_peer_prot_dropmask" ] && "$device_if" "$ifname" set_vdev_peer_prot_dropmask "$set_vdev_peer_prot_dropmask"

		config_get vht_mcsmap "$vif" vht_mcsmap
		[ -n "$vht_mcsmap" ] && "$device_if" "$ifname" vht_mcsmap "$vht_mcsmap"

		config_get he_mcs "$vif" he_mcs
		[ -n "$he_mcs" ] && "$device_if" "$ifname" he_mcs "$he_mcs"

		config_get chwidth "$vif" chwidth
		[ -n "$chwidth" ] && "$device_if" "$ifname" chwidth "$chwidth"

		config_get chbwmode "$vif" chbwmode
		[ -n "$chbwmode" ] && "$device_if" "$ifname" chbwmode "$chbwmode"

		config_get ldpc "$vif" ldpc
		[ -n "$ldpc" ] && "$device_if" "$ifname" ldpc "$ldpc"

		config_get rx_stbc "$vif" rx_stbc
		[ -n "$rx_stbc" ] && "$device_if" "$ifname" rx_stbc "$rx_stbc"

		config_get tx_stbc "$vif" tx_stbc
		[ -n "$tx_stbc" ] && "$device_if" "$ifname" tx_stbc "$tx_stbc"

		config_get cca_thresh "$vif" cca_thresh
		[ -n "$cca_thresh" ] && "$device_if" "$ifname" cca_thresh "$cca_thresh"

		config_get set11NRetries "$vif" set11NRetries
		[ -n "$set11NRetries" ] && "$device_if" "$ifname" set11NRetries "$set11NRetries"

		config_get chanbw "$vif" chanbw
		[ -n "$chanbw" ] && "$device_if" "$ifname" chanbw "$chanbw"

		config_get maxsta "$vif" maxsta
		[ -n "$maxsta" ] && "$device_if" "$ifname" maxsta "$maxsta"

		config_get sko_max_xretries "$vif" sko_max_xretries
		[ -n "$sko_max_xretries" ] && "$device_if" "$ifname" sko "$sko_max_xretries"

		config_get extprotmode "$vif" extprotmode
		[ -n "$extprotmode" ] && "$device_if" "$ifname" extprotmode "$extprotmode"

		config_get extprotspac "$vif" extprotspac
		[ -n "$extprotspac" ] && "$device_if" "$ifname" extprotspac "$extprotspac"

		config_get_bool cwmenable "$vif" cwmenable
		[ -n "$cwmenable" ] && "$device_if" "$ifname" cwmenable "$cwmenable"

		config_get_bool protmode "$vif" protmode
		[ -n "$protmode" ] && "$device_if" "$ifname" protmode "$protmode"

		config_get enablertscts "$vif" enablertscts
		[ -n "$enablertscts" ] && "$device_if" "$ifname" enablertscts "$enablertscts"

		config_get txcorrection "$vif" txcorrection
		[ -n "$txcorrection" ] && "$device_if" "$ifname" txcorrection "$txcorrection"

		config_get rxcorrection "$vif" rxcorrection
		[ -n "$rxcorrection" ] && "$device_if" "$ifname" rxcorrection "$rxcorrection"

		config_get vsp_enable "$vif" vsp_enable
		[ -n "$vsp_enable" ] && "$device_if" "$ifname" vsp_enable "$vsp_enable"

                config_get qdf_cv_lvl "$vif" qdf_cv_lvl
                [ -n "$qdf_cv_lvl" ] && "$device_if" "$ifname" qdf_cv_lvl "$qdf_cv_lvl"

		config_get mode "$vif" mode
		if [ $mode = "sta" ]; then
			config_get ssid "$vif" ssid
				[ -n "$ssid" ] && {
					cfg80211tool "$ifname" ssid  "$ssid"
				}
		fi

		config_get txqueuelen "$vif" txqueuelen
		[ -n "$txqueuelen" ] && ifconfig "$ifname" txqueuelen "$txqueuelen"

                net_cfg="$(find_net_config "$vif")"

                config_get mtu $net_cfg mtu

                [ -n "$mtu" ] && {
                        config_set "$vif" mtu $mtu
                        ifconfig "$ifname" mtu $mtu
		}

		config_get tdls "$vif" tdls
		[ -n "$tdls" ] && "$device_if" "$ifname" tdls "$tdls"

		config_get set_tdls_rmac "$vif" set_tdls_rmac
		[ -n "$set_tdls_rmac" ] && "$device_if" "$ifname" set_tdls_rmac "$set_tdls_rmac"

		config_get tdls_qosnull "$vif" tdls_qosnull
		[ -n "$tdls_qosnull" ] && "$device_if" "$ifname" tdls_qosnull "$tdls_qosnull"

		config_get tdls_uapsd "$vif" tdls_uapsd
		[ -n "$tdls_uapsd" ] && "$device_if" "$ifname" tdls_uapsd "$tdls_uapsd"

		config_get tdls_set_rcpi "$vif" tdls_set_rcpi
		[ -n "$tdls_set_rcpi" ] && "$device_if" "$ifname" set_rcpi "$tdls_set_rcpi"

		config_get tdls_set_rcpi_hi "$vif" tdls_set_rcpi_hi
		[ -n "$tdls_set_rcpi_hi" ] && "$device_if" "$ifname" set_rcpihi "$tdls_set_rcpi_hi"

		config_get tdls_set_rcpi_lo "$vif" tdls_set_rcpi_lo
		[ -n "$tdls_set_rcpi_lo" ] && "$device_if" "$ifname" set_rcpilo "$tdls_set_rcpi_lo"

		config_get tdls_set_rcpi_margin "$vif" tdls_set_rcpi_margin
		[ -n "$tdls_set_rcpi_margin" ] && "$device_if" "$ifname" set_rcpimargin "$tdls_set_rcpi_margin"

		config_get tdls_dtoken "$vif" tdls_dtoken
		[ -n "$tdls_dtoken" ] && "$device_if" "$ifname" tdls_dtoken "$tdls_dtoken"

		config_get do_tdls_dc_req "$vif" do_tdls_dc_req
		[ -n "$do_tdls_dc_req" ] && "$device_if" "$ifname" do_tdls_dc_req "$do_tdls_dc_req"

		config_get tdls_auto "$vif" tdls_auto
		[ -n "$tdls_auto" ] && "$device_if" "$ifname" tdls_auto "$tdls_auto"

		config_get tdls_off_timeout "$vif" tdls_off_timeout
		[ -n "$tdls_off_timeout" ] && "$device_if" "$ifname" off_timeout "$tdls_off_timeout"

		config_get tdls_tdb_timeout "$vif" tdls_tdb_timeout
		[ -n "$tdls_tdb_timeout" ] && "$device_if" "$ifname" tdb_timeout "$tdls_tdb_timeout"

		config_get tdls_weak_timeout "$vif" tdls_weak_timeout
		[ -n "$tdls_weak_timeout" ] && "$device_if" "$ifname" weak_timeout "$tdls_weak_timeout"

		config_get tdls_margin "$vif" tdls_margin
		[ -n "$tdls_margin" ] && "$device_if" "$ifname" tdls_margin "$tdls_margin"

		config_get tdls_rssi_ub "$vif" tdls_rssi_ub
		[ -n "$tdls_rssi_ub" ] && "$device_if" "$ifname" tdls_rssi_ub "$tdls_rssi_ub"

		config_get tdls_rssi_lb "$vif" tdls_rssi_lb
		[ -n "$tdls_rssi_lb" ] && "$device_if" "$ifname" tdls_rssi_lb "$tdls_rssi_lb"

		config_get tdls_path_sel "$vif" tdls_path_sel
		[ -n "$tdls_path_sel" ] && "$device_if" "$ifname" tdls_pathSel "$tdls_path_sel"

		config_get tdls_rssi_offset "$vif" tdls_rssi_offset
		[ -n "$tdls_rssi_offset" ] && "$device_if" "$ifname" tdls_rssi_o "$tdls_rssi_offset"

		config_get tdls_path_sel_period "$vif" tdls_path_sel_period
		[ -n "$tdls_path_sel_period" ] && "$device_if" "$ifname" tdls_pathSel_p "$tdls_path_sel_period"

		config_get tdlsmacaddr1 "$vif" tdlsmacaddr1
		[ -n "$tdlsmacaddr1" ] && "$device_if" "$ifname" tdlsmacaddr1 "$tdlsmacaddr1"

		config_get tdlsmacaddr2 "$vif" tdlsmacaddr2
		[ -n "$tdlsmacaddr2" ] && "$device_if" "$ifname" tdlsmacaddr2 "$tdlsmacaddr2"

		config_get tdlsaction "$vif" tdlsaction
		[ -n "$tdlsaction" ] && "$device_if" "$ifname" tdlsaction "$tdlsaction"

		config_get tdlsoffchan "$vif" tdlsoffchan
		[ -n "$tdlsoffchan" ] && "$device_if" "$ifname" tdlsoffchan "$tdlsoffchan"

		config_get tdlsswitchtime "$vif" tdlsswitchtime
		[ -n "$tdlsswitchtime" ] && "$device_if" "$ifname" tdlsswitchtime "$tdlsswitchtime"

		config_get tdlstimeout "$vif" tdlstimeout
		[ -n "$tdlstimeout" ] && "$device_if" "$ifname" tdlstimeout "$tdlstimeout"

		config_get tdlsecchnoffst "$vif" tdlsecchnoffst
		[ -n "$tdlsecchnoffst" ] && "$device_if" "$ifname" tdlsecchnoffst "$tdlsecchnoffst"

		config_get tdlsoffchnmode "$vif" tdlsoffchnmode
		[ -n "$tdlsoffchnmode" ] && "$device_if" "$ifname" tdlsoffchnmode "$tdlsoffchnmode"

		config_get_bool blockdfschan "$vif" blockdfschan
		[ -n "$blockdfschan" ] && "$device_if" "$ifname" blockdfschan "$blockdfschan"

		config_get dbgLVL "$vif" dbgLVL
		[ -n "$dbgLVL" ] && "$device_if" "$ifname" dbgLVL "$dbgLVL"

		config_get dbgLVL_high "$vif" dbgLVL_high
		[ -n "$dbgLVL_high" ] && "$device_if" "$ifname" dbgLVL_high "$dbgLVL_high"

		config_get acsmindwell "$vif" acsmindwell
		[ -n "$acsmindwell" ] && "$device_if" "$ifname" acsmindwell "$acsmindwell"

		config_get acsmaxdwell "$vif" acsmaxdwell
		[ -n "$acsmaxdwell" ] && "$device_if" "$ifname" acsmaxdwell "$acsmaxdwell"

		config_get acsreport "$vif" acsreport
		[ -n "$acsreport" ] && "$device_if" "$ifname" acsreport "$acsreport"

		config_get ch_hop_en "$vif" ch_hop_en
		[ -n "$ch_hop_en" ] && "$device_if" "$ifname" ch_hop_en "$ch_hop_en"

		config_get ch_long_dur "$vif" ch_long_dur
		[ -n "$ch_long_dur" ] && "$device_if" "$ifname" ch_long_dur "$ch_long_dur"

		config_get ch_nhop_dur "$vif" ch_nhop_dur
		[ -n "$ch_nhop_dur" ] && "$device_if" "$ifname" ch_nhop_dur "$ch_nhop_dur"

		config_get ch_cntwn_dur "$vif" ch_cntwn_dur
		[ -n "$ch_cntwn_dur" ] && "$device_if" "$ifname" ch_cntwn_dur "$ch_cntwn_dur"

		config_get ch_noise_th "$vif" ch_noise_th
		[ -n "$ch_noise_th" ] && "$device_if" "$ifname" ch_noise_th "$ch_noise_th"

		config_get ch_cnt_th "$vif" ch_cnt_th
		[ -n "$ch_cnt_th" ] && "$device_if" "$ifname" ch_cnt_th "$ch_cnt_th"

		config_get_bool scanchevent "$vif" scanchevent
		[ -n "$scanchevent" ] && "$device_if" "$ifname" scanchevent "$scanchevent"

		config_get_bool send_add_ies "$vif" send_add_ies
		[ -n "$send_add_ies" ] && "$device_if" "$ifname" send_add_ies "$send_add_ies"

		config_get enable_rtt "$vif" enable_rtt
		[ -n "$enable_rtt" ] && "$device_if" "$ifname" enable_rtt "$enable_rtt"

		config_get_bool enable_lci "$vif" enable_lci
		[ -n "$enable_lci" ] && "$device_if" "$ifname" enable_lci "$enable_lci"

		config_get_bool enable_lcr "$vif" enable_lcr
		[ -n "$enable_lcr" ] && "$device_if" "$ifname" enable_lcr "$enable_lcr"

		config_get_bool rrm "$vif" rrm
		[ -n "$rrm" ] && "$device_if" "$ifname" rrm "$rrm"

		config_get_bool rrmslwin "$vif" rrmslwin
		[ -n "$rrmslwin" ] && "$device_if" "$ifname" rrmslwin "$rrmslwin"

		config_get_bool rrmstats "$vif" rrmsstats
		[ -n "$rrmstats" ] && "$device_if" "$ifname" rrmstats "$rrmstats"

		config_get rrmdbg "$vif" rrmdbg
		[ -n "$rrmdbg" ] && "$device_if" "$ifname" rrmdbg "$rrmdbg"

		config_get_bool rrm_capie "$vif" rrm_capie
		[ -n "$rrm_capie" ] && "$device_if" "$ifname" rrm_capie "$rrm_capie"

		config_get acparams "$vif" acparams
		[ -n "$acparams" ] && "$device_if" "$ifname" acparams $acparams

		config_get setwmmparams "$vif" setwmmparams
		[ -n "$setwmmparams" ] && "$device_if" "$ifname" setwmmparams $setwmmparams

		config_get_bool qbssload "$vif" qbssload
		[ -n "$qbssload" ] && "$device_if" "$ifname" qbssload "$qbssload"

		config_get_bool proxyarp "$vif" proxyarp
		[ -n "$proxyarp" ] && "$device_if" "$ifname" proxyarp "$proxyarp"

		config_get_bool dgaf_disable "$vif" dgaf_disable
		[ -n "$dgaf_disable" ] && "$device_if" "$ifname" dgaf_disable "$dgaf_disable"

		config_get setibssdfsparam "$vif" setibssdfsparam
		[ -n "$setibssdfsparam" ] && "$device_if" "$ifname" setibssdfsparam "$setibssdfsparam"

		config_get startibssrssimon "$vif" startibssrssimon
		[ -n "$startibssrssimon" ] && "$device_if" "$ifname" startibssrssimon "$startibssrssimon"

		config_get setibssrssihyst "$vif" setibssrssihyst
		[ -n "$setibssrssihyst" ] && "$device_if" "$ifname" setibssrssihyst "$setibssrssihyst"

		config_get noIBSSCreate "$vif" noIBSSCreate
		[ -n "$noIBSSCreate" ] && "$device_if" "$ifname" noIBSSCreate "$noIBSSCreate"

		config_get setibssrssiclass "$vif" setibssrssiclass
		[ -n "$setibssrssiclass" ] && "$device_if" "$ifname" setibssrssiclass $setibssrssiclass

		config_get offchan_tx_test "$vif" offchan_tx_test
		[ -n "$offchan_tx_test" ] && "$device_if" "$ifname" offchan_tx_test $offchan_tx_test

		config_get twt_responder "$vif" twt_responder
		[ -n "$twt_responder" ] && "$device_if" "$ifname" twt_responder $twt_responder

		handle_vow_dbg_cfg() {
			local value="$1"
			[ -n "$value" ] && "$device_if" "$ifname" vow_dbg_cfg $value
		}

		config_list_foreach "$vif" vow_dbg_cfg handle_vow_dbg_cfg

		config_get_bool vow_dbg "$vif" vow_dbg
		[ -n "$vow_dbg" ] && "$device_if" "$ifname" vow_dbg "$vow_dbg"
#TODO
		handle_set_max_rate() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" set_max_rate $value -cfg80211
		}
		config_list_foreach "$vif" set_max_rate handle_set_max_rate

		config_get_bool implicitbf "$vif" implicitbf
		[ -n "$implicitbf" ] && "$device_if" "$ifname" implicitbf "${implicitbf}"

		config_get_bool vhtsubfee "$vif" vhtsubfee
		[ -n "$vhtsubfee" ] && "$device_if" "$ifname" vhtsubfee "${vhtsubfee}"

		config_get_bool vhtmubfee "$vif" vhtmubfee
		[ -n "$vhtmubfee" ] && "$device_if" "$ifname" vhtmubfee "${vhtmubfee}"

		config_get_bool vhtsubfer "$vif" vhtsubfer
		[ -n "$vhtsubfer" ] && "$device_if" "$ifname" vhtsubfer "${vhtsubfer}"

		config_get_bool vhtmubfer "$vif" vhtmubfer
		[ -n "$vhtmubfer" ] && "$device_if" "$ifname" vhtmubfer "${vhtmubfer}"

		config_get vhtstscap "$vif" vhtstscap
		[ -n "$vhtstscap" ] && "$device_if" "$ifname" vhtstscap "${vhtstscap}"

		config_get vhtsounddim "$vif" vhtsounddim
		[ -n "$vhtsounddim" ] && "$device_if" "$ifname" vhtsounddim "${vhtsounddim}"

		config_get enable_11v_dms "$vif" enable_11v_dms
		[ -n "$enable_11v_dms" ] && "$device_if" "$ifname" enable_11v_dms "${enable_11v_dms}"

		config_get he_subfee "$vif" he_subfee
		[ -n "$he_subfee" ] && "$device_if" "$ifname" he_subfee "${he_subfee}"

		config_get he_subfer "$vif" he_subfer
		[ -n "$he_subfer" ] && "$device_if" "$ifname" he_subfer "${he_subfer}"

		config_get he_mubfee "$vif" he_mubfee
		[ -n "$he_mubfee" ] && "$device_if" "$ifname" he_mubfee "${he_mubfee}"

		config_get he_mubfer "$vif" he_mubfer
		[ -n "$he_mubfer" ] && "$device_if" "$ifname" he_mubfer "${he_mubfer}"

		config_get he_dl_ofdma "$vif" he_dl_ofdma
		[ -n "$he_dl_ofdma" ] && "$device_if" "$ifname" he_dl_ofdma "${he_dl_ofdma}"

		config_get he_ul_ofdma "$vif" he_ul_ofdma
		[ -n "$he_ul_ofdma" ] && "$device_if" "$ifname" he_ul_ofdma "${he_ul_ofdma}"

		config_get he_ul_mimo "$vif" he_ul_mimo
		[ -n "$he_ul_mimo" ] && "$device_if" "$ifname" he_ul_mimo "${he_ul_mimo}"

		config_get he_dcm "$vif" he_dcm
		[ -n "$he_dcm" ] && "$device_if" "$ifname" he_dcm "${he_dcm}"

		config_get he_extrange "$vif" he_extrange
		[ -n "$he_extrange" ] && "$device_if" "$ifname" he_extrange "${he_extrange}"

		config_get he_ltf "$vif" he_ltf
		[ -n "$he_ltf" ] && "$device_if" "$ifname" he_ltf "${he_ltf}"

		config_get he_txmcsmap "$vif" he_txmcsmap
		[ -n "$he_txmcsmap" ] && "$device_if" "$ifname" he_txmcsmap "${he_txmcsmap}"

		config_get he_rxmcsmap "$vif" he_rxmcsmap
		[ -n "$he_rxmcsmap" ] && "$device_if" "$ifname" he_rxmcsmap "${he_rxmcsmap}"

		config_get ba_bufsize "$vif" ba_bufsize
		[ -n "$ba_bufsize" ] && "$device_if" "$ifname" ba_bufsize "${ba_bufsize}"

		config_get encap_type "$vif" encap_type
		[ -n "$encap_type" ] && "$device_if" "$ifname" encap_type "${encap_type}"

		config_get decap_type "$vif" decap_type
		[ -n "$decap_type" ] && "$device_if" "$ifname" decap_type "${decap_type}"

		config_get rawsim_txagr "$vif" rawsim_txagr
		[ -n "$rawsim_txagr" ] && "$device_if" "$ifname" rawsim_txagr "${rawsim_txagr}"

		config_get clr_rawsim_stats "$vif" clr_rawsim_stats
		[ -n "$clr_rawsim_stats" ] && "$device_if" "$ifname" clr_rawsim_stats "${clr_rawsim_stats}"

		config_get rawsim_debug "$vif" rawsim_debug
		[ -n "$rawsim_debug" ] && "$device_if" "$ifname" rawsim_debug "${rawsim_debug}"

		config_get rsim_en_frmcnt "$vif" rsim_en_frmcnt
		[ -n "$rsim_en_frmcnt" ] && "$device_if" "$ifname" rsim_en_frmcnt "${rsim_en_frmcnt}"

		config_get rsim_de_frmcnt "$vif" rsim_de_frmcnt
		[ -n "$rsim_de_frmcnt" ] && "$device_if" "$ifname" rsim_de_frmcnt "${rsim_de_frmcnt}"

		config_get set_monrxfilter "$vif" set_monrxfilter
		[ -n "$set_monrxfilter" ] && "$device_if" "$ifname" set_monrxfilter "${set_monrxfilter}"

		config_get neighbourfilter "$vif" neighbourfilter
		[ -n "$neighbourfilter" ] && "$device_if" "$ifname" neighbourfilter "${neighbourfilter}"

		config_get athnewind "$vif" athnewind
		[ -n "$athnewind" ] && "$device_if" "$ifname" athnewind "$athnewind"

		config_get osen "$vif" osen
		[ -n "$osen" ] && "$device_if" "$ifname" osen "$osen"

		if [ ! -z $osen]; then
			if [ $osen -ne 0 ]; then
				"$device_if" "$ifname" proxyarp 1
			fi
		fi

		config_get re_scalingfactor "$vif" re_scalingfactor
		[ -n "$re_scalingfactor" ] && "$device_if" "$ifname" set_whc_sfactor "$re_scalingfactor"

		config_get ul_hyst "$vif" ul_hyst
		[ -n "$ul_hyst" ] && "$device_if" "$ifname" ul_hyst "${ul_hyst}"

		config_get son_event_bcast qcawifi son_event_bcast
		[ -n "$son_event_bcast" ] && "$device_if" "$ifname" son_event_bcast "${son_event_bcast}"

		config_get root_distance "$vif" root_distance
		[ -n "$root_distance" ] && "$device_if" "$ifname" set_whc_dist "$root_distance"

		config_get caprssi "$vif" caprssi
		[ -n "$caprssi" ] && "$device_if" "$ifname" caprssi "${caprssi}"

		config_get_bool ap_isolation_enabled $device ap_isolation_enabled 0
		config_get_bool isolate "$vif" isolate 0

		if [ $ap_isolation_enabled -ne 0 ]; then
			[ "$mode" = "wrap" ] && isolate=1
			"$device_if" "$phy" isolation "$ap_isolation_enabled"
		fi

                config_get_bool ctsprt_dtmbcn "$vif" ctsprt_dtmbcn
                [ -n "$ctsprt_dtmbcn" ] && "$device_if" "$ifname" ctsprt_dtmbcn "${ctsprt_dtmbcn}"

		config_get assocwar160  "$vif" assocwar160
		[ -n "$assocwar160" ] && "$device_if" "$ifname" assocwar160 "$assocwar160"

		config_get rawdwepind "$vif" rawdwepind
		[ -n "$rawdwepind" ] && "$device_if" "$ifname" rawdwepind "$rawdwepind"

		config_get revsig160  "$vif" revsig160
		[ -n "$revsig160" ] && "$device_if" "$ifname" revsig160 "$revsig160"

		config_get channel_block_list "$vif" channel_block_list
		[ -n "$channel_block_list" ] && wifitool "$ifname" block_acs_channel "$channel_block_list"

		config_get rept_spl  "$vif" rept_spl
		[ -n "$rept_spl" ] && "$device_if" "$ifname" rept_spl "$rept_spl"

		config_get cactimeout  "$vif" cactimeout
		[ -n "$cactimeout" ] && "$device_if" "$ifname" set_cactimeout "$cactimeout"

		config_get mark_subchan  "$vif" mark_subchan
		[ -n "$mark_subchan" ] && "$device_if" "$ifname" mark_subchan "$mark_subchan"

		config_get meshdbg "$vif" meshdbg
		[ -n "$meshdbg" ] && "$device_if" "$ifname" meshdbg "$meshdbg"

		config_get rmode_pktsim "$vif" rmode_pktsim
		[ -n "$rmode_pktsim" ] && "$device_if" "$ifname" rmode_pktsim "$rmode_pktsim"

		config_get hlos_tidoverride "$vif" hlos_tidoverride
		if [ "$hlos_tidoverride" -eq 1 ]; then
			insmod qca-nss-mscs
		fi

		[ -n "$hlos_tidoverride" ] && "$device_if" "$ifname" hlos_tidoverride "$hlos_tidoverride"

		config_get mscs "$vif" mscs 0
		if [ "$mscs" -eq 1 ]; then
			insmod qca-nss-mscs
		fi
		[ -n "$mscs" ] && "$device_if" "$ifname" mscs "$mscs"

                config_get global_wds qcawifi global_wds

		if [ ! -z $global_wds ]; then
			if [ $global_wds -ne 0 ]; then
			"$device_if" "$ifname" athnewind 1
			fi
		fi

                config_get pref_uplink "$device" pref_uplink
                [ -n "$pref_uplink" ] && "$device_if" "$phy" pref_uplink "${pref_uplink}"

                config_get fast_lane "$device" fast_lane
                [ -n "$fast_lane" ] && "$device_if" "$phy" fast_lane "${fast_lane}"

		if [ ! -z $fast_lane ]; then
			if [ $fast_lane -ne 0 ]; then
			"$device_if" "$ifname" athnewind 1
			fi
		fi

		local net_cfg bridge
		net_cfg="$(find_net_config "$vif")"
		[ -z "$net_cfg" -o "$isolate" = 1 -a "$mode" = "wrap" ] || {
                        [ -f /sys/class/net/${ifname}/parent ] && { \
				bridge="$(bridge_interface "$net_cfg")"
				config_set "$vif" bridge "$bridge"
                        }
		}

		case "$mode" in
			ap|wrap|ap_monitor|ap_smart_monitor|mesh|ap_lp_iot)


				"$device_if" "$ifname" ap_bridge "$((isolate^1))"

				config_get_bool l2tif "$vif" l2tif
				[ -n "$l2tif" ] && "$device_if" "$ifname" l2tif "$l2tif"

				if [ -n "$start_wapid" ]; then
					wapid_setup_vif "$vif" || {
						echo "enable_qcawifi($device): Failed to set up wapid for interface $ifname" >&2
						ifconfig "$ifname" down
						iw "$ifname" del
						continue
					}
				fi

				if [ "$mode" == "ap_lp_iot" ]; then
					default_dtim_period=41
				else
					default_dtim_period=1
				fi
				config_get dtim_period "$vif" dtim_period
				if [ -z "$dtim_period" ]; then
					config_set "$vif" dtim_period $default_dtim_period
				fi

				if [ -n "$start_hostapd" ] && eval "type hostapd_setup_vif" 2>/dev/null >/dev/null; then
					# If the radio has a backhaul BSS configured, call hostapd_setup_vif() with the
					# backhaul BSS credentials, so that the backhaul BSS credentials get configured
					# for all fronthaul VAPS
					if [ ! -z $backhaul_BSS ]; then
						if [ "$backhaul_BSS" -eq 1 ]; then
							hostapd_setup_vif "$vif" nl80211 no_nconfig bBSS "$backhaul_ssid" "$backhaul_key" || {
							echo "enable_qcawifi($device): Failed to set up hostapd for interface $ifname" >&2
							# make sure this wifi interface won't accidentally stay open without encryption
							ifconfig "$ifname" down
							iw "$ifname" del
							continue
							}
						else
							hostapd_setup_vif "$vif" nl80211 no_nconfig || {
								echo "enable_qcawifi($device): Failed to set up hostapd for interface $ifname" >&2
								# make sure this wifi interface won't accidentally stay open without encryption
								ifconfig "$ifname" down
								iw "$ifname" del
								continue
							}

						fi
					else
						hostapd_setup_vif "$vif" nl80211 no_nconfig || {
							echo "enable_qcawifi($device): Failed to set up hostapd for interface $ifname" >&2
							# make sure this wifi interface won't accidentally stay open without encryption
							ifconfig "$ifname" down
							iw "$ifname" del
							continue
						}
					fi
				fi
			;;
			wds|sta)
				if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
					wpa_supplicant_setup_vif "$vif" nl80211 || {
						echo "enable_qcawifi($device): Failed to set up wpa_supplicant for interface $ifname" >&2
						ifconfig "$ifname" down
						iw "$ifname" del
						continue
					}
				fi
			;;
			adhoc)
				if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
					wpa_supplicant_setup_vif "$vif" nl80211 || {
						echo "enable_qcawifi($device): Failed to set up wpa"
						ifconfig "$ifname" down
						iw "$ifname" del
						continue
					}
				fi
		esac

		[ -z "$bridge" -o "$isolate" = 1 -a "$mode" = "wrap" ] || {
                        [ -f /sys/class/net/${ifname}/parent ] && { \
				start_net "$ifname" "$net_cfg"
                        }
		}

		ifconfig "$ifname" up
		set_wifi_up "$vif" "$ifname"
		# configure below options once AP is up , as wireless mode is available now
		config_get frag "$vif" frag
		[ -n "$frag" ] && iw phy "$(cat /sys/class/net/$phy/phy80211/name)"  set frag "${frag%%.*}"

		# Support added for per vap RTS setting using private command in cfg80211 mode
		# But cfg80211tool will take rts parameter as integer.
	        # MAX farme size, MAX RTS Threshold i.e 2347, is set to make RTS/CTS protection off.
		config_get rts "$vif" rts
		if [ $rts == "off" ]; then
			"$device_if" "$ifname" rts 2347
		else
			[ -n "$rts" ] && "$device_if" "$ifname" rts "${rts%%.*}"
		fi

		config_get set11NRates "$vif" set11NRates
		[ -n "$set11NRates" ] && "$device_if" "$ifname" set11NRates "$set11NRates"

		config_get setwmmparams "$vif" setwmmparams
		[ -n "$setwmmparams" ] && "$device_if" "$ifname" setwmmparams $setwmmparams

		# 256 QAM capability needs to be parsed first, since
		# vhtmcs enables/disable rate indices 8, 9 for 2G
		# only if vht_11ng is set or not
		config_get_bool vht_11ng "$vif" vht_11ng
		[ -n "$vht_11ng" ] && "$device_if" "$ifname" vht_11ng "$vht_11ng"

		config_get_bool vhtintop "$vif" vhtintop
		[ -n "$vhtintop" ] && "$device_if" "$ifname" 11ngvhtintop "$vhtintop"

		config_get vhtmcs "$vif" vhtmcs
		[ -n "$vhtmcs" ] && "$device_if" "$ifname" vhtmcs "$vhtmcs"

		config_get dis_legacy "$vif" dis_legacy
		[ -n "$dis_legacy" ] && "$device_if" "$ifname" dis_legacy "$dis_legacy"

		config_get ext_nss "$device" ext_nss
		case "$ext_nss" in
			1|on|enabled) "$device_if" "$phy" ext_nss 1 >/dev/null 2>&1
				;;
			0|on|enabled) "$device_if" "$phy" ext_nss 0 >/dev/null 2>&1
				;;
			*) ;;
		esac

		config_get ext_nss_sup "$vif" ext_nss_sup
		case "$ext_nss_sup" in
			1|on|enabled) "$device_if" "$ifname" ext_nss_sup 1 >/dev/null 2>&1
				;;
			0|on|enabled) "$device_if" "$ifname" ext_nss_sup 0 >/dev/null 2>&1
				;;
			*) ;;
		esac

		config_get mbo "$vif" mbo
		[ -n "$mbo" ] && "$device_if" "$ifname" mbo "$mbo"

		if [ $mode = "sta" ]; then
			config_get enable_ft "$vif" ieee80211r
			[ -n "$enable_ft" ] && "$device_if" "$ifname" ft "$enable_ft"
		fi

		config_get enable_fils "$vif" ieee80211ai
		config_get fils_discovery_period  "$vif" fils_fd_period 20
		[ -n "$enable_fils" ] && "$device_if" "$ifname" enable_fils "$enable_fils" "$fils_discovery_period"

		config_get bpr_enable  "$vif" bpr_enable
		[ -n "$bpr_enable" ] && "$device_if" "$ifname" set_bpr_enable "$bpr_enable"

		config_get oce "$vif" oce
		[ -n "$oce" ] && "$device_if" "$ifname" oce "$oce"

		if [ ! -z $oce ]; then
			[ "$oce" -gt 0 ] && {

				config_get prb_retry  "$vif" prb_retry 2
				"$device_if" "$ifname" prb_retry "$prb_retry"

				case "$hwmode" in
					11B*|11G*|11NG*)
						"$device_if" "$ifname" set_bcn_rate 5500
						"$device_if" "$ifname" prb_rate 5500
						;;
					*)
						;;
				esac

				[ -z "$enable_fils" ] && {
					config_get fils_discovery_period  "$vif" fils_fd_period 20
					"$device_if" "$ifname" enable_fils 1 "$fils_discovery_period"
				}
			}
		fi

		config_get set_bcn_rate "$vif" set_bcn_rate
		[ -n "$set_bcn_rate" ] && "$device_if" "$ifname" set_bcn_rate "$set_bcn_rate"

		config_get mcast_rate "$vif" mcast_rate
		[ -n "$mcast_rate" ] && "$device_if" "$ifname" mcast_rate "${mcast_rate%%.*}"

		#support nawds
		config_get nawds_mode "$vif" nawds_mode
		[ -n "$nawds_mode" ] && wlanconfig "$ifname" nawds mode "${nawds_mode}" -cfg80211

		handle_nawds() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" nawds add-repeater $value -cfg80211
		}
		config_list_foreach "$vif" nawds_add_repeater handle_nawds

		handle_hmwds() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" hmwds add_addr $value -cfg80211
		}
		config_list_foreach "$vif" hmwds_add_addr handle_hmwds

		config_get nawds_override "$vif" nawds_override
		[ -n "$nawds_override" ] && wlanconfig "$ifname" nawds override "${nawds_override}" -cfg80211

		config_get nawds_defcaps "$vif" nawds_defcaps
		[ -n "$nawds_defcaps" ] && wlanconfig "$ifname" nawds defcaps "${nawds_defcaps}" -cfg80211

		handle_hmmc_add() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" hmmc add $value -cfg80211
		}
		config_list_foreach "$vif" hmmc_add handle_hmmc_add

		# TXPower settings only work if device is up already
		# while atheros hardware theoretically is capable of per-vif (even per-packet) txpower
		# adjustment it does not work with the current atheros hal/madwifi driver
		config_get vif_txpower "$vif" txpower

		# use vif_txpower (from wifi-iface) instead of txpower (from wifi-device) if
		# the latter doesn't exist
		txpower="${txpower:-$vif_txpower}"
		[ -z "$txpower" ] || iw "$ifname" set txpower fixed "${txpower%%.*}"

		if [ $enable_rps_wifi == 1 ] && [ -f "/lib/update_system_params.sh" ]; then
			. /lib/update_system_params.sh
			enable_rps $ifname
		fi

		if [ ! -z "$vifs_name" ]; then
			break
		fi
	done
}



setup_wps_enhc_device() {
	local device=$1
	local wps_enhc_cfg=

	append wps_enhc_cfg "RADIO" "$N"
	config_get_bool wps_pbc_try_sta_always "$device" wps_pbc_try_sta_always 0
	config_get_bool wps_pbc_skip_ap_if_sta_disconnected "$device" wps_pbc_skip_ap_if_sta_disconnected 0
	config_get_bool wps_pbc_overwrite_ap_settings "$device" wps_pbc_overwrite_ap_settings 0
	config_get wps_pbc_overwrite_ssid_band_suffix "$device" wps_pbc_overwrite_ssid_band_suffix
	[ $wps_pbc_try_sta_always -ne 0 ] && \
			append wps_enhc_cfg "$device:try_sta_always" "$N"
	[ $wps_pbc_skip_ap_if_sta_disconnected -ne 0 ] && \
			append wps_enhc_cfg "$device:skip_ap_if_sta_disconnected" "$N"
	[ $wps_pbc_overwrite_ap_settings -ne 0 ] && \
			append wps_enhc_cfg "$device:overwrite_ap_settings" "$N"
	[ -n "$wps_pbc_overwrite_ssid_band_suffix" ] && \
			append wps_enhc_cfg "$device:overwrite_ssid_band_suffix:$wps_pbc_overwrite_ssid_band_suffix" "$N"

	config_get vifs $device vifs

	for vif in $vifs; do
		config_get ifname "$vif" ifname


		config_get_bool wps_pbc_enable "$vif" wps_pbc_enable 0
		config_get wps_pbc_start_time "$vif" wps_pbc_start_time
		config_get wps_pbc_duration "$vif" wps_pbc_duration
		config_get_bool wps_pbc_noclone "$vif" wps_pbc_noclone 0
		config_get_bool disabled "$vif" disabled 0
		if [ $disabled -eq 0 -a $wps_pbc_enable -ne 0 ]; then
			append wps_enhc_cfg "VAP" "$N"
			[ -n "$wps_pbc_start_time" -a -n "$wps_pbc_duration" ] && {
				if [ $wps_pbc_noclone -eq 0 ]; then
					append wps_enhc_cfg "$ifname:$wps_pbc_start_time:$wps_pbc_duration:$device:clone" "$N"
				else
					append wps_enhc_cfg "$ifname:$wps_pbc_start_time:$wps_pbc_duration:$device:noclone" "$N"
				fi
			}
			[ -n "$wps_pbc_start_time" -a -n "$wps_pbc_duration" ] || {
				if [ $wps_pbc_noclone -eq 0 ]; then
					append wps_enhc_cfg "$ifname:-:-:$device:clone" "$N"
				else
					append wps_enhc_cfg "$ifname:-:-:$device:noclone" "$N"
				fi
			}
		fi
	done

	cat >> /var/run/wifi-wps-enhc-extn.conf <<EOF
$wps_enhc_cfg
EOF
}

setup_wps_enhc() {
	local wps_enhc_cfg=

	append wps_enhc_cfg "GLOBAL" "$N"
	config_get_bool wps_pbc_overwrite_ap_settings_all qcawifi wps_pbc_overwrite_ap_settings_all 0
	[ $wps_pbc_overwrite_ap_settings_all -ne 0 ] && \
			append wps_enhc_cfg "-:overwrite_ap_settings_all" "$N"
	config_get_bool wps_pbc_overwrite_sta_settings_all qcawifi wps_pbc_overwrite_sta_settings_all 0
	[ $wps_pbc_overwrite_sta_settings_all -ne 0 ] && \
			append wps_enhc_cfg "-:overwrite_sta_settings_all" "$N"
	config_get wps_pbc_overwrite_ssid_suffix qcawifi wps_pbc_overwrite_ssid_suffix
	[ -n "$wps_pbc_overwrite_ssid_suffix" ] && \
			append wps_enhc_cfg "-:overwrite_ssid_suffix:$wps_pbc_overwrite_ssid_suffix" "$N"

	cat >> /var/run/wifi-wps-enhc-extn.conf <<EOF
$wps_enhc_cfg
EOF

	config_load wireless
	config_foreach setup_wps_enhc_device wifi-device
}

set_hw_mode_for_dynamic_mode_switch() {
	local new_hw_mode=$1
	local dynamic_hw_mode
	local primary_dev
	local primary_if
	local cnt

	# Check if dynamic hw mode is FAST(=2)
	dynamic_hw_mode=`grep "dynamic_hw_mode" /ini/internal/global_i.ini \
		| grep -m1 -v "^[#]" | awk -F'=' '{print $2}'`
	[ $dynamic_hw_mode -ne "2" ] && return

	# Check if new hw mode is DBS(=1) or DBS_SBS(=4)
	[ $new_hw_mode -eq 1 -o $new_hw_mode -eq 4 ] || return
	[ -f /sys/class/net/soc0/pdev_map ] || return

	primary_dev=`grep "*wifi" /sys/class/net/soc0/pdev_map \
		| awk -F'[* ]' '{print $2}'`
	[ -z $primary_dev ] && primary_dev=wifi0
	primary_if=${primary_dev//wifi/ath}

	config_get device_if $primary_dev device_if "cfg80211tool"
	hw_mode=`$device_if $primary_dev get_hw_mode | cut -d: -f2`
	# Check if current hw mode is DBS(=1) or DBS_SBS(=4)
	[ $hw_mode -eq 1 -o $hw_mode -eq 4 ] || return

	[ $hw_mode -eq $new_hw_mode ] && return

	[ ! -d /sys/class/net/$primary_if ] && return

	# Check if ACS is running and if then, wait until the completition
	# (max 10 secs)
	cnt=0
	while [ $cnt -le 10 ]; do
		acs_state=`cfg80211tool $primary_if get_acs_state \
			| awk -F  ':' '{print $2}'`
		[ $acs_state -eq 0 ] && break
		sleep 1
		cnt=$((cnt + 1))
	done
	[ $acs_state -ne 0 ] && return

	[ $cnt -ne 0 ] && sleep 1
	# Check if DFS CAC is running and if then, wait until the completition
	# (max CAC timeout 600 secs)
	cnt=0
	while [ $cnt -le 600 ]; do
		cac_state=`cfg80211tool $primary_if get_cac_state \
			| awk -F  ':' '{print $2}'`
		[ $cac_state -eq 0 ] && break
		sleep 1
		cnt=$((cnt + 1))
	done
	[ $cac_state -ne 0 ] && return

	[ $cnt -ne 0 ] && sleep 1
	$device_if $primary_dev hw_mode $new_hw_mode
}

qcawifi_start_hostapd_cli() {
	local device=$1
	local ifidx=0
	local radioidx=${device#wifi}

	config_get vifs $device vifs

	for vif in $vifs; do
		local config_methods vifname

		config_get vifname "$vif" ifname

		if [ -n $vifname ]; then
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"
		fi

		config_get_bool wps_pbc "$vif" wps_pbc 0
		config_get config_methods "$vif" wps_config
		[ "$wps_pbc" -gt 0 ] && append config_methods push_button

		if [ -n "$config_methods" ]; then
			pid=/var/run/hostapd_cli-$vifname.pid
			hostapd_cli -i $vifname -P $pid -a /lib/wifi/wps-hostapd-update-uci -p /var/run/hostapd-$device -B
		fi

		ifidx=$(($ifidx + 1))
	done
}

pre_qcawificfg80211() {
	local action=${1}

	config_load wireless

	lock /var/run/wifilock
	case "${action}" in
		disable)
			config_get_bool wps_vap_tie_dbdc qcawifi wps_vap_tie_dbdc 0

			if [ $wps_vap_tie_dbdc -ne 0 ]; then
				kill "$(cat "/var/run/hostapd.pid")"
				[ -f "/tmp/hostapd_conf_filename" ] &&
					rm /tmp/hostapd_conf_filename
			fi

			eval "type qwrap_teardown" >/dev/null 2>&1 && qwrap_teardown
			eval "type icm_teardown" >/dev/null 2>&1 && icm_teardown
			eval "type wpc_teardown" >/dev/null 2>&1 && wpc_teardown
			eval "type lowi_teardown" >/dev/null 2>&1 && lowi_teardown
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd stop
			[ ! -f /etc/init.d/hyd ] || /etc/init.d/hyd stop
			[ ! -f /etc/init.d/ssid_steering ] || /etc/init.d/ssid_steering stop
			[ ! -f /etc/init.d/mcsd ] || /etc/init.d/mcsd stop
			[ ! -f /etc/init.d/wsplcd ] || /etc/init.d/wsplcd stop

                       rm -f /var/run/wifi-wps-enhc-extn.conf
                       [ -r /var/run/wifi-wps-enhc-extn.pid ] && kill "$(cat "/var/run/wifi-wps-enhc-extn.pid")"

			rm -f /var/run/iface_mgr.conf
			[ -r /var/run/iface_mgr.pid ] && kill "$(cat "/var/run/iface_mgr.pid")"
                        rm -f /var/run/iface_mgr.pid
			if [ `eval pgrep qldtool` ]; then
				killall qldtool >/dev/null 2>&1
			fi

                        if [ -f  "/var/run/son.conf" ]; then
                                rm /var/run/son.conf
                        fi

			# For dynamic_hw_mode(=2), set hw mode back to DBS_SBS
			# to be able to clean up secondary pdev
			set_hw_mode_for_dynamic_mode_switch 4
			;;

		enable)
			local icm_enable

			config_get_bool icm_enable icm enable 0
			[ ${icm_enable} -gt 0 ] && \
					eval "type icm_setup" >/dev/null 2>&1 && {
				icm_setup cfg80211
			}
			;;
		disable_recover)
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd stop
			;;
	esac
	lock -u /var/run/wifilock
}

post_qcawificfg80211() {
	local action=${1}
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	config_get type "$device" type
	[ "$type" != "qcawificfg80211" ] && return

	lock /var/run/wifilock
	case "${action}" in
		enable)
			local icm_enable qwrap_enable lowi_enable

			# Run a single hostapd instance for all the radio's
			# Enables WPS VAP TIE feature

			config_get_bool wps_vap_tie_dbdc qcawifi wps_vap_tie_dbdc 0

			if [ $wps_vap_tie_dbdc -ne 0 ]; then
				hostapd_conf_file=$(cat "/tmp/hostapd_conf_filename")
				hostapd -P /var/run/hostapd.pid $hostapd_conf_file -B
				config_foreach qcawifi_start_hostapd_cli wifi-device
			fi


			config_get_bool wpc_enable wpc enable 0
			[ ${wpc_enable} -gt 0 ] && \
					eval "type wpc_setup" >/dev/null 2>&1 && {
				wpc_setup
			}

			config_get_bool lowi_enable lowi enable 0
			[ ${lowi_enable} -gt 0 ] && \
				eval "type lowi_setup" >/dev/null 2>&1 && {
				lowi_setup
			}

			eval "type qwrap_setup" >/dev/null 2>&1 && qwrap_setup && _disable_qcawificfg80211

			# These init scripts are assumed to check whether the feature is
			# actually enabled and do nothing if it is not.
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd start
			[ ! -f /etc/init.d/hyfi-bridging ] || /etc/init.d/hyfi-bridging start
			[ ! -f /etc/init.d/ssid_steering ] || /etc/init.d/ssid_steering start
			[ ! -f /etc/init.d/wsplcd ] || /etc/init.d/wsplcd restart

			config_get_bool wps_pbc_extender_enhance qcawifi wps_pbc_extender_enhance 0
			[ ${wps_pbc_extender_enhance} -ne 0 ] && {
				rm -f /var/run/wifi-wps-enhc-extn.conf
				setup_wps_enhc
			}
                        if [ -f  "/var/run/son.conf" ]; then
                                rm /var/run/son.conf
                        fi

			config_load wireless
			if [ -f  "/lib/wifi/iface_mgr.sh" ]; then
				config_foreach son_get_config_qcawificfg80211 wifi-device
			fi
			config_foreach mbss_tx_vdev_config wifi-device 0

                        rm -f /etc/ath/iface_mgr.conf
                        rm -f /var/run/iface_mgr.pid
                        iface_mgr_setup
			update_global_daemon_coldboot_qdss_support_variables
			enable_qdss_tracing
			[ -e /sys/firmware/devicetree/base/AUTO_MOUNT ] && {
				case "$board_name" in
					ap-mp*)
						. /etc/init.d/wifi_fw_mount
						stop_wifi_fw "IPQ5018"
					;;
					*)
					;;
				esac
			}

			config_get qld_max_list qcawifi qld_max_list $qld_max_list
			if [ ! -z $qld_max_list ]; then
				if [ $qld_max_list -ne 0 ]; then
				qld_enablecfg80211 wifi0
				fi
			fi

			unicastflood_configcfg80211
		;;
		enable_recover)
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd start

			# For dynamic_hw_mode(=2), set hw mode using
			# recover_mode information
			hw_mode=`grep "recover_mode" /sys/class/net/soc0/pdev_map \
				| awk -F'[(=)]' '{print $4}'`
			set_hw_mode_for_dynamic_mode_switch $hw_mode
		;;
	esac

	atf_configcfg80211
	lock -u /var/run/wifilock
}

unicastflood_configcfg80211() {
	config_load wireless
	config_foreach unicastflood_vap_configcfg80211 wifi-device
}

unicastflood_vap_configcfg80211() {
	local device="$1"

	config_get disabled $device disabled 0
	config_get unicastflood_disable $device unicastflood_disable 0
	if [ $disabled -eq 0 ] && [ $unicastflood_disable -eq 1 ]; then
		config_get vifs "$device" vifs
		for vif in $vifs; do
			config_get vifname $vif ifname
			config_get network $vif network
			config_get vif_disabled $vif disabled 0
			if [ $vif_disabled -eq 0 ]; then
				if [ -e /sys/class/net/br-$network/brif/$vifname/unicast_flood ]; then
					echo 0 > /sys/class/net/br-$network/brif/$vifname/unicast_flood
				fi
			fi
		done
	fi
}

atf_configcfg80211() {
	config_load wireless
	config_foreach atf_radio_vap_params_configcfg80211 wifi-device

	config_load wireless
	config_foreach atf_group_configcfg80211 atf-config-group

	config_load wireless
	config_foreach atf_ssid_configcfg80211 atf-config-ssid

	config_load wireless
	config_foreach atf_sta_configcfg80211 atf-config-sta

	config_load wireless
	config_foreach atf_ac_configcfg80211 atf-config-ac

	config_load wireless
	config_foreach atf_tput_configcfg80211 atf-config-tput

	config_load wireless
	config_foreach atf_enablecfg80211 wifi-device
}

atf_radio_vap_params_configcfg80211() {
	local device="$1"
	local atf_sched_dur
	local atfstrictsched
	local atfobsssched
	local atfobssscale
	local atfgrouppolicy

	config_get device_if "$device" device_if "cfg80211tool"
	config_get atf_sched_dur "$device" atf_sched_dur
	[ -n "$atf_sched_dur" ] && $device_if "$device" "atf_sched_dur" "$atf_sched_dur"

	config_get atfstrictsched "$device" atfstrictsched
	[ -n "$atfstrictsched" ] && $device_if "$device" "atfstrictsched" "$atfstrictsched"

	config_get atfobsssched "$device" atfobsssched
	[ -n "$atfobsssched" ] && $device_if "$device" "atfobsssched" "$atfobsssched"

	config_get atfobssscale "$device" atfobssscale
	[ -n "$atfobssscale" ] && $device_if "$device" "atfobssscale" "$atfobssscale"

	config_get atfgrouppolicy "$device" atfgrouppolicy
	[ -n "$atfgrouppolicy" ] && $device_if "$device" "atfgrouppolicy" "$atfgrouppolicy"

	config_get disabled $device disabled 0
	if [ $disabled -eq 0 ]; then
		config_get vifs "$device" vifs

		local ifidx=0
		local radioidx=${device#wifi}
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"

			config_get atf_shr_buf "$vif" atf_shr_buf
			[ -n "$atf_shr_buf" ] && $device_if "$vifname" "atf_shr_buf" "$atf_shr_buf"

			config_get atf_max_buf "$vif" atf_max_buf
			[ -n "$atf_max_buf" ] && $device_if "$vifname" "atf_max_buf" "$atf_max_buf"

			config_get atf_min_buf "$vif" atf_min_buf
			[ -n "$atf_min_buf" ] && $device_if "$vifname" "atf_min_buf" "$atf_min_buf"

			config_get commitatf "$vif" commitatf
			[ -n "$commitatf" ] && $device_if "$vifname" "commitatf" "$commitatf"

			config_get atfmaxclient "$vif" atfmaxclient
			[ -n "$atfmaxclient" ] && $device_if "$vifname" "atfmaxclient" "$atfmaxclient"

			config_get atfssidgroup "$vif" atfssidgroup
			[ -n "$atfssidgroup" ] && $device_if "$vifname" "atfssidgroup" "$atfssidgroup"

			config_get atf_tput_at "$vif" atf_tput_at
			[ -n "$atf_tput_at" ] && $device_if "$vifname" "atf_tput_at" "$atf_tput_at"

			config_get atfssidsched "$vif" atfssidsched
			[ -n "$atfssidsched" ] && $device_if "$vifname" "atfssidsched" "$atfssidsched"

			ifidx=$(($ifidx + 1))
		done
	fi

}

atf_group_configcfg80211() {
	local cmd
	local group
	local ssid
	local airtime
	local device

	config_get device "$1" device
	radioidx=${device#wifi}

	config_get cmd "$1" command
	config_get group "$1" group
	config_get ssid "$1" ssid
	config_get airtime "$1" airtime

	if [ -z "$cmd" ] || [ -z "$group" ] ; then
		echo "Invalid ATF GROUP Configuration"
		return 1
	fi

	if [ "$cmd" == "addgroup" ] && [ -n "$ssid" ] && [ -n "$airtime" ]; then
		for word in $ssid; do
			wlanconfig ath$radioidx addatfgroup $group $word -cfg80211
		done
		wlanconfig ath$radioidx configatfgroup $group $airtime -cfg80211
	fi

	if [ "$cmd" == "delgroup" ]; then
		wlanconfig ath$radioidx delatfgroup $group -cfg80211
	fi
}

atf_ssid_configcfg80211() {
	local cmd
	local ssid
	local airtime
	local device

	config_get device "$1" device
	radioidx=${device#wifi}

	config_get cmd "$1" command
	config_get ssid "$1" ssid
	config_get airtime "$1" airtime

	if [ -z "$cmd" ] || [ -z "$ssid" ] ; then
		echo "Invalid ATF SSID Configuration"
		return 1
	fi

	if [ "$cmd" == "addssid" ] && [ -n "$airtime" ]; then
		wlanconfig ath$radioidx $cmd $ssid $airtime -cfg80211
	fi

	if [ "$cmd" == "delssid" ]; then
		wlanconfig ath$radioidx $cmd $ssid -cfg80211
	fi
}

atf_sta_configcfg80211() {
	local cmd
	local ssid
	local airtime
	local device
	local mac

	config_get device "$1" device
	radioidx=${device#wifi}

	config_get cmd "$1" command
	config_get airtime "$1" airtime
	config_get ssid "$1" ssid
	config_get mac "$1" macaddr
	mac="${mac//:}"

	if [ -z "$cmd" ] || [ -z "$mac" ] ; then
		echo "Invalid ATF STA Configuration"
		return 1
	fi

	if [ "$cmd" == "addsta" ] && [ -n "$airtime" ]; then
		wlanconfig ath$radioidx $cmd $mac $airtime $ssid -cfg80211
	fi

	if [ "$cmd" == "delsta" ]; then
		wlanconfig ath$radioidx $cmd $mac -cfg80211
	fi
}

atf_ac_configcfg80211() {
	local cmd
	local ssid
	local device
	local ac
	local airtime

	config_get device "$1" device
	radioidx=${device#wifi}

	config_get cmd "$1" command
	config_get ac "$1" ac
	config_get airtime "$1" airtime
	config_get ssid "$1" ssid

	if [ -z "$cmd" ] || [ -z "$ssid" ] || [ -z "$ac" ] ; then
		echo "Invalid ATF AC Configuration"
		return 1
	fi

	if [ "$cmd" == "atfaddac" ] && [ -n "$airtime" ]; then
		wlanconfig ath$radioidx $cmd $ssid $ac:$airtime -cfg80211
	fi

	if [ "$cmd" == "atfdelac" ]; then
		wlanconfig ath$radioidx $cmd $ssid $ac -cfg80211
	fi
}

atf_tput_configcfg80211() {
	local cmd
	local tput
	local max_airtime
	local device
	local mac

	config_get device_if "$device" device_if "cfg80211tool"
	config_get device "$1" device
	radioidx=${device#wifi}

	config_get cmd "$1" command
	config_get tput "$1" throughput
	config_get max_airtime "$1" max_airtime
	config_get mac "$1" macaddr
	mac="${mac//:}"

	if [ -z "$cmd" ] || [ -z "$mac" ] || [ -z "$tput" ] ; then
		echo "Invalid ATF Throughput Configuration"
		return 1
	fi

	if [ "$cmd" == "addtputsta" ]; then
		$device_if ath$radioidx commitatf 0
		wlanconfig ath$radioidx addtputsta $mac $tput $max_airtime -cfg80211
	fi

	if [ "$cmd" == "deltputsta" ]; then
		$device_if ath$radioidx commitatf 0
		wlanconfig ath$radioidx deltputsta $mac -cfg80211
	fi
}

atf_enablecfg80211() {
	local device="$1"

	config_get device_if "$device" device_if "cfg80211tool"
	config_get disabled $device disabled 0
	if [ $disabled -eq 0 ]; then
		config_get vifs "$device" vifs
		echo "device: $device vifs: $vifs"

		local ifidx=0
		local radioidx=${device#wifi}
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"

			config_get commitatf "$vif" commitatf
			[ -n "$commitatf" ] && $device_if "$vifname" "commitatf" "$commitatf"

			ifidx=$(($ifidx + 1))
		done
	fi
}

qld_enablecfg80211() {
	local device="$1"
	echo "qld linked to device: $device"
	qldtool -i $device -B
}

check_qcawifi_device() {
	[ ${1%[0-9]} = "wifi" ] && config_set "$1" phy "$1"
	config_get phy "$1" phy
	[ -z "$phy" ] && {
		find_qcawifi_phy "$1" >/dev/null || return 1
		config_get phy "$1" phy
	}
	[ "$phy" = "$dev" ] && found=1
}

ftm_qcawificfg80211_kernel54() {
	[ -f /tmp/ftm_done ] && {
		echo "Already in FTM mode. Returning"  > /dev/console
		rm -rf /etc/config/wireless
		return
	}

	[ -d /etc/modules.d.bk ] && {
		rm -rf /etc/modules.d
		mv /etc/modules.d.bk /etc/modules.d
	}
	#dmesg got disabled earlier in boot-ftm file
	#enable dmesg back
	dmesg -n8
	ftm -n &
	echo "FTM mode interface is ready now" > /dev/kmsg
	touch /tmp/ftm_done
	rm -rf /etc/config/wireless
}

ftm_qcawificfg80211() {
	local board_name
	local qdf_args

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=$(cat /tmp/sysinfo/board_name)
	}
	echo_cmd -n "/ini" /sys/module/firmware_class/parameters/path
	case "$board_name" in
	*hk*|*dk*|*ac*|*cp*|*oa*|*mp*)
		echo "Entering FTM mode operation" > /dev/console
	;;
	*)
		echo "FTM mode operation not applicable. Returning" > /dev/console
		return
	;;
	esac

	if [ -e /sys/firmware/devicetree/base/MP_256 ]; then
		sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 1400000
		sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 20432
		sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
	fi

	if [ "$board_name" = "ap-hk10-c1" ]; then
		update_internal_ini global_i.ini mode_2g_phyb 1
	fi

	if [ -e /sys/firmware/devicetree/base/MP_256 ]; then
		# Force all the radios in NSS offload mode on 256M profile
		case "$board_name" in
		*hk*|*ac*|*oa*|*cp*|*mp*)
			update_ini_file nss_wifi_olcfg 7
		;;
		*)
		;;
		esac

		[  ! -e  /etc/modules.d/52-diag-char ] &&  {
			echo diagchar > /etc/modules.d/52-diag-char
			insmod_cmd diagchar
		}
	fi

	rm -rf /etc/config/wireless

	append qdf_args "mem_debug_disabled=1"

	update_ini_file cfg80211_config "1"
	for mod in $(cat /lib/wifi/qca-wifi-modules); do

		case ${mod} in
			umac) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					error=1
				}
			};;

			qdf) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} ${qdf_args} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					error=2
				}
			};;

			qca_ol) [ -d /sys/module/${mod} ] || { \
				do_cold_boot_calibration_qcawificfg80211
				insmod_cmd ${mod} testmode=1 || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					error=3
				}
			};;

			ath_pktlog) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					error=4
				}
			};;

			qca_da|ath_dev|hst_tx99|ath_rate_atheros|ath_hal)
			;;

			smart_antenna)
			;;

			*) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					error=4
				}
			};;

		esac
	done

	case "$board_name" in
	*hk*|*ac*|*cp*|*oa*|*mp*)
		[ -d /etc/modules.d.bk ] && { \
			rm -rf /etc/modules.d
			mv /etc/modules.d.bk /etc/modules.d
		}
	;;
	*)
	;;
	esac

	sync
	[ $error != 0 ] && echo "FTM error: $error" > /dev/console && return 1
	dmesg -n8
	ftm -n &
	#dmesg got disabled earlier in boot-ftm file
	#enable dmesg back
	echo "FTM mode interface is ready now" > /dev/kmsg
}

waltest_qcawificfg80211() {
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	echo_cmd -n "/ini" /sys/module/firmware_class/parameters/path
	case "$board_name" in
	ap-hk*)
		echo "Entering WALtest mode operation" > /dev/console
	;;
	*)
		echo "WALtest mode operation not applicable. Returning" > /dev/console
		return
	;;
	esac

	if [ -e /sys/firmware/devicetree/base/MP_256 ]; then
		sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 1400000
		sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 20432
		sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
	fi

	rm -rf /etc/config/wireless

	update_ini_file cfg80211_config "1"
	for mod in $(cat /lib/wifi/qca-wifi-modules); do

		case ${mod} in
			umac) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawifi
					error=1
				}
			};;

			qdf) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawifi
					error=2
				}
			};;

			qca_ol) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} testmode=3 || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawifi
					error=3
				}
			};;

			qca_da|ath_dev|hst_tx99|ath_rate_atheros|ath_hal)
			;;

			smart_antenna|ath_pktlog)
			;;

			*) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					if [ "$recover" != "1" ]; then
						lock -u /var/run/wifilock
					fi
					unload_qcawifi
					error=4
				}
			};;

		esac
	done

	[ $error != 0 ] && echo "WALtest error: $error" > /dev/console && return 1
	echo "WALtest mode interface is ready now" > /dev/kmsg
}

detect_qcawificfg80211() {
	# In 5.4 Kernel, wifi detect is called from kmodloader context when
	# uevent is received after each netdev is created. This causes wifi
	# detect to be called after each netdev is created leading to multiple
	# wifi down/up.
	# Wait here for kmodloader to be complete so that all netdevs are
	# created and detect is done once together for all the netdevs.
	count=`ps | grep -c kmodloader`
	while [ $count -gt 1 ]
	do
		count=`ps | grep -c kmodloader`
		echo "Waiting for kmodloader to complete to start wifi detect" > /dev/console
		sleep 1
	done

	local enable_cfg80211=`uci show qcacfg80211.config.enable |grep "qcacfg80211.config.enable='0'"`
	[ -n "$enable_cfg80211" ] && echo "qcawificfg80211 configuration is disable" > /dev/console && return 1;
	local ker_ver=`uname -r |cut -d. -f1`

	if [ -e /sys/firmware/devicetree/base/MP_256 ]; then
		update_ini_for_lowmem QCA8074_i.ini
		update_ini_for_lowmem QCA8074V2_i.ini
		update_ini_for_lowmem QCA6018_i.ini
		update_ini_for_lowmem QCA5018_i.ini
		update_ini_for_lowmem QCN9000_i.ini
		update_ini_for_lowmem QCN6122_i.ini
	fi

	is_ftm=`grep wifi_ftm_mode /proc/cmdline | wc -l`
	if [ $ker_ver == 5 ]; then
		[ $is_ftm = 1 ] && ftm_qcawificfg80211_kernel54 &&  return
	else
		[ $is_ftm = 1 ] && ftm_qcawificfg80211 &&  return
	fi

	is_wal=`grep waltest_mode /proc/cmdline | wc -l`
	[ $is_wal = 1 ] && waltest_qcawificfg80211 && return

	config_present=0
	devidx=0
	socidx=0
	olcfg_ng=0
	olcfg_ac=0
	olcfg_axa=0
	olcfg_axg=0
	nss_olcfg=0
	nss_ol_num=0
	reload=0
	hw_mode_detect=0
	avoid_load=0
	num_chains=0
	is_e_build=0
	local board_name

	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	if [ "$board_name" = "ap-hk10-c1" ]; then
		update_internal_ini global_i.ini mode_2g_phyb 1
	fi

	if [ "$board_name" = "ap-hk09" ]; then
		update_internal_ini QCA8074V2_i.ini led_gpio_enable_8074 1
	fi

	prefer_hw_mode_id="$(grep hw_mode_id \
			/ini/internal/global_i.ini | awk -F '=' '{print $2}')"

	[ $prefer_hw_mode_id -gt 8 ] && prefer_hw_mode_id=8

	if [ $prefer_hw_mode_id == 8 ]; then
		hw_mode_detect=1
	fi
	sleep 3

	if [ -e /sys/firmware/devicetree/base/MP_256 ] || \
		[ -e /sys/firmware/devicetree/base/MP_512 ]
	then
		for mod in $(cat /lib/wifi/qca-wifi-modules); do
			case ${mod} in
				umac) [ -d /sys/module/${mod} ] && { \
					avoid_load=1
				};;
			esac
		done
	fi

	load_qcawificfg80211
	config_load wireless

	while :; do
		config_get type "wifi$devidx" type
		[ -n "$type" ] || break
		devidx=$(($devidx + 1))
	done
	cd /sys/class/net
	for soc in $(ls -d soc* 2>&-); do
		if [ -f ${soc}/hw_modes ]; then
			hw_modes=$(cat ${soc}/hw_modes)
			ini_file=$(cat ${soc}/ini_file)
			case "${hw_modes}" in
				*2G_PHYB:*)
					prefer_hw_mode_id=7;;
				*DBS_SBS:*)
					prefer_hw_mode_id=4;;
				*DBS:*)
					prefer_hw_mode_id=1;;
				*DBS_OR_SBS:*)
					prefer_hw_mode_id=5;;
				*SINGLE:*)
					prefer_hw_mode_id=0;;
				*SBS_PASSIVE:*)
					prefer_hw_mode_id=2;;
				*SBS:*)
					prefer_hw_mode_id=3;;
			esac
			if [ $hw_mode_detect == 1 ] && [ -f /ini/internal/$ini_file ]; then
				update_internal_ini $ini_file hw_mode_id "$prefer_hw_mode_id"
			fi
		fi
	done

	[ -d wifi0 ] || return
	for dev in $(ls -d wifi* 2>&-); do
		found=0
		if [ -f /sys/class/net/${dev}/nssoffload ] && [ $(cat /sys/class/net/${dev}/nssoffload) == "capable" ]; then
			config_nss_wifi_radio_pri_map "$board_name"
		fi

		config_foreach check_qcawifi_device wifi-device
		if [ "$found" -gt 0 ]; then
			config_present=1
		       	continue
		fi

		if [ $num_chains -le $(cat ${dev}/txchains) ]; then
			num_chains=$(cat ${dev}/txchains)
		fi

		if [ $num_chains -le $(cat ${dev}/rxchains) ]; then
			num_chains=$(cat ${dev}/rxchains)
		fi

		[ -f ${dev}/is_e_build ] && {
			is_e_build=$(cat ${dev}/is_e_build)
		}

		hwcaps=$(cat ${dev}/hwcaps)
		case "${hwcaps}" in
			*11bgn)
				mode_11=ng
				mode_ht=HT40
			        mypower=21
			        mychannel=13
				ssid_pad="_2.4G"
			;;
			*11an/ac |\
			*11abgn/ac)
				mode_11=ac
			        mypower=23
			        mychannel=64
				if grep -q HT80_80 ${dev}/hwmodes
				then
					mode_ht=HT160
				else
					mode_ht=HT80
				fi

				wifi_5g_count=$(($wifi_5g_count + 1))
				if [ "$wifi_5g_count" -gt 1 ]
				then
					ssid_pad="_5G$wifi_5g_count"
				else
					ssid_pad="_5G"
				fi
			;;
			*11bgn/ax) 
                                mode_11=axg
				mode_ht=HT40
			        mypower=21
			        mychannel=13
				ssid_pad="_2.4G"
                        ;;
                        *11abgn/ac/ax |\
			*11an/ac/ax) 
                                mode_11=axa
			        mypower=23
				if grep -q HT80_80 ${dev}/hwmodes
				then
					mode_ht=HT160
				else
					mode_ht=HT80
				fi

				wifi_5g_count=$(($wifi_5g_count + 1))
				if [ "$wifi_5g_count" -gt 1 ]
				then
					ssid_pad="_5G$wifi_5g_count"
				else
					ssid_pad="_5G"
				fi
		esac
		if [ -f /sys/class/net/${dev}/nssoffload ] && [ $(cat /sys/class/net/${dev}/nssoffload) == "capable" ]; then
			case "${mode_11}" in
				ng)
					if [ $olcfg_ng == 0 ]; then
						olcfg_ng=1
						nss_olcfg=$(($nss_olcfg|$((1<<$devidx))))
						nss_ol_num=$(($nss_ol_num + 1))
					fi
				;;
				na|ac)
					if [ $olcfg_ac == 0 ]; then
						olcfg_ac=1
						nss_olcfg=$(($nss_olcfg|$((1<<$devidx))))
						nss_ol_num=$(($nss_ol_num + 1))
					fi
				;;
                                axa)
                                        if [ $olcfg_axa -le 2 ]; then
                                                olcfg_axa=$(($olcfg_axa + 1))
                                                nss_olcfg=$(($nss_olcfg|$((1<<$devidx))))
                                                nss_ol_num=$(($nss_ol_num + 1))
                                        fi
                                ;;
				axg)
                                        if [ $olcfg_axg == 0 ]; then
                                                olcfg_axg=1
                                                nss_olcfg=$(($nss_olcfg|$((1<<$devidx))))
                                                nss_ol_num=$(($nss_ol_num + 1))
                                        fi
                                ;;

			esac
		reload=1
		fi
		if [ $devidx == 0 ]; then
			. /lib/functions/system.sh
			. /lib/functions.sh
			mac=$(mtd_get_mac_binary 0:ART 0)
			mywifimac=$(macaddr_add "$mac" 3)
                        mychannel=149
			mode_ht=HT80
		fi
		if [ $devidx == 1 ]; then
			. /lib/functions/system.sh
			. /lib/functions.sh
			mac=$(mtd_get_mac_binary 0:ART 0)
			mywifimac=$(macaddr_add "$mac" 2)	
		fi		
		if [ $devidx == 2 ]; then
			. /lib/functions/system.sh
			. /lib/functions.sh
			mac=$(mtd_get_mac_binary 0:ART 0)
			mywifimac=$(macaddr_add "$mac" 4)
                        mychannel=36
			mode_ht=HT160
		fi
		cat <<EOF
config wifi-device  wifi$devidx
	option type	qcawificfg80211
	option channel  $mychannel
	option macaddr	$mywifimac
	option hwmode	11${mode_11}
	option htmode   ${mode_ht}
	option txpower  $mypower
	option country  CN
	option disabled 0

config wifi-iface
	option device	wifi$devidx
	option network	lan
	option mode	ap
	option ssid	OpenWrt_$(cat /sys/class/net/eth1/address | awk -F ":" '{print $4""$5""$6 }'| tr a-z A-Z)${ssid_pad}
	option encryption none

EOF
	devidx=$(($devidx + 1))
	done

	#config_present 1 indicates that /etc/config/wireless is already having some configuration.
	# In that case we shall not update the olcfg files
	if [ $config_present == 0 ]; then
		case "$board_name" in
		ap-dk01.1-c1 | ap-dk01.1-c2 | ap-dk04.1-c1 | ap-dk04.1-c2 | ap-dk04.1-c3 | ap152 | ap147 | ap151 | ap135 | ap137)
			;;
		ap-hk*|ap-ac*|ap-oa*|ap-cp*|ap-mp*)
			if [ -f /etc/rc.d/*qca-nss-ecm ]; then
				echo_cmd $nss_olcfg /lib/wifi/wifi_nss_olcfg
				echo_cmd $nss_ol_num /lib/wifi/wifi_nss_olnum
				echo_cmd "$(($olcfg_axa + $olcfg_axg))" /lib/wifi/wifi_nss_hk_olnum
			else
				echo_cmd 0 /lib/wifi/wifi_nss_olcfg
				echo_cmd $nss_ol_num /lib/wifi/wifi_nss_olnum
				echo_cmd "$(($olcfg_axa + $olcfg_axg))" /lib/wifi/wifi_nss_hk_olnum
			fi
			;;
		*)
			echo_cmd $nss_olcfg /lib/wifi/wifi_nss_olcfg
			echo_cmd $nss_ol_num /lib/wifi/wifi_nss_olnum
			;;
		esac
	fi

	if [ ! -f /sys/firmware/devicetree/base/MP_256 ]; then
		if [ $num_chains -le 2 ]; then
			update_ini_for_mon_buf_ring_chainmask_2 QCA8074_i.ini
			update_ini_for_mon_buf_ring_chainmask_2 QCA8074V2_i.ini
			update_ini_for_mon_buf_ring_chainmask_2 QCA6018_i.ini
			update_ini_for_mon_buf_ring_chainmask_2 QCA5018_i.ini
			update_ini_for_mon_buf_ring_chainmask_2 QCN9000_i.ini
			update_ini_for_mon_buf_ring_chainmask_2 QCN6122_i.ini
		elif [ $num_chains -le 4 -o -e /sys/firmware/devicetree/base/MP_512  ]; then
			update_ini_for_monitor_buf_ring QCA8074_i.ini
			update_ini_for_monitor_buf_ring QCA8074V2_i.ini
			update_ini_for_monitor_buf_ring QCA6018_i.ini
			update_ini_for_monitor_buf_ring QCA5018_i.ini
			update_ini_for_monitor_buf_ring QCN9000_i.ini
			update_ini_for_monitor_buf_ring QCN6122_i.ini
		fi
	fi

	if [ -e /sys/firmware/devicetree/base/MP_512 ]; then
		update_ini_for_512MP_dp_tx_desc QCA8074_i.ini
		update_ini_for_512MP_dp_tx_desc QCA8074V2_i.ini
		update_ini_for_512MP_dp_tx_desc QCA6018_i.ini
		update_ini_for_512MP_dp_tx_desc QCN9000_i.ini
		update_ini_for_512MP_dp_tx_desc QCA5018_i.ini
		update_ini_for_512MP_dp_tx_desc QCN6122_i.ini
		if [ $is_e_build -ne 1 ]; then
			update_ini_for_512MP_P_build QCA8074_i.ini
			update_ini_for_512MP_P_build QCA8074V2_i.ini
			update_ini_for_512MP_P_build QCA6018_i.ini
			update_ini_for_512MP_P_build QCN9000_i.ini
			update_ini_for_512MP_P_build QCA5018_i.ini
			update_ini_for_512MP_P_build QCN6122_i.ini
		else
			update_ini_for_512MP_E_build QCA8074_i.ini
			update_ini_for_512MP_E_build QCA8074V2_i.ini
			update_ini_for_512MP_E_build QCA6018_i.ini
			update_ini_for_512MP_E_build QCN9000_i.ini
			update_ini_for_512MP_E_build QCA5018_i.ini
			update_ini_for_512MP_E_build QCN6122_i.ini
		fi
	fi

	case "$board_name" in
		ap-mp03.4* | ap-mp03.3*)
			if [ ! -f /sys/firmware/devicetree/base/MP_256 ] && [ ! -f /sys/firmware/devicetree/base/MP_512 ]; then
				update_ini_for_512MP_dp_tx_desc QCA5018_i.ini
				update_ini_for_512MP_dp_tx_desc QCN6122_i.ini
				update_ini_for_512MP_P_build QCA5018_i.ini
				update_ini_for_512MP_P_build QCN6122_i.ini
			fi
			;;
		*)
	esac
	case "$board_name" in
		ap-mp*)
			update_internal_ini QCN9000_i.ini enable_ema_ap_ext 0
			update_internal_ini QCN6122_i.ini enable_ema_ap_ext 0
			;;
		*)
	esac
	sync

	if [ $reload == 1 ] ; then
		if [ $avoid_load == 1 ]; then
			wifi_updown "disable" "$2" > /dev/null
			ubus call network reload
			wifi_updown "enable" "$2" > /dev/null
		else
			unload_qcawificfg80211 > /dev/null
			load_qcawificfg80211 > /dev/null
		fi
	fi

	update_ini_reo_remap
	update_ini_target_dp_rx_hash_reset
	update_ini_target_dp_default_reo_reset
	start_recovery_daemon
}

# Handle traps here
trap_qcawifi() {
	# Release any locks taken
	lock -u /var/run/wifilock
}

son_get_config_qcawificfg80211()
{
    config_load wireless
    local device="$1"
    config_get disabled $device disabled 0
    if [ $disabled -eq 0 ]; then
    config_get vifs $device vifs
    for vif in $vifs; do
        config_get_bool disabled $vif disabled 0
        [ $disabled = 0 ] || continue
        config_get backhaul "$vif" backhaul 0
        config_get mode $vif mode
        config_get ifname $vif ifname
        local macaddr="$(config_get "$device" macaddr)"
        if [ $backhaul -eq 1 ]; then
            echo " $mode $ifname $device $macaddr"  >> /var/run/son.conf
        else
            echo " nbh_$mode $ifname $device $macaddr"  >> /var/run/son.conf
        fi
    done
    fi
}

# This API brings down all VDEVs, apply Tx vdev config, and brings up all VDEVs
# if user selects channel as auto, and if tx vdev is not configured in scripts
# then this reset sequence is skipped, in case of recover, mbss tx vdev
# configuration would be invoked though user configures channel as auto
#
mbss_tx_vdev_config() {
	local device="$1"
	local recover="$2"

	config_get disabled $device disabled 0
	if [ $disabled -eq 0 ]; then

		config_get vifs "$device" vifs

		local ifidx=0
		local mbss_tx_vdev_ix=0
		local radioidx=${device#wifi}
		for vif in $vifs; do

			config_get mbss_tx_vdev "$vif" mbss_tx_vdev
			[ -n "$mbss_tx_vdev" ] && mbss_tx_vdev_ix=$ifidx

			ifidx=$(($ifidx + 1))
		done

		if [ $mbss_tx_vdev_ix -eq 0 ]; then
			return 1
		fi

		acs_state=`cfg80211tool ath${radioidx} get_acs_state \
			| awk -F  ':' '{print $2}'`
		if [ $acs_state -eq 1 ]; then
			sleep 4
		fi

		config_get device_if "$device" device_if "cfg80211tool"
		local ifidx=0
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"
			config_get mode "$vif" mode
			if [ $mode = "ap_smart_monitor" ]
			then
				ifconfig "$vifname" down
			else
				hapd "$vifname" disable
			fi
			ifidx=$(($ifidx + 1))
		done

		local ifidx=0
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"

			config_get mbss_tx_vdev "$vif" mbss_tx_vdev
			[ -n "$mbss_tx_vdev" ] && "$device_if" "$vifname" mbss_tx_vdev "$mbss_tx_vdev"
			ifidx=$(($ifidx + 1))
		done

		local ifidx=0
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"
			config_get mode "$vif" mode
			if [ $mode = "ap_smart_monitor" ]
			then
				ifconfig "$vifname" up
			else
				hapd "$vifname" enable
			fi
			ifidx=$(($ifidx + 1))
		done
	fi
}
