#
# Copyright (C) 2017 Zhong Jianxin <azuwis@gmail.com>
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=mlvpn
PKG_VERSION:=2263bab
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/zehome/MLVPN.git
PKG_SOURCE_VERSION:=2263bab7e5f983e1daa33887b53120c12646398f
PKG_SOURCE_DATE:=2020-12-16
#PKG_SOURCE_URL:=https://github.com/markfoodyburton/MLVPN.git
#PKG_SOURCE_VERSION:=8f9720978b28c1954f9f229525333547283316d2
#PKG_SOURCE_DATE:=2018-09-03

#PKG_SOURCE_URL:=https://github.com/flohoff/MLVPN.git
#PKG_SOURCE_VERSION:=f45cec350a6879b8b020143a78134a022b5df2a7
#PKG_SOURCE_DATE:=2019-05-31

#PKG_SOURCE_URL:=https://github.com/link4all/MLVPN.git
#PKG_SOURCE_VERSION:=3cf976fe37a118a47bc42f51c0294beba0499652
#PKG_SOURCE_DATE:=2019-07-13


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
