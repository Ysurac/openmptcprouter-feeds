#
# Copyright (C) 2019-2023 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=golang-protobuf
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/golang/protobuf.git
PKG_SOURCE_VERSION:=5d5e8c018a13017f9d5b8bf4fad64aaa42a87308
PKG_SOURCE_DATE:=20210916

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=github.com/golang/protobuf
GO_PKG_SOURCE_ONLY:=1

include $(INCLUDE_DIR)/package.mk
include ../golang/golang-package.mk

define Package/golang-protobuf-dev
$(call GoPackage/GoSubMenu)
  TITLE:=Go support for Google protocol buffers
  URL:=https://github.com/golang/protobuf
  DEPENDS:=$(GO_ARCH_DEPENDS) +protobuf
  PKGARCH:=all
endef

define Package/golang-protobuf-dev/description
Go support for Google protocol buffers
endef

$(eval $(call GoSrcPackage,golang-protobuf-dev))
$(eval $(call BuildPackage,golang-protobuf-dev))
