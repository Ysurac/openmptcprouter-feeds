include $(TOPDIR)/rules.mk

PKG_NAME:=libwpa2
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

LIBWPA2_MAKEOPTS:= \
        TOOLPREFIX=$(TARGET_CROSS) \
	EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
	EXTRA_LDFLAGS="$(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install

LIBWPA2_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
LIBWPA2_MAKEOPTS+=ENABLE_SON_MEMORY_DEBUG=y
LIBWPA2_MAKEOPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

define Package/libwpa2
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=WPA2 Library
  DEPENDS:=$(LIBWPA2_DEPENDS)
  SUBMENU:=IEEE1905.1 features
endef

define Package/libwpa2/description
  This Package contains the wpa2 library
endef

define Package/libwpa2/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/install/lib/libwpa2.so $(1)/usr/lib/
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(LIBWPA2_MAKEOPTS))
endef

INSTALL_LIBS:= libwpa2
INSTALL_HEADERS=\
                aes.h \
                aes_wrap.h \
                asn1.h \
                bignum.h \
                build_config.h \
                common.h \
                crypto.h \
                defs.h \
                eap_defs.h \
                eloop.h \
                includes.h \
                l2_packet.h \
                md5.h \
                os.h \
                rc4.h \
                rsa.h \
                sha1.h \
                sha256.h \
                wpa_common.h \
                wps_config.h \
                wps_parser.h \
                base64.h \
                aes_siv.h


define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/wpa2
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/wpa2)
endef

$(eval $(call BuildPackage,libwpa2))
