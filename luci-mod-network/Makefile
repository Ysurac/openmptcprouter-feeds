#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
# Copyright (C) 2020 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the Apache License, Version 2.0 .
#
# From https://github.com/openwrt/luci/commit/1e07e3a52d4d06cc82ab07f2b7fbba0a9a6fb801

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Network Administration
LUCI_DEPENDS:=+luci-base +libiwinfo-lua +rpcd-mod-iwinfo

PKG_LICENSE:=Apache-2.0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

