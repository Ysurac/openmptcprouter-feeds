#
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for iPerf3
LUCI_DEPENDS:=+iperf3-ssl +luci-lua-runtime

PKG_LICENSE:=GPLv3

define Package/luci-app-iperf/conffiles
/etc/config/iperf
endef

#include ../luci/luci.mk
include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
