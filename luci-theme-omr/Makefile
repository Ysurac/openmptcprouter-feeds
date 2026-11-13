#
# Copyright (C) 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=OpenMPTCProuter Modern Theme
LUCI_DEPENDS:=+luci-base

PKG_LICENSE:=Apache-2.0

# csstidy rewrites modern CSS (masks with custom properties, :has(),
# backdrop-filter) unreliably, ship the stylesheet as written
LUCI_MINIFY_CSS:=0

define Package/luci-theme-omr/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.OMR
	uci -q delete luci.themes.OMRDark
	uci -q delete luci.themes.OMRLight
	case "$$(uci -q get luci.main.mediaurlbase)" in
		/luci-static/omr|/luci-static/omr-dark|/luci-static/omr-light)
			if [ -d /www/luci-static/openmptcprouter ]; then
				uci set luci.main.mediaurlbase=/luci-static/openmptcprouter
			else
				uci set luci.main.mediaurlbase=/luci-static/bootstrap
			fi
			;;
	esac
	uci commit luci
}
endef

#include ../luci/luci.mk
include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
