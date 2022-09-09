include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

PKG_NAME:=qca-mcs-apps
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_REV:=c50281f
PKG_VERSION:=gc50281f
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

WIFI_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_AK:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_DK:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_10_2_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_10_2_ARM:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_L:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_16M:=PACKAGE_kmod-qca-wifi-flash_16mb-profile
SSDK_NOHNAT:=PACKAGE_kmod-qca-ssdk-nohnat
SSDK_HNAT:=PACKAGE_kmod-qca-ssdk-hnat

WIFI_PKGS:=$(WIFI_U)||$(WIFI_C)||$(WIFI_AK)||$(WIFI_DK)||$(WIFI_10_2_MIPS)||$(WIFI_10_2_ARM)||$(WIFI_L)||$(WIFI_16M)
SSDK_PKGS:=$(SSDK_NOHNAT)||$(SSDK_HNAT)

PKG_BUILD_DEPENDS:=!PACKAGE_kmod-ath:qca-wifi qca-ssdk qca-mcs-lkm

ifneq ($(CONFIG_PACKAGE_kmod-ath),)
QCAMCS_MAKE_OPTS:=MCS_MODULE_WLAN=n
endif

QCAMCS_MAKE_OPTS+= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        MCSTOP=$(PKG_BUILD_DIR) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
        ATHDIR=$(STAGING_DIR)/usr/include \
        KMCDIR=$(STAGING_DIR)/usr/include/qca-mcs \
        QCASSDKDIR=$(STAGING_DIR)/usr/include/qca-ssdk \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        STAGING_DIR=$(STAGING_DIR) \
	TARGET_CFLAGS="$(TARGET_CFLAGS)" \
	TARGET_LDFLAGS="$(TARGET_LDFLAGS)"


define Package/qca-mcs-apps
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  DEPENDS:=+kmod-qca-mcs \
	   +libhyficommon +libpthread @$(SSDK_PKGS)
  TITLE:=IGMP/MLD snooping daemon and tools
endef

define Package/qca-mcs-apps/description
  This package installs the IGMP/MLD snooping daemon and tools
endef


define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/sbin
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCAMCS_MAKE_OPTS)) subdirs
endef

define Package/qca-mcs-apps/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/mcsd $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/mcsctl $(1)/usr/sbin
	$(INSTALL_BIN) ./files/mcst $(1)/usr/sbin/mcst
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/mcsd.init $(1)/etc/init.d/mcsd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_BIN) ./files/mcsd.config $(1)/etc/config/mcsd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./files/mcsd.hotplug $(1)/etc/hotplug.d/net/28-mcsd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/mcsd.netifd.hotplug $(1)/etc/hotplug.d/iface/78-mcsd
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/mcsd.uci_default $(1)/etc/uci-defaults/qca-mcsd
endef

$(eval $(call BuildPackage,qca-mcs-apps))
