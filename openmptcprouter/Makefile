#
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openmptcprouter
PKG_VERSION:=0.52
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
    mptcp       \
    unbound     \
    netifd      \
    mc          \
    omr-tracker \
    luci-mod-admin-full luci-app-firewall luci-app-glorytun luci-app-shadowsocks-libev luci-app-unbound luci-theme-bootstrap luci-base


define Package/$(PKG_NAME)
SECTION:=OMR
CATEGORY:=OpenMPTCProuter
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p))
TITLE:=OpenMPTCProuter Full Package
endef

define Package/$(PKG_NAME)/description
OpenMPTCProuter package
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/$(PKG_NAME)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
