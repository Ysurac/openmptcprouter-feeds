#!/bin/sh
# Report OMR proxy health for keepalived priority tracking.
# Exit 0 = healthy, non-zero = demote this node (vrrp_script weight -200).
#
# Process check first: when the proxy service dies the omr-tracker proxy
# instances die with it (they are instances of the same service), leaving
# the tracker verdict stale at 'up'. Then the tracker verdict
# (openmptcprouter.omr.ss_<server>/.v2ray/.xray = up/down) catches the
# daemon-running-but-server-unreachable case. Only the active proxy type's
# keys are read since keys from earlier proxy switches remain behind.
# No proxy configured = healthy so tracking never demotes anyone.

proxy=$(uci -q get openmptcprouter.settings.proxy)

case "$proxy" in
	'' | none)
		exit 0
		;;
	shadowsocks)
		pidof ss-redir >/dev/null 2>&1 || pidof ss-local >/dev/null 2>&1 || exit 1
		;;
	shadowsocks-rust)
		pidof sslocal >/dev/null 2>&1 || pidof ssservice >/dev/null 2>&1 || exit 1
		;;
	v2ray | xray)
		pidof "$proxy" >/dev/null 2>&1 || exit 1
		[ "$(uci -q get "openmptcprouter.omr.$proxy")" = "down" ] && exit 1
		exit 0
		;;
	*)
		# unknown proxy type: never demote on a guess
		exit 0
		;;
esac

# shadowsocks variants: healthy while any tracked server is up
states=$(uci -q show openmptcprouter.omr 2>/dev/null |
	sed -n "s/^openmptcprouter\.omr\.ss_[a-zA-Z0-9_]*='\(.*\)'$/\1/p")
[ -z "$states" ] && exit 0
for s in $states; do
	[ "$s" = "up" ] && exit 0
done
exit 1
