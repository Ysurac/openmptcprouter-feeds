#
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Interface to bypass domains
LUCI_DEPENDS:=+dnsmasq-full +shadowsocks-libev-ss-rules +iptables-mod-ndpi +iptables-mod-extra +kmod-ipt-ndpi +iptables

PKG_LICENSE:=GPLv3

#include ../luci/luci.mk
include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
