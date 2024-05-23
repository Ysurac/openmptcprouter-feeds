#
# Copyright (C) 2023-2024 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=xray
PKG_VERSION:=1.8.13
PKG_RELEASE:=1

PKG_LICENSE:=MPLv2
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Yannick Chabanois <contact@openmptcprouter.com>
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/XTLS/Xray-core.git
PKG_SOURCE_VERSION:=3120ca41210312c5c8b1795eaf3dbf54531e437e

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=github.com/XTLS/Xray-core

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/openmptcprouter/golang/golang-package.mk

define Package/$(PKG_NAME)/template
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Xray-core
	DEPENDS:=$(GO_ARCH_DEPENDS)
endef

define Package/$(PKG_NAME)-core
	$(call Package/$(PKG_NAME)/template)
	PROVIDES:=xray-core
endef

define Package/$(PKG_NAME)-config
	$(call Package/$(PKG_NAME)/template)
	TITLE+= (init script)
endef

define Package/$(PKG_NAME)-config-nft
	$(call Package/$(PKG_NAME)/template)
	TITLE+= (init script with nft)
endef

define Package/$(PKG_NAME)-core/description
	Xray-core bare bones binary (compiled without cgo)
endef

define Package/$(PKG_NAME)-config/description
	Xray-core init script
endef

define Package/$(PKG_NAME)-config-nft/description
	Xray-core init script with nft support
endef

define Package/$(PKG_NAME)-core/config
menu "Xray Configuration"
	depends on PACKAGE_$(PKG_NAME)-core

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

define Build/Compile
	cd $(PKG_BUILD_DIR); $(GO_PKG_VARS) $(USE_GOPROXY) CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o $(PKG_INSTALL_DIR)/bin/xray ./main; 
endef

define Package/$(PKG_NAME)-core/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/xray $(1)/usr/bin/xray
endef

define Package/$(PKG_NAME)-config/install
	$(CP) ./files/* $(1)/
	rm -f $(1)/etc/init.d/xray-nft
endef

define Package/$(PKG_NAME)-config-nft/install
	$(CP) ./files/* $(1)/
	mv $(1)/etc/init.d/xray-nft $(1)/etc/init.d/xray
endef

$(eval $(call BuildPackage,$(PKG_NAME)-core))
$(eval $(call BuildPackage,$(PKG_NAME)-config))
$(eval $(call BuildPackage,$(PKG_NAME)-config-nft))
