include $(TOPDIR)/rules.mk

PKG:=qca-cfg80211tool
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://qca-git01.qualcomm.com:29418/wifi/$(PKG_NAME).git
PKG_BRANCH:=master
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/common-tools
DRIVER_PATH:=$(TOPDIR)/qca/src/qca-wifi
include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif


PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

PKG_BUILD_DEPENDS:=qca-wifi

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:= QCA cfg80211 utils
  DEPENDS:=+libnl +libpthread +libroxml +iw
endef

TARGET_CFLAGS += \
		     -I$(STAGING_DIR)/usr/include/ \
		     -I$(STAGING_DIR)/usr/include/libnl \
		     -I$(STAGING_DIR)/usr/include/libnl3 \
                     -D_GNU_SOURCE=1 -D__USE_GNU=1 -D__WIN__=1 -DCONFIG_SUPPORT_LIBROXML=1

TARGET_LDFLAGS += \
	             -lnl-3 -lnl-genl-3 -lroxml

TARGET_CFLAGS += -fpie
TARGET_CFLAGS += -fPIC
TARGET_LDFLAGS += -pie

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/vendorcmdtool \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/vendorcmdtool/cfg80211tool.1 $(1)/usr/sbin
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
