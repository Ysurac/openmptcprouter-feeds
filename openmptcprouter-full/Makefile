#
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openmptcprouter-full
PKG_VERSION:=0.10
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
    mptcp       \
    unbound     \
    netifd      \
    mc          \
    openmptcprouter \
    dnsmasq-full \
    uhttpd \
    uhttpd-mod-ubus \
    curl \
    iperf3 \
    arptables \
    bind-dig \
    conntrack conntrackd \
    ebtables ebtables-utils \
    ip-full \
    iputils-traceroute6 \
    iptables-mod-iface iptables-mod-ipmark iptables-mod-hashlimit iptables-mod-condition iptables-mod-trace iptables-mod-conntrack-extra \
    wireless-tools \
    libiwinfo-lua \
    luci-i18n-base-en \
    luci-i18n-base-fr \
    luci-i18n-base-de \
    luci-i18n-base-es \
    luci-i18n-base-ca \
    luci-i18n-base-cs \
    luci-i18n-base-el \
    luci-i18n-base-he \
    luci-i18n-base-hu \
    luci-i18n-base-it \
    luci-i18n-base-ja \
    luci-i18n-base-ko \
    luci-i18n-base-ms \
    luci-i18n-base-no \
    luci-i18n-base-pl \
    luci-i18n-base-pt \
    luci-i18n-base-ro \
    luci-i18n-base-ru \
    luci-i18n-base-sk \
    luci-i18n-base-sv \
    luci-i18n-base-tr \
    luci-i18n-base-vi \
    luci-i18n-base-zh-cn \
    luci-i18n-base-zh-tw \
    luci-i18n-firewall-en \
    luci-i18n-firewall-fr \
    ca-bundle ca-certificates \
    luci-mod-admin-full luci-app-firewall luci-app-glorytun luci-app-shadowsocks-libev luci-app-unbound luci-theme-openmptcprouter luci-base \
    luci-app-nginx-ha luci-app-omr-tracker luci-app-qos \
    luci-app-vnstat omr-quota luci-app-omr-quota \
    speedtestc \
    ip6tables-mod-nat luci-proto-ipv6 ethtool

define Package/$(PKG_NAME)
SECTION:=OMR
CATEGORY:=OpenMPTCProuter
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p))
TITLE:=OpenMPTCProuter Full Package
endef

define Package/$(PKG_NAME)/description
OpenMPTCProuter Full package
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/$(PKG_NAME)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
endef


$(eval $(call BuildPackage,$(PKG_NAME)))
