
include $(TOPDIR)/rules.mk

PKG:=qca-hostap
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://qca-git01.qualcomm.com:29418/wifi/$(PKG_NAME).git
PKG_BRANCH:=master
PKG_RELEASE:=1
PATCH_DIR:=$(TOPDIR)/qca/src/$(PKG_NAME)/qca-patches

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif

LOCAL_TYPE=$(strip \
		$(if $(findstring supplicant,$(BUILD_VARIANT)),supplicant, \
		hostap \
	))

LOCAL_VARIANT=$(patsubst supplicant-%,%,$(BUILD_VARIANT))

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(BUILD_VARIANT)/$(PKG)-$(PKG_VERSION)

PKG_BUILD_DEPENDS:=qca-wifi

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=Hostap authenticator
  DEPENDS:=@$(WIFI_PKGS) @(!(PACKAGE_hostapd)) +libnl +libopenssl
  VARIANT:=default
endef

define Package/$(PKG_NAME)-lite
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=Hostap authenticator for lite profile
  DEPENDS:=@$(WIFI_PKGS) @(!(PACKAGE_hostapd)) +libnl +libopenssl
  VARIANT:=lite
endef

define Package/$(PKG_NAME)/description
 This package contains the IEEE 802.1x/WPA/EAP/RADIUS Authenticator.
endef

define Package/$(PKG_NAME)-lite/description
 This package contains the IEEE 802.1x/WPA/EAP/RADIUS Authenticator.
endef

define Package/$(PKG_NAME)-macsec
  $(call Package/$(PKG_NAME))
  TITLE:=Hostap authenticator (MACSEC)
  DEPENDS+= @TARGET_ipq806x||TARGET_ipq||TARGET_ipq807x||TARGET_ipq60xx||TARGET_ipq50xx +kmod-qca-nss-macsec
  VARIANT:=macsec
endef

define Package/$(PKG_NAME)-macsec/Description
  Hostap authenticator with MACSEC support for IPQ807x.
endef

define Package/qca-hostapd-cli
  $(call Package/$(PKG_NAME)/Default)
  DEPENDS:=@(PACKAGE_qca-hostap||PACKAGE_qca-hostap-macsec||PACKAGE_qca-hostap-lite) +librt +libnl +libopenssl
  DEPENDS+= PACKAGE_kmod-qca-nss-macsec:kmod-qca-nss-macsec
  TITLE:=Hostap authenticator command line interface
endef

define Package/qca-hostapd-cli/description
 This package contains a command line utility to control the
 IEEE 802.1x/WPA/EAP/RADIUS Authenticator.
endef

define Package/qca-wpa-supplicant
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=WPA Supplicant
  DEPENDS:=@$(WIFI_PKGS) @(!(PACKAGE_wpa-supplicant)) +libopenssl +libnl
  VARIANT:=supplicant-default
endef

define Package/qca-wpa-supplicant-lite
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=WPA Supplicant for lite profile
  DEPENDS:=@$(WIFI_PKGS) @(!(PACKAGE_wpa-supplicant)) +libopenssl +libnl
  VARIANT:=supplicant-lite
endef

define Package/qca-wpa-supplicant/Description
  WPA Supplicant
endef

define Package/qca-wpa-supplicant-lite/Description
  WPA Supplicant for lite profile
endef

define Package/qca-wpa-supplicant-macsec
  $(call Package/qca-wpa-supplicant)
  TITLE:=WPA Supplicant (MACSEC)
  DEPENDS+= @TARGET_ipq806x||TARGET_ipq||TARGET_ipq807x||TARGET_ipq60xx||TARGET_ipq50xx +kmod-qca-nss-macsec
  VARIANT:=supplicant-macsec
endef

define Package/qca-wpa-supplicant-macsec/Description
  WPA Supplicant with MACSEC support for IPQ8066.
endef

