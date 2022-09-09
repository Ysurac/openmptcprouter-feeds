#!/bin/sh
# Copyright (c) 2013 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.

. /lib/functions.sh

IGNORE_NON_WIFISEC=0
IS_CURRENT_WIFISEC=0
# This counter is used to record the correct indices of VAPs in wireless config
# file.
TOTAL_NUM_VIFS=0

cfg_append() {
    if [ "$IGNORE_NON_WIFISEC" -gt 0 ] && [ "$IS_CURRENT_WIFISEC" -eq 0 ]; then
        return
    fi
    echo "$1"
}

cfg_radio_set() {
    local radioidx=$(($1 + 1))
    local cfg="$2"
    local val="$3"
    cfg_append "RADIO.$radioidx.$cfg=$val"
}


cfg_radio_add() {
    local device="$1"
    local radioidx=$(($2 + 1))
    local cfg="$3"
    local key="$4"
    local def="$5"
    local val

    config_get val $device $key $def
    [ -n "$val" ] && cfg_append "RADIO.$radioidx.$cfg=$val"
}

cfg_vif_set() {
    local vifidx=$(($1 + 1))
    local cfg="$2"
    local val="$3"
    cfg_append "WLAN.$vifidx.$cfg=$val"
}


cfg_vif_add() {
    local vif="$1"
    local vifidx=$(($2 + 1))
    local cfg="$3"
    local key="$4"
    local def="$5"
    local val

    config_get val $vif $key $def
    [ -n "$val" ] && cfg_append "WLAN.$vifidx.$cfg=$val"
}


cfg_vifsec_set() {
    IS_CURRENT_WIFISEC=1
    cfg_vif_set "$@"
    IS_CURRENT_WIFISEC=0
}


cfg_vifsec_add() {
    IS_CURRENT_WIFISEC=1
    cfg_vif_add "$@"
    IS_CURRENT_WIFISEC=0
}


scan_wifi() {
    local cfgfile="$1"
    DEVICES=
    config_load "${cfgfile:-wireless}"

    # Create a virtual interface list field for each wifi-device
    #
    # input: $1 section: section name of each wifi-device
    create_vifs_list() {
        local section="$1"
        append DEVICES "$section"
        config_set "$section" vifs ""
    }
    config_foreach create_vifs_list wifi-device

    # Append each wifi-iface to the virtual interface list of its associated wifi-device
    #
    # input: $1 section: section name of each wifi-iface
    append_vif() {
        local section="$1"
        config_get device "$section" device
        config_get vifs "$device" vifs
        append vifs "$section"
        config_set "$device" vifs "$vifs"
        # For wifi-iface (VAP), record its index and section name in variable
        # vifname_#. This will be used later when generating wsplcd config file
        # to match the VAP with correct index.
        eval "vifname_${TOTAL_NUM_VIFS}=$section"
        TOTAL_NUM_VIFS=$(($TOTAL_NUM_VIFS + 1))
    }
    config_foreach append_vif wifi-iface
}

