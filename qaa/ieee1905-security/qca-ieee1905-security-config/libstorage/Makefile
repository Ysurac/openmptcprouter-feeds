include $(TOPDIR)/rules.mk

PKG_NAME:=libstorage
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

WIFI_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_A:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_D:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_MIPS_UNIFIED:=PACKAGE_kmod-qca-wifi-unified-perf
WIFI_10_2_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_10_2_ARM:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_L:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_16M:=PACKAGE_kmod-qca-wifi-flash_16mb-profile
WIFI_PKGS:=$(WIFI_U)||$(WIFI_C)||$(WIFI_A)||$(WIFI_D)||$(WIFI_MIPS)||$(WIFI_MIPS_UNIFIED)||$(WIFI_10_2_MIPS)||$(WIFI_10_2_ARM)||$(WIFI_L)||$(WIFI_16M)
PKG_BUILD_DEPENDS:=$(WIFI_U):qca-wifi $(WIFI_C):qca-wifi $(WIFI_A):qca-wifi $(WIFI_D):qca-wifi $(WIFI_MIPS):qca-wifi $(WIFI_16M):qca-wifi \
	$(WIFI_MIPS_UNIFIED):qca-wifi $(WIFI_10_2_MIPS):qca-wifi $(WIFI_10_2_ARM):qca-wifi $(WIFI_L):qca-wifi

include $(INCLUDE_DIR)/package.mk


QCASTORAGE_MAKEOPTS:= \
        TOOLPREFIX=$(TARGET_CROSS) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        ATHDIR=$(STAGING_DIR)/usr/include \
        EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
        EXTRA_LDFLAGS="$(TARGET_LDFLAGS)" \
        LIB_STORAGE_USE_UCI_FORMAT=y

QCASTORAGE_DEPENDS:=@$(WIFI_PKGS) +libhyficommon +libuci +libwifisoncfg

QCASTORAGE_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
QCASTORAGE_MAKEOPTS+=ENABLE_SON_MEMORY_DEBUG=y
QCASTORAGE_MAKEOPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif


define Package/libstorage
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=Storage Abstration Library
  DEPENDS:=$(QCASTORAGE_DEPENDS)
  SUBMENU:=IEEE1905.1 features
endef

define Package/libstorage/description
  This Package installs the Storage Abstration Library
endef

define Package/libstorage/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/install/lib/libstorage.so $(1)/usr/lib/
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(QCASTORAGE_MAKEOPTS))
endef

INSTALL_LIBS:= libstorage
INSTALL_HEADERS=storage.h

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/storage
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/storage)
endef

$(eval $(call BuildPackage,libstorage))
