
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=omr-events
PKG_VERSION:=0.01
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
    omr-tracker \
    jsonfilter

define Package/$(PKG_NAME)
SECTION:=net
CATEGORY:=Network
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p))
TITLE:=OMR-Tracker interface event history
endef

define Package/$(PKG_NAME)/description
OpenMPTCProuter interface event history. Logs a timestamped event every time
an interface tracked by omr-tracker changes state: up, down, high latency,
packet loss or disconnection. Events are exposed over ubus and kept in a log
capped by a configurable age and/or size (2 days / 10MB by default).
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
