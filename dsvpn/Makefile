#
# Copyright (C) 2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter project
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/jedisct1/dsvpn.git
PKG_SOURCE_VERSION:=917910d5f66a6d9f3302931c9d34e0a255979cf0
PKG_NAME:=dsvpn
PKG_VERSION:=0.1.0-$(PKG_SOURCE_VERSION)
PKG_RELEASE:=1

PKG_FIXUP:=autoreconf

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
SECTION:=net
CATEGORY:=Network
DEPENDS:=+kmod-tun
TITLE:=A Dead Simple VPN
URL:=https://github.com/jedisct1/dsvpn
SUBMENU:=VPN
endef


define Package/$(PKG_NAME)/conffiles
/etc/config/dsvpn
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/dsvpn $(1)/usr/sbin/$(PKG_NAME)
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) init $(1)/etc/init.d/$(PKG_NAME)
	$(INSTALL_DIR) $(1)/etc/config
	touch $(1)/etc/config/dsvpn
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

