#!/bin/sh
# shellcheck shell=ash
#
# OpenMPTCProuter keepalived HA easy-setup engine.
# Sourced by /usr/libexec/rpcd/luci.keepalived-ha and /usr/sbin/keepalived-ha.
#
# Reads the wizard settings from the 'keepalived.ha' UCI section:
#   option enabled       '1'
#   option vip           '192.168.100.1'      (or CIDR; default prefix /24)
#   option interface     'lan'    (logical iface resolved per-router, or a device)
#   option vrid          '51'
#   option advert_int    '1'
#   option track_omrvpn  '1'
#   option track_proxy   '1'
#   option track_wans    '1'
#   option manage_dhcp   '1'
#   option pubkey        'ssh-ed25519 ...'    (primary sync pubkey, backups only)
#   list   router        '192.168.100.2'      (ordered, first = preferred master)
#   list   router        '192.168.100.3'
#
# and (re)generates all keepalived sections named 'omr_ha_*', the DHCP
# gateway/DNS options pointing at the VIP, the rsync.sh cron entry and,
# on the preferred master, the SSH key used by keepalived-sync.
#
# Test overrides: KAHA_UCI_DIR, KAHA_NO_SERVICES=1, KAHA_CRONTAB,
# KAHA_HOME, KAHA_LOCAL_IPS, KAHA_CHECK_SCRIPT.
#
# Copyright 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
# Licensed to the public under the GNU General Public License v3.

KAHA_CRONTAB="${KAHA_CRONTAB:-/etc/crontabs/root}"
KAHA_CHECK_SCRIPT="${KAHA_CHECK_SCRIPT:-/usr/share/keepalived-ha/omr-vpn-up.sh}"
KAHA_PROXY_CHECK_SCRIPT="${KAHA_PROXY_CHECK_SCRIPT:-/usr/share/keepalived-ha/omr-proxy-up.sh}"
KAHA_WANS_CHECK_SCRIPT="${KAHA_WANS_CHECK_SCRIPT:-/usr/share/keepalived-ha/omr-wans-up.sh}"
KAHA_RSYNC_LINE='* * * * * /etc/keepalived/scripts/rsync.sh'
KAHA_ERROR=''

kaha_jshn() {
	type json_init >/dev/null 2>&1 || . /usr/share/libubox/jshn.sh
}

kaha_uci() {
	if [ -n "$KAHA_UCI_DIR" ]; then
		uci -c "$KAHA_UCI_DIR" "$@"
	else
		uci "$@"
	fi
}

kaha_get() { # <key> <default>
	local v
	v=$(kaha_uci -q get "$1")
	if [ -n "$v" ]; then echo "$v"; else echo "$2"; fi
}

kaha_home() {
	local h="$KAHA_HOME"
	[ -n "$h" ] || h=$(awk -F: '/^keepalived:/{print $6}' /etc/passwd 2>/dev/null)
	[ -n "$h" ] || h=/usr/share/keepalived/rsync
	echo "$h"
}

# keepalived-sync's rsync.sh defaults to <sync_dir>/.ssh/id_rsa as client key
kaha_keyfile() {
	echo "$(kaha_home)/.ssh/id_rsa"
}

kaha_genkey() {
	local key dir
	key=$(kaha_keyfile)
	dir="${key%/*}"
	[ -f "$key" ] && return 0
	if ! mkdir -p "$dir" || ! chmod 700 "$dir"; then
		KAHA_ERROR="cannot create $dir"
		return 1
	fi
	dropbearkey -t ed25519 -f "$key" >/dev/null 2>&1 || {
		KAHA_ERROR="SSH key generation failed (dropbearkey)"
		return 1
	}
	chmod 600 "$key"
	chown -R keepalived:keepalived "$(kaha_home)/.ssh" 2>/dev/null
	return 0
}

kaha_pubkey() {
	local key
	key=$(kaha_keyfile)
	[ -f "$key" ] || return 1
	dropbearkey -y -f "$key" 2>/dev/null | grep '^ssh-' | head -n1
}

kaha_local_ips() {
	if [ -n "$KAHA_LOCAL_IPS" ]; then
		echo "$KAHA_LOCAL_IPS"
		return 0
	fi
	ip -4 -o addr show 2>/dev/null | awk '{split($4,a,"/"); print a[1]}'
}