define Package/qca-wpa-cli
  $(call Package/$(PKG_NAME)/Default)
  DEPENDS:=@(PACKAGE_qca-wpa-supplicant||PACKAGE_qca-wpa-supplicant-macsec||PACKAGE_qca-wpa-supplicant-lite) +librt  +libopenssl +libnl
  TITLE:=WPA Supplicant command line interface
endef

define Package/qca-wpa-cli/Description
  WPA Supplicant control utility
endef


ifneq ($(wildcard $(PKG_BUILD_DIR)/.config_*),$(subst .configured_,.config_,$(STAMP_CONFIGURED)))
  define Build/Configure/rebuild
	$(FIND) $(PKG_BUILD_DIR) -name \*.o -or -name \*.a | $(XARGS) rm -f
	rm -f $(PKG_BUILD_DIR)/hostapd/hostapd
	rm -f $(PKG_BUILD_DIR)/wpa_supplicant/wpa_supplicant
	rm -f $(PKG_BUILD_DIR)/.config_*
	touch $(subst .configured_,.config_,$(STAMP_CONFIGURED))
  endef
endif

define Build/Configure
	$(Build/Configure/rebuild)
	$(if $(wildcard ./files/hostapd-$(LOCAL_VARIANT).config), \
		$(CP) ./files/hostapd-$(LOCAL_VARIANT).config $(PKG_BUILD_DIR)/hostapd/.config \
	)
	$(CP) ./files/wpa_supplicant-$(LOCAL_VARIANT).config $(PKG_BUILD_DIR)/wpa_supplicant/.config
endef

TARGET_CPPFLAGS += \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/qca-nss-macsec

TARGET_LDFLAGS += \
	-lnl-3 -lnl-genl-3 -lm -lssl -lcrypto -lpthread -ldl -pie

TARGET_CFLAGS += -fpie -Werror

ifneq ($(LOCAL_TYPE),hostap)
    TARGET_LDFLAGS += \
		-lssl -lcrypto
endif

ifeq ($(LOCAL_VARIANT),macsec)
    TARGET_LDFLAGS += -lfal -L$(STAGING_DIR)/usr/lib
endif

define Build/RunMake
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR)/$(1) \
	$(TARGET_CONFIGURE_OPTS) \
	LIBS="$(TARGET_LDFLAGS)" \
	$(2)
endef

define Build/Compile/qca-hostap
	$(call Build/RunMake,hostapd, \
		hostapd hostapd_cli \
	)
endef

define Build/Compile/qca-supplicant
	$(call Build/RunMake,wpa_supplicant, \
		wpa_supplicant wpa_cli \
	)
endef

define Build/Compile
	$(Build/Compile/qca-$(LOCAL_TYPE))
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/src/common/wpa_ctrl.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/common/qca-vendor.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/common/ieee802_11_defs.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/utils/includes.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/utils/build_config.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/utils/eloop.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/utils/os.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/utils/common.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/utils/wpa_debug.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/utils/wpabuf.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/drivers/linux_ioctl.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/drivers/linux_wext.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/drivers/netlink.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/drivers/priv_netlink.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/drivers/nl80211_copy.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/common/wpa_ctrl.o $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/src/drivers/netlink.o $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/src/utils/eloop.o $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/src/utils/wpa_debug.o $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/src/utils/common.o $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/src/utils/os_unix.o $(1)/usr/lib/
endef

define Install/$(PKG_NAME)
	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_DATA) ./files/hostapd.sh $(1)/lib/wifi/hostapd.sh
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/qca-hostapd.init $(1)/etc/init.d/qca-hostapd
	$(INSTALL_DIR) $(1)/usr/sbin
endef

define Install/qca-wpa-supplicant
	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_DATA) ./files/wpa_supplicant.sh $(1)/lib/wifi/wpa_supplicant.sh
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/qca-wpa-supplicant.init $(1)/etc/init.d/qca-wpa-supplicant
	$(INSTALL_DIR) $(1)/usr/sbin
endef

