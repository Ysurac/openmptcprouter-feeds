include $(TOPDIR)/rules.mk

PKG_NAME:=libhyficommon
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

HYFICOMMON_MAKEOPTS:= \
        TOOLPREFIX=$(TARGET_CROSS) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/qca/ \
        QCACFLAGS="$(TARGET_CFLAGS)"\
        QCALDFLAGS="-Wl,--gc-sections $(TARGET_LDFLAGS)"\
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install


HYFICOMMON_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
HYFICOMMON_MAKEOPTS+=ENABLE_SON_MEMORY_DEBUG=y
HYFICOMMON_MAKEOPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg/
endif

define Package/libhyficommon
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=Hy-Fi Common Functionality Library
  DEPENDS:=$(HYFICOMMON_DEPENDS)
  SUBMENU:=Hy-Fi features
endef

define Package/libhyficommon/description
  This Package contains the Hy-Fi Common Functionality Library
endef

define Package/libhyficommon/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/install/lib/libhyficommon.so $(1)/usr/lib/
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(HYFICOMMON_MAKEOPTS))
endef

INSTALL_LIBS:= libhyficommon
INSTALL_HEADERS=bufrd.h \
	bufwr.h \
	cmd.h \
	csh.h \
	dbg.h \
	evloop.h \
	interface.h \
	split.h

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/hyficommon
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/hyficommon)
endef

$(eval $(call BuildPackage,libhyficommon))
