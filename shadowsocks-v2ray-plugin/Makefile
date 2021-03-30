#
# Copyright (C) 2018-2019 chenhw2 <https://github.com/chenhw2>
# Copyright (C) 2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter project
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-plugin
PKG_MAINTAINER:=Ycarus

PKG_SOURCE_PROTO:=git
#PKG_SOURCE_URL:=https://github.com/shadowsocks/v2ray-plugin.git
PKG_SOURCE_URL:=https://github.com/teddysun/v2ray-plugin.git
#PKG_SOURCE_VERSION:=63a74bef9e9f639bc199255db9d452d96f01d11a
PKG_SOURCE_VERSION:=6c0c5fb15851e13b36fe2eeaaba97fd27c9d291b

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
GO_PKG:=github.com/shadowsocks/v2ray-plugin
#GO_PKG_BUILD_PKG:=github.com/shadowsocks/v2ray-plugin

PKG_USE_MIPS16:=0

include $(INCLUDE_DIR)/package.mk
include ../golang/golang-package.mk

define Package/v2ray-plugin
	SECTION:=net
	CATEGORY:=Network
	TITLE:=SIP003 plugin for shadowsocks, based on v2ray
	URL:=https://github.com/shadowsocks/v2ray-plugin
	DEPENDS:=$(GO_ARCH_DEPENDS) \
	    +golang-protobuf-dev +v2ray-core +v2ray-ext-dev +golang-golang-x-crypto-dev
	#    +golang-protobuf-dev +v2ray-core-dev +v2ray-ext-dev +golang-golang-x-crypto-dev
endef

define Package/v2ray-plugin/description
	Yet another SIP003 plugin for shadowsocks, based on v2ray
endef

$(eval $(call GoBinPackage,v2ray-plugin))
$(eval $(call BuildPackage,v2ray-plugin))
