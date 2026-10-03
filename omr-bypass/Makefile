#
# Copyright (C) 2018-2023 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=omr-bypass
PKG_VERSION:=0.1
PKG_RELEASE:=2

include $(INCLUDE_DIR)/package.mk

# nftables (firewall4) only: the legacy iptables/ipset variant ("omr-bypass"
# package, the only one for Linux 5.4) is gone. The package keeps its
# -nft name, so installed routers upgrade in place, and provides the old
# one for packages that still depend on it.
define Package/$(PKG_NAME)-nft
SECTION:=net
CATEGORY:=Network
DEPENDS:=+curl +dnsmasq-full +sqlite3-cli +firewall4 @!LINUX_5_4
PROVIDES:=$(PKG_NAME)
TITLE:=OMR-ByPass
endef

define Package/$(PKG_NAME)-nft/description
OMR-ByPass: route chosen traffic around the aggregated path, with ordered
output WAN lists, source interface policies and failover (nftables)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)-nft/install
	$(CP) ./files/* $(1)/
	mv $(1)/etc/init.d/omr-bypass-nft $(1)/etc/init.d/omr-bypass
endef

$(eval $(call BuildPackage,$(PKG_NAME)-nft))
