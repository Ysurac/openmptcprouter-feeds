#
# Copyright (c) 2017-2021 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
#!/bin/sh
#
# Copyright (c) 2014, 2016, The Linux Foundation. All rights reserved.
#
append DRIVERS "qcawifi"
log_file="/tmp/qcawifi_commands.txt"
g_qdss_tracing=0
g_daemon=0
g_cold_boot_support=0
fw_ini_file=""
board_name=""
board_name_prefix=""
daemon_features_default_string=""
cnssdaemon_log_file=""

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
+		qdss_tracing=`grep -i $board_name_prefix $fw_ini_file | grep "enable_qdss_tracing" | grep -i "qcn9000" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
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
+		daemon_support=`grep -i $board_name_prefix $fw_ini_file | grep "enable_daemon_support" | grep -i "qcn9000" | grep -i $slot | awk -F'=' '{print $2}' | grep -c 1`
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

do_cold_boot_calibration_qcawifi() {
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
	insmod_cmd qca_ol testmode=$coldbootmode
	# insmod and rmmod wifi_3_0 kernel object in addition to qca_ol
	# as wifi_3_0 initiates and shuts down driver.
	insmod_cmd wifi_3_0
	rmmod_cmd wifi_3_0
	rmmod_cmd qca_ol
	#Reset driver_mode to 0 for mission mode
	echo 0 > /sys/module/cnss2/parameters/driver_mode
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

scan_qcawifi() {
	local device="$1"
	local wds
	local adhoc sta ap monitor ap_monitor lite_monitor ap_smart_monitor mesh ap_lp_iot disabled

	[ ${device%[0-9]} = "wifi" ] && config_set "$device" phy "$device"

	local ifidx=0
	local radioidx=${device#wifi}
	local son_enabled=""

	son_enabled=$( is_son_enabled )

	config_get vifs "$device" vifs
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
			adhoc|sta|ap|monitor|wrap|lite_monitor|ap_monitor|ap_smart_monitor|mesh|ap_lp_iot)
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

	config_set "$device" vifs "${ap:+$ap }${ap_monitor:+$ap_monitor }${lite_monitor:+$lite_monitor }${mesh:+$mesh }${ap_smart_monitor:+$ap_smart_monitor }${wrap:+$wrap }${sta:+$sta }${adhoc:+$adhoc }${wds:+$wds }${monitor:+$monitor}${ap_lp_iot:+$ap_lp_iot}"
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

	find_qcawifi_phy "$device" || return 1
	config_get phy "$device" phy

	config_get vifs "$device" vifs
	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		config_get mode "$vif" mode
		case "$mode" in
			ap|wrap|ap_monitor|ap_smart_monitor|ap_lp_iot)
				iwpriv "$phy" setCountryID 840
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
				iwpriv "$phy" fc_buf_max 4096
				iwpriv "$phy" fc_q_max 512
				iwpriv "$phy" fc_q_min 32
			elif [ $memtotal -le 256000 ]; then
				# 8MB tx queue max buffer size
				iwpriv "$phy" fc_buf_max 8192
				iwpriv "$phy" fc_q_max 1024
				iwpriv "$phy" fc_q_min 64
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
		ap-cp*)
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
		ap-mp*) nss_wifi_radio_pri_map=$((0x110));;
		*) nss_wifi_radio_pri_map=$((0x1101));;
	esac
	update_internal_ini global_i.ini nss_wifi_radio_pri_map $nss_wifi_radio_pri_map
}

load_qcawifi() {
	local umac_args
	local qdf_args
	local ol_args
	local cfg_low_targ_clkspeed
	local qca_da_needed=0
	local device
	local board_name
	local def_pktlog_support=1
	local hk_ol_num=0

	echo_cmd -n "/ini" /sys/module/firmware_class/parameters/path
	is_wal=`grep waltest_mode /proc/cmdline | wc -l`
	[ $is_wal = 1 ] && waltest_qcawifi && return

	if [ ! -d "/cfg/default" ]; then
		mkdir -p /cfg/default
		cp -rf /ini/ /cfg/default/
	fi

	# Reset the global ini on wifi load. All relevent params will get updated via update_ini_file [config items] [value]
	cp /cfg/default/ini/global.ini  /ini/global.ini

	local enable_cfg80211=`uci show qcacfg80211.config.enable |grep "qcacfg80211.config.enable='1'"`
	[ -n "$enable_cfg80211" ] && echo "qcawifi configuration is disable" > /dev/console && return 1;

	lock /var/run/wifilock
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')

	case "$board_name" in
		ap-dk01.1-c1 | ap-dk01.1-c2 | ap-dk04.1-c1 | ap-dk04.1-c2 | ap-dk04.1-c3)
			if [ $memtotal -le 131072 ]; then
				echo_cmd 1 /proc/net/skb_recycler/max_skbs
				echo_cmd 1 /proc/net/skb_recycler/max_spare_skbs
				append umac_args "low_mem_system=1"
			fi
		;;
		ap152 | ap147 | ap151 | ap135 | ap137)
			if [ $memtotal -le 66560 ]; then
				def_pktlog_support=0
			fi
		;;
	esac

	update_ini_file cfg80211_config "0"
	config_get_bool testmode qcawifi testmode
	[ -n "$testmode" ] && append ol_args "testmode=$testmode"

	config_get vow_config qcawifi vow_config
	[ -n "$vow_config" ] && update_ini_file vow_config "$vow_config"

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
				lock -u /var/run/wifilock
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
	*)
		    sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 1400000
			sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 20432
			sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
			;;
	esac
	elif [ "$mp_512" == "MP_512" ]; then
		[ -d /sys/module/qca_ol ] || { \
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
		}
	else
	case "$board_name" in
	ap-hk09*)
			local soc_version_major="$(cat /sys/module/cnss2/parameters/soc_version_major)"

			if [ $soc_version_major = 2 ];then
				[ -d /sys/module/qca_ol ] || { \
					#total pbuf size is 160 bytes,allocate memory for 55672 pbufs
					sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 9000000
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 67392
					#initially after init 4k buf for 5G and 4k for 2G will be allocated, later range will be configured
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 40960
				}
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
		[ -d /sys/module/qca_ol ] || { \
			if [ $hk_ol_num -eq 3 ]; then
				#total pbuf size is 160 bytes,allocate memory for 93560 pbufs
				#NSS general payload(8000),Rx Buffer per radio(4k),Tx queue buffer per radio(1k), intial TX allocation per radio(4k)
				#Below table is Tx desc allocation based on number of clients connected
				#Radio     Range0   Range1     Range2       Range3
				#           (<=64) (<=128)     (<=256)      (>256)
				#5G-Hi        24k	24k		24k		32k
				#2G           16k	16k		16k		16k
				#5G-Low       24k	24k		24k		32k
				#Absolute high water=NSS payloads + Rx buf per radio + Tx queue per radio + TxDescRange3(5g-low/5g-hi/2g)
				#wifi pool buff = Min(Total tx desc at range 3, device_limit) - total intial tx allocation
				#extra pbuf core0 = (high_water_core0 - (NSS + OCM buffers)) * pbuf_size
				#	where NSS+OCM buffers = 11720 and pbuf_size = 160
				sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 10000000
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 72512
				#initially after init 4k buf for 5G and 4k for 2G will be allocated, later range will be configured
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 36864
			else
				#total pbuf size is 160 bytes,allocate memory for 55672 pbufs
				sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 9000000
				sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 67392
				#initially after init 4k buf for 5G and 4k for 2G will be allocated, later range will be configured
				sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 40960
			fi
		}
	;;
	ap-cp* | ap-mp*)
		[ -d /sys/module/qca_ol ] || { \
			#total pbuf size is 160 bytes,allocate memory for 18808 pbufs
			sysctl_cmd dev.nss.n2hcfg.extra_pbuf_core0 3100000
			sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 30528
			sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 4096
		}
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

	config_get enable_eapol_minrate qcawifi enable_eapol_minrate
	[ -n "$enable_eapol_minrate" ] && update_ini_file eapol_minrate_set "$enable_eapol_minrate"

        config_get set_eapol_minrate_ac qcawifi set_eapol_minrate_ac
        [ -n "$set_eapol_minrate_ac" ] && update_ini_file eapol_minrate_ac_set "$set_eapol_minrate_ac"

	config_get enable_mesh_support qcawifi enable_mesh_support
	[ -n "$enable_mesh_support" ] && update_ini_file mesh_support "$enable_mesh_support"


    if [ -n "$enable_mesh_support" ]
    then
        config_get enable_mesh_peer_cap_update qcawifi enable_mesh_peer_cap_update
        [ -n "$enable_mesh_peer_cap_update" ] && append umac_args "enable_mesh_peer_cap_update=$enable_mesh_peer_cap_update"
    fi

	config_get enable_pktlog_support qcawifi enable_pktlog_support $def_pktlog_support
	[ -n "$enable_pktlog_support" ] && append umac_args "enable_pktlog_support=$enable_pktlog_support"

    config_get g_unicast_deauth_on_stop qcawifi g_unicast_deauth_on_stop $g_unicast_deauth_on_stop
	[ -n "$g_unicast_deauth_on_stop" ] && append umac_args "g_unicast_deauth_on_stop=$g_unicast_deauth_on_stop"

	config_get beacon_offload_disable qcawifi beacon_offload_disable
	[ -n "$beacon_offload_disable" ] && update_ini_file beacon_offload_disable "$beacon_offload_disable"

	config_get spectral_disable qcawifi spectral_disable
	[ -n "$spectral_disable" ] && update_ini_file spectral_disable "$spectral_disable"

        config_get twt_enable qcawifi twt_enable
        [ -n "$twt_enable" ] && update_ini_file twt_enable "$twt_enable"

	config_get poison_spectral_bufs qcawifi poison_spectral_bufs
	[ -n "$poison_spectral_bufs" ] && update_ini_file poison_spectral_bufs "$poison_spectral_bufs"

	config_get b_twt_enable qcawifi b_twt_enable
	[ -n "$b_twt_enable" ] && update_ini_file b_twt_enable "$b_twt_enable"

	config_get re_ul_resp qcawifi re_ul_resp
	[ -n "$re_ul_resp" ] && update_ini_file re_ul_resp "$re_ul_resp"

	config_get_bool icm_enable icm enable 0
	if [ $icm_enable -ne 0 ]
	then
		update_ini_file externalacs_enable 1
	else
		update_ini_file externalacs_enable 0
	fi

	config_get load_rawsimulation_mod qcawifi load_rawsimulation_mod

	config_get carrier_vow_optimization qcawifi carrier_vow_optimization
	[ -n "$carrier_vow_optimization" ] && update_ini_file carrier_vow_optimization "$carrier_vow_optimization"

	for mod in $(cat /lib/wifi/qca-wifi-modules); do
		case ${mod} in
			umac) [ -d /sys/module/${mod} ] || { \

				insmod_cmd ${mod} ${umac_args} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					return 1
				}
			};;

			qdf) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} ${qdf_args} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					return 1
				}
			};;

			qca_ol) [ -d /sys/module/${mod} ] || { \
				do_cold_boot_calibration_qcawifi
				insmod_cmd ${mod} ${ol_args} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					return 1
				}
			};;

			qca_da|ath_dev|hst_tx99|ath_rate_atheros|ath_hal) [ -f /tmp/no_qca_da ] || { \
				[ -d /sys/module/${mod} ] || { \
					insmod_cmd ${mod} || { \
						lock -u /var/run/wifilock
						unload_qcawifi
						return 1
					}
				}
			};;

			ath_pktlog) [ $enable_pktlog_support -eq 0 ] || { \
				[ -d /sys/module/${mod} ] || { \
					insmod_cmd ${mod} || { \
						lock -u /var/run/wifilock
						unload_qcawifi
						return 1
					}
				}
			};;

			rawmode_sim) [ $load_rawsimulation_mod -ne 0 ] && { \
				[ -d /sys/module/${mod} ] || { \
					insmod_cmd ${mod} || { \
						lock -u /var/run/wifilock
						unload_qcawifi
						return 1
					}
				}
			};;

			*) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					return 1
				}
			};;

		esac
	done

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
			rmmod_cmd qca_da > /dev/null 2> /dev/null
			rmmod_cmd ath_dev > /dev/null 2> /dev/null
			rmmod_cmd hst_tx99 > /dev/null 2> /dev/null
			rmmod_cmd ath_rate_atheros > /dev/null 2> /dev/null
			rmmod_cmd ath_hal > /dev/null 2> /dev/null
			cat "1" > /tmp/no_qca_da
		fi
	fi

	if [ -f "/lib/update_smp_affinity.sh" ]; then
		. /lib/update_smp_affinity.sh
		config_foreach enable_smp_affinity_wifi wifi-device
	fi

	lock -u /var/run/wifilock

	update_ini_target_dp_default_reo_reset
}

unload_qcawifi() {
	config_load wireless
	config_foreach disable_qcawifi wifi-device
	eval "type lowi_teardown" >/dev/null 2>&1 && lowi_teardown
	sleep 3
	lock /var/run/wifilock
	for mod in $(cat /lib/wifi/qca-wifi-modules | sed '1!G;h;$!d'); do
        case ${mod} in
            mem_manager) continue;
            esac
		[ -d /sys/module/${mod} ] && rmmod_cmd ${mod}
	done
	lock -u /var/run/wifilock
}

disable_recover_qcawifi() {
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	disable_qcawifi $@ 1
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

enable_recover_qcawifi() {
	local numcrashed
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	enable_qcawifi $@ 1
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

_disable_qcawifi() {
	local device="$1"
	local parent
	local retval=0
	local recover="$2"

	echo "$DRIVERS disable radio $1" >/dev/console

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

	set_wifi_down "$device"

	# in MBSS case, send notification to allow deletion of transmitting VAP
	iwpriv $device wifi_down_ind 1

	include /lib/network
	cd /sys/class/net
	for dev in *; do
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
				    wlanconfig "$dev" destroy
				fi
			}
			[ -f /var/run/hostapd_cred_${device}.bin ] && { \
				rm /var/run/hostapd_cred_${device}.bin
			}
		}
	done

	return 0
}

destroy_vap() {
	local ifname="$1"
	ifconfig $ifname down
	wlanconfig $ifname destroy
}

disable_qcawifi() {
	local device="$1"
	lock /var/run/wifilock
	_disable_qcawifi "$device" $2
	lock -u /var/run/wifilock
}

enable_qcawifi() {
	local device="$1"
	local count=0
	echo "$DRIVERS: enable radio $1" >/dev/console
	local num_radio_instamode=0
	local recover="$2"
	local hk_ol_num=0
	local edge_ch_dep_applicable
	local hwcaps
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}

	load_qcawifi

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
					unload_qcawifi
					device=$1
					load_qcawifi
				fi
				;;
				*)
				;;
			esac
		else
			if [ $nss_override != "0" ]; then
				echo_cmd 0 /lib/wifi/wifi_nss_override
				unload_qcawifi
				device=$1
				load_qcawifi
			fi
		fi
	fi

	lock /var/run/wifilock

	config_get phy "$device" phy

	config_get interCACChan "$device" interCACChan
	[ -n "$interCACChan" ] && iwpriv "$phy" interCACChan "$interCACChan"

	config_get country "$device" country
	if [ -z "$country" ]; then
		if ! set_default_country $device; then
			lock -u /var/run/wifilock
			return 1
		fi
	else
		# If the country parameter is a number (either hex or decimal), we
		# assume it's a regulatory domain - i.e. we use iwpriv setCountryID.
		# Else we assume it's a country code - i.e. we use iwpriv setCountry.
		case "$country" in
			[0-9]*)
				iwpriv "$phy" setCountryID "$country"
			;;
			*)
				[ -n "$country" ] && iwpriv "$phy" setCountry "$country"
			;;
		esac
	fi


	config_get channel "$device" channel
	config_get vifs "$device" vifs
	config_get txpower "$device" txpower
	config_get htmode "$device" htmode auto
	config_get edge_channel_deprioritize "$device" edge_channel_deprioritize 1
	[ auto = "$channel" ] && channel=0

	# WAR to not use chan 36 as primary channel, when using higher BW.
	if [ $channel -eq 36 ]; then
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
	[ -n "$txchainmask" ] && iwpriv "$phy" txchainmask "$txchainmask"

	config_get rxchainmask "$device" rxchainmask
	[ -n "$rxchainmask" ] && iwpriv "$phy" rxchainmask "$rxchainmask"

        config_get regdomain "$device" regdomain
        [ -n "$regdomain" ] && iwpriv "$phy" setRegdomain "$regdomain"

	config_get preCACEn "$device" preCACEn
	[ -n "$preCACEn" ] && iwpriv "$phy" preCACEn "$preCACEn"

	config_get upload_pktlog "$device" upload_pktlog
	[ -n "$upload_pktlog" ] && "$device_if" "$phy" upload_pktlog "$upload_pktlog"

	config_get pCACTimeout "$device" pCACTimeout
	[ -n "$pCACTimeout" ] && iwpriv "$phy" pCACTimeout "$pCACTimeout"

	config_get mbss_auto "$device" mbss_auto
	[ -n "$mbss_auto" ] && iwpriv "$phy" mbss_auto "$mbss_auto"

	config_get AMPDU "$device" AMPDU
	[ -n "$AMPDU" ] && iwpriv "$phy" AMPDU "$AMPDU"

	config_get ampdudensity "$device" ampdudensity
	[ -n "$ampdudensity" ] && iwpriv "$phy" ampdudensity "$ampdudensity"

	config_get_bool AMSDU "$device" AMSDU
	[ -n "$AMSDU" ] && iwpriv "$phy" AMSDU "$AMSDU"

	config_get AMPDULim "$device" AMPDULim
	[ -n "$AMPDULim" ] && iwpriv "$phy" AMPDULim "$AMPDULim"

	config_get AMPDUFrames "$device" AMPDUFrames
	[ -n "$AMPDUFrames" ] && iwpriv "$phy" AMPDUFrames "$AMPDUFrames"

	config_get AMPDURxBsize "$device" AMPDURxBsize
	[ -n "$AMPDURxBsize" ] && iwpriv "$phy" AMPDURxBsize "$AMPDURxBsize"

	config_get_bool bcnburst "$device" bcnburst 1
	[ -n "$bcnburst" ] && iwpriv "$phy" set_bcnburst "$bcnburst"

	config_get set_smart_antenna "$device" set_smart_antenna
	[ -n "$set_smart_antenna" ] && iwpriv "$phy" setSmartAntenna "$set_smart_antenna"

	config_get current_ant "$device" current_ant
	[ -n  "$current_ant" ] && iwpriv "$phy" current_ant "$current_ant"

	config_get default_ant "$device" default_ant
	[ -n "$default_ant" ] && iwpriv "$phy" default_ant "$default_ant"

	config_get ant_retrain "$device" ant_retrain
	[ -n "$ant_retrain" ] && iwpriv "$phy" ant_retrain "$ant_retrain"

	config_get retrain_interval "$device" retrain_interval
	[ -n "$retrain_interval" ] && iwpriv "$phy" retrain_interval "$retrain_interval"

	config_get retrain_drop "$device" retrain_drop
	[ -n "$retrain_drop" ] && iwpriv "$phy" retrain_drop "$retrain_drop"

	config_get ant_train "$device" ant_train
	[ -n "$ant_train" ] && iwpriv "$phy" ant_train "$ant_train"

	config_get ant_trainmode "$device" ant_trainmode
	[ -n "$ant_trainmode" ] && iwpriv "$phy" ant_trainmode "$ant_trainmode"

	config_get ant_traintype "$device" ant_traintype
	[ -n "$ant_traintype" ] && iwpriv "$phy" ant_traintype "$ant_traintype"

	config_get ant_pktlen "$device" ant_pktlen
	[ -n "$ant_pktlen" ] && iwpriv "$phy" ant_pktlen "$ant_pktlen"

	config_get ant_numpkts "$device" ant_numpkts
	[ -n "$ant_numpkts" ] && iwpriv "$phy" ant_numpkts "$ant_numpkts"

	config_get ant_numitr "$device" ant_numitr
	[ -n "$ant_numitr" ] && iwpriv "$phy" ant_numitr "$ant_numitr"

	config_get ant_train_thres "$device" ant_train_thres
	[ -n "$ant_train_thres" ] && iwpriv "$phy" train_threshold "$ant_train_thres"

	config_get ant_train_min_thres "$device" ant_train_min_thres
	[ -n "$ant_train_min_thres" ] && iwpriv "$phy" train_threshold "$ant_train_min_thres"

	config_get ant_traffic_timer "$device" ant_traffic_timer
	[ -n "$ant_traffic_timer" ] && iwpriv "$phy" traffic_timer "$ant_traffic_timer"

	config_get dcs_enable "$device" dcs_enable
	[ -n "$dcs_enable" ] && iwpriv "$phy" dcs_enable "$dcs_enable"

	config_get dcs_coch_int "$device" dcs_coch_int
	[ -n "$dcs_coch_int" ] && iwpriv "$phy" set_dcs_coch_int "$dcs_coch_int"

	config_get dcs_errth "$device" dcs_errth
	[ -n "$dcs_errth" ] && iwpriv "$phy" set_dcs_errth "$dcs_errth"

	config_get dcs_phyerrth "$device" dcs_phyerrth
	[ -n "$dcs_phyerrth" ] && iwpriv "$phy" set_dcs_phyerrth "$dcs_phyerrth"

	config_get dcs_usermaxc "$device" dcs_usermaxc
	[ -n "$dcs_usermaxc" ] && iwpriv "$phy" set_dcs_usermaxc "$dcs_usermaxc"

	config_get dcs_debug "$device" dcs_debug
	[ -n "$dcs_debug" ] && iwpriv "$phy" set_dcs_debug "$dcs_debug"

	config_get set_ch_144 "$device" set_ch_144
	[ -n "$set_ch_144" ] && iwpriv "$phy" setCH144 "$set_ch_144"

	config_get eppovrd_ch_144 "$device" eppovrd_ch_144
	[ -n "$eppovrd_ch_144" ] && iwpriv "$phy" setCH144EppOvrd "$eppovrd_ch_144"

	config_get_bool ani_enable "$device" ani_enable
	[ -n "$ani_enable" ] && iwpriv "$phy" ani_enable "$ani_enable"

	config_get_bool acs_bkscanen "$device" acs_bkscanen
	[ -n "$acs_bkscanen" ] && iwpriv "$phy" acs_bkscanen "$acs_bkscanen"

	config_get acs_scanintvl "$device" acs_scanintvl
	[ -n "$acs_scanintvl" ] && iwpriv "$phy" acs_scanintvl "$acs_scanintvl"

	config_get acs_rssivar "$device" acs_rssivar
	[ -n "$acs_rssivar" ] && iwpriv "$phy" acs_rssivar "$acs_rssivar"

	config_get acs_chloadvar "$device" acs_chloadvar
	[ -n "$acs_chloadvar" ] && iwpriv "$phy" acs_chloadvar "$acs_chloadvar"

	config_get acs_lmtobss "$device" acs_lmtobss
	[ -n "$acs_lmtobss" ] && iwpriv "$phy" acs_lmtobss "$acs_lmtobss"

	config_get acs_ctrlflags "$device" acs_ctrlflags
	[ -n "$acs_ctrlflags" ] && iwpriv "$phy" acs_ctrlflags "$acs_ctrlflags"

	config_get acs_dbgtrace "$device" acs_dbgtrace
	[ -n "$acs_dbgtrace" ] && iwpriv "$phy" acs_dbgtrace "$acs_dbgtrace"

	config_get_bool dscp_ovride "$device" dscp_ovride
	[ -n "$dscp_ovride" ] && iwpriv "$phy" set_dscp_ovride "$dscp_ovride"

	config_get reset_dscp_map "$device" reset_dscp_map
	[ -n "$reset_dscp_map" ] && iwpriv "$phy" reset_dscp_map "$reset_dscp_map"

	config_get dscp_tid_map "$device" dscp_tid_map
	[ -n "$dscp_tid_map" ] && iwpriv "$phy" set_dscp_tid_map $dscp_tid_map

        #Default enable IGMP overide & TID=6
	iwpriv "$phy" sIgmpDscpOvrid 1
	iwpriv "$phy" sIgmpDscpTidMap 6

	config_get_bool igmp_dscp_ovride "$device" igmp_dscp_ovride
	[ -n "$igmp_dscp_ovride" ] && iwpriv "$phy" sIgmpDscpOvrid "$igmp_dscp_ovride"

	config_get igmp_dscp_tid_map "$device" igmp_dscp_tid_map
	[ -n "$igmp_dscp_tid_map" ] && iwpriv "$phy" sIgmpDscpTidMap "$igmp_dscp_tid_map"

	config_get_bool hmmc_dscp_ovride "$device" hmmc_dscp_ovride
	[ -n "$hmmc_dscp_ovride" ] && iwpriv "$phy" sHmmcDscpOvrid "$hmmc_dscp_ovride"

	config_get hmmc_dscp_tid_map "$device" hmmc_dscp_tid_map
	[ -n "$hmmc_dscp_tid_map" ] && iwpriv "$phy" sHmmcDscpTidMap "$hmmc_dscp_tid_map"

	config_get_bool blk_report_fld "$device" blk_report_fld
	[ -n "$blk_report_fld" ] && iwpriv "$phy" setBlkReportFld "$blk_report_fld"

	config_get_bool drop_sta_query "$device" drop_sta_query
	[ -n "$drop_sta_query" ] && iwpriv "$phy" setDropSTAQuery "$drop_sta_query"

	config_get_bool burst "$device" burst
	[ -n "$burst" ] && iwpriv "$phy" burst "$burst"

	config_get burst_dur "$device" burst_dur
	[ -n "$burst_dur" ] && iwpriv "$phy" burst_dur "$burst_dur"

	config_get TXPowLim2G "$device" TXPowLim2G
	[ -n "$TXPowLim2G" ] && iwpriv "$phy" TXPowLim2G "$TXPowLim2G"

	config_get TXPowLim5G "$device" TXPowLim5G
	[ -n "$TXPowLim5G" ] && iwpriv "$phy" TXPowLim5G "$TXPowLim5G"

	case "$board_name" in
	ap-hk*|ap-ac*|ap-cp*|ap-oak*|ap-mp*)
		echo "Enable ol_stats by default for Lithium platforms"
		iwpriv "$phy" enable_ol_stats 1
	;;
	*)
		echo "ol_stats is disabled by default for Non Lithium platforms"
	;;
	esac

	config_get_bool enable_ol_stats "$device" enable_ol_stats
	[ -n "$enable_ol_stats" ] && iwpriv "$phy" enable_ol_stats "$enable_ol_stats"

	config_get_bool low_latency_mode "$device" low_latency_mode
	[ -n "$low_latency_mode" ] && iwpriv "$phy" low_latency_mode "$low_latency_mode"

	config_get emiwar80p80 "$device" emiwar80p80
	[ -n "$emiwar80p80" ] && iwpriv "$phy" emiwar80p80 "$emiwar80p80"

	config_get_bool rst_tso_stats "$device" rst_tso_stats
	[ -n "$rst_tso_stats" ] && iwpriv "$phy" rst_tso_stats "$rst_tso_stats"

	config_get_bool rst_lro_stats "$device" rst_lro_stats
	[ -n "$rst_lro_stats" ] && iwpriv "$phy" rst_lro_stats "$rst_lro_stats"

	config_get_bool rst_sg_stats "$device" rst_sg_stats
	[ -n "$rst_sg_stats" ] && iwpriv "$phy" rst_sg_stats "$rst_sg_stats"

	config_get_bool set_fw_recovery "$device" set_fw_recovery
	[ -n "$set_fw_recovery" ] && iwpriv "$phy" set_fw_recovery "$set_fw_recovery"

	config_get_bool allowpromisc "$device" allowpromisc
	[ -n "$allowpromisc" ] && iwpriv "$phy" allowpromisc "$allowpromisc"

	config_get set_sa_param "$device" set_sa_param
	[ -n "$set_sa_param" ] && iwpriv "$phy" set_sa_param $set_sa_param

	config_get_bool aldstats "$device" aldstats
	[ -n "$aldstats" ] && iwpriv "$phy" aldstats "$aldstats"

	config_get macaddr "$device" macaddr
	[ -n "$macaddr" ] && iwpriv "$phy" setHwaddr "$macaddr"

	config_get promisc "$device" promisc
	[ -n "$promisc" ] && iwpriv "$phy" promisc $promisc

	config_get mode0 "$device" mode0
	[ -n "$mode0" ] && iwpriv "$phy" fc_buf_min 2501

	config_get mode1 "$device" mode1
	[ -n "$mode1" ] && iwpriv "$phy" fc_buf_min 0

	handle_aggr_burst() {
		local value="$1"
		[ -n "$value" ] && iwpriv "$phy" aggr_burst $value
	}

	config_list_foreach "$device" aggr_burst handle_aggr_burst

	config_get_bool block_interbss "$device" block_interbss
	[ -n "$block_interbss" ] && iwpriv "$phy" block_interbss "$block_interbss"

	config_get set_pmf "$device" set_pmf
	[ -n "$set_pmf" ] && iwpriv "$phy" set_pmf "${set_pmf}"

	config_get txbf_snd_int "$device" txbf_snd_int 100
	[ -n "$txbf_snd_int" ] && iwpriv "$phy" txbf_snd_int "$txbf_snd_int"

	config_get mcast_echo "$device" mcast_echo
	[ -n "$mcast_echo" ] && iwpriv "$phy" mcast_echo "${mcast_echo}"

	config_get obss_rssi_th "$device" obss_rssi_th 35
	[ -n "$obss_rssi_th" ] && iwpriv "$phy" obss_rssi_th "${obss_rssi_th}"

	config_get obss_rxrssi_th "$device" obss_rxrssi_th 35
	[ -n "$obss_rxrssi_th" ] && iwpriv "$phy" obss_rxrssi_th "${obss_rxrssi_th}"

        config_get acs_txpwr_opt "$device" acs_txpwr_opt
        [ -n "$acs_txpwr_opt" ] && iwpriv "$phy" acs_tcpwr_opt "${acs_txpwr_opt}"

	config_get obss_long_slot "$device" obss_long_slot
	[ -n "$obss_long_slot" ] && iwpriv "$phy" obss_long_slot "${obss_long_slot}"

	config_get staDFSEn "$device" staDFSEn
	[ -n "$staDFSEn" ] && iwpriv "$phy" staDFSEn "${staDFSEn}"

	config_get scan_over_cac_en "$device" scan_over_cac_en
	[ -n "$scan_over_cac_en" ] && iwpriv "$phy" scan_over_cac_en "${scan_over_cac_en}"

        config_get dbdc_enable "$device" dbdc_enable
        [ -n "$dbdc_enable" ] && iwpriv "$phy" dbdc_enable "${dbdc_enable}"

        config_get client_mcast "$device" client_mcast
        [ -n "$client_mcast" ] && iwpriv "$phy" client_mcast "${client_mcast}"

        config_get pas_scanen "$device" pas_scanen
        [ -n "$pas_scanen" ] && iwpriv "$phy" pas_scanen "${pas_scanen}"

        config_get delay_stavapup "$device" delay_stavapup
        [ -n "$delay_stavapup" ] && iwpriv "$phy" delay_stavapup "${delay_stavapup}"

        config_get tid_override_queue_map "$device" tid_override_queue_map
        [ -n "$tid_override_queue_map" ] && iwpriv "$phy" queue_map "${tid_override_queue_map}"

        config_get channel_block_mode "$device" channel_block_mode
        [ -n "$channel_block_mode" ] && iwpriv "$phy" acs_bmode "${channel_block_mode}"

        config_get no_vlan "$device" no_vlan
        [ -n "$no_vlan" ] && iwpriv "$phy" no_vlan "${no_vlan}"

        config_get discon_time qcawifi discon_time 10
        [ -n "$discon_time" ] && iwpriv "$phy" discon_time "${discon_time}"

        config_get reconfig_time qcawifi reconfig_time 60
        [ -n "$reconfig_time" ] && iwpriv "$phy" reconfig_time "${reconfig_time}"

        config_get alwaysprimary qcawifi alwaysprimary
        [ -n "$alwaysprimary" ] && iwpriv "$phy" alwaysprimary "${alwaysprimary}"

        config_get samessid_disable qcawifi samessid_disable
        [ -n "$samessid_disable" ] && iwpriv "$phy" samessid_disable "${samessid_disable}"

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
				if [ ! -f /lib/wifi/wifi_nss_numradios ]; then
					touch /tmp/wifi_nss_up_one_radio
					sysctl_cmd dev.nss.n2hcfg.n2h_high_water_core0 31648
					sysctl_cmd dev.nss.n2hcfg.n2h_wifi_pool_buf 0
				fi
				case "$hwmode" in
				*axa | *ac)
					iwpriv "$phy" fc_buf0_max 4096
					iwpriv "$phy" fc_buf1_max 4096
					iwpriv "$phy" fc_buf2_max 4096
					iwpriv "$phy" fc_buf3_max 4096
					;;
				*)
					iwpriv "$phy" fc_buf0_max 4096
					iwpriv "$phy" fc_buf1_max 4096
					iwpriv "$phy" fc_buf2_max 4096
					iwpriv "$phy" fc_buf3_max 4096
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
					iwpriv "$phy" fc_buf0_max 8192
					iwpriv "$phy" fc_buf1_max 8192
					iwpriv "$phy" fc_buf2_max 8192
					iwpriv "$phy" fc_buf3_max 8192
					;;
				*)
					iwpriv "$phy" fc_buf0_max 8192
					iwpriv "$phy" fc_buf1_max 8192
					iwpriv "$phy" fc_buf2_max 8192
					iwpriv "$phy" fc_buf3_max 8192
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
				iwpriv "$phy" fc_buf0_max 4096
				iwpriv "$phy" fc_buf1_max 8192
				iwpriv "$phy" fc_buf2_max 8192
				iwpriv "$phy" fc_buf3_max 8192
				;;
			*)
				iwpriv "$phy" fc_buf0_max 4096
				iwpriv "$phy" fc_buf1_max 4096
				iwpriv "$phy" fc_buf2_max 4096
				iwpriv "$phy" fc_buf3_max 4096
				;;
			esac
			;;
		ap-cp* | ap-mp*)
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
						iwpriv "$phy" fc_buf0_max 8192
						iwpriv "$phy" fc_buf1_max 12288
						iwpriv "$phy" fc_buf2_max 16384
					else
						iwpriv "$phy" fc_buf0_max 4096
						iwpriv "$phy" fc_buf1_max 8192
						iwpriv "$phy" fc_buf2_max 12288
					fi
					iwpriv "$phy" fc_buf3_max 16384
					;;
				*)
					iwpriv "$phy" fc_buf0_max 4096
					iwpriv "$phy" fc_buf1_max 8192
					iwpriv "$phy" fc_buf2_max 12288
					iwpriv "$phy" fc_buf3_max 16384
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
					iwpriv "$phy" fc_buf0_max 24576
					iwpriv "$phy" fc_buf1_max 24576
					iwpriv "$phy" fc_buf2_max 24576
					iwpriv "$phy" fc_buf3_max 32768
					;;
				*)
					iwpriv "$phy" fc_buf0_max 16384
					iwpriv "$phy" fc_buf1_max 16384
					iwpriv "$phy" fc_buf2_max 16384
					iwpriv "$phy" fc_buf3_max 24576
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
						iwpriv "$phy" fc_buf0_max 32768
						iwpriv "$phy" fc_buf1_max 32768
						iwpriv "$phy" fc_buf2_max 32768
						iwpriv "$phy" fc_buf3_max 32768
					else
						iwpriv "$phy" fc_buf0_max 8192
						iwpriv "$phy" fc_buf1_max 8192
						iwpriv "$phy" fc_buf2_max 12288
						iwpriv "$phy" fc_buf3_max 32768
					fi
				;;
				*)
					if [ $soc_version_major = 2 ];then
						iwpriv "$phy" fc_buf0_max 16384
						iwpriv "$phy" fc_buf1_max 16384
						iwpriv "$phy" fc_buf2_max 16384
						iwpriv "$phy" fc_buf3_max 32768
					else
						iwpriv "$phy" fc_buf0_max 4096
						iwpriv "$phy" fc_buf1_max 8192
						iwpriv "$phy" fc_buf2_max 12288
						iwpriv "$phy" fc_buf3_max 16384
					fi
				;;
				esac
			fi
			;;
		*)
			case "$hwmode" in
			*ng)
				iwpriv "$phy" fc_buf0_max 5120
				iwpriv "$phy" fc_buf1_max 8192
				iwpriv "$phy" fc_buf2_max 12288
				iwpriv "$phy" fc_buf3_max 16384
				;;
			*ac)
				iwpriv "$phy" fc_buf0_max 8192
				iwpriv "$phy" fc_buf1_max 16384
				iwpriv "$phy" fc_buf2_max 24576
				iwpriv "$phy" fc_buf3_max 32768
				;;
			*)
				iwpriv "$phy" fc_buf0_max 5120
				iwpriv "$phy" fc_buf1_max 8192
				iwpriv "$phy" fc_buf2_max 12288
				iwpriv "$phy" fc_buf3_max 16384
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
					iwpriv "$phy" fc_buf_max 8192
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
	if [ $(iwpriv "$phy" get_rxchainmask | awk -F ':' '{ print $2 }') -gt 3 ]; then
		disable_qrfs_wifi=1
		enable_rps_wifi=1
	fi

	for vif in $vifs; do
		local start_hostapd=
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
	done

	for vif in $vifs; do
		local start_hostapd= vif_txpower= nosbeacon= wlanaddr=""
		local wlanmode
		local is_valid_owe_group=0
		local is_valid_sae_group=0
		config_get ifname "$vif" ifname
		config_get enc "$vif" encryption "none"
		config_get eap_type "$vif" eap_type
		config_get mode "$vif" mode
		config_get ppe_vp "$vif" ppe_vp 0
		wlanmode=$mode

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
			esac
		fi

		[ "$wlanmode" = "ap_monitor" ] && wlanmode="specialvap"
		[ "$wlanmode" = "ap_smart_monitor" ] && wlanmode="smart_monitor"
		[ "$wlanmode" = "ap_lp_iot" ] && wlanmode="lp_iot_mode"

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
		[ -n "${DEBUG}" ] && echo wlanconfig "$ifname" create wlandev "$phy" wlanmode "$wlanmode" ${wlanaddr:+wlanaddr "$wlanaddr"} ${nosbeacon:+nosbeacon}
		if [ -z "$recover" ] || [ "$recover" -eq "0" ]; then
			ifname=$(/usr/sbin/wlanconfig "$ifname" create wlandev "$phy" wlanmode "$wlanmode" ${wlanaddr:+wlanaddr "$wlanaddr"} ${nosbeacon:+nosbeacon})
			[ $? -ne 0 ] && {
				echo "enable_qcawifi($device): Failed to set up $mode vif $ifname" >&2
				continue
			}
			config_set "$vif" ifname "$ifname"
		fi
		if [ $nss_wifi_olcfg != 0 ] && [ $ppe_vp == 1 ]; then
		    echo "$ifname" > /proc/sys/nss/ppe_vp/create && echo "PPE VP enabled for $ifname" > /dev/console
		fi


		config_get hwmode "$device" hwmode auto
		pureg=0
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
			*) hwmode=AUTO;;
		esac
		iwpriv "$ifname" mode "$hwmode"
		[ $pureg -gt 0 ] && iwpriv "$ifname" pureg "$pureg"

		config_get cfreq2 "$vif" cfreq2
		[ -n "$cfreq2" -a "$htmode" = "HT80_80" ] && iwpriv "$ifname" cfreq2 "$cfreq2"

		config_get puren "$vif" puren
		[ -n "$puren" ] && iwpriv "$ifname" puren "$puren"

		config_get mbss_tx_vdev "$vif" mbss_tx_vdev
		[ -n "$mbss_tx_vdev" ] && iwpriv "$ifname" mbss_tx_vdev "$mbss_tx_vdev"

		iwconfig "$ifname" channel "$channel" >/dev/null 2>/dev/null

		config_get_bool hidden "$vif" hidden 0
		iwpriv "$ifname" hide_ssid "$hidden"

                config_get_bool dynamicbeacon "$vif" dynamicbeacon 0
                [ $hidden = 1 ] && iwpriv "$ifname" dynamicbeacon "$dynamicbeacon"

                config_get db_rssi_thr "$vif" db_rssi_thr
                [ -n "$db_rssi_thr" ] && iwpriv "$ifname" db_rssi_thr "$db_rssi_thr"

                config_get db_timeout "$vif" db_timeout
                [ -n "$db_timeout" ] && iwpriv "$ifname" db_timeout "$db_timeout"

                config_get nrshareflag "$vif" nrshareflag
                [ -n "$nrshareflag" ] && iwpriv "$ifname" nrshareflag "$nrshareflag"

		config_get shortgi "$vif" shortgi
		[ -n "$shortgi" ] && iwpriv "$ifname" shortgi "${shortgi}"

		config_get_bool disablecoext "$vif" disablecoext
		[ -n "$disablecoext" ] && iwpriv "$ifname" disablecoext "${disablecoext}"

		config_get chwidth "$vif" chwidth
		[ -n "$chwidth" ] && iwpriv "$ifname" chwidth "${chwidth}"

		config_get wds "$vif" wds
		case "$wds" in
			1|on|enabled) wds=1;;
			*) wds=0;;
		esac
		iwpriv "$ifname" wds "$wds" >/dev/null 2>&1

		config_get ext_nss "$device" ext_nss
		case "$ext_nss" in
			1|on|enabled) iwpriv "$phy" ext_nss 1 >/dev/null 2>&1;;
			0|off|disabled) iwpriv "$phy" ext_nss 0 >/dev/null 2>&1;;
			*) ;;
		esac

		config_get ext_nss_sup "$vif" ext_nss_sup
		case "$ext_nss_sup" in
			1|on|enabled) iwpriv "$ifname" ext_nss_sup 1 >/dev/null 2>&1;;
			0|off|disabled) iwpriv "$ifname" ext_nss_sup 0 >/dev/null 2>&1;;
			*) ;;
		esac

		config_get  backhaul "$vif" backhaul 0
                iwpriv "$ifname" backhaul "$backhaul" >/dev/null 2>&1

		config_get TxBFCTL "$vif" TxBFCTL
		[ -n "$TxBFCTL" ] && iwpriv "$ifname" TxBFCTL "$TxBFCTL"

		config_get bintval "$vif" bintval
		[ -n "$bintval" ] && iwpriv "$ifname" bintval "$bintval"

		config_get_bool countryie "$vif" countryie
		[ -n "$countryie" ] && iwpriv "$ifname" countryie "$countryie"

		config_get_bool vap_contryie "$vif" vap_contryie
		[ -n "$vap_contryie" ] && iwpriv "$ifname" vap_contryie "$vap_contryie"

		config_get ppdu_duration "$vif" ppdu_duration
		[ -n "$ppdu_duration" ] && iwpriv "$ifname" ppdu_duration "$ppdu_duration"

                config_get own_ie_override "$vif" own_ie_override
                [ -n "$own_ie_override" ] && iwpriv "$ifname" rsn_override 1

		config_get_bool sae "$vif" sae
		config_get_bool owe "$vif" owe
		config_get suite_b "$vif" suite_b 0
		config_get_bool dpp "$vif" dpp
		config_get pkex_code "$vif" pkex_code

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
				iwpriv "$ifname" set_dpp_mode 1
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
			local sae_groups=$(echo $1 | tr "," " ")
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
			mixed*|psk*|wep*)
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
					config_get sae_password "$vif" sae_password

					if [ -z "$sae_password" ] && [ -z "$key" ] && [ -z $wpa_psk_file ]
					then
						echo "key and sae_password are NULL" > /dev/console
						destroy_vap $ifname
						continue
					fi

					case "$sae_password" in
						*|id=*)
						echo "SAE PW + PWID supported"
						"$device_if" "$ifname" en_sae_pwid 1
						;;
					esac

					case "$key" in
						*|id=*)
						echo "SAE PW + PWID supported"
						"$device_if" "$ifname" en_sae_pwid 1
						;;
					esac
					config_list_foreach "$vif" sae_groups check_sae_groups

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
					echo "sae password count:" $sae_password_count > /dev/console

					if [ sae_password_count -eq 0] && [ -z "$key" ] && [ -z $wpa_psk_file ]
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
					iwconfig "$ifname" ap "$addr"
				}
			;;
		esac

		config_get_bool uapsd "$vif" uapsd 1
		iwpriv "$ifname" uapsd "$uapsd"

		config_get powersave "$vif" powersave
		[ -n "$powersave" ] && iwpriv "$ifname" powersave "${powersave}"

		config_get_bool ant_ps_on "$vif" ant_ps_on
		[ -n "$ant_ps_on" ] && iwpriv "$ifname" ant_ps_on "${ant_ps_on}"

		config_get ps_timeout "$vif" ps_timeout
		[ -n "$ps_timeout" ] && iwpriv "$ifname" ps_timeout "${ps_timeout}"

		config_get mcastenhance "$vif" mcastenhance
		[ -n "$mcastenhance" ] && iwpriv "$ifname" mcastenhance "${mcastenhance}"

		config_get disable11nmcs "$vif" disable11nmcs
		[ -n "$disable11nmcs" ] && iwpriv "$ifname" disable11nmcs "${disable11nmcs}"

		config_get conf_11acmcs "$vif" conf_11acmcs
		[ -n "$conf_11acmcs" ] && iwpriv "$ifname" conf_11acmcs "${conf_11acmcs}"

		config_get metimer "$vif" metimer
		[ -n "$metimer" ] && iwpriv "$ifname" metimer "${metimer}"

		config_get metimeout "$vif" metimeout
		[ -n "$metimeout" ] && iwpriv "$ifname" metimeout "${metimeout}"

		config_get_bool medropmcast "$vif" medropmcast
		[ -n "$medropmcast" ] && iwpriv "$ifname" medropmcast "${medropmcast}"

		config_get me_adddeny "$vif" me_adddeny
		[ -n "$me_adddeny" ] && iwpriv "$ifname" me_adddeny ${me_adddeny}

		#support independent repeater mode
		config_get vap_ind "$vif" vap_ind
		[ -n "$vap_ind" ] && iwpriv "$ifname" vap_ind "${vap_ind}"

		#support extender ap & STA
		config_get extap "$vif" extap
		[ -n "$extap" ] && iwpriv "$ifname" extap "${extap}"

		config_get scanband "$vif" scanband
		[ -n "$scanband" ] && iwpriv "$ifname" scanband "${scanband}"

		config_get periodicScan "$vif" periodicScan
		[ -n "$periodicScan" ] && iwpriv "$ifname" periodicScan "${periodicScan}"

		config_get frag "$vif" frag
		[ -n "$frag" ] && iwconfig "$ifname" frag "${frag%%.*}"

		config_get rts "$vif" rts
		[ -n "$rts" ] && iwconfig "$ifname" rts "${rts%%.*}"

		config_get cwmin "$vif" cwmin
		[ -n "$cwmin" ] && iwpriv "$ifname" cwmin ${cwmin}

		config_get cwmax "$vif" cwmax
		[ -n "$cwmax" ] && iwpriv "$ifname" cwmax ${cwmax}

		config_get aifs "$vif" aifs
		[ -n "$aifs" ] && iwpriv "$ifname" aifs ${aifs}

		config_get txoplimit "$vif" txoplimit
		[ -n "$txoplimit" ] && iwpriv "$ifname" txoplimit ${txoplimit}

		config_get noackpolicy "$vif" noackpolicy
		[ -n "$noackpolicy" ] && iwpriv "$ifname" noackpolicy ${noackpolicy}

		config_get_bool wmm "$vif" wmm
		[ -n "$wmm" ] && iwpriv "$ifname" wmm "$wmm"

		config_get_bool doth "$vif" doth
		[ -n "$doth" ] && iwpriv "$ifname" doth "$doth"

		config_get doth_chanswitch "$vif" doth_chanswitch
		[ -n "$doth_chanswitch" ] && iwpriv "$ifname" doth_chanswitch ${doth_chanswitch}

		config_get quiet "$vif" quiet
		[ -n "$quiet" ] && iwpriv "$ifname" quiet "$quiet"

		config_get mfptest "$vif" mfptest
		[ -n "$mfptest" ] && iwpriv "$ifname" mfptest "$mfptest"

		config_get dtim_period "$vif" dtim_period
		[ -n "$dtim_period" ] && iwpriv "$ifname" dtim_period "$dtim_period"

		config_get noedgech "$vif" noedgech
		[ -n "$noedgech" ] && iwpriv "$ifname" noedgech "$noedgech"

		config_get ps_on_time "$vif" ps_on_time
		[ -n "$ps_on_time" ] && iwpriv "$ifname" ps_on_time "$ps_on_time"

		config_get inact "$vif" inact
		[ -n "$inact" ] && iwpriv "$ifname" inact "$inact"

		config_get wnm "$vif" wnm
		[ -n "$wnm" ] && iwpriv "$ifname" wnm "$wnm"

		config_get bpr_enable  "$vif" bpr_enable
		[ -n "$bpr_enable" ] && iwpriv "$ifname" set_bpr_enable "$bpr_enable"

		config_get ampdu "$vif" ampdu
		[ -n "$ampdu" ] && iwpriv "$ifname" ampdu "$ampdu"

		config_get amsdu "$vif" amsdu
		[ -n "$amsdu" ] && iwpriv "$ifname" amsdu "$amsdu"

		config_get maxampdu "$vif" maxampdu
		[ -n "$maxampdu" ] && iwpriv "$ifname" maxampdu "$maxampdu"

		config_get vhtmaxampdu "$vif" vhtmaxampdu
		[ -n "$vhtmaxampdu" ] && iwpriv "$ifname" vhtmaxampdu "$vhtmaxampdu"

		config_get setaddbaoper "$vif" setaddbaoper
		[ -n "$setaddbaoper" ] && iwpriv "$ifname" setaddbaoper "$setaddbaoper"

		config_get addbaresp "$vif" addbaresp
		[ -n "$addbaresp" ] && iwpriv "$ifname" $addbaresp

		config_get addba "$vif" addba
		[ -n "$addba" ] && iwpriv "$ifname" addba $addba

		config_get delba "$vif" delba
		[ -n "$delba" ] && iwpriv "$ifname" delba $delba

		config_get_bool stafwd "$vif" stafwd 0
		[ -n "$stafwd" ] && iwpriv "$ifname" stafwd "$stafwd"

		config_get maclist "$vif" maclist
		[ -n "$maclist" ] && {
			# flush MAC list
			iwpriv "$ifname" maccmd 3
			for mac in $maclist; do
				iwpriv "$ifname" addmac "$mac"
			done
		}

		config_get macfilter "$vif" macfilter
		case "$macfilter" in
			allow)
				iwpriv "$ifname" maccmd 1
			;;
			deny)
				iwpriv "$ifname" maccmd 2
			;;
			*)
				# default deny policy if mac list exists
				[ -n "$maclist" ] && iwpriv "$ifname" maccmd 2
			;;
		esac

		config_get nss "$vif" nss
		[ -n "$nss" ] && iwpriv "$ifname" nss "$nss"

		config_get vht_mcsmap "$vif" vht_mcsmap
		[ -n "$vht_mcsmap" ] && iwpriv "$ifname" vht_mcsmap "$vht_mcsmap"

		config_get he_mcs "$vif" he_mcs
		[ -n "$he_mcs" ] && iwpriv "$ifname" he_mcs "$he_mcs"

		config_get chwidth "$vif" chwidth
		[ -n "$chwidth" ] && iwpriv "$ifname" chwidth "$chwidth"

		config_get chbwmode "$vif" chbwmode
		[ -n "$chbwmode" ] && iwpriv "$ifname" chbwmode "$chbwmode"

		config_get ldpc "$vif" ldpc
		[ -n "$ldpc" ] && iwpriv "$ifname" ldpc "$ldpc"

		config_get rx_stbc "$vif" rx_stbc
		[ -n "$rx_stbc" ] && iwpriv "$ifname" rx_stbc "$rx_stbc"

		config_get tx_stbc "$vif" tx_stbc
		[ -n "$tx_stbc" ] && iwpriv "$ifname" tx_stbc "$tx_stbc"

		config_get cca_thresh "$vif" cca_thresh
		[ -n "$cca_thresh" ] && iwpriv "$ifname" cca_thresh "$cca_thresh"

		config_get set11NRetries "$vif" set11NRetries
		[ -n "$set11NRetries" ] && iwpriv "$ifname" set11NRetries "$set11NRetries"

		config_get chanbw "$vif" chanbw
		[ -n "$chanbw" ] && iwpriv "$ifname" chanbw "$chanbw"

		config_get maxsta "$vif" maxsta
		[ -n "$maxsta" ] && iwpriv "$ifname" maxsta "$maxsta"

		config_get sko_max_xretries "$vif" sko_max_xretries
		[ -n "$sko_max_xretries" ] && iwpriv "$ifname" sko "$sko_max_xretries"

		config_get extprotmode "$vif" extprotmode
		[ -n "$extprotmode" ] && iwpriv "$ifname" extprotmode "$extprotmode"

		config_get extprotspac "$vif" extprotspac
		[ -n "$extprotspac" ] && iwpriv "$ifname" extprotspac "$extprotspac"

		config_get_bool cwmenable "$vif" cwmenable
		[ -n "$cwmenable" ] && iwpriv "$ifname" cwmenable "$cwmenable"

		config_get_bool protmode "$vif" protmode
		[ -n "$protmode" ] && iwpriv "$ifname" protmode "$protmode"

		config_get enablertscts "$vif" enablertscts
		[ -n "$enablertscts" ] && iwpriv "$ifname" enablertscts "$enablertscts"

		config_get txcorrection "$vif" txcorrection
		[ -n "$txcorrection" ] && iwpriv "$ifname" txcorrection "$txcorrection"

		config_get rxcorrection "$vif" rxcorrection
		[ -n "$rxcorrection" ] && iwpriv "$ifname" rxcorrection "$rxcorrection"

                config_get vsp_enable "$vif" vsp_enable
                [ -n "$vsp_enable" ] && iwpriv "$ifname" vsp_enable "$vsp_enable"

		config_get ssid "$vif" ssid
                [ -n "$ssid" ] && {
                        iwconfig "$ifname" essid on
                        iwconfig "$ifname" essid ${ssid:+-- }"$ssid"
                }

		config_get txqueuelen "$vif" txqueuelen
		[ -n "$txqueuelen" ] && ifconfig "$ifname" txqueuelen "$txqueuelen"

                net_cfg="$(find_net_config "$vif")"

                config_get mtu $net_cfg mtu

                [ -n "$mtu" ] && {
                        config_set "$vif" mtu $mtu
                        ifconfig "$ifname" mtu $mtu
		}

		config_get tdls "$vif" tdls
		[ -n "$tdls" ] && iwpriv "$ifname" tdls "$tdls"

		config_get set_tdls_rmac "$vif" set_tdls_rmac
		[ -n "$set_tdls_rmac" ] && iwpriv "$ifname" set_tdls_rmac "$set_tdls_rmac"

		config_get tdls_qosnull "$vif" tdls_qosnull
		[ -n "$tdls_qosnull" ] && iwpriv "$ifname" tdls_qosnull "$tdls_qosnull"

		config_get tdls_uapsd "$vif" tdls_uapsd
		[ -n "$tdls_uapsd" ] && iwpriv "$ifname" tdls_uapsd "$tdls_uapsd"

		config_get tdls_set_rcpi "$vif" tdls_set_rcpi
		[ -n "$tdls_set_rcpi" ] && iwpriv "$ifname" set_rcpi "$tdls_set_rcpi"

		config_get tdls_set_rcpi_hi "$vif" tdls_set_rcpi_hi
		[ -n "$tdls_set_rcpi_hi" ] && iwpriv "$ifname" set_rcpihi "$tdls_set_rcpi_hi"

		config_get tdls_set_rcpi_lo "$vif" tdls_set_rcpi_lo
		[ -n "$tdls_set_rcpi_lo" ] && iwpriv "$ifname" set_rcpilo "$tdls_set_rcpi_lo"

		config_get tdls_set_rcpi_margin "$vif" tdls_set_rcpi_margin
		[ -n "$tdls_set_rcpi_margin" ] && iwpriv "$ifname" set_rcpimargin "$tdls_set_rcpi_margin"

		config_get tdls_dtoken "$vif" tdls_dtoken
		[ -n "$tdls_dtoken" ] && iwpriv "$ifname" tdls_dtoken "$tdls_dtoken"

		config_get do_tdls_dc_req "$vif" do_tdls_dc_req
		[ -n "$do_tdls_dc_req" ] && iwpriv "$ifname" do_tdls_dc_req "$do_tdls_dc_req"

		config_get tdls_auto "$vif" tdls_auto
		[ -n "$tdls_auto" ] && iwpriv "$ifname" tdls_auto "$tdls_auto"

		config_get tdls_off_timeout "$vif" tdls_off_timeout
		[ -n "$tdls_off_timeout" ] && iwpriv "$ifname" off_timeout "$tdls_off_timeout"

		config_get tdls_tdb_timeout "$vif" tdls_tdb_timeout
		[ -n "$tdls_tdb_timeout" ] && iwpriv "$ifname" tdb_timeout "$tdls_tdb_timeout"

		config_get tdls_weak_timeout "$vif" tdls_weak_timeout
		[ -n "$tdls_weak_timeout" ] && iwpriv "$ifname" weak_timeout "$tdls_weak_timeout"

		config_get tdls_margin "$vif" tdls_margin
		[ -n "$tdls_margin" ] && iwpriv "$ifname" tdls_margin "$tdls_margin"

		config_get tdls_rssi_ub "$vif" tdls_rssi_ub
		[ -n "$tdls_rssi_ub" ] && iwpriv "$ifname" tdls_rssi_ub "$tdls_rssi_ub"

		config_get tdls_rssi_lb "$vif" tdls_rssi_lb
		[ -n "$tdls_rssi_lb" ] && iwpriv "$ifname" tdls_rssi_lb "$tdls_rssi_lb"

		config_get tdls_path_sel "$vif" tdls_path_sel
		[ -n "$tdls_path_sel" ] && iwpriv "$ifname" tdls_pathSel "$tdls_path_sel"

		config_get tdls_rssi_offset "$vif" tdls_rssi_offset
		[ -n "$tdls_rssi_offset" ] && iwpriv "$ifname" tdls_rssi_o "$tdls_rssi_offset"

		config_get tdls_path_sel_period "$vif" tdls_path_sel_period
		[ -n "$tdls_path_sel_period" ] && iwpriv "$ifname" tdls_pathSel_p "$tdls_path_sel_period"

		config_get tdlsmacaddr1 "$vif" tdlsmacaddr1
		[ -n "$tdlsmacaddr1" ] && iwpriv "$ifname" tdlsmacaddr1 "$tdlsmacaddr1"

		config_get tdlsmacaddr2 "$vif" tdlsmacaddr2
		[ -n "$tdlsmacaddr2" ] && iwpriv "$ifname" tdlsmacaddr2 "$tdlsmacaddr2"

		config_get tdlsaction "$vif" tdlsaction
		[ -n "$tdlsaction" ] && iwpriv "$ifname" tdlsaction "$tdlsaction"

		config_get tdlsoffchan "$vif" tdlsoffchan
		[ -n "$tdlsoffchan" ] && iwpriv "$ifname" tdlsoffchan "$tdlsoffchan"

		config_get tdlsswitchtime "$vif" tdlsswitchtime
		[ -n "$tdlsswitchtime" ] && iwpriv "$ifname" tdlsswitchtime "$tdlsswitchtime"

		config_get tdlstimeout "$vif" tdlstimeout
		[ -n "$tdlstimeout" ] && iwpriv "$ifname" tdlstimeout "$tdlstimeout"

		config_get tdlsecchnoffst "$vif" tdlsecchnoffst
		[ -n "$tdlsecchnoffst" ] && iwpriv "$ifname" tdlsecchnoffst "$tdlsecchnoffst"

		config_get tdlsoffchnmode "$vif" tdlsoffchnmode
		[ -n "$tdlsoffchnmode" ] && iwpriv "$ifname" tdlsoffchnmode "$tdlsoffchnmode"

		config_get_bool blockdfschan "$vif" blockdfschan
		[ -n "$blockdfschan" ] && iwpriv "$ifname" blockdfschan "$blockdfschan"

		config_get dbgLVL "$vif" dbgLVL
		[ -n "$dbgLVL" ] && iwpriv "$ifname" dbgLVL "$dbgLVL"

		config_get dbgLVL_high "$vif" dbgLVL_high
		[ -n "$dbgLVL_high" ] && iwpriv "$ifname" dbgLVL_high "$dbgLVL_high"

		config_get acsmindwell "$vif" acsmindwell
		[ -n "$acsmindwell" ] && iwpriv "$ifname" acsmindwell "$acsmindwell"

		config_get acsmaxdwell "$vif" acsmaxdwell
		[ -n "$acsmaxdwell" ] && iwpriv "$ifname" acsmaxdwell "$acsmaxdwell"

		config_get acsreport "$vif" acsreport
		[ -n "$acsreport" ] && iwpriv "$ifname" acsreport "$acsreport"

		config_get ch_hop_en "$vif" ch_hop_en
		[ -n "$ch_hop_en" ] && iwpriv "$ifname" ch_hop_en "$ch_hop_en"

		config_get ch_long_dur "$vif" ch_long_dur
		[ -n "$ch_long_dur" ] && iwpriv "$ifname" ch_long_dur "$ch_long_dur"

		config_get ch_nhop_dur "$vif" ch_nhop_dur
		[ -n "$ch_nhop_dur" ] && iwpriv "$ifname" ch_nhop_dur "$ch_nhop_dur"

		config_get ch_cntwn_dur "$vif" ch_cntwn_dur
		[ -n "$ch_cntwn_dur" ] && iwpriv "$ifname" ch_cntwn_dur "$ch_cntwn_dur"

		config_get ch_noise_th "$vif" ch_noise_th
		[ -n "$ch_noise_th" ] && iwpriv "$ifname" ch_noise_th "$ch_noise_th"

		config_get ch_cnt_th "$vif" ch_cnt_th
		[ -n "$ch_cnt_th" ] && iwpriv "$ifname" ch_cnt_th "$ch_cnt_th"

		config_get_bool scanchevent "$vif" scanchevent
		[ -n "$scanchevent" ] && iwpriv "$ifname" scanchevent "$scanchevent"

		config_get_bool send_add_ies "$vif" send_add_ies
		[ -n "$send_add_ies" ] && iwpriv "$ifname" send_add_ies "$send_add_ies"

		config_get enable_rtt "$vif" enable_rtt
		[ -n "$enable_rtt" ] && iwpriv "$ifname" enable_rtt "$enable_rtt"

		config_get_bool enable_lci "$vif" enable_lci
		[ -n "$enable_lci" ] && iwpriv "$ifname" enable_lci "$enable_lci"

		config_get_bool enable_lcr "$vif" enable_lcr
		[ -n "$enable_lcr" ] && iwpriv "$ifname" enable_lcr "$enable_lcr"

		config_get_bool rrm "$vif" rrm
		[ -n "$rrm" ] && iwpriv "$ifname" rrm "$rrm"

		config_get_bool rrmslwin "$vif" rrmslwin
		[ -n "$rrmslwin" ] && iwpriv "$ifname" rrmslwin "$rrmslwin"

		config_get_bool rrmstats "$vif" rrmsstats
		[ -n "$rrmstats" ] && iwpriv "$ifname" rrmstats "$rrmstats"

		config_get rrmdbg "$vif" rrmdbg
		[ -n "$rrmdbg" ] && iwpriv "$ifname" rrmdbg "$rrmdbg"

		config_get acparams "$vif" acparams
		[ -n "$acparams" ] && iwpriv "$ifname" acparams $acparams

		config_get setwmmparams "$vif" setwmmparams
		[ -n "$setwmmparams" ] && iwpriv "$ifname" setwmmparams $setwmmparams

		config_get_bool qbssload "$vif" qbssload
		[ -n "$qbssload" ] && iwpriv "$ifname" qbssload "$qbssload"

		config_get_bool proxyarp "$vif" proxyarp
		[ -n "$proxyarp" ] && iwpriv "$ifname" proxyarp "$proxyarp"

		config_get_bool dgaf_disable "$vif" dgaf_disable
		[ -n "$dgaf_disable" ] && iwpriv "$ifname" dgaf_disable "$dgaf_disable"

		config_get setibssdfsparam "$vif" setibssdfsparam
		[ -n "$setibssdfsparam" ] && iwpriv "$ifname" setibssdfsparam "$setibssdfsparam"

		config_get startibssrssimon "$vif" startibssrssimon
		[ -n "$startibssrssimon" ] && iwpriv "$ifname" startibssrssimon "$startibssrssimon"

		config_get setibssrssihyst "$vif" setibssrssihyst
		[ -n "$setibssrssihyst" ] && iwpriv "$ifname" setibssrssihyst "$setibssrssihyst"

		config_get son_event_bcast qcawifi son_event_bcast
		[ -n "$son_event_bcast" ] && iwpriv "$ifname" son_event_bcast "$son_event_bcast"

		config_get noIBSSCreate "$vif" noIBSSCreate
		[ -n "$noIBSSCreate" ] && iwpriv "$ifname" noIBSSCreate "$noIBSSCreate"

		config_get setibssrssiclass "$vif" setibssrssiclass
		[ -n "$setibssrssiclass" ] && iwpriv "$ifname" setibssrssiclass $setibssrssiclass

		config_get offchan_tx_test "$vif" offchan_tx_test
		[ -n "$offchan_tx_test" ] && iwpriv "$ifname" offchan_tx_test $offchan_tx_test

		handle_vow_dbg_cfg() {
			local value="$1"
			[ -n "$value" ] && iwpriv "$ifname" vow_dbg_cfg $value
		}

		config_list_foreach "$vif" vow_dbg_cfg handle_vow_dbg_cfg

		config_get_bool vow_dbg "$vif" vow_dbg
		[ -n "$vow_dbg" ] && iwpriv "$ifname" vow_dbg "$vow_dbg"

		handle_set_max_rate() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" set_max_rate $value
		}
		config_list_foreach "$vif" set_max_rate handle_set_max_rate

		config_get_bool implicitbf "$vif" implicitbf
		[ -n "$implicitbf" ] && iwpriv "$ifname" implicitbf "${implicitbf}"

		config_get_bool vhtsubfee "$vif" vhtsubfee
		[ -n "$vhtsubfee" ] && iwpriv "$ifname" vhtsubfee "${vhtsubfee}"

		config_get_bool vhtmubfee "$vif" vhtmubfee
		[ -n "$vhtmubfee" ] && iwpriv "$ifname" vhtmubfee "${vhtmubfee}"

		config_get_bool vhtsubfer "$vif" vhtsubfer
		[ -n "$vhtsubfer" ] && iwpriv "$ifname" vhtsubfer "${vhtsubfer}"

		config_get_bool vhtmubfer "$vif" vhtmubfer
		[ -n "$vhtmubfer" ] && iwpriv "$ifname" vhtmubfer "${vhtmubfer}"

		config_get vhtstscap "$vif" vhtstscap
		[ -n "$vhtstscap" ] && iwpriv "$ifname" vhtstscap "${vhtstscap}"

		config_get vhtsounddim "$vif" vhtsounddim
		[ -n "$vhtsounddim" ] && iwpriv "$ifname" vhtsounddim "${vhtsounddim}"

		config_get he_subfee "$vif" he_subfee
		[ -n "$he_subfee" ] && iwpriv "$ifname" he_subfee "${he_subfee}"

		config_get he_subfer "$vif" he_subfer
		[ -n "$he_subfer" ] && iwpriv "$ifname" he_subfer "${he_subfer}"

		config_get he_mubfee "$vif" he_mubfee
		[ -n "$he_mubfee" ] && iwpriv "$ifname" he_mubfee "${he_mubfee}"

		config_get he_mubfer "$vif" he_mubfer
		[ -n "$he_mubfer" ] && iwpriv "$ifname" he_mubfer "${he_mubfer}"

		config_get he_dlofdma "$vif" he_dlofdma
		[ -n "$he_dlofdma" ] && iwpriv "$ifname" he_dlofdma "${he_dlofdma}"

		config_get he_ulofdma "$vif" he_ulofdma
		[ -n "$he_ulofdma" ] && iwpriv "$ifname" he_ulofdma "${he_ulofdma}"

		config_get he_ulmumimo "$vif" he_ulmumimo
		[ -n "$he_ulmumimo" ] && iwpriv "$ifname" he_ulmumimo "${he_ulmumimo}"

		config_get he_dcm "$vif" he_dcm
		[ -n "$he_dcm" ] && iwpriv "$ifname" he_dcm "${he_dcm}"

		config_get he_extrange "$vif" he_extrange
		[ -n "$he_extrange" ] && iwpriv "$ifname" he_extrange "${he_extrange}"

		config_get he_ltf "$vif" he_ltf
		[ -n "$he_ltf" ] && iwpriv "$ifname" he_ltf "${he_ltf}"

		config_get he_txmcsmap "$vif" he_txmcsmap
		[ -n "$he_txmcsmap" ] && iwpriv "$ifname" he_txmcsmap "${he_txmcsmap}"

		config_get he_rxmcsmap "$vif" he_rxmcsmap
		[ -n "$he_rxmcsmap" ] && iwpriv "$ifname" he_rxmcsmap "${he_rxmcsmap}"

		config_get ba_bufsize "$vif" ba_bufsize
		[ -n "$ba_bufsize" ] && iwpriv "$ifname" ba_bufsize "${ba_bufsize}"

		config_get encap_type "$vif" encap_type
		[ -n "$encap_type" ] && iwpriv "$ifname" encap_type "${encap_type}"

		config_get decap_type "$vif" decap_type
		[ -n "$decap_type" ] && iwpriv "$ifname" decap_type "${decap_type}"

		config_get_bool rawsim_txagr "$vif" rawsim_txagr
		[ -n "$rawsim_txagr" ] && iwpriv "$ifname" rawsim_txagr "${rawsim_txagr}"

		config_get clr_rawsim_stats "$vif" clr_rawsim_stats
		[ -n "$clr_rawsim_stats" ] && iwpriv "$ifname" clr_rawsim_stats "${clr_rawsim_stats}"

		config_get rawsim_debug "$vif" rawsim_debug
		[ -n "$rawsim_debug" ] && iwpriv "$ifname" rawsim_debug "${rawsim_debug}"

		config_get rsim_en_frmcnt "$vif" rsim_en_frmcnt
		[ -n "$rsim_en_frmcnt" ] && iwpriv "$ifname" rsim_en_frmcnt "${rsim_en_frmcnt}"

		config_get rsim_de_frmcnt "$vif" rsim_de_frmcnt
		[ -n "$rsim_de_frmcnt" ] && iwpriv "$ifname" rsim_de_frmcnt "${rsim_de_frmcnt}"

		config_get set_monrxfilter "$vif" set_monrxfilter
		[ -n "$set_monrxfilter" ] && iwpriv "$ifname" set_monrxfilter "${set_monrxfilter}"

		config_get neighbourfilter "$vif" neighbourfilter
		[ -n "$neighbourfilter" ] && iwpriv "$ifname" neighbourfilter "${neighbourfilter}"

		config_get athnewind "$vif" athnewind
		[ -n "$athnewind" ] && iwpriv "$ifname" athnewind "$athnewind"

		config_get osen "$vif" osen
		[ -n "$osen" ] && iwpriv "$ifname" osen "$osen"

		if [ ! -z $osen ]; then
			if [ $osen -ne 0 ]; then
				iwpriv "$ifname" proxyarp 1
			fi
		fi

		config_get re_scalingfactor "$vif" re_scalingfactor
		[ -n "$re_scalingfactor" ] && iwpriv "$ifname" set_whc_sfactor "$re_scalingfactor"

		config_get ul_hyst "$vif" ul_hyst
		[ -n "$ul_hyst" ] && iwpriv "$ifname" ul_hyst "${ul_hyst}"

		config_get root_distance "$vif" root_distance
		[ -n "$root_distance" ] && iwpriv "$ifname" set_whc_dist "$root_distance"

		config_get caprssi "$vif" caprssi
		[ -n "$caprssi" ] && iwpriv "$ifname" caprssi "${caprssi}"

		config_get_bool ap_isolation_enabled $device ap_isolation_enabled 0
		config_get_bool isolate "$vif" isolate 0

		if [ $ap_isolation_enabled -ne 0 ]; then
			[ "$mode" = "wrap" ] && isolate=1
			iwpriv "$phy" isolation "$ap_isolation_enabled"
		fi

                config_get_bool ctsprt_dtmbcn "$vif" ctsprt_dtmbcn
                [ -n "$ctsprt_dtmbcn" ] && iwpriv "$ifname" ctsprt_dtmbcn "${ctsprt_dtmbcn}"

		config_get assocwar160  "$vif" assocwar160
		[ -n "$assocwar160" ] && iwpriv "$ifname" assocwar160 "$assocwar160"

		config_get rawdwepind "$vif" rawdwepind
		[ -n "$rawdwepind" ] && iwpriv "$ifname" rawdwepind "$rawdwepind"

		config_get revsig160  "$vif" revsig160
		[ -n "$revsig160" ] && iwpriv "$ifname" revsig160 "$revsig160"

		config_get channel_block_list "$vif" channel_block_list
		[ -n "$channel_block_list" ] && wifitool "$ifname" block_acs_channel "$channel_block_list"

		config_get rept_spl  "$vif" rept_spl
		[ -n "$rept_spl" ] && iwpriv "$ifname" rept_spl "$rept_spl"

		config_get cactimeout  "$vif" cactimeout
		[ -n "$cactimeout" ] && iwpriv "$ifname" set_cactimeout "$cactimeout"

		config_get meshdbg "$vif" meshdbg
		[ -n "$meshdbg" ] && iwpriv "$ifname" meshdbg "$meshdbg"


		config_get rmode_pktsim "$vif" rmode_pktsim
		[ -n "$rmode_pktsim" ] && iwpriv "$ifname" rmode_pktsim "$rmode_pktsim"

		config_get hlos_tidoverride "$vif" hlos_tidoverride
		if [ "$hlos_tidoverride" -eq 1 ]; then
			insmod qca-nss-mscs
		fi

		[ -n "$hlos_tidoverride" ] && iwpriv "$ifname" hlos_tidoverride "$hlos_tidoverride"

		config_get mscs "$vif" mscs
		if [ "$mscs" -eq 1 ]; then
			insmod qca-nss-mscs
		fi

		[ -n "$mscs" ] && iwpriv "$ifname" mscs "$mscs"

                config_get global_wds qcawifi global_wds

                if [ $global_wds -ne 0 ]; then
                     iwpriv "$ifname" athnewind 1
                fi

                config_get pref_uplink "$device" pref_uplink
                [ -n "$pref_uplink" ] && iwpriv "$phy" pref_uplink "${pref_uplink}"

                config_get fast_lane "$device" fast_lane
                [ -n "$fast_lane" ] && iwpriv "$phy" fast_lane "${fast_lane}"

		if [ ! -z $fast_lane ]; then
			if [ $fast_lane -ne 0 ]; then
				iwpriv "$ifname" athnewind 1
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


				iwpriv "$ifname" ap_bridge "$((isolate^1))"

				config_get_bool l2tif "$vif" l2tif
				[ -n "$l2tif" ] && iwpriv "$ifname" l2tif "$l2tif"

				if [ -n "$start_wapid" ]; then
					wapid_setup_vif "$vif" || {
						echo "enable_qcawifi($device): Failed to set up wapid for interface $ifname" >&2
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
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
					hostapd_setup_vif "$vif" atheros no_nconfig || {
						echo "enable_qcawifi($device): Failed to set up hostapd for interface $ifname" >&2
						# make sure this wifi interface won't accidentally stay open without encryption
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
						continue
					}
				fi
			;;
			wds|sta)
				if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
					wpa_supplicant_setup_vif "$vif" athr || {
						echo "enable_qcawifi($device): Failed to set up wpa_supplicant for interface $ifname" >&2
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
						continue
					}
				fi
			;;
			adhoc)
				if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
					wpa_supplicant_setup_vif "$vif" athr || {
						echo "enable_qcawifi($device): Failed to set up wpa"
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
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

		config_get set11NRates "$vif" set11NRates
		[ -n "$set11NRates" ] && iwpriv "$ifname" set11NRates "$set11NRates"

		# 256 QAM capability needs to be parsed first, since
		# vhtmcs enables/disable rate indices 8, 9 for 2G
		# only if vht_11ng is set or not
		config_get_bool vht_11ng "$vif" vht_11ng
		[ -n "$vht_11ng" ] && iwpriv "$ifname" vht_11ng "$vht_11ng"

		config_get_bool vhtintop "$vif" vhtintop
		[ -n "$vhtintop" ] && iwpriv "$ifname" 11ngvhtintop "$vhtintop"

		config_get vhtmcs "$vif" vhtmcs
		[ -n "$vhtmcs" ] && iwpriv "$ifname" vhtmcs "$vhtmcs"

		config_get dis_legacy "$vif" dis_legacy
		[ -n "$dis_legacy" ] && iwpriv "$ifname" dis_legacy "$dis_legacy"

		config_get mbo "$vif" mbo
		[ -n "$mbo" ] && iwpriv "$ifname" mbo "$mbo"

		if [ $mode = "sta" ]; then
			config_get enable_ft  "$vif" ieee80211r
			[ -n "$enable_ft" ] && iwpriv "$ifname" ft "$enable_ft"
		fi

		config_get enable_fils  "$vif" ieee80211ai
		config_get fils_discovery_period  "$vif" fils_fd_period 20
		[ -n "$enable_fils" ] && iwpriv "$ifname" enable_fils "$enable_fils" "$fils_discovery_period"

		config_get bpr_enable  "$vif" bpr_enable
		[ -n "$bpr_enable" ] && iwpriv "$ifname" set_bpr_enable "$bpr_enable"

		config_get oce "$vif" oce
		[ -n "$oce" ] && iwpriv "$ifname" oce "$oce"
		if [ ! -z $oce]; then
			[ "$oce" -gt 0 ] && {
				case "$hwmode" in
					11B*|11G*|11NG*)
						iwpriv "$ifname" set_bcn_rate 5500
						iwpriv "$ifname" prb_rate 5500
						;;
					*)
						;;
				esac

				[ -z "$enable_fils" ] && {
					config_get fils_discovery_period  "$vif" fils_fd_period 20
					iwpriv "$ifname" enable_fils 1 "$fils_discovery_period"
				}
			}
		fi

		config_get set_bcn_rate "$vif" set_bcn_rate
		[ -n "$set_bcn_rate" ] && iwpriv "$ifname" set_bcn_rate "$set_bcn_rate"

		config_get mcast_rate "$vif" mcast_rate
		[ -n "$mcast_rate" ] && iwpriv "$ifname" mcast_rate "${mcast_rate%%.*}"

		#support nawds
		config_get nawds_mode "$vif" nawds_mode
		[ -n "$nawds_mode" ] && wlanconfig "$ifname" nawds mode "${nawds_mode}"

		handle_nawds() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" nawds add-repeater $value
		}
		config_list_foreach "$vif" nawds_add_repeater handle_nawds

		handle_hmwds() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" hmwds add_addr $value
		}
		config_list_foreach "$vif" hmwds_add_addr handle_hmwds

		config_get nawds_override "$vif" nawds_override
		[ -n "$nawds_override" ] && wlanconfig "$ifname" nawds override "${nawds_override}"

		config_get nawds_defcaps "$vif" nawds_defcaps
		[ -n "$nawds_defcaps" ] && wlanconfig "$ifname" nawds defcaps "${nawds_defcaps}"

		handle_hmmc_add() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" hmmc add $value
		}
		config_list_foreach "$vif" hmmc_add handle_hmmc_add

		# TXPower settings only work if device is up already
		# while atheros hardware theoretically is capable of per-vif (even per-packet) txpower
		# adjustment it does not work with the current atheros hal/madwifi driver

		config_get vif_txpower "$vif" txpower
		# use vif_txpower (from wifi-iface) instead of txpower (from wifi-device) if
		# the latter doesn't exist
		txpower="${txpower:-$vif_txpower}"
		[ -z "$txpower" ] || iwconfig "$ifname" txpower "${txpower%%.*}"

		if [ $enable_rps_wifi == 1 ] && [ -f "/lib/update_system_params.sh" ]; then
			. /lib/update_system_params.sh
			enable_rps $ifname
		fi


	done

	config_get wifi_debug_sh $device wifi_debug_sh
	[ -n "$wifi_debug_sh" -a -e "$wifi_debug_sh" ] && sh "$wifi_debug_sh"

        config_get primaryradio "$device" primaryradio
        [ -n "$primaryradio" ] && iwpriv "$phy" primaryradio "${primaryradio}"

        config_get nobckhlradio "$device" nobckhlradio
        [ -n "$nobckhlradio" ] && iwpriv "$phy" nobckhlradio "${nobckhlradio}"

        config_get CSwOpts "$device" CSwOpts
        [ -n "$CSwOpts" ] && iwpriv "$phy" CSwOpts "${CSwOpts}"

	if [ $disable_qrfs_wifi == 1 ] && [ -f "/lib/update_system_params.sh" ]; then
		. /lib/update_system_params.sh
		disable_qrfs
	fi


	lock -u /var/run/wifilock
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

pre_qcawifi() {
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

                        if [ -f  "/var/run/son.conf" ]; then
                                rm /var/run/son.conf
                        fi
		;;
		disable_recover)
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd stop
		;;
	esac
	lock -u /var/run/wifilock
}

post_qcawifi() {
	local action=${1}
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
	}
	config_get type "$device" type
	[ "$type" != "qcawifi" ] && return

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

			config_get_bool icm_enable icm enable 0
			[ ${icm_enable} -gt 0 ] && \
					eval "type icm_setup" >/dev/null 2>&1 && {
				icm_setup
			}

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

			eval "type qwrap_setup" >/dev/null 2>&1 && qwrap_setup && _disable_qcawifi

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
				config_foreach son_get_config wifi-device
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
		;;
		enable_recover)
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd start
		;;
	esac

	atf_config
	lock -u /var/run/wifilock
}

atf_config() {
	config_load wireless
	config_foreach atf_radio_vap_params_config wifi-device

	config_load wireless
	config_foreach atf_group_config atf-config-group

	config_load wireless
	config_foreach atf_ssid_config atf-config-ssid

	config_load wireless
	config_foreach atf_sta_config atf-config-sta

	config_load wireless
	config_foreach atf_ac_config atf-config-ac

	config_load wireless
	config_foreach atf_tput_config atf-config-tput

	config_load wireless
	config_foreach atf_enable wifi-device
}

atf_radio_vap_params_config() {
	local device="$1"
	local atf_sched_dur
	local atfstrictsched
	local atfobsssched
	local atfobssscale
	local atfgrouppolicy

	config_get atf_sched_dur "$device" atf_sched_dur
	[ -n "$atf_sched_dur" ] && iwpriv "$device" "atf_sched_dur" "$atf_sched_dur"

	config_get atfstrictsched "$device" atfstrictsched
	[ -n "$atfstrictsched" ] && iwpriv "$device" "atfstrictsched" "$atfstrictsched"

	config_get atfobsssched "$device" atfobsssched
	[ -n "$atfobsssched" ] && iwpriv "$device" "atfobsssched" "$atfobsssched"

	config_get atfobssscale "$device" atfobssscale
	[ -n "$atfobssscale" ] && iwpriv "$device" "atfobssscale" "$atfobssscale"

	config_get atfgrouppolicy "$device" atfgrouppolicy
	[ -n "$atfgrouppolicy" ] && iwpriv "$device" "atfgrouppolicy" "$atfgrouppolicy"

	config_get disabled $device disabled 0
	if [ $disabled -eq 0 ]; then
		config_get vifs "$device" vifs

		local ifidx=0
		local radioidx=${device#wifi}
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"

			config_get atf_shr_buf "$vif" atf_shr_buf
			[ -n "$atf_shr_buf" ] && iwpriv "$vifname" "atf_shr_buf" "$atf_shr_buf"

			config_get atf_max_buf "$vif" atf_max_buf
			[ -n "$atf_max_buf" ] && iwpriv "$vifname" "atf_max_buf" "$atf_max_buf"

			config_get atf_min_buf "$vif" atf_min_buf
			[ -n "$atf_min_buf" ] && iwpriv "$vifname" "atf_min_buf" "$atf_min_buf"

			config_get commitatf "$vif" commitatf
			[ -n "$commitatf" ] && iwpriv "$vifname" "commitatf" "$commitatf"

			config_get atfmaxclient "$vif" atfmaxclient
			[ -n "$atfmaxclient" ] && iwpriv "$vifname" "atfmaxclient" "$atfmaxclient"

			config_get atfssidgroup "$vif" atfssidgroup
			[ -n "$atfssidgroup" ] && iwpriv "$vifname" "atfssidgroup" "$atfssidgroup"

			config_get atf_tput_at "$vif" atf_tput_at
			[ -n "$atf_tput_at" ] && iwpriv "$vifname" "atf_tput_at" "$atf_tput_at"

			config_get atfssidsched "$vif" atfssidsched
			[ -n "$atfssidsched" ] && iwpriv "$vifname" "atfssidsched" "$atfssidsched"

			ifidx=$(($ifidx + 1))
		done
	fi

}

atf_group_config() {
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
			wlanconfig ath$radioidx addatfgroup $group $word
		done
		wlanconfig ath$radioidx configatgroup $group $airtime
	fi

	if [ "$cmd" == "delgroup" ]; then
		wlanconfig ath$radioidx delatfgroup $group
	fi
}

atf_ssid_config() {
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
		wlanconfig ath$radioidx $cmd $ssid $airtime
	fi

	if [ "$cmd" == "delssid" ]; then
		wlanconfig ath$radioidx $cmd $ssid
	fi
}

atf_sta_config() {
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
		wlanconfig ath$radioidx $cmd $mac $airtime $ssid
	fi

	if [ "$cmd" == "delsta" ]; then
		wlanconfig ath$radioidx $cmd $mac
	fi
}

atf_ac_config() {
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
		echo "wlanconfig ath$radioidx $cmd $ssid $ac:$airtime"
	fi

	if [ "$cmd" == "atfdelac" ]; then
		echo "wlanconfig ath$radioidx $cmd $ssid $ac"
	fi
}

atf_tput_config() {
	local cmd
	local tput
	local max_airtime
	local device
	local mac

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
		iwpriv ath$radioidx commitatf 0
		wlanconfig ath$radioidx addtputsta $mac $tput $max_airtime
	fi

	if [ "$cmd" == "deltputsta" ]; then
		iwpriv ath$radioidx commitatf 0
		wlanconfig ath$radioidx deltputsta $mac
	fi
}

atf_enable() {
	local device="$1"

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
			[ -n "$commitatf" ] && iwpriv "$vifname" "commitatf" "$commitatf"

			ifidx=$(($ifidx + 1))
		done
	fi
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

ftm_qcawifi() {
	error=0
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
		*hk*|*ac*|*cp*|*oa*|*mp*)
			update_ini_file nss_wifi_olcfg 7
		;;
		*)
		;;
		esac
	fi

	rm -rf /etc/config/wireless

	append qdf_args "mem_debug_disabled=1"

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
				do_cold_boot_calibration_qcawifi
				insmod_cmd ${mod} testmode=1 hw_mode_id=1 cfg80211_config=1 || { \
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
		rm -rf /etc/modules.d
		mv /etc/modules.d.bk /etc/modules.d
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

waltest_qcawifi() {
	error=0
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
				insmod_cmd ${mod} || { \
					lock -u /var/run/wifilock
					unload_qcawifi
					error=2
				}
			};;

			qca_ol) [ -d /sys/module/${mod} ] || { \
				insmod_cmd ${mod} testmode=3 hw_mode_id=1 cfg80211_config=1 || { \
					lock -u /var/run/wifilock
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
					lock -u /var/run/wifilock
					unload_qcawifi
					error=4
				}
			};;

		esac
	done

	[ $error != 0 ] && echo "WALtest error: $error" > /dev/console && return 1
	echo "WALtest mode interface is ready now" > /dev/kmsg
}

detect_qcawifi() {


	local enable_cfg80211=`uci show qcacfg80211.config.enable |grep "qcacfg80211.config.enable='1'"`
	[ -n "$enable_cfg80211" ] && echo "qcawifi configuration is disable" > /dev/console && return 1;

	if [ -e /sys/firmware/devicetree/base/MP_256 ]; then
		update_ini_for_lowmem QCA8074_i.ini
		update_ini_for_lowmem QCA8074V2_i.ini
		update_ini_for_lowmem QCA6018_i.ini
		update_ini_for_lowmem QCA5018_i.ini
		update_ini_for_lowmem QCN9000_i.ini
		update_ini_for_lowmem QCN6122_i.ini
	fi

	is_ftm=`grep wifi_ftm_mode /proc/cmdline | wc -l`
	[ $is_ftm = 1 ] && ftm_qcawifi && return

	is_wal=`grep waltest_mode /proc/cmdline | wc -l`
	[ $is_wal = 1 ] && waltest_qcawifi && return

	config_present=0
	devidx=0
	socidx=0
	olcfg_ng=0
	olcfg_ac=0
	olcfg_axg=0
	olcfg_axa=0
	nss_olcfg=0
	nss_ol_num=0
	reload=0
	avoid_load=0
	hw_mode_detect=0
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

	load_qcawifi
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
			if [ $hw_mode_detect == 1 ]; then
				update_internal_ini $ini_file hw_mode_id "$prefer_hw_mode_id"
			fi
		fi
	done

	[ -d wifi0 ] || return
	for dev in $(ls -d wifi* 2>&-); do
		found=0
		if [ -f /sys/class/net/${dev}/nssoffload ] && [ $(cat /sys/class/net/${dev}/nssoffload) == "capable" ]; then
			config_nss_wifi_radio_pri_map "$board"
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
			*11bgn) mode_11=ng;;
			*11bgn/ax) mode_11=axg;;
			*11abgn) mode_11=ng;;
			*11an) mode_11=na;;
			*11an/ac) mode_11=ac;;
			*11an/ac/ax) mode_11=axa;;
			*11abgn/ac) mode_11=ac;;
			*11abgn/ac/ax) mode_11=axa;;
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
		cat <<EOF
config wifi-device  wifi$devidx
	option type	qcawifi
	option channel	auto
	option macaddr	$(cat /sys/class/net/${dev}/address)
	option hwmode	11${mode_11}
	# REMOVE THIS LINE TO ENABLE WIFI:
	option disabled 1

config wifi-iface
	option device	wifi$devidx
	option network	lan
	option mode	ap
	option ssid	OpenWrt
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
				echo_cmd "$(($olcfg_axa + $olcfg_axg))" > /lib/wifi/wifi_nss_hk_olnum
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
		elif [ $num_chains -le 4 -o -e /sys/firmware/devicetree/base/MP_512 ]; then
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
	sync

	if [ $reload == 1 ] ; then
		if [ $avoid_load == 1 ]; then
			wifi_updown "disable" "$2" > /dev/null
			ubus call network reload
			wifi_updown "enable" "$2" > /dev/null
		else
			unload_qcawifi > /dev/null
			load_qcawifi > /dev/null
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

son_get_config()
{
	config_load wireless
	local device="$1"
	config_get disabled $device disabled 0
	if [ $disabled -eq 0 ]; then
	config_get vifs $device vifs
	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
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
# if tx vdev is not configured in scripts then this reset sequence is skipped
#
mbss_tx_vdev_config() {
	local device="$1"
	local recover="$2"

	config_get disabled $device disabled 0
	if [ $disabled -eq 0 ]; then
		config_get channel "$device" channel

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
			ifconfig "$vifname" down
			ifidx=$(($ifidx + 1))
		done

		local ifidx=0
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"

			config_get mbss_tx_vdev "$vif" mbss_tx_vdev
			[ -n "$mbss_tx_vdev" ] && iwpriv "$vifname" mbss_tx_vdev "$mbss_tx_vdev"
			ifidx=$(($ifidx + 1))
		done

		local ifidx=0
		for vif in $vifs; do
			local vifname
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"
			ifconfig "$vifname" up
			ifidx=$(($ifidx + 1))
		done
	fi
}
