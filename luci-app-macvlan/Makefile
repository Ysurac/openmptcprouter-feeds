#
# Copyright (C) 2020 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpeenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for macvlan
LUC_PKGARCH:=all
LUCI_DEPENDS:=+kmod-macvlan +busybox +@BUSYBOX_CUSTOM +@BUSYBOX_CONFIG_VCONFIG

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature