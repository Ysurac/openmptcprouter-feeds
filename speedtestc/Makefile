#
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=speedtestc
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://github.com/mobrembski/SpeedTestC.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=56482555e34f7f4002b116efd63cfa68634d389f
PKG_MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/speedtestc
	SECTION:=net
	CATEGORY:=Network
	MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
	TITLE:=Client for SpeedTest.net infrastructure written in pure C99 standard using only POSIX libraries.
endef

define Package/speedtestc/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/SpeedTestC $(1)/usr/sbin/speedtestc
endef


$(eval $(call BuildPackage,$(PKG_NAME)))
