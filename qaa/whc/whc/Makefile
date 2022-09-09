include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

# The packages defined in this file are just "meta" packages that pull in
# other ones.
PKG_RELEASE:=1

PKG_NAME:=whc
define Package/whc/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=Whole Home Coverage - selects all Whole Home Coverage components for build
  DEPENDS:=+(PACKAGE_whc-son||PACKAGE_whc-mesh):qca-whc-lbd
  MAINTAINER:=Qualcomm Atheros
endef

# Original Package
define Package/whc
  $(call Package/whc/Default)
  DEPENDS+=+qca-whc-repacd
endef

define Package/whc/description
  Meta package which selects all Whole Home Coverage SON components required for build
endef

define Package/whc/install
  @true
endef

# SON Package
define Package/whc-son
  $(call Package/whc/Default)
  TITLE+=(with SON Features)
  DEPENDS+=+qca-whc-repacd-son +qca-whc-repacd-init
endef

define Package/whc-son/description
  Meta package which selects all Whole Home Coverage SON components required for build
endef

define Package/whc-son/install
  @true
endef

# MAP Package
define Package/whc-map
  $(call Package/whc/Default)
  TITLE+=(with MAP Features)
  DEPENDS+=+qca-whc-repacd-map +qca-whc-repacd-init
endef

define Package/whc-map/description
  Meta package which selects all Whole Home Coverage MAP components required for build
endef

define Package/whc-map/install
  @true
endef

# ======== Engg (SON + MAP)
define Package/whc-mesh
  $(call Package/whc/Default)
  TITLE+=(with SON and MAP Features)
  DEPENDS+=+qca-whc-repacd-son +qca-whc-repacd-map +qca-whc-repacd-init
endef

define Package/whc-mesh/description
  Meta package which selects all Whole Home Coverage SON and MAP components required for build
endef

define Package/whc-mesh/install
  @true
endef

PKG_NAME:=whc-ui
define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=Whole Home Coverage - selects all Whole Home Coverage web interface components
  DEPENDS:=+luci-whc-lbd +luci-whc-lbd-advanced +luci-whc-lbd-diaglog \
           +luci-whc-repacd +luci-whc-repacd-advanced
  MAINTAINER:=Qualcomm Atheros
endef

define Package/$(PKG_NAME)/description
  Meta package which selects all Whole Home Coverage web interface components
endef

define Package/$(PKG_NAME)/install
  @true
endef

define Build/Compile
endef

$(eval $(call BuildPackage,whc))
$(eval $(call BuildPackage,whc-ui))
$(eval $(call BuildPackage,whc-son))
$(eval $(call BuildPackage,whc-map))
$(eval $(call BuildPackage,whc-mesh))
