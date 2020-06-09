#
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v3 or later.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=macvlan
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/macvlan
  SECTION:=net
  CATEGORY:=Network
  TITLE:=MacVLAN configuration scripts
  DEPENDS:=+kmod-macvlan
  PKGARCH:=all
endef

define Package/macvlan/description
  MacVLAN configuration for OpenMPTCProuter.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/macvlan/install
	$(INSTALL_DIR) $(1)
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,macvlan))
