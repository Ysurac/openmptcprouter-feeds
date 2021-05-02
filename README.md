# OpenWrt OpenMPTCProuter feed


This is the OpenWrt OpenMPTCProuter feed containing all modified and necessary packages to build the OpenMPTCProuter image.

For More information, see [https://github.com/ysurac/openmptcprouter](https://github.com/ysurac/openmptcprouter) and [https://www.openmptcprouter.com](https://www.openmptcprouter.com/).


## Glorytun
*Source:* [https://github.com/angt/glorytun](https://github.com/angt/glorytun)

*Description:* A small, simple and secure VPN


A LuCI interface was made to make it easier to use. It's used in OpenMPTCProuter to redirect ports from the VPS to the router and for UDP/ICMP traffic from the router.


## Shadowsocks-libev
*Source:* [https://github.com/shadowsocks/shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)

*Description:* A secure socks5 proxy


MPTCP support is added in LuCI interface and init scripts. IPv6 support added.

## Shadowsocks-v2ray-plugin-bin
*Source:* [https://github.com/shadowsocks/v2ray-plugin](https://github.com/shadowsocks/v2ray-plugin)

*Description:* V2ray plugin for Shadowsocks

Support is added in ShadowSocks LuCI interface and init scripts.


## Simple-obfs
*Source:* [https://github.com/shadowsocks/simple-obfs](https://github.com/shadowsocks/simple-obfs)

*Description:* A simple obfuscating tool, designed as plugin server of shadowsocks.


Support is added in ShadowSocks LuCI interface and init scripts.


## SpeedTestC
*Source:* [https://github.com/mobrembski/SpeedTestC](https://github.com/mobrembski/SpeedTestC)

*Description:* Client for SpeedTest.net infrastructure written in pure C99 standard using only POSIX libraries.

Used to test speed. No LuCI interface.


## Nginx
*Source:* [https://www.nginx.org](https://www.nginx.org)

*Description:* nginx is an HTTP and reverse proxy server, a mail proxy server, and a generic TCP/UDP proxy server. 


A LuCI interface for TCP/UDP stream is added. Used for TCP/UDP failover.


## luci-proto-ipv6
*Source:* [https://github.com/openwrt/luci](https://github.com/openwrt/luci)

*Description:* Luci support for DHCPv6/6in4/6to4/6rd/DS-Lite/aiccu

Added support to gateway set by user for 6in4. Used for IPv6 over the glorytun IPv4 VPN.


## luci-omr-bypass
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-omr-bypass](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-omr-bypass)

*Description:* Luci interface to bypass domains, IPs and networks with shadowsocks

Domains, IPs, networks and protocol (using DPI) added are bypassed when shadowsocks is used. This can be used when VPS IP is blacklisted from some sites.


## omr-tracker
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-tracker](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-tracker)

*Description:* Track connection status. This check if gateway is up then check if the connection work. If it's not working this execute scripts. This also detect if ShadowSocks is up or not.

This is used for OpenMPTCProuter failover.


## luci-omr-tracker
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-omr-tracker](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-omr-tracker)

*Description:* Luci interface to omr-tracker

Interface to omr-tracker.


## luci-app-iperf
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-iperf](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-iperf)

*Description:* Luci interface to iPerf


## omr-6in4
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-6in4](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-6in4)

*Description:* Set tunnel configuration by tracking tunnel configuration.


## omr-update
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-update](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-update)

*Description:* Update old config with new settings.


## luci-app-mptcp
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-mptcp](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-mptcp)

*Description:* Luci interface for all MPTCP settings


## luci-app-openmptcprouter
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-openmptcprouter](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-openmptcprouter)

*Description:* Wizard for OpenMPTCProuter settings and status page


## mptcp
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/mptcp](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/mptcp)

*Description:* This package set all MPTCP settings


## ndisc6
*Source:* [http://www.remlab.net/files/ndisc6](http://www.remlab.net/files/ndisc6)

*Description:* An ICMPv6 neighbour discovery tool

This is used to check if there is no other IPv6 route announced on the network


## mlvpn
*Source:* [https://github.com/markfoodyburton/MLVPN/tree/new-reorder](https://github.com/markfoodyburton/MLVPN/tree/new-reorder)

*Description:* Multi-link VPN

This is an other way to aggregate same latency connections


## dsvpn
*Source:* [https://github.com/jedisct1/dsvpn][https://github.com/jedisct1/dsvpn]

*Description:* A Dead Simple VPN

A simple TCP VPN


## ndpi-netfilter2
*Source:* [https://github.com/vel21ripn/nDPI](https://github.com/vel21ripn/nDPI)

*Description:* Open Source Deep Packet Inspection Software Toolkit

This is used to bypass a protocol


## tracebox
*Source:* [https://github.com/tracebox/tracebox](https://github.com/tracebox/tracebox)

*Description:* A middlebox detection tool


## Shortcut-FE
*Source:* [https://github.com/coolsnowwolf/lede/tree/master/package/lean/shortcut-fe](https://github.com/coolsnowwolf/lede/tree/master/package/lean/shortcut-fe)

*Description:* Shortcut is an in-Linux-kernel IP packet forwarding engine.


## V2Ray
*Source:* [https://github.com/v2fly/v2ray-core](https://github.com/v2fly/v2ray-core)

*Description:* A platform for building proxies to bypass network restrictions.

This is used as proxy, alternative to Shadowsocks



# License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2FYsurac%2Fopenmptcprouter-feeds.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2FYsurac%2Fopenmptcprouter-feeds?ref=badge_large)

## Translation status

[![Translation status](https://weblate.openmptcprouter.com/widgets/omr/-/multi-auto.svg)](https://weblate.openmptcprouter.com/engage/omr/?utm_source=widget)
