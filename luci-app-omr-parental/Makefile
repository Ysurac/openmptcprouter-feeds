#
# Copyright (C) 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Parental Control for OpenMPTCProuter
LUCI_DEPENDS:=+nftables +omr-bypass-nft +omr-adblock

PKG_LICENSE:=GPLv3

define Package/luci-app-omr-parental/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
sed -i '/omr-parental/d' /etc/crontabs/root
/etc/init.d/cron restart >/dev/null 2>&1
uci -q delete firewall.omr_parental && uci commit firewall
nft delete chain inet fw4 omr_parental 2>/dev/null
nft delete set inet fw4 omr_parental_mac 2>/dev/null
nft delete set inet fw4 omr_parental_if 2>/dev/null
nft delete chain inet fw4 omr_parental_dns 2>/dev/null
h="$$(nft -a list chain inet fw4 input 2>/dev/null | sed -n 's/.*"omr_parental_dns".*# handle \([0-9]*\)$$/\1/p')"
[ -n "$$h" ] && nft delete rule inet fw4 input handle "$$h"
for s in $$(uci -q show dhcp | sed -n 's/^dhcp\.\(omr_parental_[A-Za-z0-9_]*\)=ipset$$/\1/p'); do uci -q delete "dhcp.$$s"; done
uci -q commit dhcp
/etc/init.d/dnsmasq restart >/dev/null 2>&1
exit 0
endef

define Package/luci-app-omr-parental/conffiles
/etc/config/omr-parental
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
