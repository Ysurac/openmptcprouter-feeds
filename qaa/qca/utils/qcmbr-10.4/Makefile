#
# Copyright (c) 2014 Qualcomm Atheros, Inc..
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

include $(TOPDIR)/rules.mk

PKG:=qcmbr
PKG_NAME:=$(PKG)-10.4
PKG_SOURCE_PROTO:=git
PKG_BRANCH:=master
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/qcmbr-10.4
include $(INCLUDE_DIR)/local-development.mk

ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_VERSION:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
endif

ifeq ($(BUILD_VARIANT),netlink)
QCMBR_APP_OPTS+=USE_NETLINK=1
endif

PKG_SOURCE:=$(PKG)-$(PKG_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=$(1) - QCA ART Driver & tools
  DEPENDS:=+libpthread +libc +librt
  VARIANT:=default
endef

define Package/$(PKG_NAME)/description/Default
  ART package support for 10.4
endef

ifeq ($(BUILD_VARIANT),netlink)
TARGET_CPPFLAGS += \
	-I$(STAGING_DIR)/usr/include/libnl-tiny

TARGET_LDFLAGS+=-lnl-tiny
endif

define Build/Compile
	$(QCMBR_APP_OPTS) \
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		LD="$(TARGET_CC)" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		Qcmbr
endef

define Package/$(PKG_NAME)/install/Default
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/Qcmbr $(1)/usr/sbin
	$(INSTALL_BIN) ./files/qcmbr.init $(1)/etc/init.d/qcmbr
endef

define Package/qcmbr-10.4
$(call Package/qcmbr-10.4/Default)
endef

define Package/qcmbr-10.4/Description
$(call Package/$(PKG_NAME)/Description/Default)
endef

define Package/qcmbr-10.4/config
$(call Package/qcmbr-10.4/config/Default)
endef

define Package/qcmbr-10.4/install
$(call Package/qcmbr-10.4/install/Default,$(1))
endef

$(eval $(call BuildPackage,qcmbr-10.4))

define Package/qcmbr-10.4-netlink
  $(call Package/qcmbr-10.4/Default,netlink)
  VARIANT:=netlink
  DEPENDS+=+libnl-tiny
endef

define Package/qcmbr-10.4-netlink/Description
  $(call Package/qcmbr-10.4/Description/Default)
endef

define Package/qcmbr-10.4-netlink/config
  $(call Package/qcmbr-10.4/config/Default,netlink)
endef

define Package/qcmbr-10.4-netlink/install
  $(call Package/qcmbr-10.4/install/Default,$(1))
endef

$(eval $(call BuildPackage,qcmbr-10.4-netlink))
