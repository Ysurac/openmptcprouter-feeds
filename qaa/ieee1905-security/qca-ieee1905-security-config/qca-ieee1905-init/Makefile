include $(TOPDIR)/rules.mk

PKG_NAME:=qca-ieee1905-init
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/qca-ieee1905-init
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=IEEE1905.1 Init Script Helpers
  DEPENDS:=
  SUBMENU:=IEEE1905.1 features
endef

define Package/qca-ieee1905-init/description
  This Package contains the script helper files for the IEEE1905.1 init scripts
endef

define Package/qca-ieee1905-init/install
	$(INSTALL_DIR) $(1)/lib/functions/
	$(CP) ./files/hyfi-debug.sh $(1)/lib/functions/
	$(CP) ./files/hyfi-iface.sh $(1)/lib/functions/
	$(CP) ./files/hyfi-network.sh $(1)/lib/functions/
endef

define Build/Compile
	true
endef

$(eval $(call BuildPackage,qca-ieee1905-init))
