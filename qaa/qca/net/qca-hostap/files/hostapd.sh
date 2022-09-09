#
# Copyright (c) 2017-2018,2020 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
# Copyright (c) 2015, The Linux Foundation. All rights reserved.
#

wps_possible=
config_methods=
wps_dual_band=

hostapd_set_extra_cred() {
	local var="$1"
	local vif="$2"
	local ifname="$3"
	local temp
	local enc enc_list

	config_get ssid "$vif" ssid
	config_get enc "$vif" encryption "none"

	#wps_build_cred_network_idx
	append "$var" "1026"
	append "$var" "0001"
	append "$var" "01"

	temp=`expr length "$ssid"`
	temp=` printf "%04X" $temp`

	#wps_build_cred_ssid
	append "$var" "1045"
	append "$var"   "$temp"
	temp=`echo -n "$ssid" | hexdump -v -e '/1 "%02X "'`
	append "$var" "$temp"

	#wps_build_cred_auth_type
	append "$var" "1003"
	append "$var" "0002"

	case "$enc" in
		none)
			append "$var" "0001"
			;;
		# Need ccmp*|gcmp* check for SAE and OWE auth type
		wpa2*|*psk2*|ccmp*|gcmp*|sae*|dpp)
			append "$var" "0020"
			;;
		*)
			# TKIP alone is now prohibited by WFA so the only
			# combination left must be CCMP+TKIP (wpa=3)
			append "$var" "0022"
			;;
	esac

	#wps_build_cred_encr_type
	append "$var" "100f"
	append "$var" "0002"
	crypto=

	enc_list=`echo "$enc" | sed "s/+/ /g"`

	case "$enc_list" in
		*tkip*)
			append "$var" "0004"
			;;
		*aes* | *ccmp*)
			append "$var" "0008"
			;;
		*mixed*)
			append "$var" "000c"
			;;
	esac


	#Key Index
	append "$var" "1028"
	append "$var" "0001"
	append "$var" "01"

	#wps_build_cred_network_key
	config_get psk "$vif" key
	append "$var" "1027"

	temp=`expr length "$psk"`
	temp=` printf "%04X" $temp`

	append "$var" "$temp"
	temp=`echo -n  $psk | hexdump -v -e '/1 "%02X "'`
	append "$var" "$temp"

	#wps_build_mac_addr
	macaddr=$(cat /sys/class/net/${ifname}/address)
        macaddr="00:00:00:00:00:00"
	append "$var" "1020"
	append "$var" "0006"
	append "$var" "$macaddr"
}
hostapd_common_add_device_config() {
	config_add_array basic_rate

	config_add_string country
	config_add_boolean country_ie doth
	config_add_int beacon_int
}


hostapd_prepare_device_config() {
        local config="$1"
        local driver="$2"

        local base="${config%%.conf}"
        local base_cfg=

        json_get_vars country country_ie beacon_int doth

        hostapd_set_log_options base_cfg

        set_default country_ie 1
        set_default doth 1

        [ -n "$country" ] && {
                append base_cfg "country_code=$country" "$N"

                [ "$country_ie" -gt 0 ] && append base_cfg "ieee80211d=1" "$N"
                [ "$hwmode" = "a" -a "$doth" -gt 0 ] && append base_cfg "ieee80211h=1" "$N"
        }
        [ -n "$hwmode" ] && append base_cfg "hw_mode=$hwmode" "$N"

        local brlist= br
        json_get_values basic_rate_list basic_rate
        for br in $basic_rate_list; do
                hostapd_add_basic_rate brlist "$br"
        done
        [ -n "$brlist" ] && append base_cfg "basic_rates=$brlist" "$N"
        [ -n "$beacon_int" ] && append base_cfg "beacon_int=$beacon_int" "$N"

        cat > "$config" <<EOF
driver=$driver
$base_cfg
EOF
}

hostapd_eap_config_parameters() {
	local var="$1"
	local vif="$2"
	config_get auth_server "$vif" auth_server
	[ -z "$auth_server" ] && config_get auth_server "$vif" server
	append "$var" "auth_server_addr=$auth_server" "$N"
	config_get auth_port "$vif" auth_port
	[ -z "$auth_port" ] && config_get auth_port "$vif" port
	auth_port=${auth_port:-1812}
	append "$var" "auth_server_port=$auth_port" "$N"
	config_get auth_secret "$vif" auth_secret
	[ -z "$auth_secret" ] && config_get auth_secret "$vif" key
	append "$var" "auth_server_shared_secret=$auth_secret" "$N"
	config_get acct_server "$vif" acct_server
	[ -n "$acct_server" ] && append "$var" "acct_server_addr=$acct_server" "$N"
	config_get acct_port "$vif" acct_port
	[ -n "$acct_port" ] && acct_port=${acct_port:-1813}
	[ -n "$acct_port" ] && append "$var" "acct_server_port=$acct_port" "$N"
	config_get acct_secret "$vif" acct_secret
	[ -n "$acct_secret" ] && append "$var" "acct_server_shared_secret=$acct_secret" "$N"
	config_get eap_reauth_period "$vif" eap_reauth_period
	[ -n "$eap_reauth_period" ] && append "$var" "eap_reauth_period=$eap_reauth_period" "$N"
	config_get wep_key_len_broadcast "$vif" wep_key_len_broadcast
	config_get wep_key_len_unicast "$vif" wep_key_len_unicast
	append "$var" "eapol_key_index_workaround=1" "$N"
	append "$var" "ieee8021x=1" "$N"
	config_get identity_request_retry_interval "$vif" identity_request_retry_interval
	[ -n "$identity_request_retry_interval" ] && append "$var" "identity_request_retry_interval=$identity_request_retry_interval" "$N"
	config_get radius_server_retries "$vif" radius_server_retries
	[ -n "$radius_server_retries" ] && append "$var" "radius_server_retries=$radius_server_retries" "$N"
	config_get radius_das_port "$vif" radius_das_port
	[ -n "$radius_das_port" ] && append "$var" "radius_das_port=$radius_das_port" "$N"
	config_get radius_das_client "$vif" radius_das_client
	[ -n "$radius_das_client" ] && append "$var" "radius_das_client=$radius_das_client" "$N"
	config_get radius_das_require_event_timestamp "$vif" radius_das_require_event_timestamp
	[ -n "$radius_das_require_event_timestamp" ] && append "$var" "radius_das_require_event_timestamp=$radius_das_require_event_timestamp" "$N"

	config_get radius_max_retry_wait "$vif" radius_max_retry_wait
	[ -n "$radius_max_retry_wait" ] && append "$var" "radius_max_retry_wait=$radius_max_retry_wait" "$N"
	[ -n "$wpa_group_rekey"  ] && append "$var" "wpa_group_rekey=$wpa_group_rekey" "$N"
	[ -n "$wpa_strict_rekey"  ] && append "$var" "wpa_strict_rekey=$wpa_strict_rekey" "$N"
	[ -n "$wpa_pair_rekey"   ] && append "$var" "wpa_ptk_rekey=$wpa_pair_rekey"    "$N"
	[ -n "$wpa_master_rekey" ] && append "$var" "wpa_gmk_rekey=$wpa_master_rekey"  "$N"
	[ -n "$wep_key_len_broadcast" ] && append "$var" "wep_key_len_broadcast=$wep_key_len_broadcast" "$N"
	[ -n "$wep_key_len_unicast" ] && append "$var" "wep_key_len_unicast=$wep_key_len_unicast" "$N"
	[ -n "$wep_rekey" ] && append "$var" "wep_rekey_period=$wep_rekey" "$N"

	config_get wpa_group_update_count "$vif" wpa_group_update_count
	[ -n "$wpa_group_update_count" ] && append "$var" "wpa_group_update_count=$wpa_group_update_count" "$N"

	config_get wpa_pairwise_update_count "$vif" wpa_pairwise_update_count
	[ -n "$wpa_pairwise_update_count" ] && append "$var" "wpa_pairwise_update_count=$wpa_pairwise_update_count" "$N"

	config_get wpa_disable_eapol_key_retries "$vif" wpa_disable_eapol_key_retries
	[ -n "$wpa_disable_eapol_key_retries" ] && append "$var" "wpa_disable_eapol_key_retries=$wpa_disable_eapol_key_retries" "$N"
}

