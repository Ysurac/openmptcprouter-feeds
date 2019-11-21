#
# Copyright (C) 2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-core
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/v2ray/v2ray-core.git
PKG_SOURCE_VERSION:=44aafae19edd99583150aacfd9269fabb3ea1828
PKG_SOURCE_DATE:=20191121

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=v2ray.com/core
GO_PKG_SOURCE_ONLY:=1

include $(INCLUDE_DIR)/package.mk
include ../golang/golang-package.mk

define Package/v2ray-core-dev
$(call GoPackage/GoSubMenu)
  TITLE:=Go support for Google protocol buffers
  URL:=https://github.com/golang/protobuf
  DEPENDS:=$(GO_ARCH_DEPENDS) +protobuf
  PKGARCH:=all
endef

define Package/v2ray-core-dev/description
Go support for Google protocol buffers
endef

$(eval $(call GoSrcPackage,v2ray-core-dev))
$(eval $(call BuildPackage,v2ray-core-dev))