kaha_routers() {
	kaha_get keepalived.ha.router ''
}

kaha_first_router() {
	# shellcheck disable=SC2046,SC2086
	set -- $(kaha_routers)
	echo "$1"
}

kaha_detect_my_ip() {
	local locals r l
	locals=$(kaha_local_ips)
	for r in $(kaha_routers); do
		for l in $locals; do
			[ "$r" = "$l" ] && {
				echo "$r"
				return 0
			}
		done
	done
	return 1
}

# Resolve the configured LAN interface to a kernel network device.
# Accepts a device name as-is (eth0, br-lan) or a logical UCI interface
# name (lan) resolved to its l3 device, so the same value works on every
# router of a heterogeneous pair. Test hooks: KAHA_NETDEVS (authoritative
# device list), KAHA_NETWORK_LIB (network.sh path).
kaha_resolve_device() { # <value>  ->  echoes netdev
	local v="$1" dev netlib

	[ -n "$v" ] || v=lan

	if [ -n "$KAHA_NETDEVS" ]; then
		case " $KAHA_NETDEVS " in
			*" $v "*)
				echo "$v"
				return 0
				;;
		esac
	elif ip link show dev "$v" >/dev/null 2>&1; then
		echo "$v"
		return 0
	fi

	netlib="${KAHA_NETWORK_LIB:-/lib/functions/network.sh}"
	if [ -f "$netlib" ]; then
		. "$netlib"
		network_flush_cache 2>/dev/null
		network_get_device dev "$v" 2>/dev/null
		[ -n "$dev" ] || network_get_physdev dev "$v" 2>/dev/null
		if [ -n "$dev" ]; then
			echo "$dev"
			return 0
		fi
	fi
	return 1
}

kaha_clear_generated() {
	local s
	for s in $(kaha_uci -q show keepalived 2>/dev/null |
		sed -n 's/^keepalived\.\(omr_ha_[a-zA-Z0-9_]*\)=.*/\1/p' | sort -u); do
		kaha_uci -q delete "keepalived.$s"
	done
}

# Drop any gateway (3) / DNS (6) DHCP options we may have set on lan
kaha_dhcp_clear() {
	local o
	kaha_uci -q get dhcp.lan >/dev/null 2>&1 || return 0
	for o in $(kaha_uci -q get dhcp.lan.dhcp_option); do
		case "$o" in
			3,* | 6,*) kaha_uci -q del_list dhcp.lan.dhcp_option="$o" ;;
		esac
	done
}

kaha_dhcp_set() { # <vip ip>
	kaha_uci -q get dhcp.lan >/dev/null 2>&1 || return 0
	kaha_dhcp_clear
	kaha_uci add_list dhcp.lan.dhcp_option="3,$1"
	kaha_uci add_list dhcp.lan.dhcp_option="6,$1"
	kaha_uci commit dhcp
	[ "$KAHA_NO_SERVICES" = "1" ] || /etc/init.d/dnsmasq restart >/dev/null 2>&1
}

kaha_cron_installed() {
	grep -qF "$KAHA_RSYNC_LINE" "$KAHA_CRONTAB" 2>/dev/null
}

kaha_cron_install() {
	kaha_cron_installed && return 0
	mkdir -p "${KAHA_CRONTAB%/*}" 2>/dev/null
	echo "$KAHA_RSYNC_LINE" >>"$KAHA_CRONTAB"
	[ "$KAHA_NO_SERVICES" = "1" ] || /etc/init.d/cron restart >/dev/null 2>&1
}

