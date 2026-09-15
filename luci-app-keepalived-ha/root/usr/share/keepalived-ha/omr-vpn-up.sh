#!/bin/sh
# Report OMR tunnel health for keepalived priority tracking.
# Exit 0 = healthy, non-zero = demote this node (vrrp_script weight -200).
#
# When no omrvpn interface is configured or it is disabled (VPN 'none'
# setups), report healthy so tracking never demotes anyone.

uci -q get network.omrvpn >/dev/null 2>&1 || exit 0
[ "$(uci -q get network.omrvpn.disabled)" = "1" ] && exit 0

. /lib/functions/network.sh

network_flush_cache
network_is_up omrvpn || exit 1
network_get_device dev omrvpn
[ -n "$dev" ] || exit 1

# traffic must actually egress through the tunnel, not a bare WAN
ip route get 1.1.1.1 2>/dev/null | grep -q "dev $dev" || exit 1

exit 0
