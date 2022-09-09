include $(TOPDIR)/rules.mk

PKG:=myftm
PKG_NAME:=$(PKG)
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/common-tools/ath6kl-utils/myftm

include $(INCLUDE_DIR)/local-development.mk

ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_VERSION:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
endif

#PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qualcomm.com
  MAINTAINER:=Qualcomm Technologies, Inc
  TITLE:= QTI myftm utils
  DEPENDS:= @TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64||TARGET_ipq807x||TARGET_ipq60xx +libtcmd +librt +libnl +libathtestcmd +zlib
endef

define Package/$(PKG_NAME)/description/Default
	My FTM Package Support for QTI WIFI 11 drivers
endef

TARGET_CFLAGS += -DCONFIG_FTM_WLAN -DDEBUG -DFTM_DEBUG -DCONFIG_FTM_WLAN_AUTOLOAD -DWIN_AP_HOST -DUSE_TLV2
TARGET_CFLAGS += -MMD -O2 -Wall -g
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include/
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include/libathtestcmd
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/lib/libathtestcmd
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/lib/
TARGET_CFLAGS += -fpie
TARGET_LDFLAGS += -ltcmd -ltestcmd6174 -lz
TARGET_CSRCS := myftm_main.c myftm_wlan.c myftm_qtip.c
TARGET_LDFLAGS += -pie

define Build/Compile
$(MAKE) -C $(PKG_BUILD_DIR) \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	CSRCS="$(TARGET_CSRCS)"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/myftm $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,myftm))
