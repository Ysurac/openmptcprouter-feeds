#! /bin/sh
#
# Copyright (c) 2019-2020 Qualcomm Technologies, Inc.
# All rights reserved.
#
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

echo "=============> Syntax counters_wlan.sh <WIFI IF NAME> <ATH IF NAME> ============ "
[ -n "$1" -a -d "/sys/class/net/$1" ] || {
	echo "phy for wifi device $1 not found"
	return
}

[ -n "$2" -a -d "/sys/class/net/$2" ] || {
	echo "vap interface $2 not found"
	return
}

echo "Start collecting data"
echo "Clear kernel log"
        dmesg -c > /tmp/droplog
        rm /tmp/droplog

[ -f /tmp/sysinfo/board_name ] && {
        board_name=ap$(cat /tmp/sysinfo/board_name | awk -F 'ap' '{print$2}')
}

case "$board_name" in
ap-hk01* | ap-oak* | ap-hk07* | ap-ac01* | ap-ac02*)
		gmacs=6
                ;;

ap-ac03* | ap-ac04*)
		gmacs=5
                ;;

ap-hk02*| ap-hk08* | ap-hk09*)
		gmacs=3
                ;;

*)
		gmacs=6
		;;
esac

n=0
while [ $n -lt $gmacs ]
do
echo "======================================"
echo "eth$n stats"
echo "======================================"
	ifconfig eth$n
	ethtool -S eth$n
        sleep 1
        n=$(( n+1 ))
done

echo "======================================"
echo "NSS"
echo "======================================"
        cat /sys/kernel/debug/qca-nss-drv/stats/*
echo "======================================"

echo "Scaling command"
echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo "performance" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
echo "performance" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
echo "performance" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor

echo "======================================"
echo "NSS Disable auto scaling"
echo "======================================"
echo 0 > /proc/sys/dev/nss/clock/auto_scale

echo "======================================"
echo "NSS Clock Configuration"
echo "======================================"
case "$board_name" in
	ap-hk*)
		echo 1689600000 > /proc/sys/dev/nss/clock/current_freq
		;;

	ap-cp*)
		echo 1497600000 > /proc/sys/dev/nss/clock/current_freq
		;;

	ap-ac*)
		echo 1497600000 > /proc/sys/dev/nss/clock/current_freq
		;;

	ap-oak*)
		echo 1497600000 > /proc/sys/dev/nss/clock/current_freq
		;;

	ap-mp*)
		echo 1000000000 > /proc/sys/dev/nss/clock/current_freq
		;;
esac

echo "======================================"
echo "Wifi Host Q stats"
echo "=================================="
        iwpriv $1 enable_ol_stats 1
        iwpriv $1 enable_statsv3 1
        iwpriv $1 fc_delay_stats 1
        sleep 2
echo "===== WIFI Video Stats ============"
        iwpriv $1 fc_video_stats
        sleep 2
	iwpriv $2 txrx_stats 260
	iwpriv $2 txrx_stats 261
	iwpriv $2 txrx_stats 262
	sleep 1
	ifconfig $2
echo "========= FW Stats ================= "
n=1
while [ $n -le 10 ]
do
        wifistats $1 $n
        sleep 1
        n=$(( n+1 ))
done

echo "=================================="
echo "======================================"
echo "Kernel log"
echo "======================================"
echo "Stop collecting data"
        exit 0
