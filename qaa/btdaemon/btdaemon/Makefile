include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

PKG_NAME:=btdaemon
PKG_VERSION:=1.0
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/btdaemon

define Package/$(PKG_NAME)
	SECTION:=btdaemon
	CATEGORY:=btdaemon
	TITLE:=Bluetooth Daemon Library to transport Packets from FTM Application to Future Platforms.
	DEPENDS:=@TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64 +qca-diag
endef

define Package/$(PKG_NAME)/description
	Bluetooth Daemon Application to transport HCI Packets
endef

TARGET_CFLAGS += \
	-DIPQ_IPQ50XX_SUPPORT \
	-DDEBUG \
	-DBTD_DEBUG \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/qca-diag \
	-Wall \
	-Werror

define Package/$(PKG_NAME)/config
	source "$(SOURCE)/Config.in"
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	cp $(LOCAL_SRC)/* $(PKG_BUILD_DIR)
	$(Build/Patch)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include/btdaemon
	$(CP) $(PKG_BUILD_DIR)/btdaemon.h $(STAGING_DIR)/usr/include/btdaemon
	$(CP) $(PKG_BUILD_DIR)/libbtdaemon.so $(STAGING_DIR)/usr/lib
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libbtdaemon.so $(1)/usr/lib
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
