#
# Copyright (C) 2023 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v3 or later.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=syslogd
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/syslogd
  SECTION:=utilities
  CATEGORY:=Utilities
  TITLE:=Busybox syslogd OpenWRT init script
  DEPENDS:=+busybox
  KCONFIG:=\
      CONFIG_BUSYBOX_CUSTOM=y \
      CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOG=y \
      CONFIG_BUSYBOX_CONFIG_LOGREAD=y \
      CONFIG_BUSYBOX_CONFIG_SYSLOGD=y \
      CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOGD_CFG=y \
      CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOGD_PRECISE_TIMESTAMPS=y \
      CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOGD_READ_BUFFER_SIZE=256 \
      CONFIG_BUSYBOX_CONFIG_FEATURE_IPC_SYSLOG=y \
      CONFIG_BUSYBOX_CONFIG_FEATURE_IPC_SYSLOG_BUFFER_SIZE=64 \
      CONFIG_BUSYBOX_CONFIG_FEATURE_REMOTE_LOG=y
  PKGARCH:=all
endef

define Package/syslogd/description
  Busybox syslogd package with init script for OpenWRT
endef

define Package/syslogd/conffiles
/etc/syslog.conf
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/syslogd/install
	$(INSTALL_DIR) $(1)
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,syslogd))
