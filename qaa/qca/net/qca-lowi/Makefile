#
# Copyright (c) 2014 Qualcomm Atheros, Inc
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

include $(TOPDIR)/rules.mk

PKG:=qca-lowi
PKG_NAME:=$(PKG)
PKG_BRANCH:=master
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/qca-lowi
include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif

PKG_SOURCE_SUBDIR:=$(PKG)-$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)-$(PKG_VERSION)

include $(INCLUDE_DIR)/uclibc++.mk
include $(INCLUDE_DIR)/package.mk

PKG_BUILD_DEPENDS:=qca-hostap

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA Location WiFi Interface
  DEPENDS:=qca-hostap @(!(PACKAGE_hostapd)) +librt +libpthread +libnl +libroxml $(CXX_DEPENDS)
endef

TARGET_CPPFLAGS += \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/libnl \
	-I$(STAGING_DIR)/usr/include/libnl3

TARGET_CFLAGS += \
    -DLOWI_ON_ACCESS_POINT -DCONFIG_SUPPORT_LIBROXML=1

MAKEOPTS+= \
	$(TARGET_CONFIGURE_OPTS) \
    CXX="$(TARGET_CXX)" \
    CXXFLAGS="$(TARGET_CXXFLAGS) -std=c++11 -fno-rtti" \
	COPTS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
    INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
    LOWI_SRC_PATH=$(PKG_BUILD_DIR) \
    ATH_SUPPORT_LOWI_ON_AP=1

define Build/RunMake
	mkdir -p $(PKG_BUILD_DIR)/install/lib
	$(MAKE) -C $(PKG_BUILD_DIR)/$(1) \
	$(MAKEOPTS)
endef

define Build/Compile/$(PKG_NAME)
	$(call Build/RunMake,internal/lowi)
endef

define Build/Compile
	$(Build/Compile/$(PKG_NAME))
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/liblowi_client
	$(INSTALL_DIR) $(1)/usr/include/liblowi_client/inc
	$(CP) $(PKG_BUILD_DIR)/internal/lowi/inc/*.h $(1)/usr/include/liblowi_client/inc
	$(INSTALL_DIR) $(1)/usr/include/liblowi_client/base_util
	$(CP) $(PKG_BUILD_DIR)/util/native/base_util/*.h $(1)/usr/include/liblowi_client/base_util
	$(INSTALL_DIR) $(1)/usr/include/liblowi_client/mq_client
	$(CP) $(PKG_BUILD_DIR)/util/native/mq_client/*.h $(1)/usr/include/liblowi_client/mq_client
	$(INSTALL_DIR) $(1)/usr/lib/lowi
	$(CP) $(PKG_BUILD_DIR)/internal/lowi/lowi_client/liblowi_client.so $(1)/usr/lib/lowi
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lowi
	$(CP) $(PKG_BUILD_DIR)/internal/lowi/lowi_client/liblowi_client.so $(1)/usr/lib/lowi
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/internal/lowi/lowi_server/lowi-server $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/internal/lowi/test/lowi_test/lowi-test $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_BIN) ./files/lowi.sh $(1)/lib/wifi
	$(INSTALL_DIR) $(1)/etc/lowi
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/internal/lowi/etc/lowi.conf $(1)/etc/lowi
	$(INSTALL_DIR) $(1)/usr/share/location/lowi
	$(INSTALL_DIR) $(1)/usr/share/location/mq
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
