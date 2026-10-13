
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=omr-metrics
PKG_VERSION:=0.01
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
    omr-tracker \
    curl \
    jsonfilter \
    tc \
    ss

define Package/$(PKG_NAME)
SECTION:=net
CATEGORY:=Network
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p))
TITLE:=OMR-Tracker metrics
endef

define Package/$(PKG_NAME)/description
OpenMPTCProuter Metrics package
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/$(PKG_NAME)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
	$(INSTALL_BIN) ./files/usr/bin/omr-metrics-send $(1)/usr/bin/omr-metrics-send
	$(INSTALL_BIN) ./files/usr/bin/omr-weight-sync $(1)/usr/bin/omr-weight-sync
	$(INSTALL_BIN) ./files/etc/init.d/omr-metrics $(1)/etc/init.d/omr-metrics
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