# kaha_apply [my_ip] [primary pubkey]
# Regenerates the whole HA configuration for this node.
kaha_apply() {
	local my_ip="$1" pubkey="$2"
	local enabled vip vip_ip vip_pfx iface ifdev vrid adv track trackp trackw dhcp routers
	local n idx i j r prio sname

	# absorb LuCI-staged edits of keepalived config before reading it
	kaha_uci -q commit keepalived 2>/dev/null

	enabled=$(kaha_get keepalived.ha.enabled 1)
	if [ "$enabled" = "0" ]; then
		kaha_clear_generated
		kaha_uci commit keepalived
		# only touch DHCP options we manage ourselves
		if [ "$(kaha_get keepalived.ha.manage_dhcp 1)" != "0" ]; then
			kaha_dhcp_clear
			kaha_uci -q commit dhcp
			[ "$KAHA_NO_SERVICES" = "1" ] ||
				/etc/init.d/dnsmasq restart >/dev/null 2>&1
		fi
		[ "$KAHA_NO_SERVICES" = "1" ] ||
			/etc/init.d/keepalived restart >/dev/null 2>&1
		return 0
	fi

	vip=$(kaha_get keepalived.ha.vip '')
	iface=$(kaha_get keepalived.ha.interface lan)
	vrid=$(kaha_get keepalived.ha.vrid 51)
	adv=$(kaha_get keepalived.ha.advert_int 1)
	track=$(kaha_get keepalived.ha.track_omrvpn 1)
	trackp=$(kaha_get keepalived.ha.track_proxy 1)
	trackw=$(kaha_get keepalived.ha.track_wans 1)
	dhcp=$(kaha_get keepalived.ha.manage_dhcp 1)
	routers=$(kaha_routers)
	[ -n "$pubkey" ] || pubkey=$(kaha_get keepalived.ha.pubkey '')

	[ -n "$vip" ] || {
		KAHA_ERROR="virtual IP is not set"
		return 1
	}
	vip_ip=${vip%%/*}
	vip_pfx=${vip#*/}
	[ "$vip_pfx" = "$vip" ] && vip_pfx=24

	n=0
	for r in $routers; do n=$((n + 1)); done
	[ "$n" -ge 2 ] || {
		KAHA_ERROR="at least two router IPs are required"
		return 1
	}
	case " $routers " in
		*" $vip_ip "*)
			KAHA_ERROR="the virtual IP must not be one of the router IPs"
			return 1
			;;
	esac
	case "$vrid" in
		'' | *[!0-9]*)
			KAHA_ERROR="invalid virtual router id '$vrid'"
			return 1
			;;
	esac
	if [ "$vrid" -lt 1 ] || [ "$vrid" -gt 255 ]; then
		KAHA_ERROR="virtual router id must be between 1 and 255"
		return 1
	fi

	[ -n "$my_ip" ] || my_ip=$(kaha_detect_my_ip)
	[ -n "$my_ip" ] || {
		KAHA_ERROR="none of the router IPs is assigned to this device"
		return 1
	}
	idx=''
	i=0
	for r in $routers; do
		[ "$r" = "$my_ip" ] && idx=$i
		i=$((i + 1))
	done
	[ -n "$idx" ] || {
		KAHA_ERROR="$my_ip is not in the router list"
		return 1
	}

	ifdev=$(kaha_resolve_device "$iface") || {
		KAHA_ERROR="cannot resolve LAN device '$iface' (use the logical interface name, e.g. 'lan', or an existing device like 'br-lan' or 'eth0')"
		return 1
	}

	kaha_clear_generated

	kaha_uci -q get keepalived.globals >/dev/null 2>&1 ||
		kaha_uci set keepalived.globals=globals
	kaha_uci set keepalived.globals.enabled='1'
	[ -n "$(kaha_uci -q get keepalived.globals.vrrp_startup_delay)" ] ||
		kaha_uci set keepalived.globals.vrrp_startup_delay='15'

	kaha_uci set keepalived.omr_ha_vip=ipaddress
	kaha_uci set keepalived.omr_ha_vip.name='omr_ha_vip'
	kaha_uci set keepalived.omr_ha_vip.address="$vip_ip/$vip_pfx"
	kaha_uci set keepalived.omr_ha_vip.device="$ifdev"

	if [ "$track" != "0" ]; then
		kaha_uci set keepalived.omr_ha_check=vrrp_script
		kaha_uci set keepalived.omr_ha_check.name='omr_ha_check'
		kaha_uci set keepalived.omr_ha_check.script="$KAHA_CHECK_SCRIPT"
		kaha_uci set keepalived.omr_ha_check.interval='5'
		# large negative weight: any unhealthy node scores below any healthy one
		kaha_uci set keepalived.omr_ha_check.weight='-200'
		kaha_uci set keepalived.omr_ha_check.rise='3'
		kaha_uci set keepalived.omr_ha_check.fall='2'
	fi

	if [ "$trackp" != "0" ]; then
		kaha_uci set keepalived.omr_ha_check_proxy=vrrp_script
		kaha_uci set keepalived.omr_ha_check_proxy.name='omr_ha_check_proxy'
		kaha_uci set keepalived.omr_ha_check_proxy.script="$KAHA_PROXY_CHECK_SCRIPT"
		kaha_uci set keepalived.omr_ha_check_proxy.interval='5'
		kaha_uci set keepalived.omr_ha_check_proxy.weight='-200'
		kaha_uci set keepalived.omr_ha_check_proxy.rise='3'
		kaha_uci set keepalived.omr_ha_check_proxy.fall='2'
	fi

	if [ "$trackw" != "0" ]; then
		kaha_uci set keepalived.omr_ha_check_wans=vrrp_script
		kaha_uci set keepalived.omr_ha_check_wans.name='omr_ha_check_wans'
		kaha_uci set keepalived.omr_ha_check_wans.script="$KAHA_WANS_CHECK_SCRIPT"
		kaha_uci set keepalived.omr_ha_check_wans.interval='5'
		# -15 = one rank: priorities are spaced 10 apart, so a node with a
		# degraded WAN pool drops just below its healthy neighbour instead
		# of below every node like the -200 VPN/proxy checks
		kaha_uci set keepalived.omr_ha_check_wans.weight='-15'
		kaha_uci set keepalived.omr_ha_check_wans.rise='3'
		kaha_uci set keepalived.omr_ha_check_wans.fall='2'
	fi

	prio=$((245 - idx * 10))
	[ "$prio" -lt 11 ] && prio=11

	kaha_uci set keepalived.omr_ha_vi=vrrp_instance
	kaha_uci set keepalived.omr_ha_vi.name='OMR_HA'
	kaha_uci set keepalived.omr_ha_vi.interface="$ifdev"
	# all nodes start BACKUP; preemption stays enabled so the healthiest
	# node always ends up holding the VIP (priorities encode health via
	# the track scripts) - with nopreempt a demoted backup would keep the
	# VIP after the master recovers
	kaha_uci set keepalived.omr_ha_vi.state='BACKUP'
	kaha_uci set keepalived.omr_ha_vi.priority="$prio"
	kaha_uci set keepalived.omr_ha_vi.virtual_router_id="$vrid"
	kaha_uci set keepalived.omr_ha_vi.advert_int="$adv"
	kaha_uci set keepalived.omr_ha_vi.accept='1'
	kaha_uci set keepalived.omr_ha_vi.unicast_src_ip="$my_ip"
	kaha_uci add_list keepalived.omr_ha_vi.virtual_ipaddress='omr_ha_vip'
	[ "$track" != "0" ] &&
		kaha_uci add_list keepalived.omr_ha_vi.track_script='omr_ha_check'
	[ "$trackp" != "0" ] &&
		kaha_uci add_list keepalived.omr_ha_vi.track_script='omr_ha_check_proxy'
	[ "$trackw" != "0" ] &&
		kaha_uci add_list keepalived.omr_ha_vi.track_script='omr_ha_check_wans'

	# peer sections are named by position in the router list so that
	# omr_ha_peer_0 is the preferred master on every node
	j=0
	for r in $routers; do
		if [ "$r" != "$my_ip" ]; then
			sname="omr_ha_peer_$j"
			kaha_uci set "keepalived.$sname=peer"
			kaha_uci set "keepalived.$sname.name=$sname"
			kaha_uci set "keepalived.$sname.address=$r"
			if [ "$idx" = "0" ]; then
				# preferred master pushes config to every backup
				kaha_uci set "keepalived.$sname.sync=1"
				kaha_uci set "keepalived.$sname.sync_mode=send"
			elif [ "$j" = "0" ]; then
				# backups receive from the preferred master only
				kaha_uci set "keepalived.$sname.sync=1"
				kaha_uci set "keepalived.$sname.sync_mode=receive"
				[ -n "$pubkey" ] &&
					kaha_uci set "keepalived.$sname.ssh_pubkey=$pubkey"
			else
				kaha_uci set "keepalived.$sname.sync=0"
			fi
			kaha_uci add_list "keepalived.omr_ha_vi.unicast_peer=$sname"
		fi
		j=$((j + 1))
	done

	# keep the primary pubkey so a later re-apply on a backup retains it
	[ -n "$pubkey" ] && kaha_uci set keepalived.ha.pubkey="$pubkey"

	kaha_uci commit keepalived

	[ "$dhcp" != "0" ] && kaha_dhcp_set "$vip_ip"

	kaha_cron_install

	if [ "$idx" = "0" ] && [ "$KAHA_NO_SERVICES" != "1" ]; then
		kaha_genkey || return 1
	fi

	if [ "$KAHA_NO_SERVICES" != "1" ]; then
		/etc/init.d/keepalived enable >/dev/null 2>&1
		/etc/init.d/keepalived restart >/dev/null 2>&1
	fi
	return 0
}

