#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
# Copyright (C) 2020-2021 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the Apache License, Version 2.0 .
#
# From https://github.com/openwrt/luci/commit/29fe3f5fdad6bc7c72799adff22847a6e257f7c0

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Network Administration
LUCI_DEPENDS:=+luci-base +libiwinfo-lua +rpcd-mod-iwinfo

PKG_LICENSE:=Apache-2.0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

