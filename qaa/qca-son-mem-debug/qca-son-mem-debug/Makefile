include $(TOPDIR)/rules.mk

PKG_NAME:=qca-son-mem-debug
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/qca-son-mem-debug/config
  source "$(SOURCE)/Config.in"
endef

define Package/qca-son-mem-debug
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=SON Memory Management Abstraction Library
  DEPENDS:=
  SUBMENU:=SON Memory Management Abstraction Library
endef

define Package/qca-son-mem-debug/description
  This Package contains the QCA son memory debug
endef

define Package/qca-son-mem-debug/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/install/lib/libqcasonmemdebug.so $(1)/usr/lib/
endef

QCASONMEMDBG_MAKEOPTS:= \
        TOOLPREFIX=$(TARGET_CROSS) \
	EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
	EXTRA_LDFLAGS="$(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(QCASONMEMDBG_MAKEOPTS))
endef

INSTALL_LIBS:= libqcasonmemdebug
INSTALL_HEADERS=\
                qca-son-mem-debug.h \
                son-mem-debug.h

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/son-mem-dbg
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/son-mem-dbg)
endef

$(eval $(call BuildPackage,qca-son-mem-debug))
