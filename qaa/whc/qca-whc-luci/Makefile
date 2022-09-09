#
# @@-COPYRIGHT-START-@@
#
# Copyright (c) 2014 Qualcomm Atheros, Inc.
# All rights reserved.
# Qualcomm Atheros Confidential and Proprietary.
#
# @@-COPYRIGHT-END-@@
#

include $(TOPDIR)/rules.mk

PKG_NAME:=whc-ui
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

# Top-level Whole Home Coverage package.
define Package/luci-whc/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  SUBMENU:=Whole Home Coverage features
endef

define Package/luci-whc
  $(call Package/luci-whc/Default)
  DEPENDS:=+luci +luci-mod-admin-full
  TITLE:=WHC Web UI
endef

define Package/luci-whc/description
  Luci WebUI for Whole Home Coverage
endef

define Package/luci-whc/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(CP) files/luci-whc/luasrc/controller/whc.lua /$(1)/usr/lib/lua/luci/controller/
endef

# Packages for Load Balancing Daemon (lbd).
define Package/luci-whc-lbd
  $(call Package/luci-whc/Default)
  DEPENDS:=+luci-whc
  TITLE:=WHC Web UI - Load Balancing
endef

define Package/luci-whc-lbd/description
  Luci WebUI for Whole Home Coverage - Load Balancing
endef

define Package/luci-whc-lbd/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/whc
	$(CP) files/luci-whc/luasrc/model/cbi/whc/lbd.lua /$(1)/usr/lib/lua/luci/model/cbi/whc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/whc
	$(CP) files/luci-whc/luasrc/view/whc/lbd_dview_js.htm /$(1)/usr/lib/lua/luci/view/whc/
endef

define Package/luci-whc-lbd-advanced
  $(call Package/luci-whc/Default)
  DEPENDS:=+luci-whc-lbd
  TITLE:=WHC Web UI - Load Balancing Advanced
endef

define Package/luci-whc-lbd-advanced/description
  Luci WebUI for Whole Home Coverage - Load Balancing Daemon Advanced Settings
endef

define Package/luci-whc-lbd-advanced/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/whc
	$(CP) files/luci-whc/luasrc/model/cbi/whc/lbd_advanced.lua /$(1)/usr/lib/lua/luci/model/cbi/whc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/whc
	$(CP) files/luci-whc/luasrc/view/whc/lbd_btn_adv.htm /$(1)/usr/lib/lua/luci/view/whc/
endef

define Package/luci-whc-lbd-diaglog
  $(call Package/luci-whc/Default)
  DEPENDS:=+luci-whc-lbd
  TITLE:=WHC Web UI - Load Balancing Diagnostic Logging
endef

define Package/luci-whc-lbd-diaglog/description
  Luci WebUI for Whole Home Coverage - Load Balancing Daemon Diagnostic Logging Settings
endef

define Package/luci-whc-lbd-diaglog/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/whc
	$(CP) files/luci-whc/luasrc/model/cbi/whc/lbd_diaglog.lua /$(1)/usr/lib/lua/luci/model/cbi/whc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/whc
	$(CP) files/luci-whc/luasrc/view/whc/lbd_btn_diag.htm /$(1)/usr/lib/lua/luci/view/whc/
endef

# Packages for RE Placement and Auto-configuration Daemon (repacd).
define Package/luci-whc-repacd
  $(call Package/luci-whc/Default)
  DEPENDS:=+luci-whc
  TITLE:=WHC Web UI - Range Extender
endef

define Package/luci-whc-repacd/description
  Luci WebUI for Whole Home Coverage RE Placement and Auto-Configuration Daemon
endef

define Package/luci-whc-repacd/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/whc
	$(CP) files/luci-whc/luasrc/model/cbi/whc/repacd.lua /$(1)/usr/lib/lua/luci/model/cbi/whc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/whc
	$(CP) files/luci-whc/luasrc/view/whc/repacd_dview_js.htm /$(1)/usr/lib/lua/luci/view/whc/
endef

define Package/luci-whc-repacd-advanced
  $(call Package/luci-whc/Default)
  DEPENDS:=+luci-whc-repacd
  TITLE:=WHC Web UI - Range Extender Advanced
endef

define Package/luci-whc-repacd-advanced/description
  Luci WebUI for Whole Home Coverage - RE Placement and Auto-Configuration Daemon Advanced Settings
endef

define Package/luci-whc-repacd-advanced/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/whc
	$(CP) files/luci-whc/luasrc/model/cbi/whc/repacd_advanced.lua /$(1)/usr/lib/lua/luci/model/cbi/whc/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/whc
	$(CP) files/luci-whc/luasrc/view/whc/repacd_btn_adv.htm /$(1)/usr/lib/lua/luci/view/whc/
endef

define Build/Compile
	true
endef

$(eval $(call BuildPackage,luci-whc))
$(eval $(call BuildPackage,luci-whc-lbd))
$(eval $(call BuildPackage,luci-whc-lbd-advanced))
$(eval $(call BuildPackage,luci-whc-lbd-diaglog))
$(eval $(call BuildPackage,luci-whc-repacd))
$(eval $(call BuildPackage,luci-whc-repacd-advanced))
