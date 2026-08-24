#
# Copyright (C) 2026 Yannick Chabanois (Ycarus)
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=omr-sockdiag
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Yannick Chabanois

include $(INCLUDE_DIR)/package.mk

define Package/omr-sockdiag
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Netlink INET_DIAG socket dumper for MPTCP subflow metrics
  DEPENDS:=+libc
endef

define Package/omr-sockdiag/description
  Small standalone tool that dumps established TCP sockets (with tcp_info:
  cwnd, rtt, retransmissions, byte counters, pacing/delivery rate) as JSON
  by querying the kernel directly over NETLINK_SOCK_DIAG -- the same
  INET_DIAG protocol iproute2's "ss" uses internally, without spawning ss
  or parsing its text output. Since each MPTCP subflow is a regular kernel
  TCP socket sourced from its WAN's local IP, this doubles as a per-subflow
  metrics source for omr-metrics and luci-app-mptcp.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		-Wall -Wextra \
		-o $(PKG_BUILD_DIR)/omr-sockdiag \
		$(PKG_BUILD_DIR)/omr-sockdiag.c
endef

define Package/omr-sockdiag/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/omr-sockdiag $(1)/usr/bin/omr-sockdiag
endef

$(eval $(call BuildPackage,omr-sockdiag))
