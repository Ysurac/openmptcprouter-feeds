#
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openmptcprouter-full
PKG_VERSION:=0.8
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
    conntrack conntrackd ebtables ebtables-utils ip-full \
    iptables-mod-iface iptables-mod-ipmark iptables-mod-hashlimit iptables-mod-condition iptables-mod-trace iptables-mod-conntrack-extra \
    wireless-tools \
    libiwinfo-lua \
    ca-bundle ca-certificates libustream-openssl \
    luci-mod-admin-full luci-app-firewall luci-app-glorytun luci-app-shadowsocks-libev luci-app-unbound luci-theme-openmptcprouter luci-base \
    luci-app-nginx-ha luci-app-omr-tracker luci-app-qos \
    luci-app-vnstat omr-quota luci-app-omr-quota \
    luci-app-mptcp luci-app-openmptcprouter luci-app-omr-bypass \
    omr-6in4 ip6tables-mod-nat luci-proto-ipv6 6to4 6in4 6rd iputils-traceroute6 \
    speedtestc ethtool \
    luci-proto-3g \
    luci-app-mlvpn mlvpn \
    omr-update \
    openvpn-openssl \
    kmod-rt2800-usb libimobiledevice \
    kmod-rtl8xxxu kmod-rtl8192cu kmod-net-rtl8192su comgt kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan usb-modeswitch uqmi adb-enablemodem umbim kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan kmod-usb-net-cdc-mbim

OMR_SUPPORTED_LANGS := ca zh-cn en fr de el he hu it ja ms no pl pt-br pt ro ru es sv uk vi

define Package/$(PKG_NAME)
SECTION:=OMR
CATEGORY:=OpenMPTCProuter
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p)) $(foreach lang,$(OMR_SUPPORTED_LANGS),+LUCI_LANG_$(lang):luci-i18n-base-$(lang))
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
