#
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for MPTCP
LUCI_DEPENDS:=+mptcp +ip-full +ss +nstat +tracebox +omr-sockdiag
PKG_LICENSE:=GPLv3

#include ../luci/luci.mk
include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-mptcp/install
	$(call Package/luci-app-mptcp/install/default,$(1))
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/luci.mptcp \
		$(1)/usr/libexec/rpcd/luci.mptcp
endef

# call BuildPackage - OpenWrt buildroot signature