kaha_status() {
	kaha_jshn
	local routers my_ip first role vip r j st tm

	routers=$(kaha_routers)
	vip=$(kaha_get keepalived.ha.vip '')
	my_ip=$(kaha_detect_my_ip)
	first=$(kaha_first_router)
	role='unknown'
	if [ -n "$my_ip" ]; then
		if [ "$my_ip" = "$first" ]; then role='primary'; else role='backup'; fi
	fi

	json_init
	json_add_boolean configured "$([ -n "$(kaha_uci -q get keepalived.omr_ha_vi)" ] && echo 1 || echo 0)"
	json_add_boolean enabled "$([ "$(kaha_get keepalived.ha.enabled 1)" != "0" ] && echo 1 || echo 0)"
	json_add_string role "$role"
	json_add_string my_ip "${my_ip:-}"
	json_add_string vip "$vip"
	json_add_boolean running "$(pidof keepalived >/dev/null 2>&1 && echo 1 || echo 0)"
	json_add_boolean key_present "$([ -f "$(kaha_keyfile)" ] && echo 1 || echo 0)"
	json_add_boolean cron_installed "$(kaha_cron_installed && echo 1 || echo 0)"
	json_add_string pubkey "$(kaha_pubkey 2>/dev/null)"
	json_add_array peers
	j=0
	for r in $routers; do
		if [ "$r" != "$my_ip" ]; then
			st=$(uci -q -P /var/state get "keepalived.omr_ha_peer_$j.last_sync_status" 2>/dev/null)
			tm=$(uci -q -P /var/state get "keepalived.omr_ha_peer_$j.last_sync_time" 2>/dev/null)
			json_add_object ''
			json_add_string address "$r"
			json_add_string name "omr_ha_peer_$j"
			json_add_string last_sync_status "${st:-NA}"
			json_add_int last_sync_time "${tm:-0}"
			json_close_object
		fi
		j=$((j + 1))
	done
	json_close_array
	json_dump
}

