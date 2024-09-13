#
# Copyright (C) 2023 Yannick Chabanois (Ycarus) for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mptcp-bpf-red
PKG_VERSION:=$(LINUX_VERSION)

PKG_BUILD_DEPENDS:=HAS_BPF_TOOLCHAIN:bpf-headers

PKG_BUILD_PARALLEL:=1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)

PKG_MAINTAINER:=Yannick Chabanois <contact@openmptcprouter.com>

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/bpf_mptcp.mk
include $(INCLUDE_DIR)/nls.mk

define Package/mptcp-bpf-red
  SECTION:=net
  CATEGORY:=Network
  TITLE:=MPTCP BPF Redundant Scheduler
  DEPENDS:=+libbpf +kmod-sched-core +kmod-sched-flower +kmod-sched-bpf $(BPF_DEPENDS) @!LINUX_5_4
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(call CompileBPF,$(PKG_BUILD_DIR)/mptcp_bpf_red.c)
endef

#define Package/mptcpify-bpf/conffiles
#/etc/config/mptcpify
#/etc/mptcpify/00-defaults.conf
#endef

define Package/mptcp-bpf-red/install
	$(INSTALL_DIR) $(1)/usr/share/bpf/scheduler
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mptcp_bpf_red.o $(1)/usr/share/bpf/scheduler
endef

$(eval $(call BuildPackage,mptcp-bpf-red))
