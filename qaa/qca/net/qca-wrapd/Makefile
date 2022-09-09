include $(TOPDIR)/rules.mk

PKG:=qca-wrapd
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

PKG_BUILD_DEPENDS:=qca-hostap
PKG_ASLR_PIE:=0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA wrapd daemon
  DEPENDS:=@(PACKAGE_qca-hostap||PACKAGE_qca-hostap-lite) @(!(PACKAGE_hostapd)) +libpthread +libnl +qca-cfg80211
endef

define Package/$(PKG_NAME)/description
  User Space application to support QWRAP feature
endef

ifeq (${ARCH},mips)
    export ARCH
endif

MAKEOPTS+= \
           $(TARGET_CONFIGURE_OPTS) \
           COPTS="$(TARGET_CFLAGS)" \
           WPA_PATH=$(STAGING_DIR)/usr/lib \
           QSDK_WRAPD=$(STAGING_DIR)/usr/include \
           LIBS="$(TARGET_LDFLAGS)"

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) $(MAKEOPTS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wrapd $(1)/usr/sbin

	$(INSTALL_DIR) $(1)/etc/ath
	$(INSTALL_DATA) ./files/wrap-vma-wifi0.conf $(1)/etc/ath
	$(INSTALL_DATA) ./files/wrap-vma-wifi1.conf $(1)/etc/ath
	$(INSTALL_DATA) ./files/wrap-vma-wifi2.conf $(1)/etc/ath

	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_DATA) ./files/qwrap.sh $(1)/lib/wifi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
