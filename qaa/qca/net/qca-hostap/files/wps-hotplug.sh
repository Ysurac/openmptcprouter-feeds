#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
# Copyright (c) 2014, The Linux Foundation. All rights reserved.
#

send_to_son()
{
    local staname1
    local staname2
    local ret
    local pattern
    local count
    [ -r /var/run/son.conf ] || return 0
    staname1=$(grep sta /var/run/son.conf | head -n 1 | cut -f3 -d" " )
    staname2=$(grep sta /var/run/son.conf | tail -n 1 | cut -f3 -d" " )
    echo "$staname1 $staname2"
    count=0
    pattern="Not-Associated"
    for sta in $staname1 $staname2;do
    result=$(iwconfig $sta | head -2 | tail -1 | grep -o "Not-Associated")
    if [ $result == $pattern ];then
       count=$((count+1))
    fi
    done
    if [ $count -lt 2 ];then
    echo "Sending to son"
    echo "wps_pbc $SEEN" > /var/run/sonwps.pipe &
    touch /var/run/son_active
    ret=1
    else
    ret=0
    echo "Son not processing push - sta not connected"
    fi
    return $ret
}

if [ "$ACTION" = "pressed" -a "$BUTTON" = "wps" ]; then
	echo "" > /dev/console
	echo "WPS PUSH BUTTON EVENT DETECTED" > /dev/console
    # cleanup old file
    rm -f /var/run/son_active
    #check for son.conf - if not there exit
    # ret is 1 if push is consumed by son , if ret == 0 continue to next scripts
    send_to_son
    ret=$?
    [ $ret -eq 1 ] && exit 0
    # Son did not process the push  call wps-extender if confgured
    # If multi node wps is enabled then wps-extender will not process the push.
	if [ -r /var/run/wifi-wps-enhc-extn.conf ] &&
		[ ! -r /var/run/son.conf ]; then
		exit 0
    fi
    # son and wps_extender are not processing the push
	for dir in /var/run/hostapd-*; do
                [ -d "$dir" ] || continue
                for vap_dir in $dir/ath* $dir/wlan*; do
                        [ -r "$vap_dir" ] || continue
                        nopbn=`cfg80211tool "${vap_dir#"$dir/"}"   get_nopbn  |   cut -d':' -f2`
                        if [ $nopbn != 1 ]; then
                                hostapd_cli -i "${vap_dir#"$dir/"}" -p "$dir" wps_pbc
                        fi
                done
        done
fi
