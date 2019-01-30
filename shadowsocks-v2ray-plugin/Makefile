#
# Copyright (C) 2018-2019 chenhw2 <https://github.com/chenhw2>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-plugin
PKG_MAINTAINER:=chenhw2 <https://github.com/chenhw2>

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/shadowsocks/v2ray-plugin.git
PKG_SOURCE_VERSION:=8cea1a3

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_DEPENDS:=golang/host
GO_PKG:=github.com/shadowsocks/v2ray-plugin
#GO_PKG_BUILD_PKG:=github.com/shadowsocks/v2ray-plugin

include $(INCLUDE_DIR)/package.mk
include ../golang/golang-package.mk

define Package/v2ray-plugin
	SECTION:=net
	CATEGORY:=Network
	TITLE:=SIP003 plugin for shadowsocks, based on v2ray
	URL:=https://github.com/shadowsocks/v2ray-plugin
	DEPENDS:=$(GO_ARCH_DEPENDS) \
	    +golang-protobuf-dev +v2ray-core-dev +v2ray-ext-dev +golang-golang-x-crypto-dev
	PKGARCH:=all
endef

define Package/v2ray-plugin/description
	Yet another SIP003 plugin for shadowsocks, based on v2ray
endef

#define Build/Prepare
#	gzip -dc "$(DL_DIR)/$(PKG_SOURCE)" | tar -C $(PKG_BUILD_DIR)/ -xf -
#endef

#define Build/Compile
#	echo "$(PKG_NAME)Compile Skiped!"
#endef

#define Package/v2ray-plugin/install
#	$(INSTALL_DIR) $(1)/usr/bin
#	$(INSTALL_BIN) $(PKG_BUILD_DIR)/v2ray-plugin $(1)/usr/bin/v2ray-plugin
#endef

$(eval $(call GoBinPackage,v2ray-plugin))
$(eval $(call BuildPackage,v2ray-plugin))
