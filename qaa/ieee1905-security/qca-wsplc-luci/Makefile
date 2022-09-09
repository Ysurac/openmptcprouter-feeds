include $(TOPDIR)/rules.mk

PKG_NAME:=wsplc-ui
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-wsplc/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  SUBMENU:=IEEE1905.1 features
endef

define Package/luci-wsplc
  $(call Package/luci-wsplc/Default)
  DEPENDS:=+luci +luci-mod-admin-full
  TITLE:=IEEE1905.1 Security Web UI
endef

define Package/luci-wsplc/description
  Luci WebUI for 1905.1 AP Auto Configuration and Security
endef

define Package/luci-wsplc-advanced
  $(call Package/luci-wsplc/Default)
  DEPENDS:=+luci +luci-mod-admin-full +luci-wsplc
  TITLE:=IEEE1905.1 Security Web UI - Advanced
endef

define Package/luci-wsplc-advanced/description
  Luci WebUI for 1905.1 AP Auto Configuration and Security - Advanced
endef

define Build/Compile
	true
endef

define Package/luci-wsplc/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/wsplc
	$(CP) files/luci-wsplc/luasrc/model/cbi/wsplc/wsplc.lua /$(1)/usr/lib/lua/luci/model/cbi/wsplc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/wsplc
	$(CP) files/luci-wsplc/luasrc/view/wsplc/dview_js.htm /$(1)/usr/lib/lua/luci/view/wsplc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(CP) files/luci-wsplc/luasrc/controller/wsplc.lua /$(1)/usr/lib/lua/luci/controller/
endef

define Package/luci-wsplc-advanced/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/wsplc
	$(CP) files/luci-wsplc/luasrc/model/cbi/wsplc/advanced.lua /$(1)/usr/lib/lua/luci/model/cbi/wsplc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/wsplc
	$(CP) files/luci-wsplc/luasrc/view/wsplc/btn_adv.htm /$(1)/usr/lib/lua/luci//view/wsplc/
endef

$(eval $(call BuildPackage,luci-wsplc))
$(eval $(call BuildPackage,luci-wsplc-advanced))