setup_wps_rf_band_info() {
	local device=$1
	config_get_bool disabled "$device" disabled 0
	config_get hwmode "$device" hwmode 0
	case "$hwmode" in
		*g*|*b|*bg) [ "$disabled" -eq 0 ] && append wps_dual_band g;;
		*a|*na|*axa|*ac) [ "$disabled" -eq 0 ] && append wps_dual_band a;;
		*) [ "$disabled" -eq 0 ] && append wps_dual_band a;;
	esac
	wps_dual_band=$(echo "$wps_dual_band" | sed 's/ //g')
	wps_dual_band=$(echo "$wps_dual_band" | sed 's/\([A-Za-z]\)\1\+/\1/g')
	if [ ${#wps_dual_band} -gt 2 ]; then
		wps_dual_band=$(echo ${wps_dual_band:0:2})
	fi
}

update_wps_rf_bands() {
	config_foreach setup_wps_rf_band_info wifi-device
}

hostapd_set_bss_options() {
	local var="$1"
	local vif="$2"
	local hidden beacon_prot
	local auth_algs
	local enc wep_rekey wpa_group_rekey wpa_strict_rekey wpa_pair_rekey wpa_master_rekey pid sae owe suite_b dpp
	local add_sha256_str ieee80211r_str enc_list ieee80211ai_sha256_str ieee80211ai_sha384_str sae_str owe_str suite_b_str dpp_str
	local owe_transition_bssid owe_transition_ssid owe_transition_ifname owe_groups owe_ptk_workaround dpp_connector dpp_csign dpp_netaccesskey dpp_1905_connector
	local sae_reflection_attack sae_commit_override sae_password sae_anti_clogging_threshold sae_groups sae_sync sae_require_mfp sae_confirm_immediate
	local wpa_enterprise

	[ -z "$vif" ] && hostapd_get_vif_name

	config_load wireless

	config_get enc "$vif" encryption "none"
	config_get wep_rekey        "$vif" wep_rekey        # 300
	config_get wpa_group_rekey  "$vif" wpa_group_rekey  # 300
	config_get wpa_strict_rekey  "$vif" wpa_strict_rekey  # 300
	config_get wpa_pair_rekey   "$vif" wpa_pair_rekey   # 300
	config_get wpa_master_rekey "$vif" wpa_master_rekey # 640
	config_get_bool ap_isolate "$vif" isolate 0
	config_get_bool ieee80211r "$vif" ieee80211r 0
	config_get_bool ieee80211ai "$vif" ieee80211ai 0
	config_get_bool hidden "$vif" hidden 0
	config_get kh_key_hex "$vif" kh_key_hex "000102030405060708090a0b0c0d0e0f"
	config_get_bool sae "$vif" sae 0
	config_get_bool owe "$vif" owe 0
	config_get suite_b "$vif" suite_b 0
	config_get_bool dpp "$vif" dpp 0

	config_get  sae_reflection_attack  "$vif" sae_reflection_attack
	config_get  sae_commit_override  "$vif" sae_commit_override
	config_get  sae_anti_clogging_threshold   "$vif" sae_anti_clogging_threshold

	config_get  owe_transition_bssid   "$vif" owe_transition_bssid
	[ -n "$owe_transition_bssid" ] && append "$var" "owe_transition_bssid=$owe_transition_bssid" "$N"
	config_get  owe_transition_ssid   "$vif" owe_transition_ssid
	[ -n "$owe_transition_ssid" ] && append "$var" "owe_transition_ssid=\"$owe_transition_ssid\"" "$N"
	config_get  owe_transition_ifname "$vif" owe_transition_ifname
	[ -n "$owe_transition_ifname" ] && append "$var" "owe_transition_ifname=$owe_transition_ifname" "$N"
	config_get_bool owe_ptk_workaround "$vif" owe_ptk_workaround 1
	[ -n "$owe_ptk_workaround" ] && append "$var" "owe_ptk_workaround=$owe_ptk_workaround" "$N"

	config_get own_ie_override "$vif" own_ie_override
	[ -n "$own_ie_override" ] && append "$var" "own_ie_override=$own_ie_override" "$N"

	config_get dpp_map "$vif" dpp_map
	[ -n "$dpp_map" ] && append "$var" "dpp_map=$dpp_map" "$N"
	config_get dpp_pfs "$vif" dpp_pfs
	[ -n "$dpp_pfs" ] && append "$var" "dpp_pfs=$dpp_pfs" "$N"

	config_get device "$vif" device
	config_get hwmode "$device" hwmode
	config_get phy "$device" phy
	config_get enable_tkip "$vif" enable_tkip 0

	[ -f /var/run/hostapd-$phy/$ifname ] && rm /var/run/hostapd-$phy/$ifname
	ctrl_interface=/var/run/hostapd-$phy

	append "$var" "ctrl_interface=$ctrl_interface" "$N"

	if [ "$ap_isolate" -gt 0 ]; then
		append "$var" "ap_isolate=$ap_isolate" "$N"
	fi
	if [ "$hidden" -gt 0 ]; then
		append "$var" "ignore_broadcast_ssid=$hidden" "$N"
	fi

	append "$var" "send_probe_response=0" "$N"

	# Examples:
	# psk-mixed/tkip 	=> WPA1+2 PSK, TKIP
	# wpa-psk2/tkip+aes	=> WPA2 PSK, CCMP+TKIP
	# wpa2/tkip+aes 	=> WPA2 RADIUS, CCMP+TKIP
	# ...

	# TODO: move this parsing function somewhere generic, so that
	# later it can be reused by drivers that don't use hostapd

	# crypto defaults: WPA2 vs WPA1

	# If suite_b is set then hard code
	# wpa as 2
	# set ieee80211w as 2
	# set group_mgmt_cipher as BIP-GMAC-256
	# set pairwise as GCMP-256

	if [ "${suite_b}" -eq 192 ]
	then
		wpa=2
		config_set "$vif" ieee80211w 2
		config_set "$vif" group_mgmt_cipher "BIP-GMAC-256"
		hostapd_eap_config_parameters "$var" "$vif"
		append "$var" "wpa_pairwise=GCMP-256" "$N"
	else
		case "$enc" in
			none)
				wpa=0
			;;
			# Need ccmp*|gcmp* check for SAE and OWE auth type
			wpa2*|*psk2*|ccmp*|gcmp*|dpp|sae*)
				wpa=2
			;;
			*)
				wpa=3
				if [ "$enable_tkip" == 1 ]
				then
					case "$enc" in
						*mixed*|*ccmp*|*gcmp*|*aes*)
							wpa=3
						;;
						*tkip*)
							wpa=1
						;;
					esac
				fi
			;;
		esac

		crypto=
		enc_list=`echo "$enc" | sed "s/+/ /g"`

		for enc_var in $enc_list; do
			case "$enc_var" in
				*tkip)
					crypto="TKIP $crypto"
				;;
				#This case is added only to act as a testbed AP for 11ax WFA PF
				*tkip-pure)
					crypto="PURETKIP $crypto"
				;;
				*aes)
					crypto="CCMP $crypto"
				;;
				*ccmp)
					crypto="CCMP $crypto"
				;;
				*ccmp-256)
					crypto="CCMP-256 $crypto"
				;;
				*gcmp)
					crypto="GCMP $crypto"
				;;
				*gcmp-256)
					crypto="GCMP-256 $crypto"
			esac
		done

		case "$enc_list" in
			psk | wpa)
				crypto="TKIP"
			;;
			dpp|sae*|psk2|wpa2)
				if [ -f /sys/class/net/$device/ciphercaps ]
				then
					cat /sys/class/net/$device/ciphercaps | grep -i "gcmp"
					if [ $? -eq 0 ]
					then
						crypto="CCMP CCMP-256 GCMP GCMP-256"
					else
						crypto="CCMP"
					fi
				fi
			;;
			*mixed*)
				[ -z "$crypto" ] && crypto="CCMP TKIP"
			;;
		esac

		if [ "$enable_tkip" == 0 ]; then
			# WPA TKIP alone is no longer allowed for certification
			case "$hwmode:$crypto" in
				*:TKIP*) crypto="CCMP TKIP";;
			esac
		fi

		# This case is added only to act as a testbed AP for 11ax WFA PF
		# 11ax WFA PF requires WPA TKIP alone for testbed AP
		case "$hwmode:$crypto" in
			*:PURETKIP*) crypto="TKIP";;
		esac

		# use crypto/auth settings for building the hostapd config
		case "$enc" in
			none)
				wps_possible=1
				# Here we make the assumption that if we're in open mode
				# with WPS enabled, we got to be in unconfigured state.
				wps_configured_state=1
			;;
			# Need ccmp*|gcmp* check for SAE and OWE auth type
			*psk*|ccmp*|gcmp*|sae*)
				config_get psk "$vif" key
				config_get wpa_psk_file "$vif" wpa_psk_file
				if [ ${#psk} -eq 64 ]; then
					append "$var" "wpa_psk=$psk" "$N"
				else
					[ -n "$psk" ] && append "$var" "wpa_passphrase=$psk" "$N"
					[ -n "$wpa_psk_file" ] && append "$var" "wpa_psk_file=$wpa_psk_file"  "$N"
				fi
				wps_possible=1
				# By default we assume we are in configured state,
				# while the user has the provision to override this.
				wps_configured_state=2
				[ -n "$wpa_group_rekey"  ] && append "$var" "wpa_group_rekey=$wpa_group_rekey" "$N"
				[ -n "$wpa_strict_rekey"  ] && append "$var" "wpa_strict_rekey=$wpa_strict_rekey" "$N"
				[ -n "$wpa_pair_rekey"   ] && append "$var" "wpa_ptk_rekey=$wpa_pair_rekey"    "$N"
				[ -n "$wpa_master_rekey" ] && append "$var" "wpa_gmk_rekey=$wpa_master_rekey"  "$N"

				config_get wpa_group_update_count "$vif" wpa_group_update_count
				[ -n "$wpa_group_update_count" ] && append "$var" "wpa_group_update_count=$wpa_group_update_count" "$N"

				config_get wpa_pairwise_update_count "$vif" wpa_pairwise_update_count
				[ -n "$wpa_pairwise_update_count" ] && append "$var" "wpa_pairwise_update_count=$wpa_pairwise_update_count" "$N"

				config_get wpa_disable_eapol_key_retries "$vif" wpa_disable_eapol_key_retries
				[ -n "$wpa_disable_eapol_key_retries" ] && append "$var" "wpa_disable_eapol_key_retries=$wpa_disable_eapol_key_retries" "$N"
			;;
			*wpa*)
				hostapd_eap_config_parameters "$var" "$vif"
				wpa_enterprise=1
			;;
			*wep*)
				config_get key "$vif" key
				key="${key:-1}"
				case "$key" in
					[1234])
						for idx in 1 2 3 4; do
							local zidx
							zidx=$(($idx - 1))
							config_get ckey "$vif" "key${idx}"
							[ -n "$ckey" ] && \
								append "$var" "wep_key${zidx}=$(prepare_key_wep "$ckey")" "$N"
						done
						append "$var" "wep_default_key=$((key - 1))"  "$N"
					;;
					*)
						append "$var" "wep_key0=$(prepare_key_wep "$key")" "$N"
						append "$var" "wep_default_key=0" "$N"
						[ -n "$wep_rekey" ] && append "$var" "wep_rekey_period=$wep_rekey" "$N"
					;;
				esac
				case "$enc" in
					*shared*)
						auth_algs=2
					;;
					*mixed*)
						auth_algs=3
					;;
				esac
				wpa=0
				crypto=
			;;
			8021x)
				# For Dynamic WEP 802.1x,maybe need more fields
				config_get auth_server "$vif" auth_server
				[ -z "$auth_server" ] && config_get auth_server "$vif" server
				append "$var" "auth_server_addr=$auth_server" "$N"
				config_get auth_port "$vif" auth_port
				[ -z "$auth_port" ] && config_get auth_port "$vif" port
				auth_port=${auth_port:-1812}
				append "$var" "auth_server_port=$auth_port" "$N"
				config_get auth_secret "$vif" auth_secret
				[ -z "$auth_secret" ] && config_get auth_secret "$vif" key
				config_get eap_reauth_period "$vif" eap_reauth_period
				[ -n "$eap_reauth_period" ] && append "$var" "eap_reauth_period=$eap_reauth_period" "$N"
				config_get wep_rekey "$vif" wep_rekey 300

				append "$var" "ieee8021x=1" "$N"
				append "$var" "auth_server_shared_secret=$auth_secret" "$N"
				append "$var" "wep_rekey_period=$wep_rekey" "$N"
				append "$var" "eap_server=0" "$N"
				append "$var" "eapol_version=2" "$N"
				append "$var" "eapol_key_index_workaround=0" "$N"
				append "$var" "wep_key_len_broadcast=13" "$N"
				append "$var" "wep_key_len_unicast=13" "$N"
				auth_algs=1
				wpa=0
				crypto=
			;;
			dpp)
			;;
			*)
				wpa=0
				crypto=
			;;
		esac
	#termination of suite_b enable or not check
	fi

	append "$var" "auth_algs=${auth_algs:-1}" "$N"
	append "$var" "wpa=$wpa" "$N"

	if [ "${suite_b}" -ne 192 ]
	then
		[ -n "$crypto" ] && append "$var" "wpa_pairwise=$crypto" "$N"
	fi

	[ -n "$wpa_group_rekey" ] && append "$var" "wpa_group_rekey=$wpa_group_rekey" "$N"
	[ -n "$wpa_strict_rekey" ] && append "$var" "wpa_strict_rekey=$wpa_strict_rekey" "$N"

	config_get nasid "$vif" nasid
	[ -n "$nasid" ] && append "$var" "nas_identifier=$nasid" "$N"

	config_get ssid "$vif" ssid
	config_get bridge "$vif" bridge
	config_get ieee80211d "$vif" ieee80211d
	config_get iapp_interface "$vif" iapp_interface

	config_get_bool wps_pbc "$vif" wps_pbc 0
	config_get_bool wps_label "$vif" wps_label 0

	config_get wds_sta qcawifi wds_ext 0
	[ "$wds_sta" -gt 0 ] && append "$var" "wds_sta=1" "$N"

	config_get config_methods "$vif" wps_config
	[ "$wps_pbc" -gt 0 ] && append config_methods push_button

	case "$config_methods" in
		*push_button*) update_wps_rf_bands;;
	esac

	# WPS 2.0 test case 4.1.7:
	# if we're configured to enable WPS and we hide our SSID, then
	# we have to require an "explicit user operation to continue"
	config_get_bool hidden "$vif" hidden 0
	[ -n "$wps_possible" -a -n "$config_methods" -a "$hidden" -gt 0 ] && {
		echo "Hidden SSID is enabled on \"$ifname\", WPS will be automatically disabled"
		echo "Please press any key to continue."
		read -s -n 1
		wps_possible=
	}

	[ -n "$wps_possible" -a -n "$config_methods" ] && {
		config_get device_type "$vif" wps_device_type "6-0050F204-1"
		config_get device_name "$vif" wps_device_name "OpenWrt AP"
		config_get manufacturer "$vif" wps_manufacturer "openwrt.org"
		config_get model_name "$vif" model_name "WAP"
		config_get model_number "$vif" model_number "123"
		config_get serial_number "$vif" serial_number "12345"
		config_get wps_pin "$vif" wps_pin "12345670"
		config_get wps_state "$vif" wps_state $wps_configured_state
		config_get_bool wps_independent "$vif" wps_independent 1
		config_get wps_rf_bands "$vif" wps_rf_bands 0
		config_get wps_sae "$vif" sae
		[ $wps_rf_bands -eq 0 ] && {
			case "$hwmode" in
				*g*|*b|*bg) hwmode=g;;
				*a|*na|*axa|*ac) hwmode=a;;
				*) hwmode=a;;
			esac
			config_get wps_rf_bands "$vif" wps_rf_bands "$hwmode"
		}
		[ ${#wps_dual_band} -gt 1 ] && wps_rf_bands=$wps_dual_band

		config_get pbc_in_m1 "$vif" pbc_in_m1
		[ -n "$pbc_in_m1" ] && append "$var" "pbc_in_m1=$pbc_in_m1" "$N"

		config_get_bool ext_registrar "$vif" ext_registrar 0
		[ "$ext_registrar" -gt 0 -a -n "$bridge" ] && append "$var" "upnp_iface=$bridge" "$N"

		append "$var" "eap_server=1" "$N"
		append "$var" "ap_pin=$wps_pin" "$N"
		if [ "${wps_sae}" -gt 0 ] && [ $wps_pbc -eq 1 ]
		then
			wps_state=2
		fi
		append "$var" "wps_state=$wps_state" "$N"
		append "$var" "ap_setup_locked=0" "$N"
		append "$var" "device_type=$device_type" "$N"
		append "$var" "device_name=$device_name" "$N"
		append "$var" "manufacturer=$manufacturer" "$N"
		append "$var" "model_name=$model_name" "$N"
		append "$var" "model_number=$model_number" "$N"
		append "$var" "serial_number=$serial_number" "$N"
		append "$var" "config_methods=$config_methods" "$N"
		append "$var" "wps_independent=$wps_independent" "$N"
		append "$var" "wps_rf_bands=$wps_rf_bands" "$N"

		# fix the overlap session of WPS PBC for dual band AP
		local macaddr=$(cat /sys/class/net/${bridge}/address)
		uuid=$(echo "$macaddr" | sed 's/://g')
		[ -n "$uuid" ] && {
			append "$var" "uuid=87654321-9abc-def0-1234-$uuid" "$N"
		}

	}

	append "$var" "ssid=$ssid" "$N"
	[ -n "$bridge" ] && append "$var" "bridge=$bridge" "$N"
	[ -n "$ieee80211d" ] && append "$var" "ieee80211d=$ieee80211d" "$N"
	[ -n "$iapp_interface" ] && append "$var" iapp_interface=$(uci_get_state network "$iapp_interface" ifname "$iapp_interface") "$N"

	config_get  ocv  "$vif" ocv
	[ -n "$ocv" ] && append "$var" "ocv=$ocv" "$N"

	if [ "$wpa" -ge "2" ]
	then
		# RSN -> allow preauthentication
		config_get rsn_preauth "$vif" rsn_preauth
		if [ -n "$bridge" -a "$rsn_preauth" = 1 ]
		then
			append "$var" "rsn_preauth=1" "$N"
			append "$var" "rsn_preauth_interfaces=$bridge" "$N"
		fi

		# RSN -> allow management frame protection

		config_get ieee80211w "$vif" ieee80211w 0

		# Allow SHA256
		case "$enc" in
			*wpa2*+osen*) keymgmt=EAP
				key_mgmt_str="WPA-EAP OSEN"
			;;
			osen*) key_mgmt_str="OSEN"
			;;
			*wpa*) keymgmt=EAP
				key_mgmt_str="WPA-EAP"
			;;
			*psk*)  keymgmt=PSK
				key_mgmt_str="WPA-PSK"
			;;
		esac
		config_get_bool add_sha256 "$vif" add_sha256 0
		config_get_bool add_sha384 "$vif" add_sha384 0

		if [ "${ieee80211w}" -eq 2 ]
		then
			add_sha256=1
		fi

		if [ "${ieee80211r}" -gt 0 ]
		then
			if [ "${sae}" -eq 1 ]
			then
				ieee80211r_str="FT-SAE"
			elif [ "${suite_b}" -eq 192 ]
			then
				ieee80211r_str="FT-EAP-SHA384"
			else
				ieee80211r_str="FT-${keymgmt}"
			fi
		fi

		config_get  rsnxe_override_eapol  "$vif" rsnxe_override_eapol
		[ -n "$rsnxe_override_eapol" ] && append "$var" "rsnxe_override_eapol=$rsnxe_override_eapol" "$N"

		config_get  transition_disable  "$vif" transition_disable
		[ -n "$transition_disable" ] && append "$var" "transition_disable=$transition_disable" "$N"


		if [ "${sae}" -eq 1 ]
		then
			config_get sae_commit_status "$vif" sae_commit_status
			[ -n "$sae_commit_status" ] && append "$var" "sae_commit_status=$sae_commit_status" "$N"

			config_get sae_pk_omit "$vif" sae_pk_omit
			[ -n "$sae_pk_omit" ] && append "$var" "sae_pk_omit=$sae_pk_omit" "$N"

			config_get sae_pk_password_check_skip "$vif" sae_pk_password_check_skip
			[ -n "$sae_pk_password_check_skip" ] && append "$var" "sae_pk_password_check_skip=$sae_pk_password_check_skip" "$N"

			config_get sae_require_mfp  "$vif" sae_require_mfp
			config_get sae_confirm_immediate "$vif" sae_confirm_immediate

			[ -n "$sae_reflection_attack" ] && append "$var" "sae_reflection_attack=$sae_reflection_attack" "$N"
			[ -n "$sae_commit_override" ] && append "$var" "sae_commit_override=$sae_commit_override" "$N"
			[ -n "$sae_confirm_immediate" ] && append "$var" "sae_confirm_immediate=$sae_confirm_immediate" "$N"
			config_get sae_pwe "$vif" sae_pwe 2
			[ -n "$sae_pwe" ] && append "$var" "sae_pwe=$sae_pwe" "$N"
			add_sae_passwords() {
				append "$var" "sae_password=${1}" "$N"
			}
			config_list_foreach "$vif" sae_password add_sae_passwords

			[ -n "$sae_anti_clogging_threshold" ] && append "$var" "sae_anti_clogging_threshold=$sae_anti_clogging_threshold" "$N"

			add_sae_groups() {
				local sae_groups=$(echo $1 | tr "," " ")
				[ -n "$sae_groups" ] && append "$var" "sae_groups=$sae_groups" "$N"
			}
			config_list_foreach  "$vif" sae_groups add_sae_groups

			sae_str="SAE"

			config_get sae_sync  "$vif" sae_sync
			[ -n "$sae_sync" ] && append "$var" "sae_sync=$sae_sync" "$N"

			case "$enc" in
				*wpa*);;
				*psk*)
					if [ "${ieee80211w}" -eq 0 ]
					then
						ieee80211w=1
						sae_require_mfp=1
					elif [ "${ieee80211w}" -eq 1 ]
					then
						sae_require_mfp=1
					fi
				;;
				*)
					ieee80211w=2
					add_sha256=0
			esac

			[ -n "$sae_require_mfp" ] && append "$var" "sae_require_mfp=$sae_require_mfp" "$N"

		fi

		if [ "${owe}" -eq 1 ]
		then
			owe_str="OWE"

			add_owe_groups() {
				local owe_groups=$(echo $1 | tr "," " ")
				[ -n "$owe_groups" ] && append "$var" "owe_groups=$owe_groups" "$N"
			}
			config_list_foreach  "$vif" owe_groups add_owe_groups

			case "$enc" in
				*wpa*);;
				*psk*);;
				*)
					config_get ieee80211w "$vif" ieee80211w 2
					add_sha256=0
			esac
		fi

		if [ "${dpp}" -eq 1 ]
		then
			dpp_str="DPP"
			add_sha256=0
			config_get dpp_connector "$vif" dpp_connector
			config_get dpp_1905_connector "$vif" dpp_1905_connector
			config_get dpp_csign "$vif" dpp_csign
			config_get dpp_netaccesskey "$vif" dpp_netaccesskey
			config_get dpp_configurator_connectivity "$vif" dpp_configurator_connectivity

			[ -n "$dpp_connector" ] && append "$var" "dpp_connector=$dpp_connector" "$N"
			[ -n "$dpp_1905_connector" ] && append "$var" "dpp_1905_connector=$dpp_1905_connector" "$N"
			[ -n "$dpp_csign" ] && append "$var" "dpp_csign=$dpp_csign" "$N"
			[ -n "$dpp_netaccesskey" ] && append "$var" "dpp_netaccesskey=$dpp_netaccesskey" "$N"
			[ -n "$dpp_configurator_connectivity" ] && append "$var" "dpp_configurator_connectivity=$dpp_configurator_connectivity" "$N"
		fi

		if [ "${suite_b}" -eq 192 ]
		then
			suite_b_str="WPA-EAP-SUITE-B-192"
		fi

		append "$var" "ieee80211w=$ieee80211w" "$N"
		[ "$ieee80211w" -gt "0" ] && {
			config_get ieee80211w_max_timeout "$vif" ieee80211w_max_timeout
			config_get ieee80211w_retry_timeout "$vif" ieee80211w_retry_timeout
			config_get group_mgmt_cipher "$vif" group_mgmt_cipher
			config_get beacon_prot "$vif" beacon_prot 0
			[ -n "$ieee80211w_max_timeout" ] && \
				append "$var" "assoc_sa_query_max_timeout=$ieee80211w_max_timeout" "$N"
			[ -n "$ieee80211w_retry_timeout" ] && \
				append "$var" "assoc_sa_query_retry_timeout=$ieee80211w_retry_timeout" "$N"
			[ -n "$group_mgmt_cipher" ] && \
				append "$var" "group_mgmt_cipher=$group_mgmt_cipher" "$N"
			append "$var" "beacon_prot=$beacon_prot" "$N"
		}

		[ "${add_sha256}" -gt 0 ] && add_sha256_str="${key_mgmt_str}-SHA256"

	        if [ "${ieee80211ai}" -gt 0 ]
		then
			if [ "${ieee80211r}" -gt 0 ]
			then
				[ "${add_sha256}" -gt 0 ] && ieee80211ai_sha256_str="FILS-SHA256 FT-FILS-SHA256"
				[ "${add_sha384}" -gt 0 ] && ieee80211ai_sha384_str="FILS-SHA384 FT-FILS-SHA384"
			else
				[ "${add_sha256}" -gt 0 ] && ieee80211ai_sha256_str="FILS-SHA256"
				[ "${add_sha384}" -gt 0 ] && ieee80211ai_sha384_str="FILS-SHA384"
			fi
			config_get erp_send_reauth_start "$vif" erp_send_reauth_start
			[ -n "$erp_send_reauth_start" ] && append "$var" "erp_send_reauth_start=$erp_send_reauth_start" "$N"
			config_get erp_domain "$vif" erp_domain
			[ -n "$erp_domain" ] && append "$var" "erp_domain=$erp_domain" "$N"
			config_get fils_realm "$vif" fils_realm
			[ -n "$fils_realm" ] && append "$var" "fils_realm=$fils_realm" "$N"
			config_get fils_cache_id "$vif" fils_cache_id
			[ -n "$fils_cache_id" ] && append "$var" "fils_cache_id=$fils_cache_id" "$N"
			config_get own_ip_addr "$vif" own_ip_addr
			[ -n "$own_ip_addr" ] && append "$var" "own_ip_addr=$own_ip_addr" "$N"
			config_get dhcp_server "$vif" dhcp_server
			[ -n "$dhcp_server" ] && append "$var" "dhcp_server=$dhcp_server" "$N"
			config_get fils_hlp_wait_time "$vif" fils_hlp_wait_time
			[ -n "$fils_hlp_wait_time" ] && append "$var" "fils_hlp_wait_time=$fils_hlp_wait_time" "$N"
			config_get dhcp_rapid_commit_proxy "$vif" dhcp_rapid_commit_proxy
			[ -n "$dhcp_rapid_commit_proxy" ] && append "$var" "dhcp_rapid_commit_proxy=$dhcp_rapid_commit_proxy" "$N"
        	fi

		config_get disable_pmksa_caching "$vif" disable_pmksa_caching
		[ -n "$disable_pmksa_caching" ] && append "$var" "disable_pmksa_caching=$disable_pmksa_caching" "$N"

		config_get wpa_key_mgmt "$vif" wpa_key_mgmt
		if [ -n "$wpa_key_mgmt" ]
		then
			append "$var" "wpa_key_mgmt=$wpa_key_mgmt" "$N"
		else
			case "$ieee80211w" in
				[01]) append "$var" "wpa_key_mgmt=${key_mgmt_str} ${add_sha256_str} ${ieee80211r_str} ${ieee80211ai_sha256_str} ${ieee80211ai_sha384_str} ${sae_str} ${owe_str} ${dpp_str}" "$N";;
				2)
					if [ "${suite_b}" -eq 192 ]
					then
						append "$var" "wpa_key_mgmt=${suite_b_str}" "$N"
					else
						append "$var" "wpa_key_mgmt=${add_sha256_str} ${ieee80211r_str} ${ieee80211ai_sha256_str} ${ieee80211ai_sha384_str} ${sae_str} ${owe_str} ${dpp_str}" "$N"
					fi
				;;
			esac
		fi
	fi

	config_get dpp_controller "$vif" dpp_controller
	[ -n "$dpp_controller" ] && append "$var" "dpp_controller=$dpp_controller" "$N"

	config_get dpp_pfs "$vif" dpp_pfs
	[ -n "$dpp_pfs" ] && append "$var" "dpp_pfs=$dpp_pfs" "$N"

	if [ "$wpa" -eq "1" ] && [ $wpa_enterprise -eq 1 ]
	then
		append "$var" "wpa_key_mgmt=WPA-EAP" "$N"
	fi

	config_get multi_cred "$vif" multi_cred 0

	if [ "$multi_cred" -gt 0 ]; then
		append "$var" "skip_cred_build=1" "$N"
		append "$var" "extra_cred=/var/run/hostapd_cred_${device}.bin" "$N"
	fi

	config_get bss_load_update_period "$vif" bss_load_update_period
	[ -n "$bss_load_update_period" ] && append "$var" "bss_load_update_period=$bss_load_update_period" "$N"

	config_get_bool hs20 "$vif" hs20 0
	if [ "$hs20" -gt 0 ]
	then
		append "$var" "hs20=1" "$N"
		config_get hs20_release "$vif" hs20_release
		[ -n "$hs20_release" ] && append "$var" "hs20_release=$hs20_release" "$N"

		config_get disable_dgaf "$vif" disable_dgaf
		[ -n "$disable_dgaf" ] && append "$var" "disable_dgaf=$disable_dgaf" "$N"

		add_hs20_oper_friendly_name() {
			append "$var" "hs20_oper_friendly_name=${1}" "$N"
		}

		config_list_foreach "$vif" hs20_oper_friendly_name add_hs20_oper_friendly_name

		add_hs20_conn_capab() {
			append "$var" "hs20_conn_capab=${1}" "$N"
		}

		config_list_foreach "$vif" hs20_conn_capab add_hs20_conn_capab

		config_get hs20_wan_metrics "$vif" hs20_wan_metrics
		[ -n "$hs20_wan_metrics" ] && append "$var" "hs20_wan_metrics=$hs20_wan_metrics" "$N"
		config_get hs20_operating_class "$vif" hs20_operating_class
		[ -n "$hs20_operating_class" ] && append "$var" "hs20_operating_class=$hs20_operating_class" "$N"

		config_get hs20_t_c_filename "$vif" hs20_t_c_filename
		[ -n "$hs20_t_c_filename" ] && append "$var" "hs20_t_c_filename=$hs20_t_c_filename" "$N"

		config_get hs20_t_c_timestamp "$vif" hs20_t_c_timestamp
		[ -n "$hs20_t_c_timestamp" ] && append "$var" "hs20_t_c_timestamp=$hs20_t_c_timestamp" "$N"

		config_get hs20_t_c_server_url "$vif" hs20_t_c_server_url
		[ -n "$hs20_t_c_server_url" ] && append "$var" "hs20_t_c_server_url=$hs20_t_c_server_url" "$N"

		append "$var" "interworking=1" "$N"
		append "$var" "manage_p2p=1" "$N"
		append "$var" "tdls_prohibit=1" "$N"
		config_get hessid "$vif" hessid
		[ -n "$hessid" ] && append "$var" "hessid=$hessid" "$N"
		config_get access_network_type "$vif" access_network_type
		[ -n "$access_network_type" ] && append "$var" "access_network_type=$access_network_type" "$N"
		config_get internet "$vif" internet
		[ -n "$internet" ] && append "$var" "internet=$internet" "$N"
		config_get asra "$vif" asra
		[ -n "$asra" ] && append "$var" "asra=$asra" "$N"
		config_get esr "$vif" esr
		[ -n "$esr" ] && append "$var" "esr=$esr" "$N"
		config_get uesa "$vif" uesa
		[ -n "$uesa" ] && append "$var" "uesa=$uesa" "$N"
		config_get venue_group "$vif" venue_group
		[ -n "$venue_group" ] && append "$var" "venue_group=$venue_group" "$N"
		config_get venue_type "$vif" venue_type
		[ -n "$venue_type" ] && append "$var" "venue_type=$venue_type" "$N"
		add_roaming_consortium() {
			append "$var" "roaming_consortium=${1}" "$N"
		}
		config_list_foreach "$vif" roaming_consortium add_roaming_consortium

		add_venue_name() {
			append "$var" "venue_name=${1}" "$N"
		}
		config_list_foreach "$vif" venue_name add_venue_name

		add_venue_url() {
			append "$var" "venue_url=${1}" "$N"
		}
		config_list_foreach "$vif" venue_url add_venue_url

		add_network_auth_type() {
			append "$var" "network_auth_type=${1}" "$N"
		}
		config_list_foreach "$vif" network_auth_type add_network_auth_type
		config_get ipaddr_type_availability "$vif" ipaddr_type_availability
		[ -n "$ipaddr_type_availability" ] && append "$var" "ipaddr_type_availability=$ipaddr_type_availability" "$N"


		add_domain_name() {
			append "$var" "domain_name=${1}" "$N"
		}

		config_list_foreach "$vif" domain_name add_domain_name

		config_get anqp_3gpp_cell_net "$vif" anqp_3gpp_cell_net
		[ -n "$anqp_3gpp_cell_net" ] && append "$var" "anqp_3gpp_cell_net=$anqp_3gpp_cell_net" "$N"

		config_get qos_map_set "$vif" qos_map_set
		[ -n "$qos_map_set" ] && append "$var" "qos_map_set=$qos_map_set" "$N"
		config_get gas_frag_limit "$vif" gas_frag_limit
		[ -n "$gas_frag_limit" ] && append "$var" "gas_frag_limit=$gas_frag_limit" "$N"
		config_get hs20_deauth_req_timeout "$vif" hs20_deauth_req_timeout
		[ -n "$hs20_deauth_req_timeout" ] && append "$var" "hs20_deauth_req_timeout=$hs20_deauth_req_timeout" "$N"

		add_nai_realm() {
			append "$var" "nai_realm=${1}" "$N"
		}
		config_list_foreach "$vif" nai_realm add_nai_realm

		add_hs20_icon() {
			append "$var" "hs20_icon=${1}" "$N"
		}
		config_list_foreach "$vif" hs20_icon add_hs20_icon

		config_get operator_icon "$vif" operator_icon
		[ -n "$operator_icon" ] && append "$var" "operator_icon=$operator_icon" "$N"

		config_get osu_ssid "$vif" osu_ssid
		[ -n "$osu_ssid" ] && append "$var" "osu_ssid=$osu_ssid" "$N"


		add_osu_friendly_name() {
			append "$var" "osu_friendly_name=${1}" "$N"
		}

		add_osu_icon() {
			append "$var" "osu_icon=${1}" "$N"
		}

		add_osu_service_desc() {
			append "$var" "osu_service_desc=${1}" "$N"
		}

		add_osu_params() {
			local osu_server_uri osu_nai

			config_get osu_provider  $1 osu_provider

			if [ $osu_provider == "$2" ]; then

				config_get osu_server_uri $1 osu_server_uri
				[ -n "$osu_server_uri" ] && append "$var" "osu_server_uri=$osu_server_uri" "$N"

				config_list_foreach $1 osu_friendly_name add_osu_friendly_name

				config_get osu_nai $1 osu_nai
				[ -n "$osu_nai" ] && append "$var" "osu_nai=$osu_nai" "$N"

				config_get osu_nai2 $1 osu_nai2
				[ -n "$osu_nai2" ] && append "$var" "osu_nai2=$osu_nai2" "$N"

				config_get osu_method_list $1  osu_method_list
				[ -n "$osu_method_list" ] && append "$var" "osu_method_list=$osu_method_list" "$N"

				config_list_foreach $1 osu_icon add_osu_icon

				config_list_foreach $1 osu_service_desc add_osu_service_desc
			fi
		}

		add_osu_server_uri() {
			if [ -n "${1}" ]; then
				config_foreach add_osu_params osu_server $1
			fi
		}
		config_list_foreach "$vif" osu_provider  add_osu_server_uri


	else
		config_get interworking "$vif" interworking
		[ -n "$interworking" ] && append "$var" "interworking=$interworking" "$N"
	fi

	add_anqp_elem() {
		append "$var" "anqp_elem=${1}" "$N"
	}
	config_list_foreach "$vif" anqp_elem add_anqp_elem

	config_get mbo_cell_data_conn_pref "$vif" mbo_cell_data_conn_pref
	[ -n "$mbo_cell_data_conn_pref" ] && append "$var" "mbo_cell_data_conn_pref=$mbo_cell_data_conn_pref" "$N"

	config_get osen "$vif" osen
	[ -n "$osen" ] && append "$var" "osen=$osen" "$N"

	config_get gas_comeback_delay "$vif" gas_comeback_delay
	[ -n "$gas_comeback_delay" ] && append "$var" "gas_comeback_delay=$gas_comeback_delay" "$N"

	if [ "$ieee80211r" -gt 0 ]
	then

		config_get mobility_domain "$vif" mobility_domain
		[ -n "$mobility_domain" ] && append "$var" "mobility_domain=$mobility_domain" "$N"
		config_get r0_key_lifetime "$vif" r0_key_lifetime 10000
		append "$var" "r0_key_lifetime=$r0_key_lifetime" "$N"

		config_get ft_r0_key_lifetime "$vif" ft_r0_key_lifetime 1209600
		append "$var" "ft_r0_key_lifetime=$ft_r0_key_lifetime" "$N"

		config_get r1_max_key_lifetime "$vif" r1_max_key_lifetime 0
		append "$var" "r1_max_key_lifetime=$r1_max_key_lifetime" "$N"

		config_get r1_key_holder "$vif" r1_key_holder
		[ -n "$r1_key_holder" ] && append "$var" "r1_key_holder=$r1_key_holder" "$N"
		config_get reassociation_deadline "$vif" reassociation_deadline 1000
		append "$var" "reassociation_deadline=$reassociation_deadline" "$N"
		config_get pmk_r1_push "$vif" pmk_r1_push 1
		append "$var" "pmk_r1_push=$pmk_r1_push" "$N"
		config_get ft_psk_generate_local "$vif" ft_psk_generate_local 0
		append "$var" "ft_psk_generate_local=$ft_psk_generate_local" "$N"
		config_get ft_over_ds "$vif" ft_over_ds
		[ -n "$ft_over_ds" ] && append "$var" "ft_over_ds=$ft_over_ds" "$N"

		config_get nasid2 "$vif" nasid2
		config_get ap_macaddr "$vif" ap_macaddr
		config_get ap2_macaddr "$vif" ap2_macaddr
		config_get ap2_r1_key_holder "$vif" ap2_r1_key_holder

		append "$var" "r0kh=$ap_macaddr $nasid $kh_key_hex" "$N"
		append "$var" "r0kh=$ap2_macaddr $nasid2 $kh_key_hex" "$N"
		append "$var" "r1kh=$ap2_macaddr $ap2_r1_key_holder $kh_key_hex" "$N"
	fi

	config_get_bool wnm_sleep_mode "$vif" wnm_sleep_mode
	[ -n "$wnm_sleep_mode" ] && append "$var" "wnm_sleep_mode=$wnm_sleep_mode" "$N"

	config_get_bool wnm_sleep_mode_no_keys "$vif" wnm_sleep_mode_no_keys
	[ -n "$wnm_sleep_mode_no_keys" ] && append "$var" "wnm_sleep_mode_no_keys=$wnm_sleep_mode_no_keys" "$N"

	config_get_bool bss_transition "$vif" bss_transition
	[ -n "$bss_transition" ] && append "$var" "bss_transition=$bss_transition" "$N"

	# MapBSSType can have following bits set
	# backhaul BSS BIT(6)
	# fronthaul BSS BIT(5)
	# teardown BIT(4)
	# Profile-1 Backhaul STA association disallowed BIT(3)
	# Profile-2 Backhaul STA association disallowed BIT(2)
	config_get MapBSSType "$vif" MapBSSType

	# map 1, multi_ap_profile-1 enabled
	# map 2, multi_ap_profile-2 enabled
	config_get map "$vif" map 0
	[ "$map" != "0" ] && append "$var" "multi_ap_profile=$map" "$N"

	# MapBSSType 96, vap is both fronthaul and backhaul BSS
	# MapBSSType 32, vap is fronthaul BSS
	# MapBSSType 64, vap is backhaul BSS
	if [ $(($((MapBSSType&64)) >> 6)) -eq 1 ] && [ $(($((MapBSSType&32)) >> 5)) -eq 1 ]; then
		append "$var" "multi_ap=3" "$N"
	elif [ $(($((MapBSSType&32)) >> 5)) -eq 1 ]; then
		append "$var" "multi_ap=2" "$N"
	elif [ $(($((MapBSSType&64)) >> 6)) -eq 1 ]; then
		append "$var" "multi_ap=1" "$N"
	fi

	if [ "$map" -ge 2 ]; then
		# MapBSSType 8, Profile-1 Backhaul STA association disallowed
		# MapBSSType 4, Profile-2 Backhaul STA association disallowed
		if [ $(($((MapBSSType&8)) >> 3)) -eq 1 ]; then
			append "$var" "multi_ap_client_disallow=1" "$N"
		elif [ $(($((MapBSSType&4)) >> 2)) -eq 1 ]; then
			append "$var" "multi_ap_client_disallow=2" "$N"
		fi

		config_get vlan_bridge "$vif" vlan_bridge
		if [ -n "$vlan_bridge" ]; then
			append "$var" "vlan_bridge=$vlan_bridge" "$N"
                fi

		append "$var" "wps_cred_add_sae=1" "$N"
		# Add vlanID to Easy Mesh IE
		config_get map_vlan "$vif" map8021qvlan
		[ -n "$map_vlan" ] && append "$var" "multi_ap_vlanid=$map_vlan" "$N"
	fi

	add_wps_sae_passwords() {
		append "$var" "wpa_passphrase=${1}" "$N"
	}
	config_get wps_pbc "$vif" wps_pbc 0
	config_get wps_sae "$vif" sae 0
	[ "${wps_sae}" -gt 0 ] && [ $wps_pbc -eq 1 ] && append "$var" "wps_cred_add_sae=1" "$N"
	[ "${wps_sae}" -gt 0 ] && [ $wps_pbc -eq 1 ] && [ -z "$psk" ] && config_list_foreach "$vif" sae_password add_wps_sae_passwords
	config_get wps_add_sae "$vif" wps_cred_add_sae 0
	[ -n "${wps_add_sae}" ] && [ "${wps_sae}" -eq 0 ] && append "$var" "wps_cred_add_sae=$wps_add_sae" "$N"

	if [ $(($((MapBSSType&32)) >> 5)) -eq 1 ]; then
		[ -n "$multi_ap_backhaul_ssid" ] && append "$var" "multi_ap_backhaul_ssid=\"$multi_ap_backhaul_ssid\"" "$N"
		[ -n "$multi_ap_backhaul_wpa_passphrase" ] && append "$var" "multi_ap_backhaul_wpa_passphrase=$multi_ap_backhaul_wpa_passphrase" "$N"
		[ -n "$multi_ap_backhaul_wpa_psk" ] && append "$var" "multi_ap_backhaul_wpa_psk=$multi_ap_backhaul_wpa_psk" "$N"
	fi

	if [ "$map" -eq 3 ]; then
		config_get dpp_cce "$vif" dpp_configurator_connectivity
		[ -n "$dpp_cce" ] && append "$var" "dpp_configurator_connectivity=$dpp_cce" "$N"
	fi

	config_get bss_load_update_period "$vif" bss_load_update_period
	[ -n "$bss_load_update_period" ] && append "$var" "bss_load_update_period=$bss_load_update_period" "$N"

	return 0
}

