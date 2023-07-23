#
# Copyright 2019-2020 ZHANG Zhao <Zhao.Zhang2@etu.univ-grenoble-alpes.fr>
# Copyright 2020 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the Apache License, Version 2.0 .
#
# Based on openwrt luci commit 03c77dafe3cfb922b995adfe9c0f8a75c98a18af
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Dashboard Pages
LUCI_DEPENDS:=+luci-base +libiwinfo

PKG_BUILD_DEPENDS:=iwinfo
PKG_LICENSE:=Apache-2.0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

