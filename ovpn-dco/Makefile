#
# Copyright (C) 2021 Jianhui Zhao <zhaojh329@gmail.com>
# Copyright (C) 2023 Yannick Chabanois (Ycarus) <contact@openmptcprouter.com> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ovpn-dco
PKG_VERSION:=0.2.20240320
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/OpenVPN/ovpn-dco.git
PKG_SOURCE_VERSION:=2aa7f931803f81d2745b0cefafb63654a35cc3d5

PKG_MAINTAINER:=Yannick Chabanois <contact@openmptcprouter.com>
PKG_LICENSE:=GPL-2.0-only


include $(INCLUDE_DIR)/package.mk

define KernelPackage/ovpn-dco-v2
  SUBMENU:=Network Support
  TITLE:=OpenVPN data channel offload
  DEPENDS:=+kmod-crypto-aead +kmod-udptunnel4 +IPV6:kmod-udptunnel6
  FILES:=$(PKG_BUILD_DIR)/drivers/net/ovpn-dco/ovpn-dco-v2.ko
  AUTOLOAD:=$(call AutoLoad,30,ovpn-dco-v2)
endef

define KernelPackage/ovpn-dco-v2/description
  This module enhances the performance of the OpenVPN userspace software
  by offloading the data channel processing to kernelspace.
endef

NOSTDINC_FLAGS += \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(PKG_BUILD_DIR)/include \
	-include $(PKG_BUILD_DIR)/linux-compat.h \
	-I$(PKG_BUILD_DIR)/compat-include/

EXTRA_KCONFIG:= \
	CONFIG_OVPN_DCO_V2=m

PKG_EXTMOD_SUBDIRS = drivers/net/ovpn-dco

MAKE_OPTS:= \
	$(KERNEL_MAKE_FLAGS) \
	M="$(PKG_BUILD_DIR)/drivers/net/ovpn-dco" \
	NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
	$(EXTRA_KCONFIG)

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		modules
endef

$(eval $(call KernelPackage,ovpn-dco-v2))
