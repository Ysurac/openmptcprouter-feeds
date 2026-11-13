#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=omr-wifi-acs
PKG_VERSION:=0.01
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
SECTION:=net
CATEGORY:=Network
DEPENDS:=+iw +jsonfilter
TITLE:=Wi-Fi channel re-optimization
endef

define Package/$(PKG_NAME)/description
Restarts a Wi-Fi radio set to channel auto when its channel stays busy with
the traffic of others, so that hostapd chooses the least busy channel again.
Only with no client connected or in the quiet hours, every 6 hours at most.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/$(PKG_NAME)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
sed -i '/omr-wifi-acs/d' /etc/crontabs/root
/etc/init.d/cron restart >/dev/null 2>&1
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
