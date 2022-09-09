include $(TOPDIR)/rules.mk

PKG:=libathtestcmd
PKG_NAME:=$(PKG)
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/common-tools/ath6kl-utils/libathtestcmd

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
  TITLE:= QTI libathtestcmd utils
  DEPENDS:= @TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64||TARGET_ipq807x +libpthread +libnl +libtcmd +libtlv2 +libtlvutil
endef

define Package/$(PKG_NAME)/description/Default
  LIBATHTESTCMD Package Support for QTI WIFI 11 drivers
endef


TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include \
		 -I./include \
		 -I$(STAGING_DIR)/usr/lib/ \
		 -I$(STAGING_DIR)/usr/include/libnl3 \
		 -I$(STAGING_DIR)/usr/include/libnl3/netlink \
		 -I$(STAGING_DIR)/usr/include/libtlv2 \
		 -I$(STAGING_DIR)/usr/include/libtlvutil \
		 -fPIC -DWLAN_API_NL80211 -DLIBNL_2 -DWIN_AP_HOST -D_HOST_SIM_TESTING -DLinux -DUSE_TLV2

TARGET_LDFLAGS += -shared
TARGET_LDFLAGS += -ltcmd -ltlv2 -ltlv1util

ifneq ($(CONFIG_PACKAGE_kmod-ath11k),)
	TARGET_CFLAGS+=-DWIN_AP_HOST_OPEN=1
endif

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/libathtestcmd $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/testcmd6174.h $(1)/usr/include/libathtestcmd
	$(CP)   $(PKG_BUILD_DIR)/include/*.h $(1)/usr/include/libathtestcmd
	$(CP) $(PKG_BUILD_DIR)/libtestcmd6174.so $(1)/usr/lib
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libtestcmd6174.so $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libathtestcmd))
