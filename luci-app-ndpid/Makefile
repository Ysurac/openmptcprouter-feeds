#
# Copyright (C) 2024 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for nDPId DPI Flows
LUCI_DEPENDS:=+ndpid +omr-bypass

PKG_LICENSE:=GPLv3

#include ../luci/luci.mk
include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-ndpid/install
	$(call Package/luci-app-ndpid/install/default,$(1))
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/luci.ndpid \
		$(1)/usr/libexec/rpcd/luci.ndpid
endef

# call BuildPackage - OpenWrt buildroot signature
