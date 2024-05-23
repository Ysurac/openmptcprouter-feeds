#
# Copyright (C) 2006-2010 OpenWrt.org
# Copyright (C) 2016 Stijn Segers
# Copyright (C) 2020 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=net-tools
PKG_SOURCE_DATE:=2023-06-29
PKG_SOURCE_VERSION:=20a78e06a69bd9b6b4e15468201d5d3aa9c395db
PKG_RELEASE:=2

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.code.sf.net/p/net-tools/code

PKG_MAINTAINER:=Yannick Chabanois <ycarus@zugaina.org>
PKG_LICENSE:=GPL-2.0-or-later
PKG_LICENSE_FILES:=COPYING

include $(INCLUDE_DIR)/package.mk

define Package/mii-tool
  SECTION:=net
  CATEGORY:=Network
  TITLE:=configure media type using MII commands
  URL:=http://net-tools.sourceforge.net/
endef

define Package/mii-tool/description
	The mii-tool command allows you to set or autodetect the media type
	or mii chipset-based ethernet devices. It traditionally had been
	distributed in the net-tools package. This is a single distribution
	optimized for embedded systems and fully automated cross/-sysroot-builds
endef

define Package/net-tools-route
  SECTION:=net
  CATEGORY:=Network
  TITLE:=net-tools - route utility
  URL:=http://net-tools.sourceforge.net/
  PROVIDES:=route
  ALTERNATIVES:=300:/sbin/route:/usr/libexec/net-tools-route
endef

define Package/net-tools-route/description
	Replace busybox version of the route command with the full net-tools
	version. This is normally not needed as busybox is smaller and provides
	sufficient functionality, but some users may want or need the full
	functionality of the net-tools variant (e.g. AF_X25).
endef

define Build/Configure
	# Failed configure.sh leaves stub config.h around.
	rm -f $(PKG_BUILD_DIR)/config.h
	( cd $(PKG_BUILD_DIR); yes $$$$'\n' | ./configure.sh config.in )
endef

define Package/mii-tool/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mii-tool $(1)/usr/sbin/
endef

define Package/net-tools-route/install
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/route $(1)/usr/libexec/net-tools-route
endef

$(eval $(call BuildPackage,mii-tool))
$(eval $(call BuildPackage,net-tools-route))
