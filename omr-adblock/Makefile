#
# Copyright (C) 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=omr-adblock
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Light DNS ad blocking for dnsmasq
  PKGARCH:=all
  DEPENDS:=+rpcd
endef

define Package/$(PKG_NAME)/description
  Blocks ads, trackers and malware domains with dnsmasq. The lists are
  processed as a stream with the tools already on the router (busybox,
  curl or uclient-fetch), deduplicated, packed and kept gzip-compressed in
  RAM; dnsmasq reads them through a conf-script.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/$(PKG_NAME)
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/rpcd reload
exit 0
endef

# the blocklist, the force DNS rules, the cron line and the dnsmasq jail
# mounts the service added go with the package
define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/omr-adblock stop >/dev/null 2>&1
/etc/init.d/omr-adblock disable
sed -i '/# omr-adblock$$/d' /etc/crontabs/root 2>/dev/null && /etc/init.d/cron restart
if [ -f /etc/omr-adblock.addnmount ]; then
	while read -r section path; do
		uci -q del_list "dhcp.$$section.addnmount=$$path"
	done < /etc/omr-adblock.addnmount
	uci -q commit dhcp
	rm -f /etc/omr-adblock.addnmount
	/etc/init.d/dnsmasq restart
fi
# the query statistics options (stop removed them already, unless the
# service was disabled before)
if [ -f /etc/omr-adblock.dhcp ]; then
	while read -r section option; do
		uci -q delete "dhcp.$$section.$$option"
	done < /etc/omr-adblock.dhcp
	uci -q commit dhcp
	rm -f /etc/omr-adblock.dhcp
	/etc/init.d/dnsmasq restart
fi
rm -f /var/log/omr-adblock-dns.log
rm -rf /var/run/omr-adblock /tmp/omr-adblock.work /etc/omr-adblock
exit 0
endef

# rpcd forgets the omr-adblock object only when it reads its plugins again
define Package/$(PKG_NAME)/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/rpcd reload
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
