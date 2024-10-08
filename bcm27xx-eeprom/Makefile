include $(TOPDIR)/rules.mk

PKG_NAME:=bcm27xx-eeprom
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/raspberrypi/rpi-eeprom
PKG_SOURCE_DATE:=2024-06-05
PKG_SOURCE_VERSION:=e430a41e7323a1e28fb42b53cf79e5ba9b5ee975
PKG_MIRROR_HASH:=6c9a45d4ea0f33a9dc18f11b6cdeb425f0682dc41099df3a1f350939aecce353

PKG_LICENSE:=BSD-3-Clause Custom
PKG_LICENSE_FILES:=LICENSE

PKG_MAINTAINER:=Álvaro Fernández Rojas <noltari@gmail.com>

include $(INCLUDE_DIR)/package.mk

TAR_OPTIONS:=--strip-components 1 $(TAR_OPTIONS)
TAR_CMD=$(HOST_TAR) -C $(1) $(TAR_OPTIONS)

define Package/bcm27xx-eeprom/Default
  SECTION:=utils
  CATEGORY:=Utilities
endef

define Package/bcm27xx-eeprom
$(call Package/bcm27xx-eeprom/Default)
  TITLE:=BCM27xx EEPROM tools
  DEPENDS:=bcm27xx-utils +blkid +coreutils +coreutils-od +mount-utils +pciutils +python3-light
endef

define Package/bcm2711-eeprom
$(call Package/bcm27xx-eeprom/Default)
  TITLE:=BCM2711 EEPROM tools
  DEPENDS:=+bcm27xx-eeprom
endef

define Package/bcm2712-eeprom
$(call Package/bcm27xx-eeprom/Default)
  TITLE:=BCM2712 EEPROM tools
  DEPENDS:=+bcm27xx-eeprom
endef

define Package/bcm27xx-eeprom/description
  BCM27xx EEPROM config and update tools.
endef

define Package/bcm2711-eeprom/description
  BCM2711 EEPROM config and update tools.
endef

define Package/bcm2712-eeprom/description
  BCM2712 EEPROM config and update tools.
endef

define Build/Compile
	true
endef

define Package/bcm27xx-eeprom/conffiles
/etc/bcm27xx-eeprom.conf
endef

define Package/bcm27xx-eeprom/install
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/rpi-eeprom-update-default $(1)/etc/bcm27xx-eeprom.conf

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/rpi-eeprom-config $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/rpi-eeprom-digest $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/rpi-eeprom-update $(1)/usr/bin
endef

define Package/bcm2711-eeprom/install
	$(INSTALL_DIR) $(1)/lib/firmware/raspberrypi/bootloader-2711
	$(INSTALL_DIR) $(1)/lib/firmware/raspberrypi/bootloader-2711/default

	$(CP) $(PKG_BUILD_DIR)/firmware-2711/release-notes.md $(1)/lib/firmware/raspberrypi/bootloader-2711
	$(CP) $(PKG_BUILD_DIR)/firmware-2711/default/pieeprom-2024-04-15.bin $(1)/lib/firmware/raspberrypi/bootloader-2711/default
	$(CP) $(PKG_BUILD_DIR)/firmware-2711/default/recovery.bin $(1)/lib/firmware/raspberrypi/bootloader-2711/default
	$(CP) $(PKG_BUILD_DIR)/firmware-2711/default/vl805-000138c0.bin $(1)/lib/firmware/raspberrypi/bootloader-2711/default
endef

define Package/bcm2712-eeprom/install
	$(INSTALL_DIR) $(1)/lib/firmware/raspberrypi/bootloader-2712
	$(INSTALL_DIR) $(1)/lib/firmware/raspberrypi/bootloader-2712/default

	$(CP) $(PKG_BUILD_DIR)/firmware-2712/release-notes.md $(1)/lib/firmware/raspberrypi/bootloader-2712
	$(CP) $(PKG_BUILD_DIR)/firmware-2712/default/pieeprom-2024-04-20.bin $(1)/lib/firmware/raspberrypi/bootloader-2712/default
	$(CP) $(PKG_BUILD_DIR)/firmware-2712/default/recovery.bin $(1)/lib/firmware/raspberrypi/bootloader-2712/default
endef

$(eval $(call BuildPackage,bcm27xx-eeprom))
$(eval $(call BuildPackage,bcm2711-eeprom))
$(eval $(call BuildPackage,bcm2712-eeprom))
