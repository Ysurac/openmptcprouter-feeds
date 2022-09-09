#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

#
# Copyright (c) 2014, The Linux Foundation. All rights reserved.
#

wpa_supplicant_setup_vif() {
	local vif="$1"
	local driver="$2"
	local key="$key"
	local options="$3"
	local freq="" crypto=""
	local sae owe suite_b dpp sae_groups owe_group sae_password sae_password_id
	local sae_str owe_str dpp_str dpp_connector dpp_csign dpp_netaccesskey dpp_map dpp_pfs dpp_1905_connector
	local ieee80211r_str
	local device beacon_prot
	local pwe=""

	[ -n "$4" ] && freq="frequency=$4"
	config_get_bool sae "$vif" sae 0
	config_get_bool owe "$vif" owe 0
	config_get sae_password "$vif" sae_password
	config_get sae_password_id "vif" sae_password_id
	config_get ieee80211w "$vif" ieee80211w 0
	config_get suite_b "$vif" suite_b 0
	config_get ieee80211r "$vif" ieee80211r 0
	config_get dpp "$vif" dpp 0
	config_get device "$vif" device
	config_get sae_pwe "$vif" sae_pwe 2

	if [ $suite_b -eq 192 ]
	then
		key_mgmt=WPA-EAP-SUITE-B-192
		pairwise="pairwise=GCMP-256"
		group="group=GCMP-256"
		group_mgmt="group_mgmt=BIP-GMAC-256"
		ieee80211w="ieee80211w=2"
		proto="proto=RSN"

		config_get eap_type "$vif" eap_type
		[ -n "$eap_type" ] && eap_type="eap=$eap_type"

		config_get identity "$vif" identity
		[ -n "$identity" ] && identity="identity=\"$identity\""

		config_get ca_cert "$vif" ca_cert
		[ -n "$ca_cert" ] && ca_cert="ca_cert=\"$ca_cert\""

		config_get client_cert "$vif" client_cert
		[ -n "$client_cert" ] && client_cert="client_cert=\"$client_cert\""

		config_get priv_key "$vif" priv_key
		[ -n "$priv_key" ] && priv_key="private_key=\"$priv_key\""

		config_get priv_key_pwd "$vif" priv_key_pwd
		[ -n "$priv_key_pwd" ] && priv_key_pwd="private_key_passwd=\"$priv_key_pwd\""

		config_get phase1 "$vif" phase1
		[ -n "$phase1" ] && phase1="phase1=\"$phase1\""

	else
		# make sure we have the encryption type and the psk
		[ -n "$enc" ] || {
			config_get enc "$vif" encryption
		}

		enc_list=`echo "$enc" | sed "s/+/ /g"`

		for enc_var in $enc_list; do
			case "$enc_var" in
				*tkip)
					crypto="TKIP $crypto"
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
				;;
			esac
		done

		case "$enc_list" in
				dpp|sae*|psk2)
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
		esac

		[ -n "$key" ] || {
			config_get key "$vif" key
		}

		local net_cfg bridge
		config_get bridge "$vif" bridge
		[ -z "$bridge" ] && {
			net_cfg="$(find_net_config "$vif")"
			[ -z "$net_cfg" ] || bridge="$(bridge_interface "$net_cfg")"
			config_set "$vif" bridge "$bridge"
		}

		local mode ifname wds modestr=""
		config_get mode "$vif" mode
		config_get ifname "$vif" ifname
		config_get_bool wds "$vif" wds 0
		config_get_bool extap "$vif" extap 0

		config_get device "$vif" device
		config_get_bool qwrap_enable "$device" qwrap_enable 0

		[ -z "$bridge" ] || [ "$mode" = ap ] || [ "$mode" = sta -a $wds -eq 1 ] || \
		[ "$mode" = sta -a $extap -eq 1 ] || [ $qwrap_enable -ne 0 ] || {
			echo "wpa_supplicant_setup_vif($ifname): Refusing to bridge $mode mode interface"
			return 1
		}
		[ "$mode" = "adhoc" ] && modestr="mode=1"

		key_mgmt='NONE'
		case "$enc" in
			*none*) ;;
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
								append "wep_key${zidx}" "wep_key${zidx}=$(prepare_key_wep "$ckey")"
						done
						wep_tx_keyidx="wep_tx_keyidx=$((key - 1))"
					;;
					*)
						wep_key0="wep_key0=$(prepare_key_wep "$key")"
						wep_tx_keyidx="wep_tx_keyidx=0"
					;;
				esac
				case "$enc" in
					*mixed*)
						wep_auth_alg='auth_alg=OPEN SHARED'
					;;
					*shared*)
						wep_auth_alg='auth_alg=SHARED'
					;;
					*open*)
						wep_auth_alg='auth_alg=OPEN'
					;;
				esac
			;;
			*psk*)
				key_mgmt='WPA-PSK'
				# if you want to use PSK with a non-nl80211 driver you
				# have to use WPA-NONE and wext driver for wpa_s
				[ "$mode" = "adhoc" -a "$driver" != "nl80211" ] && {
					key_mgmt='WPA-NONE'
					driver='wext'
				}

				if [ "${ieee80211r}" -eq 1 ]
				then
					ieee80211r_str=FT-PSK
				fi

				if [ ${sae} -eq 1 ]
				then
					if [ ${sae_password} ]
					then
						sae_pwd="sae_password=\"${sae_password}\""
					else
						sae_pwd="sae_password=\"${key}\""
					fi
				fi
				if [ ${#key} -eq 64 ]; then
					passphrase="psk=${key}"
				else
					passphrase="psk=\"${key}\""
				fi

				[ -n "$crypto" ] || crypto="CCMP"
				pairwise="pairwise=$crypto"

				case "$enc" in
					*mixed*)
						proto='proto=RSN WPA'
					;;
					*psk2*)
						proto='proto=RSN'
						config_get ieee80211w "$vif" ieee80211w 0
					;;
					*psk*)
						proto='proto=WPA'
					;;
				esac
			;;
			*wpa*|*8021x*)
				proto='proto=WPA2'
				key_mgmt='WPA-EAP'
				config_get ieee80211w "$vif" ieee80211w 0
				config_get ca_cert "$vif" ca_cert
				config_get eap_type "$vif" eap_type
				ca_cert=${ca_cert:+"ca_cert=\"$ca_cert\""}

				[ -n "$crypto" ] || crypto="CCMP"
				pairwise="pairwise=$crypto"

				case "$eap_type" in
					tls)
						config_get identity "$vif" identity
						config_get client_cert "$vif" client_cert
						config_get priv_key "$vif" priv_key
						config_get priv_key_pwd "$vif" priv_key_pwd
						identity="identity=\"$identity\""
						client_cert="client_cert=\"$client_cert\""
						priv_key="private_key=\"$priv_key\""
						priv_key_pwd="private_key_passwd=\"$priv_key_pwd\""
					;;
					peap|ttls)
						config_get auth "$vif" auth
						config_get identity "$vif" identity
						config_get password "$vif" password
						phase2="phase2=\"auth=${auth:-MSCHAPV2}\""
							identity="identity=\"$identity\""
						password="password=\"$password\""
						;;
				esac
				eap_type="eap=$(echo $eap_type | tr 'a-z' 'A-Z')"
			;;
			ccmp*|gcmp*|sae*)
				proto='proto=RSN'
				if [ ${sae} -eq 1 ]
				then
					if [ ${sae_password} ]
					then
						sae_pwd="sae_password=\"${sae_password}\""
					else
						sae_pwd="sae_password=\"${key}\""
					fi
				fi
				case $enc in
					ccmp-256)
						[ -n "$crypto" ] || crypto="CCMP-256"
						pairwise="pairwise=$crypto"
					;;
					gcmp-256)
						[ -n "$crypto" ] || crypto="GCMP-256"
						pairwise="pairwise=$crypto"
					;;
					ccmp*)
						[ -n "$crypto" ] || crypto="CCMP"
						pairwise="pairwise=$crypto"
					;;
					gcmp*)
						[ -n "$crypto" ] || crypto="GCMP"
						pairwise="pairwise=$crypto"
					;;
					sae*)
						pairwise="pairwise=$crypto"
					;;
				esac
			;;
		esac

		keymgmt='NONE'

		# Allow SHA256
		case "$enc" in
			*wpa*|*8021x*) keymgmt=WPA-EAP;;
			ccmp*|gcmp*|sae*) keymgmt=;;
			*psk*) keymgmt=WPA-PSK;;
		esac

		if [ "${sae}" -eq 1 -a "${ieee80211r}" -gt 0 ]
		then
			ieee80211w=2
			sae_str=FT-SAE
		elif [ "${sae}" -eq 1 ]
		then
			if [ "${keymgmt}" == "WPA-PSK" ];then
				ieee80211w=1
			else
				ieee80211w=2
			fi
			sae_str=SAE
		fi

		if [ "${owe}" -eq 1 ]
		then
			proto='proto=RSN'
			ieee80211w=2
			owe_only='owe_only=1'
			owe_str=OWE
			passphrase=
			config_get  owe_group "$vif" owe_group
			if [ "$owe_group" ];then
				owe_group="owe_group=$owe_group"
			else
				owe_group=
			fi
		fi

		if [ "${dpp}" -eq 1 ]
		then
			dpp_str=DPP
			proto="proto=RSN"
			config_get dpp_connector "$vif" dpp_connector
			config_get dpp_1905_connector "$vif" dpp_1905_connector
			config_get dpp_csign     "$vif" dpp_csign
			config_get dpp_netaccesskey "$vif" dpp_netaccesskey

			[ -n "$dpp_connector" ] && dpp_connector="dpp_connector=\"${dpp_connector}\""
			[ -n "$dpp_1905_connector" ] && dpp_1905_connector="dpp_1905_connector=${dpp_1905_connector}"
			[ -n "$dpp_csign" ] && dpp_csign="dpp_csign=$dpp_csign"
			[ -n "$dpp_netaccesskey" ] && dpp_netaccesskey="dpp_netaccesskey=$dpp_netaccesskey"
			update_config="update_config=1"
		fi

		case "$ieee80211w" in
			0)
				key_mgmt="${keymgmt}"
			;;
			1)
				if [ "$key_mgmt" != "NONE" ]
				then
					key_mgmt="${keymgmt} ${keymgmt}-SHA256"
				fi
			;;
			2)
				if [ "$owe" -eq 1 ] || [ "$sae" -eq 1 ] || [ "$dpp" -eq 1 ]
				then
					key_mgmt="${keymgmt}"
				else
					key_mgmt="${keymgmt}-SHA256"
				fi
			;;
		esac

		if [ "${sae}" -eq 1 ]
		then
			add_sae_groups() {
				sae_groups=$(echo $1 | tr "," " ")
			}
			config_list_foreach  "$vif" sae_groups add_sae_groups
			if [ "$sae_groups" ];then
				sae_groups="sae_groups=$sae_groups"
			else
				sae_groups=
			fi
			key_mgmt="${sae_str} ${key_mgmt}"
			pwe="sae_pwe=$sae_pwe"
			[ -n "${sae_password_id}" ] && sae_password_id="sae_password_id=$sae_password_id"
		fi
		if [ "${owe}" -eq 1 ]
		then
			key_mgmt="${key_mgmt} ${owe_str}"
		fi
		if [ "${ieee80211r}" -eq 1 ]
		then
			key_mgmt="${key_mgmt} ${ieee80211r_str}"
		fi

		[ "$ieee80211w" -gt "0" ] && {
			config_get beacon_prot "$vif" beacon_prot 0
			[ -n "$beacon_prot" ] && beacon_prot="beacon_prot=$beacon_prot"
		}

		[ -n "$ieee80211w" ] && ieee80211w="ieee80211w=$ieee80211w"

		if [ $sae -ne 1 ] && [ $owe -ne 1 ] && [ $dpp -ne 1 ]
		then
			case "$pairwise" in
				*CCMP-256*) group="group=CCMP-256 GCMP-256 GCMP CCMP TKIP";;
				*GCMP-256*) group="group=GCMP-256 GCMP CCMP TKIP";;
				*GCMP*) group="group=GCMP CCMP TKIP";;
				*CCMP*) group="group=CCMP TKIP";;
				*TKIP*) group="group=TKIP";;
			esac
		else
			case "$pairwise" in
				*CCMP-256*) group="group=CCMP-256 GCMP-256 GCMP CCMP";;
				*GCMP-256*) group="group=GCMP-256 GCMP CCMP";;
				*GCMP*) group="group=GCMP CCMP";;
				*CCMP*) group="group=CCMP";;
			esac
		fi
		if [ "${dpp}" -eq 1 ]
		then
			if [ "$key_mgmt" != "NONE" ]
			then
				key_mgmt="${dpp_str} ${key_mgmt}"
			else
				key_mgmt="${dpp_str}"
			fi
			[ -n "$crypto" ] || crypto="CCMP"
			pairwise="pairwise=$crypto"
			ieee80211w="ieee80211w=1"
		fi

	#End of suite_b is 192 check
	fi

	config_get MapBSSType "$vif" MapBSSType 0
	config_get map "$vif" map 0

	if [ "$map" -eq 3 ]; then
		config_get dpp_map "$vif" dpp_map
		[ -n "$dpp_map" ] && dpp_map="dpp_map=$dpp_map"
	fi
	config_get dpp_pfs "$vif" dpp_pfs
	[ -n "$dpp_pfs" ] && dpp_pfs="dpp_pfs=$dpp_pfs"

	# MapBSSType 128, vap is backhaul STA
	if [ $MapBSSType -eq 128 ]; then
		multi_ap_backhaul_sta=1
		if [ "$map" -ge 2 ]; then
			wps_cred_add_sae=1
			config_get vlan_bridge "$vif" vlan_bridge
			if [ -n "$vlan_bridge" ]; then
				config_set "$vif" bridge "$vlan_bridge"
			fi
		fi
	fi
	wps_cred_add_sae=1

	config_get ifname "$vif" ifname
	config_get bridge "$vif" bridge
	config_get ssid "$vif" ssid
	config_get bssid "$vif" bssid
	bssid=${bssid:+"bssid=$bssid"}

	config_get pmf "$vif" ieee80211w 0
	config_get_bool wps_pbc "$vif" wps_pbc 0

	config_get config_methods "$vif" wps_config
	[ "$wps_pbc" -gt 0 ] && append config_methods "push_button display"

	[ -n "$config_methods" ] && {
		wps_cred="wps_cred_processing=2"
		wps_config_methods="config_methods=$config_methods"
		update_config="update_config=1"
		# fix the overlap session of WPS PBC for two STA vifs
		macaddr=$(cat /sys/class/net/${bridge}/address)
		uuid=$(echo "$macaddr" | sed 's/://g')
		[ -n "$uuid" ] && {
			uuid_config="uuid=87654321-9abc-def0-1234-$uuid"
		}
	}

	local ctrl_interface wait_for_wrap=""

	if [ $qwrap_enable -ne 0 ]; then
		ctrl_interface="/var/run/wpa_supplicant"
		if [ -f "/tmp/qwrap_conf_filename-$ifname.conf" ]; then
			rm -rf /tmp/qwrap_conf_filename-$ifname.conf
		fi
		echo -e "/var/run/wpa_supplicant-$ifname.conf \c\h" > /tmp/qwrap_conf_filename-$ifname.conf
		wait_for_wrap="-W"
	fi

	ctrl_interface="/var/run/wpa_supplicant-$ifname"

	rm -rf $ctrl_interface
	rm -f /var/run/wpa_supplicant-$ifname.conf
	cat > /var/run/wpa_supplicant-$ifname.conf <<EOF
