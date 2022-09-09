include $(TOPDIR)/rules.mk

PKG:=qca-acfg
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://qca-git01.qualcomm.com:29418/wifi/$(PKG_NAME).git
PKG_BRANCH:=master
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)-$(PKG_VERSION)

PKG_BUILD_DEPENDS:=kmod-qca-wifi

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA Configuration Utility
  DEPENDS:=@(!(PACKAGE_hostapd)) +libgcc +libc +wireless-tools +librt +kmod-cfg80211-linux  +libnl +qca-cfg80211 +qca-hostap
endef

define Package/$(PKG_NAME)/description
 QCA configuration utility provides a set of library
 API's through which user applications can configure
 and register events for wifi driver and hostap
endef

MAKEOPTS+= \
	$(TARGET_CONFIGURE_OPTS) \
	WLAN_TOP=$(STAGING_DIR)/usr \
	COPTS="$(TARGET_CFLAGS) -I. -I$(PKG_BUILD_DIR)/include" \
	QSDK_ACFG=1 MEM_PROFILE="$(CONFIG_KERNEL_IPQ_MEM_PROFILE)"

define Build/Compile
	#Compile acfg_fw_recovery only for low mem
ifeq ($(strip ${CONFIG_LOWMEM_FLASH}),y)
ifeq ($(strip ${CONFIG_DEBUG}),y)
	$(MAKE) -C $(PKG_BUILD_DIR)/acfg_fw_rec $(MAKEOPTS)
endif
else
	$(MAKE) -C $(PKG_BUILD_DIR)/src $(MAKEOPTS)
	$(MAKE) -C $(PKG_BUILD_DIR)/acfg_test_app $(MAKEOPTS) LIB_OUT=acfg
	$(MAKE) -C $(PKG_BUILD_DIR)/acfg_profile_app $(MAKEOPTS) \
	PROFILE_LIB_OUT=acfg_profile
endif
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d

ifeq ($(strip ${CONFIG_LOWMEM_FLASH}),y)
ifeq ($(strip ${CONFIG_DEBUG}),y)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/acfg_fw_rec/acfg_fw_recovery $(1)/usr/sbin
	$(INSTALL_BIN) ./files/qca-acfg_fw_rec.init $(1)/etc/init.d/qca-acfg_fw_rec
endif
else
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/acfg_test_app/acfg_tool $(1)/usr/sbin
ifneq ($(strip ${CONFIG_KERNEL_IPQ_MEM_PROFILE}),512)
ifneq ($(strip ${CONFIG_KERNEL_IPQ_MEM_PROFILE}),256)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/acfg_profile_app/acfg_set_profile $(1)/usr/sbin
endif
endif

	$(INSTALL_BIN) ./files/qca-acfg.init $(1)/etc/init.d/qca-acfg
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/acfg_common.conf $(1)/etc
endif
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
