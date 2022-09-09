#!/bin/sh /etc/rc.common
# Copyright (c) 2020 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.

START=55
USE_PROCD=1
RESPAWN_THRESHOLD=120
RESPAWN_TIMEOUT=5
RESPAWN_RETRIES=1

. /lib/functions/procd.sh

init()
{
    /sbin/wifi detect > /etc/config/wireless
    return 0
}

config()
{
    /sbin/uci set wireless.wifi0=wifi-device
    /sbin/uci set wireless.wifi0.type='qcawificfg80211'
    /sbin/uci set wireless.wifi0.channel='auto'
    /sbin/uci set wireless.wifi0.macaddr='00:03:7f:75:53:17'
    /sbin uci set wireless.wifi0.hwmode='11axa'
    /sbin/uci set wireless.wifi0.htmode='HT80'
    /sbin/uci set wireless.wifi0.disabled='0'
    /sbin/uci set network.lan.ipaddr='192.168.1.1'
    /sbin/uci set wireless.@wifi-iface[0]=wifi-iface
    /sbin/uci set wireless.@wifi-iface[0].device='wifi0'
    /sbin/uci set wireless.@wifi-iface[0].network='lan'
    /sbin/uci set wireless.@wifi-iface[0].mode='ap'
    /sbin/uci set wireless.@wifi-iface[0].ssid='son_cli_5g'
    /sbin/uci set wireless.@wifi-iface[0].encryption='none'
    /sbin/uci set wireless.@wifi-iface[0].wds='1'
    /sbin/uci set wireless.wifi1=wifi-device
    /sbin/uci set wireless.wifi1.type='qcawificfg80211'
    /sbin/uci set wireless.wifi1.channel='auto'
    /sbin/uci set wireless.wifi1.macaddr='00:03:7f:75:63:17'
    /sbin/uci set wireless.wifi1.hwmode='11axg'
    /sbin/uci set wireless.wifi1.htmode='HT20'
    /sbin/uci set wireless.wifi1.disabled='0'
    /sbin/uci set network.lan.ipaddr='192.168.1.1'
    /sbin/uci set wireless.@wifi-iface[1]=wifi-iface
    /sbin/uci set wireless.@wifi-iface[1].device='wifi1'
    /sbin/uci set wireless.@wifi-iface[1].network='lan'
    /sbin/uci set wireless.@wifi-iface[1].mode='ap'
    /sbin/uci set wireless.@wifi-iface[1].ssid='son_cli_2g'
    /sbin/uci set wireless.@wifi-iface[1].encryption='none'
    /sbin/uci set wireless.@wifi-iface[1].wds='1'
    /sbin/uci commit wireless
    /sbin/uci commit network
    return 0 
}

config3r()
{
    /sbin/uci set wireless.wifi0=wifi-device
    /sbin/uci set wireless.wifi0.type='qcawificfg80211'
    /sbin/uci set wireless.wifi0.channel='auto'
    /sbin/uci set wireless.wifi0.macaddr='00:03:7f:12:21:f3'
    /sbin uci set wireless.wifi0.hwmode='11axa'
    /sbin/uci set wireless.wifi0.htmode='HT80'
    /sbin/uci set wireless.wifi0.band='3'
    /sbin/uci set wireless.wifi0.country='US4'
    /sbin/uci set wireless.wifi0.disabled='0'
    /sbin/uci set wireless.@wifi-iface[0]=wifi-iface
    /sbin/uci set wireless.@wifi-iface[0].device='wifi0'
    /sbin/uci set wireless.@wifi-iface[0].network='lan'
    /sbin/uci set wireless.@wifi-iface[0].mode='ap'
    /sbin/uci set wireless.@wifi-iface[0].ssid='son_cli_6g'
    /sbin/uci set wireless.@wifi-iface[0].encryption='none'
    /sbin/uci set wireless.@wifi-iface[0].wds='1'
    /sbin/uci set wireless.wifi1=wifi-device
    /sbin/uci set wireless.wifi1.type='qcawificfg80211'
    /sbin/uci set wireless.wifi1.channel='auto'
    /sbin/uci set wireless.wifi1.macaddr='00:03:7f:12:55:c7'
    /sbin/uci set wireless.wifi1.hwmode='11axg'
    /sbin/uci set wireless.wifi1.htmode='HT20'
    /sbin/uci set wireless.wifi1.disabled='0'
    /sbin/uci set wireless.@wifi-iface[1]=wifi-iface
    /sbin/uci set wireless.@wifi-iface[1].device='wifi1'
    /sbin/uci set wireless.@wifi-iface[1].network='lan'
    /sbin/uci set wireless.@wifi-iface[1].mode='ap'
    /sbin/uci set wireless.@wifi-iface[1].ssid='son_cli_2g'
    /sbin/uci set wireless.@wifi-iface[1].encryption='none'
    /sbin/uci set wireless.@wifi-iface[1].wds='1'
    /sbin/uci set wireless.wifi2=wifi-device
    /sbin/uci set wireless.wifi2.type='qcawificfg80211'
    /sbin/uci set wireless.wifi2.channel='auto'
    /sbin/uci set wireless.wifi2.macaddr='00:03:7f:12:e9:fb'
    /sbin/uci set wireless.wifi2.hwmode='11axa'
    /sbin/uci set wireless.wifi2.htmode='HT80'
    /sbin/uci set wireless.wifi2.disabled='0'
    /sbin/uci set wireless.@wifi-iface[2]=wifi-iface
    /sbin/uci set wireless.@wifi-iface[2].device='wifi2'
    /sbin/uci set wireless.@wifi-iface[2].network='lan'
    /sbin/uci set wireless.@wifi-iface[2].mode='ap'
    /sbin/uci set wireless.@wifi-iface[2].ssid='son_cli_5g'
    /sbin/uci set wireless.@wifi-iface[2].encryption='none'
    /sbin/uci set wireless.@wifi-iface[2].wds='1'
    /sbin/uci commit wireless
    return 0
}

wifi()
{
    /sbin/wifi
    return 0
}

ping_test()
{
    ping -w 1 192.168.1.2 -c1 > /dev/null 
    eval "$1='$?'"
}

iperf_test()
{
    procd_open_instance
    procd_set_param command /usr/bin/iperf -u -c 192.168.1.2 -i 1 -t $1 -P 5 -b 400M
    procd_close_instance
    return 0
}

txpow_test()
{
#    echo "1 = $1 2 = $2"
    iwconfig $1 txpow $2
}

start_service()
{
    local ping_ret=0
if [ "$1" == "init" ]
then
    init
    return 0
fi

if [ "$1" == "config" ]
then
    config
    return 0
fi

if [ "$1" == "wifi" ]
then
    wifi
    return 0
fi

if [ "$1" == "ping_test" ]
then
    ping_test ping_ret
    if [ "$ping_ret" == "0" ]; then
        return 0
    fi 
fi

if [ "$1" == "txpow_test" ]
then
    txpow_test $2 $3
    return 0
fi

if [ "$1" == "iperf_test" ]
then
    iperf_test $2
    return 0
fi
    exit 1
}
