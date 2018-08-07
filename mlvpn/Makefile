#
# Copyright (C) 2017 Zhong Jianxin <azuwis@gmail.com>
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=mlvpn
#PKG_VERSION:=6f13423b
PKG_VERSION:=eda650a
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
#PKG_SOURCE_URL:=https://github.com/zehome/MLVPN.git
#PKG_SOURCE_VERSION:=6f13423b8108f46edb9f230deee20e3741abe64c
#PKG_SOURCE_DATE:=2017-09-01
PKG_SOURCE_URL:=https://github.com/markfoodyburton/MLVPN.git
PKG_SOURCE_VERSION:=eda650af241a9e410b7567e21d33dd26d0854adc
PKG_SOURCE_DATE:=2018-07-27

PKG_LICENSE:=BSD-2-Clause
PKG_MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>

PKG_INSTALL:=1
PKG_FIXUP:=autoreconf
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/mlvpn
  TITLE:=Multi-Link Virtual Public Network
  SECTION:=net
  CATEGORY:=Network
  URL:=https://zehome.github.io/MLVPN/
  SUBMENU:=VPN
  MENU:=1
  DEPENDS:=+kmod-tun +libev +libpcap +libsodium
endef

define Package/mlvpn/description
  Multi-Link Virtual Public Network
  Bond your internet links to increase bandwidth (unlimited).
  Secure your internet connection by actively monitoring your links and removing the faulty ones, without loosing your TCP connections.
  Secure your internet connection to the aggregation server using strong cryptography.
  Scriptable automation and monitoring.
endef

define Package/mlvpn/conffiles
/etc/config/mlvpn
endef

define Package/mlvpn/install
	$(INSTALL_DIR) $(1)
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/sbin/mlvpn $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,mlvpn))
