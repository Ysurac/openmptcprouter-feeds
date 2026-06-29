#
# Copyright (C) 2025 Yannick Chabanois (Ycarus) for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mptcp-weight-manager
PKG_VERSION:=$(LINUX_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)

PKG_MAINTAINER:=Yannick Chabanois

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/nls.mk

define Package/mptcp-weight-manager
  SECTION:=net
  CATEGORY:=Network
  TITLE:=MPTCP BPF Weight Manager
  DEPENDS:=+libbpf @!LINUX_5_4
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/mptcp-weight-manager/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,mptcp-weight-manager))
