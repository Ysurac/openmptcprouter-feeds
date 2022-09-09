include $(TOPDIR)/rules.mk

PKG_NAME:=libieee1905
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

QCAIEEE1905_DEPENDS:=+libhyficommon

QCAIEEE1905_MAKEOPTS:= \
        TOOLPREFIX=$(TARGET_CROSS) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon/ \
	EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
	EXTRA_LDFLAGS="$(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install

QCAIEEE1905_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
QCAIEEE1905_MAKEOPTS+=ENABLE_SON_MEMORY_DEBUG=y
QCAIEEE1905_MAKEOPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

define Package/libieee1905
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=IEEE1905.1 Library
  DEPENDS:=$(QCAIEEE1905_DEPENDS)
  SUBMENU:=IEEE1905.1 features
endef

define Package/libieee1905/description
  This Package contains the IEEE1905.1 library
endef

define Package/libieee1905/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/install/lib/libieee1905.so $(1)/usr/lib/
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(QCAIEEE1905_MAKEOPTS))
endef

INSTALL_LIBS:= libieee1905
INSTALL_HEADERS=ieee1905_defs.h \
              ieee1905.h \
              ieee1905_vendor.h \
              ieee1905_vendor_consts.h \
              mid.h

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/ieee1905
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/ieee1905)
endef

$(eval $(call BuildPackage,libieee1905))
