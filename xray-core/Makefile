include $(TOPDIR)/rules.mk

PKG_NAME:=xray-core
PKG_VERSION:=1.8.5
PKG_RELEASE:=1

PKG_LICENSE:=MPLv2
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Yannick Chabanois <contact@openmptcprouter.com>
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/XTLS/Xray-core.git
PKG_SOURCE_VERSION:=585d5ba7c8b64f6da60837546a70bbcfd2350c64

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=github.com/XTLS/Xray-core

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/openmptcprouter/golang/golang-package.mk

define Package/$(PKG_NAME)
	SECTION:=Custom
	CATEGORY:=Extra packages
	TITLE:=Xray-core
	DEPENDS:=$(GO_ARCH_DEPENDS)
	PROVIDES:=xray-core
endef

define Package/$(PKG_NAME)/description
	Xray-core bare bones binary (compiled without cgo)
endef

define Package/$(PKG_NAME)/config
menu "Xray Configuration"
	depends on PACKAGE_$(PKG_NAME)

config PACKAGE_XRAY_ENABLE_GOPROXY_IO
	bool "Use goproxy.io to speed up module fetching (recommended for some network situations)"
	default n

endmenu
endef

USE_GOPROXY:=
ifdef CONFIG_PACKAGE_XRAY_ENABLE_GOPROXY_IO
	USE_GOPROXY:=GOPROXY=https://goproxy.io,direct
endif

MAKE_PATH:=$(GO_PKG_WORK_DIR_NAME)/build/src/$(GO_PKG)
MAKE_VARS += $(GO_PKG_VARS)

#define Build/Patch
#	$(CP) $(PKG_BUILD_DIR)/../Xray-core-$(PKG_VERSION)/* $(PKG_BUILD_DIR)
#	$(Build/Patch/Default)
#endef

define Build/Compile
	cd $(PKG_BUILD_DIR); $(GO_PKG_VARS) $(USE_GOPROXY) CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o $(PKG_INSTALL_DIR)/bin/xray ./main; 
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/xray $(1)/usr/bin/xray
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))