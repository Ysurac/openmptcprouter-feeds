# OpenWrt OpenMPTCProuter feed

This is the OpenWrt OpenMPTCProuter feed containing all modified and necessary packages to build the OpenMPTCProuter image.

For More information, see [https://github.com/ysurac/openmptcprouter](https://github.com/ysurac/openmptcprouter) and [https://www.openmptcprouter.com](https://www.openmptcprouter.com/).


## Glorytun
*Source:* [https://github.com/angt/glorytun](https://github.com/angt/glorytun)

*Description:* A small, simple and secure VPN


A LuCI interface was made to make it easier to use. It's used in OpenMPTCProuter to redirect ports from the VPS to the router and for UDP/ICMP traffic from the router.


## Shadowsocks
*Source:* [https://github.com/shadowsocks/shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)

*Description:* A secure socks5 proxy


MPTCP support is added in LuCI interface and init scripts. IPv6 support added.


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

*Description:* Luci interface to bypass domains with shadowsocks

Domains added are bypassed when shadowsocks is used. This can be used when VPS IP is blacklisted from some sites.


## omr-tracker
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-tracker](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/omr-tracker)

*Description:* Track connection status. This check if gateway is up then check if the connection work. If it's not working this execute scripts.

This is used for OpenMPTCProuter failover.


## luci-omr-tracker
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-omr-tracker](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-omr-tracker)

*Description:* Luci interface to omr-tracker

Interface to omr-tracker.


## luci-app-mptcp
*Source:* [https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-mptcp](https://github.com/Ysurac/openmptcprouter-feeds/tree/master/luci-app-mptcp)

*Description:* Luci interface for all MPTCP settings

