include $(TOPDIR)/rules.mk

PKG_NAME:=qca-whc-init
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/qca-whc-init
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=Whole Home Coverage Init Script Helpers
  DEPENDS:=
  SUBMENU:=Whole Home Coverage features
endef

define Package/qca-whc-init/description
  This Package contains the script helper files for the Whole Home Coverage init scripts
endef

define Package/qca-whc-init/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/lib/functions/
	$(CP) ./files/whc-debug.sh $(1)/lib/functions/
	$(CP) ./files/whc-iface.sh $(1)/lib/functions/
	$(INSTALL_BIN) ./files/wifimeshconfig $(1)/usr/sbin/
endef

define Build/Compile
	true
endef

$(eval $(call BuildPackage,qca-whc-init))
