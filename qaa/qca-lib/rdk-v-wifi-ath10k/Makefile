include $(TOPDIR)/rules.mk

PKG_NAME:=rdk-v-wifi-ath10k
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
	PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
	PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/rdk-v-wifi-ath10k
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=RDK-V HAL API Library
  DEPENDS:=+libnl wpad-mesh
endef

define Package/rdk-v-wifi-ath10k/description
  This Package contains the RDK-V HAL API Functionality Library
endef

EXTLIB_MAKEOPTS:= \
	TOOLPREFIX=$(TARGET_CROSS) \
	GWINCLUDE=$(STAGING_DIR)/usr/include/ \
	NLINCLUDE=$(STAGING_DIR)/usr/include/mac80211/uapi \
	LIBNLINCLUDE=$(STAGING_DIR)/usr/include/libnl3 \
	QCACFLAGS="$(TARGET_CFLAGS)"\
	EXTRA_LDFLAGS="-lnl-3 -lnl-genl-3 -lwpa_client -lpthread"\
	QCALDFLAGS="-pie -Wl,--gc-sections $(TARGET_LDFLAGS)"\
	INSTALL_ROOT=$(PKG_BUILD_DIR)/install
	#INSTALL_ROOT=$(PKG_BUILD_DIR)/install
	#EXTRA_CFLAGS=$(STAGING_DIR)/usr/include/libnl \

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/bin
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(EXTLIB_MAKEOPTS))
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libwifi_hal.so $(1)/usr/lib/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ut $(1)/usr/bin
endef

define Package/rdk-v-wifi-ath10k/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_BUILD_DIR)/libwifi_hal.so $(1)/usr/lib/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ut $(1)/usr/bin
endef


$(eval $(call BuildPackage,rdk-v-wifi-ath10k,libwpa_client.so))
