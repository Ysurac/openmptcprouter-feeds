include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

PKG_RELEASE:=1

define Package/hyfi/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  DEPENDS:=+kmod-qca-hyfi-bridge +qca-libhyfi-bridge \
           +qca-hyctl +libwpa2 \
           +libhyficommon +libstorage +libieee1905 +SUPPORT_WIFISON_EXT_LIB:qca-wifison-ext-lib
  MAINTAINER:=Qualcomm Atheros
endef

define Package/hyfi
  $(call Package/hyfi/Default)
  TITLE:=Hy-Fi - selects all Hy-Fi components for build
  DEPENDS+=+qca-hyd +qca-wsplcd
  MAINTAINER:=Qualcomm Atheros
endef

define Package/hyfi/description
  Meta package which selects all Hy-Fi components require for build
endef

define Package/hyfi/install
  @true
endef

define Package/hyfi-plc
  $(call Package/hyfi/Default)
  TITLE:=Hy-Fi - selects all Hy-Fi and PLC components for build
  DEPENDS+=+qca-hyd-plc +qca-wsplcd +qca-vhyfid +qca-plc-serv
endef

define Package/hyfi-plc/description
  Meta package which selects all Hy-Fi and PLC components require for build
endef

define Package/hyfi-plc/install
  @true
endef

define Package/hyfi-son
  $(call Package/hyfi/Default)
  TITLE:=Hy-Fi - selects all Hy-Fi components for build (with SON Features)
  DEPENDS+=+qca-hyd-son +qca-wsplcd-son
endef

define Package/hyfi-son/description
  Meta package which selects all Hy-Fi SON components require for build
endef

define Package/hyfi-son/install
  @true
endef

define Package/hyfi-map
  $(call Package/hyfi/Default)
  TITLE:=Hy-Fi - selects all Hy-Fi components for build (with MAP Features)
  DEPENDS+=+qca-wsplcd-map
endef

define Package/hyfi-map/description
  Meta package which selects all Hy-Fi MAP components require for build
endef

define Package/hyfi-map/install
  @true
endef

define Package/hyfi-sonplc
  $(call Package/hyfi/Default)
  TITLE:=Hy-Fi - selects all Hy-Fi and PLC components for build (with SON Features)
  DEPENDS+=+qca-hyd-sonplc +qca-wsplcd-son +qca-vhyfid +qca-plc-serv
endef

define Package/hyfi-sonplc/description
  Meta package which selects all Hy-Fi SON and PLC components require for build
endef

define Package/hyfi-sonplc/install
  @true
endef

# =============== Engg
#
define Package/hyfi-mesh
  $(call Package/hyfi/Default)
  TITLE:=Hy-Fi - selects all Hy-Fi components for build
  DEPENDS+=+qca-wsplcd-map +qca-hyd-son +qca-wsplcd-son
endef

define Package/hyfi-mesh/description
  Meta package which selects all Hy-Fi components require for build
endef

define Package/hyfi-mesh/install
  @true
endef

PKG_NAME:=hyfi-ui
define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=Hy-Fi - selects all Hy-Fi web interfaces
  DEPENDS:=+luci-hyfi +luci-hyfi-advanced +luci-wsplc +luci-wsplc-advanced
  MAINTAINER:=Qualcomm Atheros
endef

define Package/$(PKG_NAME)/description
  Meta package which selects all Hy-Fi web interfaces
endef

define Package/$(PKG_NAME)/install
  @true
endef

define Build/Compile
endef

$(eval $(call BuildPackage,hyfi))
$(eval $(call BuildPackage,hyfi-plc))
$(eval $(call BuildPackage,hyfi-ui))
$(eval $(call BuildPackage,hyfi-son))
$(eval $(call BuildPackage,hyfi-map))
$(eval $(call BuildPackage,hyfi-sonplc))
$(eval $(call BuildPackage,hyfi-mesh))
