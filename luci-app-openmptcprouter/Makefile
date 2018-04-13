#
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for OpenMPTCProuter
LUCI_DEPENDS:=+luci-lib-json
PKG_LICENSE:=Apache-2.0

include ../luci/luci.mk

define Package/luci-app-openmptcprouter/conffiles
/etc/sysctl.d/zzz_openmptcprouter.conf
endef

# call BuildPackage - OpenWrt buildroot signature