hostapd_get_vif_name () {
	[ -e /lib/functions.sh ] && . /lib/functions.sh
	DEVICES=
	config_cb() {
		local type="$1"
		local section="$2"
		local index="$(cat /sys/class/ieee80211/$phy/index)"

		# section start
		case "$type" in
			wifi-device)
				append DEVICES "$section"
				config_set "$section" vifs ""
				config_set "$section" ht_capab ""
			;;
		esac

		# section end
		config_get TYPE "$CONFIG_SECTION" TYPE
		case "$TYPE" in
			wifi-iface)
				config_get device "$CONFIG_SECTION" device
				config_get vifs "$device" vifs
				append vifs "$CONFIG_SECTION"
				config_set "$device" vifs "$vifs"
				for vif_interface in $vifs; do
					[ "$device" == "radio$index" ] && {
						config_set "$device" phy "$phy"
						vif=$vif_interface
					}
				done
			;;
		esac
	}
}

hostapd_set_log_options() {
	local var="$1"
	local cfg="$2"
	local log_level log_80211 log_8021x log_radius log_wpa log_driver log_iapp log_mlme

	config_get log_level "$cfg" log_level 2

	config_get_bool log_80211  "$cfg" log_80211  1
	config_get_bool log_8021x  "$cfg" log_8021x  1
	config_get_bool log_radius "$cfg" log_radius 1
	config_get_bool log_wpa    "$cfg" log_wpa    1
	config_get_bool log_driver "$cfg" log_driver 1
	config_get_bool log_iapp   "$cfg" log_iapp   1
	config_get_bool log_mlme   "$cfg" log_mlme   1

	[ -z "$cfg" ] && {
		set_default log_level 2
		set_default log_80211  1
		set_default log_8021x  1
		set_default log_radius 1
		set_default log_wpa    1
		set_default log_driver 1
		set_default log_iapp   1
		set_default log_mlme   1
	}

	local log_mask=$((       \
		($log_80211  << 0) | \
		($log_8021x  << 1) | \
		($log_radius << 2) | \
		($log_wpa    << 3) | \
		($log_driver << 4) | \
		($log_iapp   << 5) | \
		($log_mlme   << 6)   \
	))

	append "$var" "logger_syslog=$log_mask" "$N"
	append "$var" "logger_syslog_level=$log_level" "$N"
	append "$var" "logger_stdout=$log_mask" "$N"
	append "$var" "logger_stdout_level=$log_level" "$N"
}

