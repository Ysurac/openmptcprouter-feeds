#! /bin/sh

#
# Copyright (c) 2016 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

. /lib/functions.sh

add_delete_per_vap() {
	local vap_id=$1
	local wifi_device_name=$2
	local channels=$3
	local vap_name="${wifi_device_name/wifi/ath}"

	config_get device_name $vap_id device && {
		[ "$device_name" == "$wifi_device_name" ] && {
			[ -z "$channels" ] && {
				config_get is_available $vap_id channel_block_list && {
					[ -n "$is_available" ] && {
						echo "Deleting entry channel_block_list from $vap_name" > /dev/console
						uci delete wireless.$vap_id.channel_block_list
						uci commit wireless
						wifitool $vap_name block_acs_channel 0
					}
				}
			}
			[ -n "$channels" ] && {
				echo "Adding $channels to channel_block_list entry on $vap_name" > /dev/console
				uci set wireless.$vap_id.channel_block_list=$channels
				uci commit wireless
				echo "Blocking channels $channels on $vap_name" > /dev/console
				wifitool $vap_name block_acs_channel 0
				wifitool $vap_name block_acs_channel $channels
				iwconfig $vap_name channel 0
			}
			break
		}
	}
}

channel_addition_deletion() {
	local wifi_device_name=$1
	local channels=$2

	config_get wifi_hwmode "$wifi_device_name" hwmode

	case "$wifi_hwmode" in
		11n* | 11b* | 11c*)	echo "$wifi_device_name operating in co-existence range" > /dev/console
					config_foreach add_delete_per_vap wifi-iface $wifi_device_name $channels;;

				 *)	echo "$wifi_device_name not operating in co-existence range" > /dev/console;;
	esac
}

configure_channel_list() {
	local channels=$1
	config_load wireless && {
		config_foreach channel_addition_deletion wifi-device
		[ -n "$channels" ] && {
			config_foreach channel_addition_deletion wifi-device $channels
		}
		return 0
	}
}

configure_channel_list $1
