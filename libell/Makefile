#
# Copyright (C) 2020-2021 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ell
PKG_VERSION:=0.41
PKG_RELEASE:=1
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_HASH:=4e8dba6c53cf152dbd0fd1dc3d4c7b04abf79e20a948895f85943e586870505c
PKG_SOURCE_URL:=@KERNEL/linux/libs/ell
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=GPL
PKG_INSTALL:=1
PKG_MAINTAINER:=Ycarus <ycarus@zugaina.org>

include $(INCLUDE_DIR)/package.mk

define Package/libell
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Embedded Linux library
  URL:=https://git.kernel.org/pub/scm/libs/ell/ell.git
endef

define Package/libell/description
  Embeded Linux library
endef

define Package/libell/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libell*.so* $(1)/usr/lib
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)
	$(CP) $(PKG_INSTALL_DIR)/* $(1)/
endef

$(eval $(call BuildPackage,libell))
