#
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Interface to bypass domains
#LUCI_DEPENDS:=+dnsmasq-full +shadowsocks-libev-ss-rules +(LINUX_5_4||LINUX_5_15||TARGET_x86_64):iptables-mod-ndpi +iptables-mod-extra +(LINUX_5_4||LINUX_5_15||TARGET_x86_64):kmod-ipt-ndpi +iptables
LUCI_DEPENDS:=+dnsmasq-full +shadowsocks-libev-ss-rules +(LINUX_5_4||LINUX_5_15):iptables-mod-ndpi +iptables-mod-extra +(LINUX_5_4||LINUX_5_15):kmod-ipt-ndpi +iptables

PKG_LICENSE:=GPLv3

#include ../luci/luci.mk
include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
