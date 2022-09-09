include $(TOPDIR)/rules.mk

PKG:=qca-wpc
PKG_NAME:=$(PKG)
PKG_BRANCH:=master
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/qca-wpc
include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif

PKG_SOURCE_SUBDIR:=$(PKG)-$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)-$(PKG_VERSION)

PKG_BUILD_DEPENDS:=qca-wifi

include $(INCLUDE_DIR)/package.mk

ifeq ($(CONFIG_GCC_USE_VERSION_7),y)
ifeq ($(CONFIG_TARGET_ipq807x_generic)$(CONFIG_TARGET_ipq50xx_generic)$(CONFIG_TARGET_ipq60xx_generic),y)
TARGET_CFLAGS += -DQCA_GCC_7_SUPPORT
endif
endif

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA Wifi Positioning
  DEPENDS:=@!TARGET_ipq_ipq807x_64 @!TARGET_ipq807x_generic @!TARGET_ipq50xx_generic @!TARGET_ipq60xx_generic @!TARGET_ipq_ipq60xx_64 @!TARGET_ipq_ipq50xx_64 +libpthread +librt
endef

MAKEOPTS+= \
	$(TARGET_CONFIGURE_OPTS) \
	COPTS="$(TARGET_CFLAGS)" \
        TARGET_CFLAGS="$(TARGET_CFLAGS)" \
        TARGET_LDFLAGS="$(TARGET_LDFLAGS)" \
	ATHEROSPATH=$(STAGING_DIR)/usr/include \
	ATH_SUPPORT_WIFIPOS=1

define Build/RunMake
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR)/$(1) \
	$(MAKEOPTS) \
	$(TARGET_CONFIGURE_OPTS) \
	LIBS="$(TARGET_LDFLAGS)" \
	$(2)
endef

define Build/Compile/$(PKG_NAME)
	$(call Build/RunMake,wpc, \
		wpc \
	)
endef

define Build/Compile
	$(Build/Compile/$(PKG_NAME))
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wpc/wpc $(1)/usr/sbin

	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_BIN) ./files/wpc.sh $(1)/lib/wifi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