hostapd_config_multi_cred() {
	local vif="$1" && shift
	local ifname device
	local cred_config temp
	extra_cred=

	config_get ifname "$vif" ifname
	config_get device "$vif" device

	hostapd_set_extra_cred extra_cred "$vif" "$ifname"


	extra_cred=$(echo $extra_cred | tr -d ' ')
	extra_cred=$(echo $extra_cred | tr -d ':')

	temp=`expr length "$extra_cred" / 2 `
	temp=` printf "%04X" $temp`

	#ATTR_CRED
	cred_config="100e$temp$extra_cred"

		cat > /var/run/hostapd_cred_tmp.conf <<EOF
$cred_config
EOF
		sed 's/\([0-9A-F]\{2\}\)/\\\\\\x\1/gI' /var/run/hostapd_cred_tmp.conf | xargs printf >> /var/run/hostapd_cred_$device.bin
}


hostapd_setup_vif() {
	local vif="$1" && shift
	local driver="$1" && shift
	local no_nconfig
	local ifname device channel hwmode htmode dpp_operating_class
	local fst_disabled
	local fst_iface1
	local fst_iface2
	local fst_group_id
	local fst_priority1
	local fst_priority2
	local edge_ch_dep_applicable

	hostapd_cfg=

	# These are flags that may or may not be used when calling
	# "hostapd_setup_vif()". These are not mandatory and may be called in
	# any order.
	# The flag bBSS expects backhaul ssid and backhaul key to be passed when
	# calling "hostapd_setup_vif()", in that order.
	while [ $# -ne 0 ]; do
		local tmparg="$1" && shift
		case "$tmparg" in
		no_nconfig)
			no_nconfig=1
			;;

		bBSS)
			multi_ap_backhaul_ssid="$1" && shift
			temp=`expr length "$1"`
			if [ $temp -eq 64 ]; then
				multi_ap_backhaul_wpa_psk="$1" && shift
			else
				multi_ap_backhaul_wpa_passphrase="$1" && shift
			fi
			;;
		esac
	done

	config_get ifname "$vif" ifname
	config_get device "$vif" device
	config_get bintval "$vif" bintval
	config_get_bool dpp "$vif" dpp 0
	config_get channel "$device" channel
	config_get hwmode "$device" hwmode
	config_get htmode "$device" htmode
	config_get_bool shortgi "$vif" shortgi 1
	config_get edge_channel_deprioritize "$device" edge_channel_deprioritize 1
	config_get acs_freq_list "$vif" acs_freq_list
	config_get band "$device" band 0
	config_get acs_6g_only_psc "$vif" acs_6g_only_psc 0

	# WAR to not use chan 36 as primary channel when higher BW are used.
	# -Added a string comparison for channel to avoid shell warning or error
	# when the value of channel is set to auto.
	if { [ $band -eq 0 ] || [ $band -eq 2 ]; } && { \
		[ "$channel" != "auto" ] && [ $channel -eq 36 ]; }; then
		if [ -f /sys/class/net/${device}/edge_ch_dep_applicable ]; then
			edge_ch_dep_applicable=$(cat /sys/class/net/${device}/edge_ch_dep_applicable)
			if [ $edge_ch_dep_applicable == "1" -a $edge_channel_deprioritize -eq 1 ]; then
				[ HT20 != "$htmode" ] && channel=40 && echo " Primary channel is changed to 40"
				[ HT40+ = "$htmode" ] && htmode=HT40- && echo " Mode changed to HT40MINUS with channel 40"
			fi
		fi
	fi

	hostapd_set_log_options hostapd_cfg "$device"

	config_load fst && {
		config_get fst_disabled config disabled
		config_get fst_iface1 config interface1
		config_get fst_iface2 config interface2
		config_get fst_group_id config mux_interface
		config_get fst_priority1 config interface1_priority
		config_get fst_priority2 config interface2_priority

		if [ $fst_disabled -eq 0 ]; then
			if [ "$ifname" == $fst_iface1 ] ; then
				append hostapd_cfg "fst_group_id=$fst_group_id" "$N"
				append hostapd_cfg "fst_priority=$fst_priority1" "$N"
			elif [ "$ifname" == $fst_iface2 ] ; then
				append hostapd_cfg "fst_group_id=$fst_group_id" "$N"
				append hostapd_cfg "fst_priority=$fst_priority2" "$N"
			fi
		fi
	}

	case "$hwmode" in
		*bg|*gdt|*gst|*fh) hwmode=g;;
		*adt|*ast) hwmode=a;;
	esac
	if [ "$driver" == "nl80211" ]; then
		append hostapd_cfg "${channel:+channel=$channel}" "$N"
		ht_capab=$(cat /sys/class/net/${ifname}/cfg80211_htcaps)
		vht_capab=$(cat /sys/class/net/${ifname}/cfg80211_vhtcaps)
		nl_hwmode=
		idx="$channel"
		# if UCI configuration is 11ac and htmode is not configured
		# then get htmode form syctl file /sys/class/net/$device/5g_maxchwidth
		if ( [ "$hwmode" == "11ac" ] || [ "$hwmode" == "11axa"  ] || \
		     [ "$hwmode" == "11na" ] ) && [ -z $htmode ]; then
			if [ -f /sys/class/net/$device/5g_maxchwidth ]; then
				maxchwidth="$(cat /sys/class/net/$device/5g_maxchwidth)"
				[ -n "$maxchwidth" ] && htmode=HT$maxchwidth
			else
				htmode=HT80
			fi
		fi

		case "$hwmode:$htmode" in
		# The parsing stops at the first match so we need to make sure
		# these are in the right orders (most generic at the end)
			*ng:HT20)
				nl_hwmode=g
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-20]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*ng:HT40-)
				nl_hwmode=g
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*ng:HT40+)
				nl_hwmode=g
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*ng:HT40)
				nl_hwmode=g
			case "$channel" in
				1|2|3|4|5|6|7) append ht_capab "[HT40+]";;
				8|9|10|11|12|13) append ht_capab "[HT40-]";;
			esac
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*ng:*)
				nl_hwmode=g
				append ht_capab "[HT20]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-20]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;

			*na:HT20)
				nl_hwmode=a
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-20]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*na:HT40-)
				nl_hwmode=a
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*na:HT40+)
				nl_hwmode=a
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*na:HT40)
				nl_hwmode=a
			case "$channel" in
				36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
				40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
				0|"auto") append ht_capab "[HT40+][HT40-]";;
				esac
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*na:*)
				nl_hwmode=a
			case "$channel" in
				36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
				40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
				0|"auto") append ht_capab "[HT40+][HT40-]";;
				esac
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				;;
			*ac:HT20)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-20]"
				append hostapd_cfg "vht_oper_chwidth=0" "$N"
				append hostapd_cfg "vht_oper_centr_freq_seg0_idx=$idx" "$N"
				;;
			*ac:HT40+|*ac:HT40-|*ac:HT40)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				case "$channel" in
					36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
					40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
					0|"auto") append ht_capab "[HT40+][HT40-]";;
				esac
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				case "$channel" in
					36|40) idx=38;;
					44|48) idx=46;;
					52|56) idx=54;;
					60|64) idx=62;;
					100|104) idx=102;;
					108|112) idx=110;;
					116|120) idx=118;;
					124|128) idx=126;;
					132|136) idx=134;;
					140|144) idx=142;;
					149|153) idx=151;;
					157|161) idx=159;;
					165|169) idx=167;;
					173|177) idx=175;;
				esac
				append hostapd_cfg "vht_oper_chwidth=0" "$N"
				append hostapd_cfg "vht_oper_centr_freq_seg0_idx=$idx" "$N"
				;;
			*ac:HT80)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				case "$channel" in
					36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
					40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
				esac
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
 				case "$channel" in
					36|40|44|48) idx=42;;
					52|56|60|64) idx=58;;
					100|104|108|112) idx=106;;
					116|120|124|128) idx=122;;
					132|136|140|144) idx=138;;
					149|153|157|161) idx=155;;
					165|169|173|177) idx=171;;
				esac
				append hostapd_cfg "vht_oper_chwidth=1" "$N"
				append hostapd_cfg "vht_oper_centr_freq_seg0_idx=$idx" "$N"
				;;
			*ac:HT160)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				case "$channel" in
					36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
					40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
				esac
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				case "$channel" in
					36|40|44|48|52|56|60|64) idx=50;;
					100|104|108|112|116|120|124|128) idx=114;;
					149|153|157|161|165|169|173|177) idx=163;;
				esac
				append hostapd_cfg "vht_oper_chwidth=2" "$N"
				append hostapd_cfg "vht_oper_centr_freq_seg0_idx=$idx" "$N"
				;;
			*ac:HT80_80) nl_hwmode=a;;
			*ac:*) nl_hwmode=a;;
			*axg:HT20)
				nl_hwmode=g
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-20]"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				;;
			*axg:HT40-)
				nl_hwmode=g
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				;;
			*axg:HT40+)
				nl_hwmode=g
				append ht_capab "[$htmode]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				;;
			*axg:HT40)
				nl_hwmode=g
			        case "$channel" in
				    1|2|3|4|5|6|7) append ht_capab "[HT40+]";;
				    8|9|10|11|12|13) append ht_capab "[HT40-]";;
				esac
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				;;
			*axg:*) nl_hwmode=g
				append ht_capab "[HT20]"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-20]"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				;;
			*axa:HT20)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-20]"
				append hostapd_cfg "he_oper_chwidth=0" "$N"
				append hostapd_cfg "he_oper_centr_freq_seg0_idx=$idx" "$N"

				if [ "$band" -eq 3 ]; then
					append hostapd_cfg "op_class=131" "$N"
                fi
				;;
			*axa:HT40+|*axa:HT40-|*axa:HT40)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				if [ "$band" -ne 3 ]; then
					case "$channel" in
						36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
						40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
						0|"auto") append ht_capab "[HT40+][HT40-]";;
					esac
					[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"

					case "$(( ($channel / 4) % 2 ))" in
						0) idx=$(($channel - 2));;
						1) idx=$(($channel + 2));;
					esac
				else
					append hostapd_cfg "op_class=132" "$N"
					case "$(( ($channel / 4) % 2 ))" in
						0) idx=$(($channel + 2));;
						1) idx=$(($channel - 2));;
					esac
						if [ "$channel" -lt "$idx" ]; then
							append ht_capab "[HT40+]"
						else
							append ht_capab "[HT40-]"
						fi
				fi

				append hostapd_cfg "he_oper_chwidth=0" "$N"
				append hostapd_cfg "he_oper_centr_freq_seg0_idx=$idx" "$N"
				;;
			*axa:HT80)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				if [ "$band" -ne 3 ]; then
					case "$channel" in
						36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
						40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
					esac
					[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"

					case "$(( ($channel / 4) % 4 ))" in
						1) idx=$(($channel + 6));;
						2) idx=$(($channel + 2));;
						3) idx=$(($channel - 2));;
						0) idx=$(($channel - 6));;
					esac
				else
					append hostapd_cfg "op_class=133" "$N"
					case "$(( ($channel / 4) % 4 ))" in
						0) idx=$(($channel + 6));;
						1) idx=$(($channel + 2));;
						2) idx=$(($channel - 2));;
						3) idx=$(($channel - 6));;
					esac
				fi
				append hostapd_cfg "he_oper_chwidth=1" "$N"
				append hostapd_cfg "he_oper_centr_freq_seg0_idx=$idx" "$N"
				;;
			*axa:HT160)
				nl_hwmode=a
				append hostapd_cfg "ieee80211ac=1" "$N"
				append hostapd_cfg "ieee80211n=1" "$N"
				append hostapd_cfg "ieee80211ax=1" "$N"
				if [ "$band" -ne 3 ]; then
					case "$channel" in
						36|44|52|60|100|108|116|124|132|140|149|157|165|173) append ht_capab "[HT40+]";;
						40|48|56|64|104|112|120|128|136|144|153|161|169|177) append ht_capab "[HT40-]";;
					esac
					[ "$shortgi" != "0" ] &&  append ht_capab "[SHORT-GI-40]"
					case "$channel" in
						36|40|44|48|52|56|60|64) idx=50;;
						100|104|108|112|116|120|124|128) idx=114;;
						149|153|157|161|165|169|173|177) idx=163;;
					esac

					append hostapd_cfg "he_oper_chwidth=2" "$N"

					case "$channel" in
						132|136|140|144)
							case "$(( ($channel / 4) % 4 ))" in
								0) idx=$(($channel - 6));;
								1) idx=$(($channel + 6));;
								2) idx=$(($channel + 2));;
								3) idx=$(($channel - 2));;
							esac
						append hostapd_cfg "he_oper_chwidth=1" "$N";;
					esac
				else
					append hostapd_cfg "op_class=134" "$N"
					case "$channel" in
						1|5|9|13|17|21|25|29) idx=15;;
						33|37|41|45|49|53|57|61) idx=47;;
						65|69|73|77|81|85|89|93) idx=79;;
						97|101|105|109|113|117|121|125) idx=111;;
						129|133|137|141|145|149|153|157) idx=143;;
						161|165|169|173|177|181|185|189) idx=175;;
						193|197|201|205|209|213|217|221) idx=207;;
					esac
					append hostapd_cfg "he_oper_chwidth=2" "$N"
				fi
				append hostapd_cfg "he_oper_centr_freq_seg0_idx=$idx" "$N"
				;;
			*axa:*) nl_hwmode=a
				if [ "$band" -ne 3 ]; then
					append hostapd_cfg "ieee80211n=1" "$N"
					append hostapd_cfg "ieee80211ac=1" "$N"
				else
					append hostapd_cfg "op_class=132" "$N"
				fi
				;;
			*bg:*)
				nl_hwmode=g
				;;
			*g:*)
				nl_hwmode=g
				;;
			*a:*)
				nl_hwmode=a
				;;
			*b:*)
				nl_hwmode=g
				;;
			*)
				;;
		esac

		[ -n "$ht_capab" ] && append hostapd_cfg "ht_capab=$ht_capab" "$N"
		[ -n "$vht_capab" ] && append hostapd_cfg "vht_capab=$vht_capab" "$N"

		case "$nl_hwmode" in
			*g) hwmode=g;;
			*a) hwmode=a;;
		esac

		append hostapd_cfg "hw_mode=$hwmode" "$N"
		append hostapd_cfg "wmm_enabled=1" "$N"

		[ -n "$bintval" ] && append hostapd_cfg "beacon_int=$bintval" "$N"
		[ -n "$acs_freq_list" ] && append hostapd_cfg "freqlist=$acs_freq_list" "$N"
		config_get dtim_period "$vif" dtim_period 1
		append hostapd_cfg "dtim_period=$dtim_period" "$N"
		config_get_bool hidden "$vif" hidden 0
		append hostapd_cfg "ignore_broadcast_ssid=$hidden" "$N"
		if [ "$acs_6g_only_psc" -ne 0 ]; then
			append hostapd_cfg "acs_exclude_6ghz_non_psc=$acs_6g_only_psc" "$N"
		fi

	fi  #end of nl80211

	hostapd_set_bss_options hostapd_cfg "$vif"

	[ "$channel" = auto ] && channel=
	[ -n "$channel" -a -z "$hwmode" ] && wifi_fixup_hwmode "$device"
	rm -f /var/run/hostapd-$ifname.conf
	cat > /var/run/hostapd-$ifname.conf <<EOF
