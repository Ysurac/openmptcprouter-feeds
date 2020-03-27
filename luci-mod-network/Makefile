#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#
# From https://github.com/openwrt/luci/commit/6efaea2ffb46f9909038b85cf12e7acf4467ae2e

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Network Administration
LUCI_DEPENDS:=+luci-base +libiwinfo-lua +rpcd-mod-iwinfo

PKG_LICENSE:=Apache-2.0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

