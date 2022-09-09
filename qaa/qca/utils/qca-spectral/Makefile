include $(TOPDIR)/rules.mk

PKG:=qca-spectral
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://qca-git01.qualcomm.com:29418/wifi/$(PKG_NAME).git
PKG_BRANCH:=master
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif


PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)-$(PKG_VERSION)
PKG_BUILD_DEPENDS:=qca-wifi

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA Spectral Analysis
  DEPENDS:=+libpthread +libnl +qca-cfg80211
endef

TARGET_CFLAGS += \
        -I$(STAGING_DIR)/usr/include/ \
        -I$(STAGING_DIR)/usr/include/libnl3

TARGET_LDFLAGS += \
        -lnl-3 -lnl-genl-3

MAKEOPTS+= \
	$(TARGET_CONFIGURE_OPTS) \
	COPTS="$(TARGET_CFLAGS) $(TARGET_LDFLAGS)" \
	ATHEROSPATH=$(STAGING_DIR)/usr/include \
	ATH_SUPPORT_SPECTRAL=1 \
	SPECTRAL_SUPPORT_CFG80211=1 \
	WLAN_FEATURE_ATHSSD_DEBUG=1 \
	QSDK_SPECTRAL=1

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) $(MAKEOPTS)
	$(CP) $(PKG_BUILD_DIR)/libath_classifier.a $(STAGING_DIR)/usr/lib/libath_classifier.a
	$(CP) $(PKG_BUILD_DIR)/ath_classifier.h $(STAGING_DIR)/usr/include/ath_classifier.h
	$(CP) $(PKG_BUILD_DIR)/wireless_copy.h $(STAGING_DIR)/usr/include/wireless_copy.h
	$(CP) $(PKG_BUILD_DIR)/common/spectral.h $(STAGING_DIR)/usr/include/spectral.h
	$(CP) $(PKG_BUILD_DIR)/common/spec_msg_proto.h $(STAGING_DIR)/usr/include/spec_msg_proto.h
	$(CP) $(PKG_BUILD_DIR)/common/spectral_data.h $(STAGING_DIR)/usr/include/spectral_data.h
	$(CP) $(PKG_BUILD_DIR)/common/spectral_types.h $(STAGING_DIR)/usr/include/spectral_types.h
	$(CP) $(PKG_BUILD_DIR)/common/classifier.h $(STAGING_DIR)/usr/include/classifier.h
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/athssd $(1)/usr/sbin
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
