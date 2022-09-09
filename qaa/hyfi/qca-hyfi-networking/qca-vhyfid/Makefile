include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-vhyfid
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_REV:=9b756b9
PKG_VERSION:=g9b756b9
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

QCAVHYFID_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        HYTOP=$(PKG_BUILD_DIR) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
        PLCSRV=$(STAGING_DIR)/usr/include/plcserv \
        QCACFLAGS="$(TARGET_CFLAGS)" \
        QCALDFLAGS="-Wl,--gc-sections $(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        STAGING_DIR=$(STAGING_DIR)

include $(INCLUDE_DIR)/package.mk

define Package/qca-vhyfid
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  DEPENDS:=+qca-ieee1905-init +libhyficommon +qca-hyd-plc +qca-plc-serv
  TITLE:=Virtual Hy-Fi daemon (For non-embedded PLC platforms)
  SUBMENU:=Hy-Fi features
endef

define Package/qca-vhyfid/description
  This package installs the Virtual Hy-Fi daemon. It is designed for non-embedded PLC platforms, and detects plugged in PLC devices. It requires qca-plc-host package. 
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/lib
	mkdir -p $(PKG_BUILD_DIR)/install/include
	mkdir -p $(PKG_BUILD_DIR)/install/sbin
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCAVHYFID_MAKE_OPTS)) subdirs
endef

define Package/qca-vhyfid/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/share/vhyfi
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/vhyfid $(1)/usr/sbin
	$(INSTALL_CONF) ./files/vhyfid.config $(1)/etc/config/vhyfid
	$(INSTALL_BIN) ./files/vhyfid.init $(1)/etc/init.d/vhyfid
	$(INSTALL_BIN) ./files/start_hyfi $(1)/usr/share/vhyfi
	$(INSTALL_BIN) ./files/stop_hyfi $(1)/usr/share/vhyfi
	$(INSTALL_BIN) ./files/vhyfi.sh $(1)/usr/share/vhyfi
endef

$(eval $(call BuildPackage,qca-vhyfid))
