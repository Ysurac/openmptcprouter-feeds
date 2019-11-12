# 
# Copyright (C) 2012 OpenWrt.org
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=rpi-userland
PKG_VERSION:=20191107
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/raspberrypi/userland.git
PKG_SOURCE_VERSION:=666d281a7a5e374975ec9a20068f371599b0e6f8

PKG_BUILD_DEPENDS:=zlib
CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/rpi-userland
  SECTION:=rpi
  CATEGORY:=Raspberry Pi
  URL:=https://github.com/raspberrypi/userland
  DEPENDS:=+librt
  TITLE:=rpi-userland
  MENU:=1
endef

define Package/rpi-userland/description
 Raspberry PI userland libraries for interfaces EGL, mmal, GLESv2,
 vcos, openmaxil, vchiq_arm, bcm_host, WCF and OpenVG
 with Wayland EGL support.
endef

#TARGET_CFLAGS += -Wno-error

define Package/rpi-userland/install
	$(INSTALL_DIR) $(1)/usr/lib \
		$(1)/usr/bin \
		$(1)/usr/sbin \
		$(1)/usr/share/install
	$(CP) $(PKG_INSTALL_DIR)/opt/vc/lib/*.so* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/opt/vc/bin/* $(1)/usr/bin/
endef

$(eval $(call BuildPackage,rpi-userland))