define Package/$(PKG_NAME)/install
	$(call Install/$(PKG_NAME),$(1))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd $(1)/usr/sbin/
endef

define Package/$(PKG_NAME)-lite/install
	$(call Install/$(PKG_NAME),$(1))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd $(1)/usr/sbin/
endef

define Package/$(PKG_NAME)-macsec/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd $(1)/usr/sbin/hostapd-macsec
endef

ifneq ($(LOCAL_TYPE),supplicant)
ifneq ($(LOCAL_VARIANT),macsec)
  define Package/qca-hostapd-cli/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/hotplug.d/button
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd_cli $(1)/usr/sbin/
	$(INSTALL_DATA) ./files/wps-hotplug.sh $(1)/etc/hotplug.d/button/50-wps
	$(INSTALL_DATA) ./files/wps-extender-hotplug.sh \
			$(1)/etc/hotplug.d/button/54-wps-extender
	$(INSTALL_DATA) ./files/wps-reset-hotplug.sh $(1)/etc/hotplug.d/button/51-wps-reset

	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_BIN) ./files/wps-hostapd-update-uci.sh \
			$(1)/lib/wifi/wps-hostapd-update-uci

	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_BIN) ./files/dpp-supplicant-update-uci.sh \
			$(1)/lib/wifi/dpp-supplicant-update-uci

	$(INSTALL_BIN) ./files/wps-hostapd-nbh-update.sh \
			$(1)/lib/wifi/wps-hostapd-nbh-update

	$(INSTALL_BIN) ./files/dpp-hostapd-update-uci.sh \
			$(1)/lib/wifi/dpp-hostapd-update-uci
	$(INSTALL_BIN) ./files/dpp-operating-class-update.sh \
			$(1)/lib/wifi/dpp-operating-class-update.sh

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/hapd.sh \
			$(1)/usr/sbin/hapd
	$(INSTALL_BIN) ./files/wpsd.sh \
			$(1)/usr/sbin/wpsd
  endef
endif
endif

define Package/qca-wpa-supplicant/install
	$(call Install/qca-wpa-supplicant,$(1))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wpa_supplicant/wpa_supplicant $(1)/usr/sbin/
endef

define Package/qca-wpa-supplicant-lite/install
	$(call Install/qca-wpa-supplicant,$(1))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wpa_supplicant/wpa_supplicant $(1)/usr/sbin/
endef

define Package/qca-wpa-supplicant-macsec/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wpa_supplicant/wpa_supplicant $(1)/usr/sbin/wpa_supplicant-macsec
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) ./files/macsec.init $(1)/etc/init.d/macsec
	$(INSTALL_BIN) ./files/macsec.config $(1)/etc/config/macsec
endef

ifneq ($(LOCAL_TYPE),hostap)
ifneq ($(LOCAL_VARIANT),macsec)
  define Package/qca-wpa-cli/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(CP) $(PKG_BUILD_DIR)/wpa_supplicant/wpa_cli $(1)/usr/sbin/

	$(INSTALL_DIR) $(1)/etc/hotplug.d/button
	$(INSTALL_DATA) ./files/wps-supplicant-hotplug.sh \
			$(1)/etc/hotplug.d/button/52-wps-supplicant

	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_BIN) ./files/wps-supplicant-update-uci.sh \
			$(1)/lib/wifi/wps-supplicant-update-uci
  endef
endif
endif

$(eval $(call BuildPackage,$(PKG_NAME)))
$(eval $(call BuildPackage,qca-wpa-supplicant))
$(eval $(call BuildPackage,$(PKG_NAME)-lite))
$(eval $(call BuildPackage,$(PKG_NAME)-macsec))
$(eval $(call BuildPackage,qca-wpa-supplicant-lite))
$(eval $(call BuildPackage,qca-wpa-supplicant-macsec))
$(eval $(call BuildPackage,qca-hostapd-cli))
$(eval $(call BuildPackage,qca-wpa-cli))