ctrl_interface=$ctrl_interface
$wps_config_methods
pmf=$pmf
$wps_cred
$update_config
$uuid_config
$sae_groups
$pwe
wps_cred_add_sae=$wps_cred_add_sae
$dpp_map
$dpp_1905_connector
network={
	$modestr
	scan_ssid=1
	ssid="$ssid"
	$bssid
	key_mgmt=$key_mgmt
	$proto
	$freq
	$ieee80211w
	$beacon_prot
	$passphrase
	$sae_pwd
	$sae_password_id
	$pairwise
	$group
	$eap_type
	$ca_cert
	$client_cert
	$priv_key
	$priv_key_pwd
	$phase2
	$identity
	$password
	$wep_key0
	$wep_key1
	$wep_key2
	$wep_key3
	$wep_tx_keyidx
	$wep_auth_alg
	$owe_only
	$group_mgmt
	$phase1
	$owe_group
	$dpp_connector
	$dpp_csign
	$dpp_netaccesskey
	multi_ap_backhaul_sta=$multi_ap_backhaul_sta
	multi_ap_profile=$map
	$dpp_pfs
}
EOF

	[ -z "$proto" -a "$key_mgmt" != "NONE" ] || {\
                # If there is a change in path of wpa_supplicant-$ifname.lock file, please make the path
                # change also in wrapd_api.c file.
		[ -f "/var/run/wpa_supplicant-$ifname.lock" ] &&
			rm /var/run/wpa_supplicant-$ifname.lock
		wpa_cli -g /var/run/wpa_supplicantglobal interface_add  $ifname /var/run/wpa_supplicant-$ifname.conf $driver /var/run/wpa_supplicant-$ifname "" $bridge
		touch /var/run/wpa_supplicant-$ifname.lock
    }

	if [ "${dpp}" -eq 1 ]
	then
		type=
		config_get dpp_type "$vif" dpp_type "qrcode"
		config_get dpp_curve "$vif" dpp_curve
		config_get dpp_key "$vif" dpp_key
		config_get channel "$device" channel auto
		config_get htmode  "$device" htmode auto
		config_get hwmode "$device" hwmode auto
		config_get pkex_code "$vif" pkex_code
		config_get pkex_identifier "$vif" pkex_identifier
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
			pkex_identifier="pkex_identifier=$pkex_identifier"
		fi

		if [ "$pkex_code" ]; then
			pkex_code="pkex_code=$pkex_code"
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

		run_wpa_cli() {
			ifname=$1
			ctrl_path=$2
			arguments=$3
			wpa_cli -i $ifname -p $ctrl_path $arguments
		}

		run_wpa_cli $ifname "/var/run/wpa_supplicant-$ifname" "-a /lib/wifi/dpp-supplicant-update-uci -B"
		wpa_cli -i $ifname -p /var/run/wpa_supplicant-$ifname dpp_bootstrap_remove \*
		wpa_cli -i $ifname -p /var/run/wpa_supplicant-$ifname dpp_pkex_remove \*
		wpa_cli -i $ifname -p /var/run/wpa_supplicant-$ifname dpp_configurator_remove \*
		if [ "$map" -eq 3 ]; then
			run_wpa_cli $ifname  "/var/run/wpa_supplicant-$ifname" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve $dpp_key"
		else
			run_wpa_cli $ifname  "/var/run/wpa_supplicant-$ifname" "DPP_BOOTSTRAP_GEN $dpp_type $dpp_curve  $channel mac=$(cat /sys/class/net/$ifname/address | sed 's/://g') $dpp_key"
		fi

		if [ -z "$map" ] || [ "$map" -eq 0 ]; then
			if [ "${type}" == "qrcode" ]
			then
				run_wpa_cli $ifname "/var/run/wpa_supplicant-$ifname" "dpp_auth_init peer=1  role=enrollee"
			else
				run_wpa_cli $ifname "/var/run/wpa_supplicant-$ifname" "dpp_pkex_add own=1 $pkex_identifier role=enrollee $pkex_code"
			fi
		fi
	fi
}
