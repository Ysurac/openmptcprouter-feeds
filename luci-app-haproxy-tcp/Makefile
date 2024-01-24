#
# Copyright (C) 2016 chenhw2 <chenhw2@github.com>
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for haproxy-tcp
LUCI_DEPENDS:=+haproxy-nossl

PKG_LICENSE:=MIT

#include ../luci/luci.mk
include $(TOPDIR)/feeds/luci/luci.mk
# call BuildPackage - OpenWrt buildroot signature
