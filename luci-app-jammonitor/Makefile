#
# Copyright (C) 2024 Ycarus (Yannick Chabanois) for OpenMPTCProuter <contact@openmptcprouter.com>
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-jammonitor
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/madebyjamstudios/jammonitor.git
PKG_SOURCE_VERSION:=df217f9fc4deec631c6d668606706de4dfd5b8a6
PKG_MIRROR_HASH:=skip
# The commit is part of the version, so of the source tarball name: with a
# fixed version, a PKG_SOURCE_VERSION bump reused the old tarball from dl/
# (no mirror hash to catch it) and the package version never changed
PKG_VERSION:=1.0.0~$(call version_abbrev,$(PKG_SOURCE_VERSION))

PKG_MAINTAINER:=Yannick Chabanois <yannick.chabanois@openmptcprouter.com>
PKG_LICENSE:=GPL-2.0-only

LUCI_TITLE:=Jam Monitor – LuCI status dashboard
LUCI_DEPENDS:=+luci-base +luci-mod-admin-full +luci-lua-runtime

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  LuCI-based dashboard for monitoring OpenMPTCProuter / OpenWrt systems.
  Provides real-time system stats, MPTCP status, WAN policy management,
  client tracking, Wi-Fi AP overview, diagnostics bundle generation,
  VPN/tunnel status, vnstat traffic data and self-update support.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	# LuCI controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/jammonitor.lua \
		$(1)/usr/lib/lua/luci/controller/jammonitor.lua

	# LuCI view template
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/jammonitor.htm \
		$(1)/usr/lib/lua/luci/view/jammonitor.htm

	# Static JS resources
	$(INSTALL_DIR) $(1)/www/luci-static/resources
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/jammonitor.js \
		$(1)/www/luci-static/resources/jammonitor.js
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/jammonitor-i18n.js \
		$(1)/www/luci-static/resources/jammonitor-i18n.js

	# Version file (short git hash) used for the in-app update checker
	echo "$(PKG_SOURCE_VERSION)" > $(1)/www/luci-static/resources/jammonitor.version
endef

# Clear LuCI caches on install / removal so the new controller is picked up
define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || rm -rf /tmp/luci-*
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || rm -rf /tmp/luci-*
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
