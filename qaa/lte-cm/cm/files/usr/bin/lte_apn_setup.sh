#! /bin/sh

#
# Copyright (c) 2016 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

. /lib/functions.sh

find_active_profile() {
	local profile_id=$1

	config_get_bool enabled "$profile_id" enabled '0'
	echo "$profile_id enabled = $enabled"
	[ $enabled -eq 1 ] && {
		config_get profile_name "$profile_id" name ""

		[ "$profile_name" = "default" ] && {
			echo "Default profile enabled" > /dev/console
			break
		}
		config_get profile_conn_type "$profile_id" connectiontype ""
		config_get profile_ip_family "$profile_id" ipfamily ""
		config_get profile_pdp "$profile_id" pdptype ""
		config_get profile_ipaddress "$profile_id" ipaddress ""
		config_get profile_primarydns "$profile_id" primarydns ""
		config_get profile_secondarydns "$profile_id" secondarydns ""
		config_get profile_auth "$profile_id" authvalue ""
		config_get profile_apn "$profile_id" apn ""
		config_get profile_user "$profile_id" username ""
		config_get profile_pass "$profile_id" password ""

		[ -z "$profile_conn_type" ] ||[ -z "$profile_ip_family" ] ||
		[ -z "$profile_pdp" ] || [ -z "$profile_ipaddress" ] ||
		[ -z "$profile_primarydns" ] || [ -z "$profile_secondarydns" ] ||
		[ -z "$profile_auth" ] && {
			echo "Invalid profile values"  > /dev/console
			return 1
		}
		echo "Writing $profile_name values to profiles.txt"
		echo "$profile_conn_type $profile_ip_family $profile_pdp $profile_ipaddress" \
			"$profile_primarydns $profile_secondarydns $profile_auth $profile_name" \
			"$profile_apn $profile_user $profile_pass" > /usr/lib/lte-cm/profiles.txt
	}
}

config_load sierra-cm && {
	local value
	config_get_bool disabled config 'disabled' '1'
	echo $disabled

	[ $disabled -eq 0 ] || {
		return 1
	}

	[ -e "/usr/lib/lte-cm/profiles.txt" ] && {
		rm /usr/lib/lte-cm/profiles.txt
	}
	config_foreach find_active_profile profile
	return 0
}
