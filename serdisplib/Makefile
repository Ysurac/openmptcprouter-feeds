# 
# Copyright (C) 2006-2011 OpenWrt.org
# Copyright (C) 2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=serdisplib
PKG_VERSION:=2.01
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=@SF/serdisplib
PKG_MD5SUM:=4eb17cd70aa963c30a237d426ac24449

include $(INCLUDE_DIR)/package.mk

define Package/serdisplib
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=A display control library
  URL:=http://serdisplib.sourceforge.net/
  DEPENDS:=+libusb-1.0 +libusb-compat
endef

define Package/serdisplib/description
	serdisplib is a library to drive serial and parallel displays 
	with built-in controllers.
endef

CONFIGURE_ARGS+= \
	--enable-shared \
	--enable-static \

TARGET_CFLAGS += $(FPIC)

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CFLAGS="$(TARGET_CFLAGS) -Wall -Wno-implicit -I../include -I.." \
		all
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_BUILD_DIR)/include/serdisplib $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/lib/libserdisp.{a,so*} $(1)/usr/lib/
endef

define Package/serdisplib/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/lib/libserdisp.so.* $(1)/usr/lib
endef

$(eval $(call BuildPackage,serdisplib))
