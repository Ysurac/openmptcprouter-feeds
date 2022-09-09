include $(TOPDIR)/rules.mk

PKG_NAME:=hyfi-ui
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-hyfi/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  SUBMENU:=Hy-Fi features
endef

define Package/luci-hyfi
  $(call Package/luci-hyfi/Default)
  DEPENDS:=+luci +luci-mod-admin-full
  TITLE:=Hy-Fi Web UI
endef

define Package/luci-hyfi/description
  Luci WebUI for Hy-Fi
endef

define Package/luci-hyfi-advanced
  $(call Package/luci-hyfi/Default)
  DEPENDS:=+luci +luci-mod-admin-full +luci-hyfi
  TITLE:=Hy-Fi Web UI - Advanced
endef

define Package/luci-hyfi-advanced/description
  Luci WebUI for Hy-Fi - Advanced
endef

define Build/Compile
	true
endef

define Package/luci-hyfi/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/hyfi
	$(CP) files/luci-hyfi/luasrc/model/cbi/hyfi/hyfi.lua /$(1)/usr/lib/lua/luci/model/cbi/hyfi/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/hyfi
	$(CP) files/luci-hyfi/luasrc/view/hyfi/dview_js.htm /$(1)/usr/lib/lua/luci/view/hyfi/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(CP) files/luci-hyfi/luasrc/controller/hyfi.lua /$(1)/usr/lib/lua/luci/controller/
endef

define Package/luci-hyfi-advanced/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/hyfi
	$(CP) files/luci-hyfi/luasrc/model/cbi/hyfi/advanced.lua /$(1)/usr/lib/lua/luci/model/cbi/hyfi/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/hyfi
	$(CP) files/luci-hyfi/luasrc/view/hyfi/btn_adv.htm /$(1)/usr/lib/lua/luci/view/hyfi/
endef

$(eval $(call BuildPackage,luci-hyfi))
$(eval $(call BuildPackage,luci-hyfi-advanced))