cfg_get_wifi() {
    local vifidx=0
    local managed_network=$1
    local network=""

    scan_wifi
    for device in $DEVICES; do
        local radioidx=${device#wifi}
        local vidx_per_radio=0
        local channel
        local wsplcd_unmanaged

        # All of the radio parameters are not used in IEEE1905.1 cloning
        config_get channel "$device" channel '0'
       config_get macaddr "$device" macaddr
        [ "$channel" = "auto" ] && channel=0
        cfg_radio_set $radioidx Channel $channel
        config_get disabled "$device" disabled '0'
        [ "$disabled" = "1" ] && radioena=0 || radioena=1
        cfg_radio_set $radioidx  RadioEnabled $radioena
       cfg_radio_set $radioidx  macaddr $macaddr
        # UCI based targets have different definition of "txpower" from mib based targets
        cfg_radio_add  $device  $radioidx X_ATH-COM_Powerlevel    txpower
        cfg_radio_add  $device  $radioidx X_ATH-COM_Rxchainmask   rxchainmask
        cfg_radio_add  $device  $radioidx X_ATH-COM_Txchainmask   txchainmask
        # X_ATH-COM_TBRLimit is not implemented in QSDK
        # cfg_radio_add  $device  $radioidx X_ATH-COM_TBRLimit      tbrlimit
        cfg_radio_add  $device  $radioidx X_ATH-COM_AMPDUEnabled  AMPDU
        cfg_radio_add  $device  $radioidx X_ATH-COM_AMPDULimit    AMPDULim
        # X_ATH-COM_AMPDUFrames is not implemented in QSDK
        # cfg_radio_add  $device  $radioidx X_ATH-COM_AMPDUFrames   AMPDUFrames

        config_get hwmode "$device" hwmode auto
        config_get htmode "$device" htmode auto

        case "$hwmode:$htmode" in
        # The parsing stops at the first match so we need to make sure
        # these are in the right orders (most generic at the end)
            *ng:HT20) hwmode=ng20;;
            *ng:HT40-) hwmode=ng40minus;;
            *ng:HT40+) hwmode=ng40plus;;
            *ng:HT40) hwmode=ng40;;
            *ng:*) hwmode=ng20;;
            *na:HT20) hwmode=na20;;
            *na:HT40-) hwmode=na40minus;;
            *na:HT40+) hwmode=na40plus;;
            *na:HT40) hwmode=na40;;
            *na:*) hwmode=na40;;
            *ac:HT20) hwmode=acvht20;;
            *ac:HT40+) hwmode=acvht40plus;;
            *ac:HT40-) hwmode=acvht40minus;;
            *ac:HT40) hwmode=acvht40;;
            *ac:HT80) hwmode=acvht80;;
            *ac:HT160) hwmode=acvht160;;
            *ac:HT80_80) hwmode=acvht80_80;;
            *ac:*) hwmode=acvht80;;
            *b:*) hwmode=b;;
            *bg:*) hwmode=g;;
            *g:*) hwmode=g;;
            *a:*) hwmode=a;;
            *) hwmode=auto;;
        esac

        config_get_bool device_unmanaged "$device" wsplcd_unmanaged '0'

        config_get vifs "$device" vifs

        # determine vif name
        for vif in $vifs; do
            local vifname

            config_get network "$vif" network
            [ "$network" = "$managed_network" ] || continue

            config_get_bool disabled "$vif" disabled 0
            [ "$disabled" = 0 ] ||
            {
                config_set "$vif" ifname ""
                continue
            }

            [ $vidx_per_radio -gt 0 ] && vifname="ath${radioidx}${vidx_per_radio}" || vifname="ath${radioidx}"

            config_get ifname "$vif" ifname
            config_set "$vif" ifname "${ifname:-$vifname}"
            vidx_per_radio=$(($vidx_per_radio + 1))
        done

        for vif in $vifs; do
            local bssid enc
            local beacontype wepencrmode wepauthmode wpaencrmode wpaauthmode wpa2encrmode wpa2authmode
            local vapidx=0
            local vifidx

            config_get network "$vif" network
            [ "$network" = "$managed_network" ] || continue

            # First need to find the correct VAP index for the current vif. This
            # can be done by looking for the matching interface name from
            # vifname_${vapidx} variables,
            while [ $vapidx -lt $TOTAL_NUM_VIFS ]
            do
                local name=$(eval "echo \$vifname_${vapidx}")
                if [ "$name" == "$vif" ];
                then
                    vifidx=$vapidx
                    break
                fi
                vapidx=$(($vapidx + 1))
            done

            [ -n "$vifidx" ] || continue

            config_get_bool disabled "$vif" disabled 0
            [ "$disabled" = "1" ] && vifena=0 || vifena=1
            cfg_vif_set $vifidx Enable $vifena

            cfg_vif_set $vifidx X_ATH-COM_RadioIndex $(($radioidx +1))
            config_get ifname "$vif" ifname

            bssid=`ifconfig $ifname 2>&1 | awk '/HWaddr/ {print \$5}'`
            cfg_vif_set $vifidx BSSID $bssid

            cfg_vifsec_add $vif $vifidx SSID ssid
            cfg_vifsec_add $vif $vifidx backhaul_ap backhaul_ap
            cfg_vifsec_add $vif $vifidx SteeringDisabled SteeringDisabled
            [ "$hwmode" == "auto" ] && {
                local is5G=`iwconfig $ifname 2>&1 | grep Frequency:5`
               [ -n "$is5G" ] && hwmode="na40minus" || hwmode="ng20"
            }
            config_load wsplcd
            config_get deep_clone_son config 'DeepClone_SON' 1
            config_get map_enable config 'MapEnable' 0
            config_load wireless

            if [ "$deep_clone_son" = 1 ] && [ "$map_enable" = 0 ]; then
                local current_channel=`iwlist $ifname 2>&1 channel | grep "Current Frequency" | awk -F" " '{print $5}' | awk -F')' '{print $1}'`
                local current_operating_mode=`cfg80211tool $ifname 2>&1 get_mode | grep "get_mode" | awk -F" " '{print $2}' | awk -F':' '{print $2}'`
                local current_freq=`iwlist $ifname 2>&1 channel | grep "Current Frequency" | awk -F':' '{print $2}' | awk -F" " '{print $1}' | sed 's/\.//g' | cut -c1-1`
                local band_freq=`iwlist $ifname 2>&1 channel | grep "Current Frequency" | awk -F':' '{print $2}' | awk -F" " '{print $1}' | sed 's/\.//g' | sed -e "s/\<\([0-9]\{1,4\}\)\>/\10000/; s/\([0-9]\{4\}\)/\1/" | awk '{ print $1; }' | sed -n 's/\([0-9]\{4\}\).*/\1/p' `

                if [ "$band_freq" -gt 5950 ] && [ "$band_freq" -lt 7130 ]; then
                    if [ "$current_operating_mode" == "11AHE80_80" ]; then
                        cfg_vifsec_set $vifidx Standard axahe80_80_6g
                    elif [ "$current_operating_mode" == "11AHE160" ]; then
                        cfg_vifsec_set $vifidx Standard axahe160_6g
                    elif [ "$current_operating_mode" == "11AHE80" ]; then
                        cfg_vifsec_set $vifidx Standard axahe80_6g
                    elif [ "$current_operating_mode" == "11AHE40PLUS" ]; then
                        cfg_vifsec_set $vifidx Standard axahe40plus_6g
                    elif [ "$current_operating_mode" == "11AHE40MINUS" ]; then
                        cfg_vifsec_set $vifidx Standard axahe40minus_6g
                    elif [ "$current_operating_mode" == "11AHE20" ]; then
                        cfg_vifsec_set $vifidx Standard axahe20_6g
                    fi
                fi

                if [ "$band_freq" -gt 5175 ] && [ "$band_freq" -lt 5900 ] && [ "$current_freq" == 5 ] ; then
                    if [ "$current_channel" -gt 35 ] && [ "$current_channel" -lt 99 ]; then
                        if [ "$current_operating_mode" == "11AHE80_80" ]; then
                            cfg_vifsec_set $vifidx Standard axahe80_80low
                        elif [ "$current_operating_mode" == "11AHE160" ]; then
                            cfg_vifsec_set $vifidx Standard axahe160low
                        elif [ "$current_operating_mode" == "11AHE80" ]; then
                            cfg_vifsec_set $vifidx Standard axahe80low
                        elif [ "$current_operating_mode" == "11AHE40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard axahe40pluslow
                        elif [ "$current_operating_mode" == "11AHE40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard axahe40minuslow
                        elif [ "$current_operating_mode" == "11AHE20" ]; then
                            cfg_vifsec_set $vifidx Standard axahe20low
                        elif [ "$current_operating_mode" == "11ACVHT80_80" ]; then
                            cfg_vifsec_set $vifidx Standard acvht80_80low
                        elif [ "$current_operating_mode" == "11ACVHT160" ]; then
                            cfg_vifsec_set $vifidx Standard acvht160low
                        elif [ "$current_operating_mode" == "11ACVHT80" ]; then
                            cfg_vifsec_set $vifidx Standard acvht80low
                        elif [ "$current_operating_mode" == "11ACVHT40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard acvht40pluslow
                        elif [ "$current_operating_mode" == "11ACVHT40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard acvht40minuslow
                        elif [ "$current_operating_mode" == "11ACVHT20" ]; then
                            cfg_vifsec_set $vifidx Standard acvht20low
                        elif [ "$current_operating_mode" == "11NAHT20" ]; then
                            cfg_vifsec_set $vifidx Standard na20low
                        elif [ "$current_operating_mode" == "11NAHT40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard na40minuslow
                        elif [ "$current_operating_mode" == "11NAHT40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard na40pluslow
                        elif [ "$current_operating_mode" == "11NAHT40" ]; then
                            cfg_vifsec_set $vifidx Standard na40low
                        elif [ "$current_operating_mode" == "11A" ]; then
                            cfg_vifsec_set $vifidx Standard alow
                        fi
                    fi
                    if [ "$current_channel" -gt 99 ]; then
                        if [ "$current_operating_mode" == "11AHE80_80" ]; then
                            cfg_vifsec_set $vifidx Standard axahe80_80
                        elif [ "$current_operating_mode" == "11AHE160" ]; then
                            cfg_vifsec_set $vifidx Standard axahe160
                        elif [ "$current_operating_mode" == "11AHE80" ]; then
                            cfg_vifsec_set $vifidx Standard axahe80
                        elif [ "$current_operating_mode" == "11AHE40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard axahe40plus
                        elif [ "$current_operating_mode" == "11AHE40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard axahe40minus
                        elif [ "$current_operating_mode" == "11AHE20" ]; then
                            cfg_vifsec_set $vifidx Standard axahe20
                        elif [ "$current_operating_mode" == "11ACVHT80_80" ]; then
                            cfg_vifsec_set $vifidx Standard acvht80_80
                        elif [ "$current_operating_mode" == "11ACVHT160" ]; then
                            cfg_vifsec_set $vifidx Standard acvht160
                        elif [ "$current_operating_mode" == "11ACVHT80" ]; then
                            cfg_vifsec_set $vifidx Standard acvht80
                        elif [ "$current_operating_mode" == "11ACVHT40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard acvht40plus
                        elif [ "$current_operating_mode" == "11ACVHT40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard acvht40minus
                        elif [ "$current_operating_mode" == "11ACVHT20" ]; then
                            cfg_vifsec_set $vifidx Standard acvht20
                        elif [ "$current_operating_mode" == "11NAHT20" ]; then
                            cfg_vifsec_set $vifidx Standard na20
                        elif [ "$current_operating_mode" == "11NAHT40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard na40minus
                        elif [ "$current_operating_mode" == "11NAHT40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard na40plus
                        elif [ "$current_operating_mode" == "11NAHT40" ]; then
                            cfg_vifsec_set $vifidx Standard na40
                        elif [ "$current_operating_mode" == "11A" ]; then
                            cfg_vifsec_set $vifidx Standard a
                        fi
                    fi
                fi
                if [ "$current_freq" == 2 ] ; then
                    if [ "$current_channel" -lt 15 ]; then
                        if [ "$current_operating_mode" == "11NGHT20" ]; then
                            cfg_vifsec_set $vifidx Standard ng20
                        elif [ "$current_operating_mode" == "11NGHT40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard ng40minus
                        elif [ "$current_operating_mode" == "11NGHT40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard ng40plus
                        elif [ "$current_operating_mode" == "11NGHT40" ]; then
                            cfg_vifsec_set $vifidx Standard ng40
                        elif [ "$current_operating_mode" == "11GHE20" ]; then
                            cfg_vifsec_set $vifidx Standard axghe20
                        elif [ "$current_operating_mode" == "11GHE40PLUS" ]; then
                            cfg_vifsec_set $vifidx Standard axghe40plus
                        elif [ "$current_operating_mode" == "11GHE40MINUS" ]; then
                            cfg_vifsec_set $vifidx Standard axghe40minus
                        elif [ "$current_operating_mode" == "11G" ]; then
                            cfg_vifsec_set $vifidx Standard g
                        elif [ "$current_operating_mode" == "11B" ]; then
                            cfg_vifsec_set $vifidx Standard b
                        fi
                    fi
                fi
                    cfg_vif_set $vifidx Channel $current_channel
            else
                cfg_vifsec_set $vifidx Standard $hwmode
                cfg_vif_set $vifidx Channel $channel
            fi
            cfg_vif_set $vifidx Network $network
            config_get enc "$vif" encryption "none"
            case "$enc" in
                none)
                    beacontype="None"
                ;;
                *wep*)
                    beacontype="Basic"
                    wepencrmode="WEPEncryption"
                    case "$enc" in
                        *shared*)
                            wepauthmode="SharedAuthentication"
                        ;;
                        *mixed*)
                            wepauthmode="Both"
                        ;;
                        *)
                            wepauthmode="None"
                        ;;
                    esac
                ;;
                *mixed*)
                    beacontype="WPAand11i"
                    wpa2authmode="PSKAuthentication"
                    wpa2encrmode="TKIPandAESEncryption"
                    case "$enc" in
                        *psk*)
                            wpa2authmode="PSKAuthentication"
                        ;;
                        *wpa*)
                            wpa2authmode="EAPAuthentication"
                        ;;
                    esac
                ;;
                *psk2*)
                    beacontype="11i"
                    wpa2authmode="PSKAuthentication"
                    wpa2encrmode="AESEncryption"
                ;;
                *wpa2*)
                    beacontype="11i"
                    wpa2authmode="EAPAuthentication"
                    wpa2encrmode="AESEncryption"
                ;;
                *psk*)
                    beacontype="WPA"
                    wpaauthmode="PSKAuthentication"
                    wpaencrmode="TKIPEncryption"
                ;;
                *wpa*)
                    beacontype="WPA"
                    wpaauthmode="EAPAuthentication"
                    wpaencrmode="TKIPEncryption"
                ;;
                8021x)
                    beacontype="Basic"
                    wepencrmode="WEPEncryption"
                    wepauthmode="EAPAuthentication"
                ;;
                ccmp)
                    beacontype="11i"
                    wpa2authmode="WPA3Authentication"
                    wpa2encrmode="AESEncryption"
                ;;
            esac


            # explicit override for crypto setting
            case "$enc" in
                *tkip+aes|*tkip+ccmp|*aes+tkip|*ccmp+tkip) crypto="TKIPandAESEncryption";;
                *aes|*ccmp) crypto="AESEncryption";;
                *tkip) crypto="TKIPEncryption";;
            esac

            [ -n "$crypto" ] &&
            case "$beacontype" in
                WPA)
                    wpaencrmode=$crypto
                ;;
                11i|WPAand11i)
                    wpa2encrmode=$crypto
                ;;
            esac

            cfg_vifsec_set $vifidx BeaconType $beacontype
            cfg_vifsec_set $vifidx BasicEncryptionModes $wepencrmode
            cfg_vifsec_set $vifidx BasicAuthenticationMode $wepauthmode
            cfg_vifsec_set $vifidx WPAEncryptionModes ${wpaencrmode}
            cfg_vifsec_set $vifidx WPAAuthenticationMode $wpaauthmode
            cfg_vifsec_set $vifidx IEEE11iEncryptionModes ${wpa2encrmode}
            cfg_vifsec_set $vifidx IEEE11iAuthenticationMode $wpa2authmode

            config_get key "$vif" key
            case "$enc" in
                *wep*)#WEP key
                ;;
                *)#WPA psk
                    if [ ${#key} -eq 64 ]; then
                        cfg_vifsec_set $vifidx PreSharedKey.1.PreSharedKey "$key"
                    else
                        cfg_vifsec_set $vifidx KeyPassphrase "$key"
                    fi
                ;;
            esac

            cfg_vif_add $vif $vifidx BasicDataTransmitRates mcast_rate

            config_get wds "$vif" wds
            case "$wds" in
                1|on|enabled) wds=1;;
                *) wds=0;;
            esac

            config_get mode "$vif" mode
            case "$mode" in
                ap)
                    [ "$wds" = 1 ] && opmode=RootAP || opmode=InfrastructureAccessPoint
                ;;
                sta)
                    [ "$wds" = 1 ] && opmode=WDSStation || opmode=WirelessStation
                ;;
                adhoc)
                    # don't support adhoc
                ;;
                wds)
                    opmode=WDSStation
                ;;
            esac
           cfg_vif_set $vifidx DeviceOperationMode $opmode

        # WPA3: Add SAE Configurations
            #SAE Enable
            config_get sae "$vif" sae
            [ -n "$sae" ] &&
            case "$sae" in
                1|on|enabled)
                        sae=1;;
                *)
                        sae=0;;
            esac
            [ -n "$sae" ] && cfg_vifsec_set $vifidx EnableSAE $sae

            append_list_parameter() {
                cfg_vifsec_set $vifidx "${2}" "${1}"
            }

            #SAE_PASSWORD / SAE GROUPS / OWE GROUPS
            case "$mode" in
                ap)
                    config_list_foreach "$vif" sae_password append_list_parameter SAEPassword
                    config_list_foreach "$vif" sae_groups append_list_parameter SAEGroups
                    config_list_foreach "$vif" owe_groups append_list_parameter OWEGroups
                ;;
                sta)
                    config_get sae_password "$vif" sae_password
                    [ -n "$sae_password" ] && cfg_vifsec_set $vifidx SAEPassword "$sae_password"
                    config_get sae_groups "$vif" sae_groups
                    [ -n "$sae_groups" ] && cfg_vifsec_set $vifidx SAEGroups "$sae_groups"
                    config_get owe_groups "$vif" owe_groups
                    [ -n "$owe_groups" ] && cfg_vifsec_set $vifidx OWEGroups "$owe_groups"
                ;;
            esac

            #SAE ANTI CLOGGING THRESHOLD
            config_get sae_anti_clogging_threshold "$vif" sae_anti_clogging_threshold
            [ -n "$sae_anti_clogging_threshold" ] && cfg_vifsec_set $vifidx SAEAntiCloggingThreshold $sae_anti_clogging_threshold

            #SAE SYNC
            config_get sae_sync "$vif" sae_sync
            [ -n "$sae_sync" ] && cfg_vifsec_set $vifidx SAESync $sae_sync

            #SAE REQUIRE MFP
            config_get sae_require_mfp "$vif" sae_require_mfp
            [ -n "$sae_require_mfp" ] && cfg_vifsec_set $vifidx SAERequireMFP $sae_require_mfp

        #OWE: Add OWE Configurations
            #OWE Enable
            config_get owe "$vif" owe
            [ -n "$owe" ] &&
            case "$owe" in
                1|on|enabled)
                        owe=1;;
                *)
                        owe=0;;
            esac
            [ -n "$owe" ] && cfg_vifsec_set $vifidx EnableOWE $owe

            config_get owe_transition_ifname  "$vif" owe_transition_ifname
            [ -n "$owe_transition_ifname" ] && cfg_vifsec_set $vifidx OWETransIfname "$owe_transition_ifname"

            config_get owe_transition_ssid  "$vif" owe_transition_ssid
            [ -n "$owe_transition_ssid" ] && cfg_vifsec_set $vifidx OWETransSSID "$owe_transition_ssid"

            config_get owe_transition_bssid  "$vif" owe_transition_bssid
            [ -n "$owe_transition_bssid" ] && cfg_vifsec_set $vifidx OWETransBSSID "$owe_transition_bssid"

        #SUITE_B: Add SUITE_B Configurations
            config_get suite_b  "$vif" suite_b
            [ -n "$suite_b" ] && cfg_vifsec_set $vifidx SuiteB "$suite_b"


        # IEEE802.11i Management Frame Protection (MFP)
            # MFP Enable
            config_get ieee80211w "$vif" ieee80211w
            [ -n "$ieee80211w" ] && cfg_vifsec_set $vifidx IEEE80211w $ieee80211w

        # SAE mandatory parameter for 6G band
            cfg_vifsec_add $vif $vifidx SAEPWE sae_pwe
            cfg_vifsec_add $vif $vifidx SAEEn6GSecComp en_6g_sec_comp

        # X_ATH-COM Authentication fields

            config_get auth_server "$vif" auth_server
            [ -n "$auth_server" ] && cfg_vifsec_set $vifidx X_ATH-COM_AuthServerAddr $auth_server

            config_get auth_port "$vif" auth_port
            [ -n "$auth_port" ] && cfg_vifsec_set $vifidx X_ATH-COM_AuthServerPort $auth_port

            config_get auth_secret "$vif" auth_secret
            [ -n "$auth_secret" ] && cfg_vifsec_set $vifidx X_ATH-COM_AuthServerSecret $auth_secret

            config_get nasid "$vif" nasid
            [ -n "$nasid" ] && cfg_vifsec_set $vifidx X_ATH-COM_NASID $nasid

            # RTS and Rragmentation have different definitions from mib based targets
            cfg_vif_add $vif $vifidx RTS rts
            cfg_vif_add $vif $vifidx Fragmentation frag
            cfg_vif_add $vif $vifidx X_ATH-COM_SSIDHide hidden
            cfg_vif_set $vifidx X_ATH-COM_APModuleEnable $vifena
            cfg_vif_add $vif $vifidx X_ATH-COM_WPSPin wps_pin "12345670"
            [ "$disabled" = "1" ]  || cfg_vif_set $vifidx X_ATH-COM_VapIfname "$ifname"
            if [ "$enc" = "none"  ] ; then
                cfg_vif_set $vifidx X_ATH-COM_WPSConfigured NOTCONFIGURED
            else
                cfg_vif_set $vifidx X_ATH-COM_WPSConfigured CONFIGURED
            fi;


            cfg_vif_add $vif $vifidx X_ATH-COM_ShortGI shortgi
            cfg_vif_add $vif $vifidx X_ATH-COM_CWMEnable 1
            cfg_vif_add $vif $vifidx X_ATH-COM_WMM wmm

            # Note that disablecoext and HT40Coexist are logical negations of
            # one another, hence the inverted logic here. libstorage takes
            # care of mapping back to the UCI setting.
            # As per HOST design, disablecoext should be configured for only
            # one vap. Otherwise it will take the value of disablecoext from
            # the last created vap. So avoided to configure disablecoext for
            # multiple vaps. Considered only if disablecoext is 0/1.
            # If no value in disablecoext then, no need to do anything.
            config_get_bool disablecoext "$vif" disablecoext
            if [ "$disablecoext" = 1 ] ; then
                cfg_vif_set $vifidx X_ATH-COM_HT40Coexist 0
            else
                if [ "$disablecoext" = 0 ] ; then
                    cfg_vif_set $vifidx X_ATH-COM_HT40Coexist 1
                fi
            fi

            if [ "$device_unmanaged" -gt 0 ] ; then
                wsplcd_unmanaged=1
            else
                config_get_bool wsplcd_unmanaged "$vif" wsplcd_unmanaged 0
            fi
            cfg_vif_set $vifidx WsplcdUnmanaged $wsplcd_unmanaged

            # HBR is not implemented in QSDK
            # cfg_vif_set $vifidx X_ATH-COM_HBREnable 0
            # cfg_vif_set $vifidx X_ATH-COM_HBRPERLow 20
            # cfg_vif_set $vifidx X_ATH-COM_HBRPERHigh 35

            # Multicast Enhancement is not implemented in QSDK
            # cfg_vif_set $vifidx X_ATH-COM_MEMode Translate
            # cfg_vif_set $vifidx X_ATH-COM_MELength 32
            # cfg_vif_set $vifidx X_ATH-COM_METimer 30000
            # cfg_vif_set $vifidx X_ATH-COM_METimeout 120000
            # cfg_vif_set $vifidx X_ATH-COM_MEDropMcast 1

        done

    done

}

case "$1" in
    "wifisec")
        IGNORE_NON_WIFISEC=1
        network_name=$2
        cfg_get_wifi $network_name
    ;;
    "wifi")
        network_name=$2
        cfg_get_wifi $network_name
    ;;
    *)
        network_name=$1
        cfg_get_wifi $network_name
    ;;
esac
