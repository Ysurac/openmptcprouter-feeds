include $(TOPDIR)/rules.mk

PKG:=qca-icm
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://qca-git01.qualcomm.com:29418/qca/src/$(PKG_NAME).git
PKG_BRANCH:=master
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/common-tools
include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif


PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)-$(PKG_VERSION)
PKG_BUILD_DEPENDS:=kmod-qca-wifi

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA Intelligent channel manager
  DEPENDS:=kmod-qca-wifi +libpthread qca-spectral +libnl
endef

TARGET_CFLAGS += \
  -I$(STAGING_DIR)/usr/include \
  -I. \
  -Idriver \
  -Icommon \
  -I$(STAGING_DIR)/usr/include/libnl3

TARGET_LDFLAGS += \
  -lnl-3 -lnl-genl-3

# Update CFLAGS
TARGET_CFLAGS+= -Wall -Werror

ifeq (${BUILD_STATIC}, y)
TARGET_LDFLAGS+= -static
endif

ifeq (${BUILD_DEBUG}, y)
TARGET_CFLAGS+= -g
endif

ifeq (${BUILD_OPTIMIZED}, y)
TARGET_CFLAGS += -Os -pipe -mips32r2 -mtune=mips32r2 -funit-at-a-time
endif

TARGET_CFLAGS += -DICM_RTR_DRIVER

ifdef CONFIG_USE_MUSL
ifeq ($(ARCH),aarch64)
 TARGET_CFLAGS+=-DAARCH64_WITH_MUSL
endif
endif

MAKEOPTS+= \
  $(TARGET_CONFIGURE_OPTS) \
  WLAN_SPECTRAL_ENABLE=1 \
  LDFLAGS="$(TARGET_LDFLAGS)" \
  CFLAGS="$(TARGET_CFLAGS)"\

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/icm $(MAKEOPTS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/icm/icm $(1)/usr/sbin

	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_BIN) ./files/icm.sh $(1)/lib/wifi

	$(INSTALL_DIR) $(1)/etc/ath
	$(INSTALL_DATA) ./files/icm.conf $(1)/etc/ath
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
