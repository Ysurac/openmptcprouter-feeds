#
# Copyright (C) 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v3.

include $(TOPDIR)/rules.mk

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
PKG_VERSION:=0.1
PKG_RELEASE:=1

LUCI_TITLE:=Keepalived HA easy setup for OpenMPTCProuter
LUCI_DEPENDS:=+luci-base +luci-app-keepalived +keepalived-sync +curl
LUCI_DESCRIPTION:=One-page high availability setup for several OpenMPTCProuter \
	devices: enter the router IPs, the shared virtual IP and the peers \
	credentials; keepalived VRRP, config sync (keepalived-sync) and DHCP \
	options are generated on every router automatically.

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
