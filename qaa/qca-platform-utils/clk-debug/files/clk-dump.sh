: '
/*
 * Copyright (c) 2017, 2019 Qualcomm Technologies, Inc.
 *
 * All Rights Reserved.
 * Confidential and Proprietary - Qualcomm Technologies, Inc.
 */
'

device=$( cat /tmp/sysinfo/model )
if echo "$device" | grep -q "IPQ807";
then
        /usr/sbin/clk-debug-ipq807x.sh "$@"
elif echo "$device" | grep -q "IPQ60";
then
	/usr/sbin/clk-debug-ipq6018.sh "$@"
elif echo "$device" | grep -q "IPQ50";
then
	/usr/sbin/clk-debug-ipq5018.sh "$@"
else
	echo "Unrecognized Device...\nDevices Supported: ipq807x, ipq6018, ipq5018"
fi
