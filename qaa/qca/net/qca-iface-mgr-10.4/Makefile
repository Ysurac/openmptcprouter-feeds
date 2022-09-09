include $(TOPDIR)/rules.mk

PKG:=qca-iface-mgr
PKG_NAME:=$(PKG)-10.4
PKG_SOURCE_PROTO:=git
PKG_BRANCH:=master
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

PKG_BUILD_DEPENDS:=qca-hostap libnl libwifisoncfg

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA Interface manager daemon
  DEPENDS:=@(PACKAGE_qca-hostap||PACKAGE_qca-hostap-lite) @(!(PACKAGE_hostapd)) +libpthread +libnl +libwifisoncfg
endef

define Package/$(PKG_NAME)/config
source "$(SOURCE)/Config.in"
endef

define Package/$(PKG_NAME)/description
  User Space application to manage interfaces
endef

TARGET_CFLAGS += \
		  -I$(STAGING_DIR)/usr/include \
		  -I$(STAGING_DIR)/usr/include/libnl \
		  -I$(STAGING_DIR)/usr/include/libnl3 \
		  -I$(STAGING_DIR)/usr/lib \
		  -fpie

TARGET_LDFLAGS += \
	-lnl-3 -lnl-genl-3 -pie -lwifisoncfg -lhyficommon

ifeq ($(CONFIG_IFACE_SUPPORT_CFG80211),y)
TARGET_CFLAGS += -DIFACE_SUPPORT_CFG80211
TARGET_LDFLAGS += -lqca_nl80211_wrapper
endif

MAKEOPTS+= \
           $(TARGET_CONFIGURE_OPTS) \
	   CFLAGS="$(TARGET_CFLAGS)" \
           COPTS="$(TARGET_CFLAGS)" \
           WPA_PATH=$(STAGING_DIR)/usr/lib \
           LIBS="$(TARGET_LDFLAGS)"

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) $(MAKEOPTS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/iface-mgr $(1)/usr/sbin

	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_DATA) ./files/iface_mgr.sh $(1)/lib/wifi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
