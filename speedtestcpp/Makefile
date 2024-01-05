#
# Copyright (C) 2021 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter project
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=speedtestcpp
PKG_VERSION:=1.12
PKG_RELEASE:=2

PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=a01ae6eb04c5d3f4847aef73bf77849275ccc6eb
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/fmantz/SpeedTest.git

PKG_MAINTAINER:=Ycarus <ycarus@zugaina.org>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/speedtestcpp
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Yet another unofficial speedtest.net client cli interface
	URL:=https://github.com/fmantz/SpeedTest
	DEPENDS:=+curl +libstdcpp +libopenssl +libxml2
endef

define Package/speedtestcpp/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/SpeedTest $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/speedtestJson $(1)/usr/bin/
endef

$(eval $(call BuildPackage,speedtestcpp))