include $(TOPDIR)/rules.mk

PKG_NAME:=meson
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/mesonbuild/meson.git
PKG_SOURCE_VERSION:=77e0008a1fede82851fdf13438619cb62e61c297

PKG_VERSION:=0.52.1-$(PKG_SOURCE_VERSION)
PKG_RELEASE:=1

PKG_MAINTAINER:=Yannick Chabanois <ycarus@zugaina.org>
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=COPYING

HOST_BUILD_DEPENDS:=ninja/host

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/package.mk
include ../../lang/python/python3-package.mk

define Host/Configure
endef

define Host/Compile
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/lib/meson
	$(CP) $(HOST_BUILD_DIR)/* $(STAGING_DIR_HOSTPKG)/lib/meson/
endef

define Host/Clean
	$(call Host/Clean/Default)
	rm -rf $(STAGING_DIR_HOSTPKG)/lib/meson
endef

define Package/meson
  SECTION:=devel
  CATEGORY:=Development
  TITLE:=meson
  URL:=https://mesonbuild.com/
  DEPENDS:=+ninja +python3-pkg-resources
  VARIANT:=python3
endef

define Package/meson/description
  Meson is an open source build system meant to be both extremely fast, and, even more importantly, as user friendly as possible.
endef

define Package/meson/install
endef

$(eval $(call HostBuild))
$(eval $(call Py3Package,meson))
$(eval $(call BuildPackage,meson))
$(eval $(call BuildPackage,meson-src))
