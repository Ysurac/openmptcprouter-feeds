#
# Copyright (C) 2020 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter project
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mptcpd
PKG_VERSION:=0.4
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/intel/mptcpd/releases/download/v$(PKG_VERSION)
PKG_HASH:=459c45ba86ea574f1ad7a062a9914474ca650229b97375017bd46d0732f985ba
PKG_RELEASE:=1
PKG_MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>

PKG_FORTIFY_SOURCE:=2
PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1
PKG_BUILD_DEPENDS:=!USE_GLIBC:argp-standalone

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
SECTION:=net
CATEGORY:=Network
DEPENDS:=+libell
TITLE:=mptcpd
URL:=https://github.com/intel/mptcpd
endef

define Package/$(PKG_NAME)/conffiles
/etc/mptcpd/mptcpd.conf
endef

TARGET_CFLAGS += -D_GNU_SOURCE -Wno-unused-result -Wno-format-nonliteral

define Build/Compile
	+$(MAKE_VARS) $(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) $(MAKE_FLAGS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/mptcpd $(1)/usr/bin/mptcpd
	$(INSTALL_DIR) $(1)/usr/include/mptcpd
	$(CP) $(PKG_INSTALL_DIR)/usr/include/mptcpd/*.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib/mptcpd
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/mptcpd/* $(1)/usr/lib/mptcpd/
	$(INSTALL_DIR) $(1)/etc/mptcpd
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/etc/mptcpd.conf $(1)/etc/mptcpd/mptcpd.conf
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
