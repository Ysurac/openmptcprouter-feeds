include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-libhyfi-bridge
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_REV:=c5b6eb6
PKG_VERSION:=gc5b6eb6
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

QCALIBHYFI_BRIDGE_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        GWINCLUDE=$(STAGING_DIR)/usr/include/qca \
        EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
        EXTRA_LDFLAGS="$(TARGET_LDFLAGS)" \
        HYFIDIR=$(STAGING_DIR)/usr/include/hyfibr \
        HYFIMCDIR=$(STAGING_DIR)/usr/include/hyfibr

QCALIBHYFI_BRIDGE_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
QCALIBHYFI_BRIDGE_MAKE_OPTS+=ENABLE_SON_MEMORY_DEBUG=y
QCALIBHYFI_BRIDGE_MAKE_OPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

define Package/qca-libhyfi-bridge
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  DEPENDS:=+kmod-qca-hyfi-bridge $(QCALIBHYFI_BRIDGE_DEPENDS)
  TITLE:=Hy-Fi Bridging API Library
  SUBMENU:=Hy-Fi features
endef

define Package/qca-libhyfi-bridge/description
  This package installs the Hy-Fi Bridging API Library
endef

INSTALL_LIBS:= libhyfi-bridge
INSTALL_HEADERS=hyfi-bridge.h

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/libhyfibr
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/libhyfibr)
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/lib
	mkdir -p $(PKG_BUILD_DIR)/install/include
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCALIBHYFI_BRIDGE_MAKE_OPTS))
endef

define Package/qca-libhyfi-bridge/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/install/lib/libhyfi-bridge.so $(1)/usr/lib
endef

$(eval $(call BuildPackage,qca-libhyfi-bridge))
