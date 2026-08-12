#
# Copyright (C) 2026 Yannick Chabanois (Ycarus)
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mptcp-bpf-dscp
PKG_VERSION:=$(LINUX_VERSION)

PKG_BUILD_DEPENDS:=HAS_BPF_TOOLCHAIN:bpf-headers

PKG_BUILD_PARALLEL:=1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)

PKG_MAINTAINER:=Yannick Chabanois

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/bpf_mptcp.mk
include $(INCLUDE_DIR)/nls.mk

define Package/mptcp-bpf-dscp
  SECTION:=net
  CATEGORY:=Network
  TITLE:=MPTCP BPF DSCP Scheduler
  DEPENDS:=+libbpf +kmod-sched-core +kmod-sched-flower +kmod-sched-bpf $(BPF_DEPENDS) @!LINUX_5_4
endef

define Package/mptcp-bpf-dscp/description
  MPTCP BPF scheduler that pins each DSCP class to a chosen WAN. Pins
  are stored in the pinned dscp_iface BPF map (keyed by local endpoint
  IP, for router-side use) and/or the pinned dscp_remote_id BPF map
  (keyed by MPTCP remote endpoint id, for server/VPS-side use where
  every subflow shares the same local IP). Both are managed with
  mptcp-scheduler-dscp.sh (mptcp-dscp-manager package).
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(call CompileBPF,$(PKG_BUILD_DIR)/mptcp_bpf_dscp.c)
endef

define Package/mptcp-bpf-dscp/install
	$(INSTALL_DIR) \
		$(1)/usr/share/bpf/scheduler
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mptcp_bpf_dscp.o $(1)/usr/share/bpf/scheduler
endef

$(eval $(call BuildPackage,mptcp-bpf-dscp))