driver=$driver
interface=$ifname
#${channel:+channel=$channel}
$hostapd_cfg
EOF
	[ -z "${no_nconfig}" ] &&
		echo ${hwmode:+hw_mode=${hwmode#11}} >> /var/run/hostapd-$ifname.conf

	entropy_file=/var/run/entropy-$ifname.bin

	# Run a single hostapd instance for all the radio's
	# Enables WPS VAP TIE feature
	config_get_bool wps_vap_tie_dbdc qcawifi wps_vap_tie_dbdc 0

	if [ $wps_vap_tie_dbdc -ne 0 ]; then
		echo -e "/var/run/hostapd-$ifname.conf \c\h" >> /tmp/hostapd_conf_filename
	else
		[ -f "/var/run/hostapd-$ifname.lock" ] &&
			rm /var/run/hostapd-$ifname.lock
		wpa_cli -g /var/run/hostapd/global raw ADD bss_config=$ifname:/var/run/hostapd-$ifname.conf
		[ $? -eq 0 ] || return
		touch /var/run/hostapd-$ifname.lock

		run_hostapd_cli() {
			ifname=$1
			ctrl_path=$2
			arguments=$3
			hostapd_cli -i $ifname -p $ctrl_path $arguments
		}

		if [ -n "$wps_possible" -a -n "$config_methods" ]; then
			pid=/var/run/hostapd_cli-$ifname.pid
			run_hostapd_cli $ifname "/var/run/hostapd-$device" "-P $pid -a /lib/wifi/wps-hostapd-update-uci -B"
		elif [ "${dpp}" -eq 1 ]
		then
			type=
			config_get dpp_type "$vif" dpp_type "qrcode"
			config_get dpp_curve "$vif" dpp_curve
			config_get dpp_key "$vif" dpp_key
			config_get channel "$device" channel auto
			config_get hwmode "$device" hwmode auto
			config_get htmode  "$device" htmode auto
			config_get pkex_code "$vif" pkex_code
			config_get pkex_identifier "$vif" pkex_identifier
			config_get dpp_auth_role "$vif" dpp_auth_role "initiator"
			config_get dpp_freq "$vif" dpp_freq 0
			config_get dpp_chirp "$vif" dpp_chirp
			config_get dpp_mud_url "$vif" dpp_mud_url
			config_get dpp_over_tcp "$vif" dpp_over_tcp
			type=$dpp_type
			dpp_type="type=$dpp_type"

			if [ -z $dpp_curve ]; then
				dpp_curve=
			else
				dpp_curve="curve=$dpp_curve"
			fi

			if [ -z $dpp_key ]; then
				dpp_key=
			else
				dpp_key="key=$dpp_key"
			fi

			if [ "$pkex_identifier" ]; then
				pkex_identifier="identifier=$pkex_identifier"
			fi

			if [ "$pkex_code" ]; then
				pkex_code="code=$pkex_code"
			fi

			if [ "${htmode}" == "auto" ]
			then
				case "$hwmode:$htmode" in
					*ng:*) htmode=HT20;;
					*na:*) htmode=HT40;;
					*ac:*) htmode=HT80;;
					*axg:*) htmode=HT20;;
					*axa:*) htmode=HT80;;
					*:*) htmode=HT20;
				esac
			fi

			if [ "$channel" == "auto" ]; then
				channel=
			else
				dpp_operating_class_setup "$htmode" "$channel"
				dpp_operating_class=$?
				echo "dpp_operating_class=$dpp_operating_class" > /dev/console
				channel="chan=$dpp_operating_class/$channel"
			fi

			pid=/var/run/hostapd_cli-$ifname.pid
			run_hostapd_cli $ifname "/var/run/hostapd-$device" "-P $pid -a /lib/wifi/dpp-hostapd-update-uci -B"

			run_hostapd_cli $ifname "/var/run/hostapd-$device" "DPP_CONTROLLER_STOP"

			hostapd_cli -i $ifname -p /var/run/hostapd-$device dpp_bootstrap_remove \*
			hostapd_cli -i $ifname -p /var/run/hostapd-$device dpp_pkex_remove \*
			hostapd_cli -i $ifname -p /var/run/hostapd-$device dpp_configurator_remove \*
			if [ "$map" -eq 3 ]; then
				run_hostapd_cli $ifname  "/var/run/hostapd-$device" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve $dpp_key"
			else
				run_hostapd_cli $ifname  "/var/run/hostapd-$device" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve  $channel mac=$(cat /sys/class/net/$ifname/address | sed 's/://g') $dpp_key"
			fi

			if [ "$dpp_mud_url" ]; then
				run_hostapd_cli $ifname "/var/run/hostapd-$device" "SET dpp_mud_url $dpp_mud_url"
			fi

			config_get dpp_controller "$vif" dpp_controller
			if [ -z "$dpp_controller" ] && [ -z "$map" ] && [ "$map" -eq 0 ]; then
				if [ "$dpp_auth_role" == "initiator" ]; then
					#Initiator configuration
					if [ "$dpp_over_tcp" ]; then
						tcp_addr="tcp_addr=$dpp_over_tcp"
					else
						tcp_addr=
					fi

					if [ "dpp_freq" -ne 0]; then
						neg_freq="neg_freq=$dpp_freq"
					else
						neg_freq=
					fi

					if [ "${type}" == "qrcode" ]
					then
						run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_auth_init peer=1 role=enrollee $neg_freq $tcp_addr"
					else
						run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_pkex_add own=1 $pkex_identifier role=enrollee $pkex_code $tcp_addr"
					fi
				else
					#Responder configuration
					if [ "dpp_over_tcp" -ne 0 ]; then
						run_hostapd_cli $ifname "/var/run/hostapd-$device" "DPP_CONTROLLER_START qr=single"
					fi

					if [ "${type}" == "qrcode" ]; then
						run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_listen $dpp_freq role=enrollee"
					else
						run_hostapd_cli $ifname  "/var/run/hostapd-$device" "dpp_pkex_add own=1 $pkex_identifier role=enrollee $pkex_code"
					fi

					if [ $dpp_chirp -eq 1 ]; then
						run_hostapd_cli $ifname "/var/run/hostapd-$device" "dpp_chirp own=1 iter=10 listen=$dpp_freq"
					fi

				fi
			fi

		fi
	fi
}
