#
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openmptcprouter-full
PKG_VERSION:=0.12
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
    mptcp       \
    unbound unbound-control \
    netifd      \
    mc          \
    openmptcprouter \
    dnsmasq-full \
    uhttpd \
    uhttpd-mod-ubus \
    curl \
    iperf3-ssl luci-app-iperf \
    arptables \
    bind-dig \
    conntrack conntrackd ebtables ebtables-utils ip-full \
    iptables-mod-iface iptables-mod-ipmark iptables-mod-hashlimit iptables-mod-condition iptables-mod-trace iptables-mod-conntrack-extra iptables-mod-account \
    kmod-nf-nat kmod-nf-nathelper kmod-nf-nathelper-extra \
    wireless-tools \
    libiwinfo-lua \
    ca-bundle ca-certificates libustream-openssl \
    luci-mod-admin-full luci-app-firewall luci-app-glorytun luci-app-shadowsocks-libev luci-app-unbound luci-theme-openmptcprouter luci-base \
    luci-app-nginx-ha luci-app-omr-tracker \
    luci-app-sqm sqm-scripts-extra \
    luci-app-vnstat omr-quota luci-app-omr-quota \
    luci-app-mptcp luci-app-openmptcprouter luci-app-omr-bypass luci-app-mail luci-app-snmpd luci-app-upnp \
    omr-6in4 ip6tables-mod-nat luci-proto-ipv6 6to4 6in4 6rd iputils-traceroute6 ip6tables \
    speedtestc \
    iftop \
    htop \
    tcpdump \
    ethtool \
    iputils-ping \
    tracebox \
    luci-proto-3g \
    comgt-ncm luci-proto-ncm \
    luci-app-mlvpn mlvpn \
    omr-update \
    rng-tools \
    openvpn-openssl \
    mmc-utils \
    libimobiledevice \
    comgt kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan usb-modeswitch uqmi adb-enablemodem umbim kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan kmod-usb-net-cdc-mbim umbim \
    kmod-usb-net-huawei-cdc-ncm kmod-usb-net-rndis kmod-usb-net-cdc-ether kmod-usb-net-ipheth usbmuxd \
    kmod-rt2800-usb     \
    kmod-mt7601u        \
    kmod-rtl8xxxu       \
    kmod-rtl8192cu      \
    kmod-net-rtl8192su \
    wpad-basic \
    luci-proto-qmi

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

define Build/Compile
endef

define Package/$(PKG_NAME)/install
endef


$(eval $(call BuildPackage,$(PKG_NAME)))
