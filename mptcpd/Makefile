#
# Copyright (C) 2020-2025 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter project
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mptcpd
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/multipath-tcp/mptcpd.git
PKG_SOURCE_VERSION:=68fd9a156669ca7029a101f32282706df069cb4f
PKG_VERSION:=0.13
PKG_RELEASE:=1
PKG_MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=COPYING

PKG_FORTIFY_SOURCE:=2
PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1
PKG_BUILD_DEPENDS:=!USE_GLIBC:argp-standalone

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
SECTION:=net
CATEGORY:=Network
DEPENDS:=+libell @!(LINUX_5_4)
TITLE:=mptcpd
URL:=https://github.com/intel/mptcpd
endef

define Package/$(PKG_NAME)/conffiles
/etc/mptcpd/mptcpd.conf
endef

CONFIGURE_ARGS += \
	--disable-doxygen-doc \
	--disable-logging \
	--with-kernel=upstream

TARGET_CFLAGS += -Wno-unused-result -Wno-format-nonliteral

define Build/Prepare
	$(Build/Prepare/Default)
	( cd $(PKG_BUILD_DIR); $(AM_TOOL_PATHS) ./bootstrap )
endef

define Build/Compile
	+$(MAKE_VARS) $(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) $(MAKE_FLAGS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/mptcpd $(1)/usr/bin/mptcpd
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/mptcpize $(1)/usr/bin/mptcpize
	$(INSTALL_DIR) $(1)/usr/include/mptcpd
	$(CP) $(PKG_INSTALL_DIR)/usr/include/mptcpd/*.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib/mptcpd
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/mptcpd/* $(1)/usr/lib/mptcpd/
	$(INSTALL_DIR) $(1)/etc/mptcpd
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/etc/mptcpd.conf $(1)/etc/mptcpd/mptcpd.conf
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
