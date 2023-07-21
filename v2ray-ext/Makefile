#
# Copyright (C) 2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-ext
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/v2ray/ext.git
PKG_SOURCE_VERSION:=9eb3057da9bf83f83f4f1bda8528d0567419e709
PKG_SOURCE_DATE:=20190725

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=v2ray.com/ext
GO_PKG_SOURCE_ONLY:=1

include $(INCLUDE_DIR)/package.mk
include ../golang/golang-package.mk

define Package/v2ray-ext-dev
$(call GoPackage/GoSubMenu)
  TITLE:=Go support for Google protocol buffers
  URL:=https://github.com/golang/protobuf
  DEPENDS:=$(GO_ARCH_DEPENDS) +protobuf
  PKGARCH:=all
endef

define Package/v2ray-ext-dev/description
Go support for Google protocol buffers
endef

$(eval $(call GoSrcPackage,v2ray-ext-dev))
$(eval $(call BuildPackage,v2ray-ext-dev))