# --- remote configuration through the peer's LuCI ubus RPC endpoint ---

# On success sets KAHA_SCHEME and KAHA_TOKEN (no command substitution so
# that KAHA_ERROR set on failure survives into the caller's shell)
kaha_login() { # <ip> <user> <pass>
	kaha_jshn
	local ip="$1" user="${2:-root}" pass="$3"
	local scheme resp token code args

	KAHA_SCHEME=''
	KAHA_TOKEN=''

	json_init
	json_add_string username "$user"
	json_add_string password "$pass"
	json_add_int timeout 300
	args=$(json_dump)

	for scheme in https http; do
		resp=$(curl -s -k -m 10 --connect-timeout 5 \
			-H 'Content-Type: application/json' \
			-d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"call\",\"params\":[\"00000000000000000000000000000000\",\"session\",\"login\",$args]}" \
			"$scheme://$ip/ubus" 2>/dev/null)
		[ -n "$resp" ] || continue
		token=$(echo "$resp" | jsonfilter -q -e '@.result[1].ubus_rpc_session')
		if [ -n "$token" ]; then
			KAHA_SCHEME="$scheme"
			KAHA_TOKEN="$token"
			return 0
		fi
		code=$(echo "$resp" | jsonfilter -q -e '@.result[0]')
		if [ -n "$code" ]; then
			KAHA_ERROR="authentication failed on $ip (wrong username/password?)"
			return 1
		fi
	done
	KAHA_ERROR="cannot reach the LuCI RPC endpoint on $ip"
	return 1
}

kaha_call_remote() { # <scheme> <ip> <token> <object> <method> <args json>
	curl -s -k -m 30 --connect-timeout 5 \
		-H 'Content-Type: application/json' \
		-d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"call\",\"params\":[\"$3\",\"$4\",\"$5\",$6]}" \
		"$1://$2/ubus" 2>/dev/null
}

