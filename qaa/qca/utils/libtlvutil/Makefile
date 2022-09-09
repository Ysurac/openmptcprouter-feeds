include $(TOPDIR)/rules.mk

PKG:=libtlvutil
PKG_NAME:=$(PKG)
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/common-tools/ath6kl-utils/libathtestcmd/

include $(INCLUDE_DIR)/local-development.mk

ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_VERSION:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
endif

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qualcomm.com
  MAINTAINER:=Qualcomm Technologies, Inc
  TITLE:= QTI libtlvutil utils
  DEPENDS:= @TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64||TARGET_ipq807x||TARGET_ipq60xx +libpthread +libnl
endef

define Package/$(PKG_NAME)/description/Default
  LIBTLVUTIL Package Support for QTI WIFI 11 drivers
endef


TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include \
		 -I./../include \
		 -I./common/ \
		 -I./templete/ \
		 -I./defParm/ \
		 -fPIC -DWLAN_API_NL80211 -DLIBNL_2 -DWIN_AP_HOST -D_HOST_SIM_TESTING -D_FOR_HOST_TESTING

TARGET_LDFLAGS += -shared

ifneq ($(CONFIG_PACKAGE_kmod-ath11k),)
	TARGET_CFLAGS+=-DWIN_AP_HOST_OPEN=1
endif

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/libtlvutil \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/$(PKG_NAME) $(1)/usr/lib/
	$(CP)   $(PKG_BUILD_DIR)/libtlvutil/common/tcmdHostInternal.h $(1)/usr/include/$(PKG_NAME)
	$(CP)   $(PKG_BUILD_DIR)/libtlvutil/*.h $(1)/usr/include/$(PKG_NAME)
	$(CP)   $(PKG_BUILD_DIR)/libtlvutil/libtlv1util.so  $(1)/usr/lib/
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libtlvutil/libtlv1util.so $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libtlvutil))
