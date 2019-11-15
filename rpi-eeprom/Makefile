# 
# Copyright (C) 2012 OpenWrt.org
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=rpi-eeprom
PKG_VERSION:=20191111
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/raspberrypi/rpi-eeprom.git
PKG_SOURCE_VERSION:=99e88912af108d46e4edd5f168634b84883c1d86

CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/rpi-eeprom
  SECTION:=rpi
  CATEGORY:=Raspberry Pi
  URL:=https://github.com/raspberrypi/rpi-eeprom
  TITLE:=rpi-eeprom
  DEPENDS:=+rpi-userland +fwtool +pciutils +blkid
endef

define Package/rpi-eeprom/description
 Update Raspberry PI 4 bootloader EEPROM
endef

define Build/Compile
endef

define Package/rpi-eeprom/install
	$(INSTALL_DIR) $(1)/lib/firmware/raspberrypi/bootloader \
		$(1)/usr/bin \
		$(1)/etc/default
	$(CP) $(PKG_BUILD_DIR)/rpi-eeprom-update $(1)/usr/bin
	$(CP) $(PKG_BUILD_DIR)/rpi-eeprom-update $(1)/usr/bin
	$(CP) $(PKG_BUILD_DIR)/firmware/vl805 $(1)/usr/bin
	$(CP) -r $(PKG_BUILD_DIR)/firmware/critical $(1)/lib/firmware/raspberrypi/bootloader/critical
	$(CP) -r $(PKG_BUILD_DIR)/firmware/beta $(1)/lib/firmware/raspberrypi/bootloader/beta
endef

$(eval $(call BuildPackage,rpi-eeprom))
