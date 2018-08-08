#
# Copyright (C) 2015 Minho Ryang <minhoryang@gmail.com>
# Initial ebuild come from https://github.com/minhoryang/open-vm-tools--openwrt
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v3 or later.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=open-vm-tools
PKG_VERSION:=stable-10.3.0
PKG_RELEASE:=1
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_DEPENDS:=glib2
PKG_SOURCE:=$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/vmware/open-vm-tools/archive/
PKG_LICENSE:=LGPLv2.1
PKG_LICENSE_FILE:=COPYING

PKG_FIXUP:=autoreconf

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  TITLE:=open-vm-tools
  CATEGORY:=Languages
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=+glib2 +libdnet
  URL:=https://github.com/vmware/open-vm-tools
  MAINTAINER:= Minho Ryang <minhoryang@gmail.com>
endef
  # TODO: PKGARCH:=i386 x86_64
  # TODO: mmu
  # TODO: depends on BR2_TOOLCHAIN_HAS_NATIVE_RPC
  # TODO: depends on BR2_ENABLE_LOCALE
  # TODO: BR2_PACKAGE_OPENVMTOOLS_PROCPS
  # TODO: BR2_PACKAGE_OPENVMTOOLS_PAM

define Package/$(PKG_NAME)/description
	  Open Virtual Machine Tools for VMware guest OS

	  http://open-vm-tools.sourceforge.net/

	  ICU locales, Xerces, and X11 tools are currently not supported.

	  NOTE: Support for vmblock-fuse will be enabled in openvmtools if the
		libfuse package is selected.
endef

CONFIGURE_ARGS+= \
	--with-dnet \
	--without-icu \
	--without-x \
	--without-gtk2 \
	--without-gtkmm \
	--without-kernel-modules \
	--disable-deploypkg \
	--without-xerces \
	--without-ssl \
	--without-procps \
	--without-pam
# TODO: --without-ssl -procps -pam optionable

CONFIGURE_VARS += \
	CUSTOM_DNET_CPPFLAGS=" "

define Package/$(PKG_NAME)/install
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
