#
# Copyright (C) 2026 Yannick Chabanois (Ycarus) for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mptcp-dscp-manager
PKG_VERSION:=$(LINUX_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)

PKG_MAINTAINER:=Yannick Chabanois

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/nls.mk

define Package/mptcp-dscp-manager
  SECTION:=net
  CATEGORY:=Network
  TITLE:=MPTCP BPF DSCP Manager
  DEPENDS:=+libbpf +mptcp-bpf-dscp @!LINUX_5_4
endef

define Package/mptcp-dscp-manager/description
  Userspace helper for the bpf_dscp MPTCP scheduler: sets/shows/removes
  DSCP class -> WAN interface pins in the pinned dscp_iface BPF map,
  and keeps them in sync with network.<iface>.mptcp_dscp via an
  omr-tracker post-tracking hook.
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/mptcp-dscp-manager/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,mptcp-dscp-manager))
