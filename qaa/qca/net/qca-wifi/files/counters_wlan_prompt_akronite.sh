#! /bin/sh
#
# Copyright (c) 2018 Qualcomm Technologies, Inc.
# All rights reserved.
#
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

echo "=============> Syntax counters_wlan.sh <WIFI IF NAME> <ATH IF NAME> ============ "
echo "----------- Make sure you have passed right arguments -----------"
sleep 4

echo "Start collecting data"
echo "Clear kernel log"
        dmesg -c > /tmp/droplog
        rm /tmp/droplog

echo "======================================"
echo "switch port 0"
echo "======================================"
	swconfig dev switch0 port 0 get mib
	sleep 1
echo "======================================"
echo "switch port 1"
echo "======================================"
	swconfig dev switch0 port 1 get mib
	sleep 1
echo "======================================"
echo "switch port 2"
echo "======================================"
	swconfig dev switch0 port 2 get mib
	sleep 1
echo "======================================"
echo "switch port 3"
echo "======================================"
	swconfig dev switch0 port 3 get mib
	sleep 1
echo "======================================"
echo "switch port 4"
echo "======================================"
	swconfig dev switch0 port 4 get mib
	sleep 1
echo "======================================"
echo "switch port 5"
echo "======================================"
	swconfig dev switch0 port 5 get mib
	sleep 1
echo "======================================"
echo "switch port 6"
echo "======================================"
	swconfig dev switch0 port 6 get mib
	sleep 2

echo "======================================"
echo "NSS"
echo "======================================"
        cat /sys/kernel/debug/qca-nss-drv/stats/*
echo "======================================"

echo "Scaling command"
echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo "performance" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
echo 0 > /proc/sys/dev/nss/clock/auto_scale
echo 800000000 > /proc/sys/dev/nss/clock/current_freq

cat /sys/class/net/ath0/queues/rx-0/rps_cpus
cat /sys/class/net/ath1/queues/rx-0/rps_cpus
cat /sys/class/net/ath2/queues/rx-0/rps_cpus

echo 1 > /proc/sys/net/gmac/per_prec_stats_enable
echo "48 1 1" > /proc/sys/dev/nss/ipv4cfg/ipv4_dscp_map
echo "40 1 1" > /proc/sys/dev/nss/ipv4cfg/ipv4_dscp_map



ifconfig eth0
ifconfig eth1
ifconfig eth2

echo "GMAC0"
echo "======================================"
        ethtool -S eth0
        sleep 1
echo "======================================"
echo "GMAC1"
echo "======================================"
        ethtool -S eth1
        sleep 2
echo "======================================"
echo "GMAC2"
echo "======================================"
        ethtool -S eth2
        sleep 2
echo "======================================"
echo "Wifi Host Q stats"
echo "=================================="
        iwpriv $1 fc_stats_global 1
        sleep 3
echo "===== WIFI Video Stats ============"
	iwpriv $1 fc_video_stats
        sleep 2
        iwpriv $1 fc_tidq_map 1
        sleep 2
        iwpriv $2 txrx_fw_stats 8
        sleep 1
	ifconfig $2
echo "========= FW Stats ================= "
        wifitool $2 beeliner_fw_test 191 0
        wifitool $2 beeliner_fw_test 191 1
        wifitool $2 beeliner_fw_test 191 2
        wifitool $2 beeliner_fw_test 191 3
        wifitool $2 beeliner_fw_test 195 1
        wifitool $2 beeliner_fw_test 195 2
        wifitool $2 beeliner_fw_test 195 3
        wifitool $2 beeliner_fw_test 195 4
        wifitool $2 beeliner_fw_test 195 5
echo "=================================="
        sleep 1
        iwpriv $2 txrx_fw_stats 19
        iwpriv $2 txrx_fw_stats 20
        sleep 1
        iwpriv $2 txrx_fw_stats 21
        iwpriv $2 txrx_fw_stats 22
        iwpriv $2 txrx_fw_stats 23
        sleep 1
	iwpriv $2 txrx_fw_stats 1
        iwpriv $2 txrx_fw_stats 2
        sleep 1
        iwpriv $2 txrx_fw_stats 3
        iwpriv $2 txrx_fw_stats 6
        iwpriv $2 txrx_fw_stats 12
        sleep 1
echo "======================================"
echo "Kernel log"
echo "======================================"
echo "Stop collecting data"

        exit 0
