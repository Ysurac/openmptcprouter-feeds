include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-hyctl
PKG_VERSION:=g26508a7

PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_REV:=26508a7
PKG_VERSION:=g26508a7
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -fpie
TARGET_LDFLAGS += -pie

QCAHYCTL_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        GWINCLUDE=$(STAGING_DIR)/usr/include/qca \
        HYFIDIR=$(STAGING_DIR)/usr/include/hyfibr \
        HYFIMCDIR=$(STAGING_DIR)/usr/include/hyfibr \
        HYFIBRLIBDIR=$(STAGING_DIR)/usr/include/libhyfibr \
        EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
        EXTRA_LDFLAGS="-Wl,--gc-sections $(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install

QCAHYCTL_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
  QCAHYCTL_MAKE_OPTS+=ENABLE_SON_MEMORY_DEBUG=y
  QCAHYCTL_MAKE_OPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

define Package/qca-hyctl
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  DEPENDS:=+kmod-qca-hyfi-bridge +qca-libhyfi-bridge $(QCAHYCTL_DEPENDS)
  TITLE:=Hy-Fi Control and Configuration command line utility
  SUBMENU:=Hy-Fi features
endef

define Package/qca-hyctl/description
  This package installs the Hy-Fi control command line utility
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/lib
	mkdir -p $(PKG_BUILD_DIR)/install/include
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCAHYCTL_MAKE_OPTS)) all
endef

define Package/qca-hyctl/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/hyctl $(1)/usr/sbin
endef

$(eval $(call BuildPackage,qca-hyctl))
