include $(TOPDIR)/rules.mk

PKG_NAME:=qca-whc-repacd
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://qca-git01.qualcomm.com:29418/whc/qca-whc-repacd
PKG_BRANCH:=master
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/qca-whc-repacd
include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(BUILD_VARIANT)$(PKG)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/qca-whc-repacd/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  DEPENDS:=+libnl +qca-cfg80211 +qca-whc-init +qca-ieee1905-init +qca-ssdk-shell
  TITLE:=Whole Home Coverage RE Placement and Auto-Configuration Daemon
  SUBMENU:=Whole Home Coverage features
endef

# Common Package

define Package/qca-whc-repacd-init
  $(call Package/qca-whc-repacd/Default)
  TITLE+= (Common package files)
  VARIANT:=init
endef

define Package/qca-whc-repacd-init/description
  This package installs the Whole Home Coverage Range Extender Placement and
  Auto-configuration SON and MAP init scripts
endef


# Original Package

define Package/qca-whc-repacd
  $(call Package/qca-whc-repacd/Default)
  DEPENDS+=+qca-wsplcd
  VARIANT:=all
endef

define Package/qca-whc-repacd/description
  This package installs the Whole Home Coverage Range Extender Placement and
  Auto-configuration scripts
endef

# SON PACKAGE

define Package/qca-whc-repacd-son
  $(call Package/qca-whc-repacd/Default)
  DEPENDS+=+lldpd +bridge +qca-wsplcd-son
  TITLE+= (With SON Features)
  VARIANT:=son
endef

define Package/qca-whc-repacd-son/description
  This package installs the Whole Home Coverage Range Extender Placement and
  Auto-configuration scripts (with SON Features)
endef

# MAP PACKAGE

define Package/qca-whc-repacd-map
  $(call Package/qca-whc-repacd/Default)
  DEPENDS+=+ethtool +qca-wsplcd-map
  TITLE+= (With MAP Features)
  VARIANT:=map
endef

define Package/qca-whc-repacd-map/description
  This package installs the Whole Home Coverage Range Extender Placement and
  Auto-configuration scripts (with MAP Features)
endef

TARGET_CFLAGS += \
		     -I$(STAGING_DIR)/usr/include/ \
		     -I$(STAGING_DIR)/usr/include/libnl \
		     -I$(STAGING_DIR)/usr/include/libnl3

TARGET_LDFLAGS += \
		  -lnl-3 -lnl-genl-3 -lqca_nl80211_wrapper

$(info PKG_BUILD_DIR is $(PKG_BUILD_DIR))

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/repacdcli \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/qca-whc-repacd/Default/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/repacd.init $(1)/etc/init.d/repacd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/repacd.config $(1)/etc/config/repacd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/button
	$(INSTALL_BIN) ./files/repacd.button $(1)/etc/hotplug.d/button/53-wps-repacd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/repacd.iface $(1)/etc/hotplug.d/iface/30-repacd
	$(INSTALL_DIR) $(1)/lib/functions/
	$(CP) ./files/whc-network.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/*.sh $(1)/lib/functions/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/repacd-run.sh $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/repacd-detect_device_mode.sh $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/hotplug.d/switch
	$(INSTALL_BIN) ./files/lp.switch $(1)/etc/hotplug.d/switch/10-lp
	$(INSTALL_BIN) ./files/netdet.switch $(1)/etc/hotplug.d/switch/20-netdet

	$(INSTALL_DIR) $(1)/etc/hotplug.d/edge
	$(INSTALL_BIN) ./files/apconf.edge $(1)/etc/hotplug.d/edge/10-apconf
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/repacdcli/repacdcli $(1)/usr/sbin
endef

define Package/qca-whc-repacd-init/Default/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/repacd-init.sh $(1)/etc/init.d/repacd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/repacd.config $(1)/etc/config/repacd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/button
	$(INSTALL_BIN) ./files/repacd.button $(1)/etc/hotplug.d/button/53-wps-repacd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/repacd.iface $(1)/etc/hotplug.d/iface/30-repacd
	$(INSTALL_DIR) $(1)/lib/functions/
	$(CP) ./files/whc-network.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-fronthaulmgr.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-led.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-gwmon.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-lp.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-netdet.sh $(1)/lib/functions/
	$(CP) ./files/repacd-cmn.sh $(1)/lib/functions/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/repacd-run.sh $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/repacd-detect_device_mode.sh $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/hotplug.d/switch
	$(INSTALL_BIN) ./files/lp.switch $(1)/etc/hotplug.d/switch/10-lp
	$(INSTALL_BIN) ./files/netdet.switch $(1)/etc/hotplug.d/switch/20-netdet

	$(INSTALL_DIR) $(1)/etc/hotplug.d/edge
	$(INSTALL_BIN) ./files/apconf.edge $(1)/etc/hotplug.d/edge/10-apconf
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/repacdcli/repacdcli $(1)/usr/sbin
endef

define Package/qca-whc-repacd/install
	$(call Package/qca-whc-repacd/Default/install, $(1))
endef

# MAP Package

define Package/qca-whc-repacd-map/install
	$(INSTALL_DIR) $(1)/lib/functions/
	$(CP) ./files/repacd-map.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-wifimon-map.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-vlanmon-map.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-maplitemode.sh $(1)/lib/functions/
endef

# SON Package

define Package/qca-whc-repacd-son/install
	$(INSTALL_DIR) $(1)/lib/functions/
	$(CP) ./files/repacd-son.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-backhaulmgr.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-ethmon.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-plcmon.sh $(1)/lib/functions/
	$(CP) $(PKG_BUILD_DIR)/lib/repacd-wifimon.sh $(1)/lib/functions/
endef

# Common Package

define Package/qca-whc-repacd-init/install
	$(call Package/qca-whc-repacd-init/Default/install, $(1))
endef

$(eval $(call BuildPackage,qca-whc-repacd))
$(eval $(call BuildPackage,qca-whc-repacd-son))
$(eval $(call BuildPackage,qca-whc-repacd-map))
$(eval $(call BuildPackage,qca-whc-repacd-init))