kaha_remote_result() { # <resp> <ip>  -> 0 and echoes result[1] json on success
	local resp="$1" ip="$2" code msg
	code=$(echo "$resp" | jsonfilter -q -e '@.result[0]')
	case "$code" in
		0)
			msg=$(echo "$resp" | jsonfilter -q -e '@.result[1].error')
			if [ -n "$msg" ]; then
				KAHA_ERROR="peer $ip: $msg"
				return 1
			fi
			echo "$resp" | jsonfilter -q -e '@.result[1]'
			return 0
			;;
		4 | 6)
			KAHA_ERROR="luci-app-keepalived-ha is not installed (or rpcd was not reloaded) on $ip"
			return 1
			;;
		*)
			KAHA_ERROR="RPC call failed on $ip (code ${code:-no response})"
			return 1
			;;
	esac
}

kaha_check_peer() { # <ip> <user> <pass>  -> echoes remote status json
	local ip="$1" resp
	kaha_login "$ip" "$2" "$3" || return 1
	resp=$(kaha_call_remote "$KAHA_SCHEME" "$ip" "$KAHA_TOKEN" "luci.keepalived-ha" "status" "{}")
	kaha_remote_result "$resp" "$ip"
}

kaha_push_peer() { # <ip> <user> <pass>
	kaha_jshn
	local ip="$1" user="${2:-root}" pass="$3"
	local routers args resp r found

	routers=$(kaha_routers)
	found=0
	for r in $routers; do
		[ "$r" = "$ip" ] && found=1
	done
	[ "$found" = "1" ] || {
		KAHA_ERROR="$ip is not in the configured router list"
		return 1
	}

	kaha_genkey || return 1

	kaha_login "$ip" "$user" "$pass" || return 1

	json_init
	json_add_string vip "$(kaha_get keepalived.ha.vip '')"
	json_add_string interface "$(kaha_get keepalived.ha.interface br-lan)"
	json_add_string vrid "$(kaha_get keepalived.ha.vrid 51)"
	json_add_string advert_int "$(kaha_get keepalived.ha.advert_int 1)"
	json_add_string track_omrvpn "$(kaha_get keepalived.ha.track_omrvpn 1)"
	json_add_string track_proxy "$(kaha_get keepalived.ha.track_proxy 1)"
	json_add_string track_wans "$(kaha_get keepalived.ha.track_wans 1)"
	json_add_string manage_dhcp "$(kaha_get keepalived.ha.manage_dhcp 1)"
	json_add_string routers "$routers"
	json_add_string my_ip "$ip"
	json_add_string pubkey "$(kaha_pubkey)"
	args=$(json_dump)

	resp=$(kaha_call_remote "$KAHA_SCHEME" "$ip" "$KAHA_TOKEN" "luci.keepalived-ha" "setup_remote" "$args")
	kaha_remote_result "$resp" "$ip" >/dev/null
}

# kaha_setup_remote_settings: store settings received from the configuring
# node into keepalived.ha on this node (called by the rpcd setup_remote method)
kaha_setup_remote_settings() { # <vip> <iface> <vrid> <adv> <track> <dhcp> <routers> <pubkey> <track_proxy> <track_wans>
	local r
	kaha_uci -q delete keepalived.ha
	kaha_uci set keepalived.ha=ha
	kaha_uci set keepalived.ha.enabled='1'
	kaha_uci set keepalived.ha.vip="$1"
	kaha_uci set keepalived.ha.interface="${2:-lan}"
	kaha_uci set keepalived.ha.vrid="${3:-51}"
	kaha_uci set keepalived.ha.advert_int="${4:-1}"
	kaha_uci set keepalived.ha.track_omrvpn="${5:-1}"
	kaha_uci set keepalived.ha.manage_dhcp="${6:-1}"
	kaha_uci set keepalived.ha.track_proxy="${9:-1}"
	kaha_uci set keepalived.ha.track_wans="${10:-1}"
	for r in $7; do
		kaha_uci add_list keepalived.ha.router="$r"
	done
	[ -n "$8" ] && kaha_uci set keepalived.ha.pubkey="$8"
	return 0
}
