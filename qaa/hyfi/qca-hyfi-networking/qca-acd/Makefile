include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-acd
PKG_VERSION:=master.131

include $(INCLUDE_DIR)/package.mk

define Package/qca-acd
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  DEPENDS:=+qca-ieee1905-init +kmod-qca-hyfi-bridge +qca-hyctl
  TITLE:=Hy-Fi Auto-configuration
  SUBMENU:=Hy-Fi features
endef

define Package/qca-acd/description
  This package installs the Hy-Fi Auto-configuration scripts
endef

define Build/Compile
endef

define Package/qca-acd/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/acd-run.sh $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/acd.init $(1)/etc/init.d/acd
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/acd.config $(1)/etc/config/acd
endef

$(eval $(call BuildPackage,qca-acd))
