#
# Copyright (C) 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openmptcprouter-mini
PKG_VERSION:=0.1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
    mptcp       \
    unbound-daemon unbound-control unbound-anchor \
    netifd      \
    luci-app-dsvpn \
    mc          \
    f2fs-tools \
    openmptcprouter \
    dnsmasq-full \
    uhttpd \
    uhttpd-mod-ubus \
    curl \
    iperf3-ssl luci-app-iperf \
    arptables \
    bind-dig \
    libnetfilter-conntrack ebtables ebtables-utils ip-full \
    iptables-mod-iface iptables-mod-ipmark iptables-mod-hashlimit iptables-mod-condition iptables-mod-trace iptables-mod-conntrack-extra iptables-mod-account \
    kmod-nf-nat kmod-nf-nathelper kmod-nf-nathelper-extra iptables-mod-extra \
    iptables-mod-ipsec kmod-crypto-authenc kmod-ipsec kmod-ipsec4 kmod-ipsec6 kmod-ipt-ipsec \
    wireless-tools \
    libiwinfo-lua \
    ca-bundle ca-certificates libustream-openssl \
    luci-mod-admin-full luci-app-firewall luci-app-glorytun-tcp luci-app-glorytun-udp luci-app-shadowsocks-libev luci-app-unbound luci-theme-openmptcprouter luci-base \
    luci-app-omr-tracker luci-app-omr-dscp \
    luci-app-sqm sqm-scripts-extra \
    luci-app-vnstat2 omr-quota luci-app-omr-quota \
    luci-app-mptcp luci-app-openmptcprouter luci-app-omr-bypass luci-app-mail luci-app-upnp \
    luci-app-opkg \
    luci-app-uhttpd \
    luci-mod-rpc rpcd-mod-rpcsys rpcd-mod-file rpcd-mod-iwinfo \
    luci-app-openvpn \
    macvlan \
    shadowsocks-libev-ss-server shadowsocks-libev-ss-tunnel \
    omr-6in4 ip6tables-mod-nat luci-proto-ipv6 6to4 6in4 6rd ip6tables \
    iftop \
    htop \
    tcpdump \
    ethtool \
    iputils-ping \
    !TARGET_mvebu:luci-proto-3g \
    !TARGET_mvebu:comgt-ncm !TARGET_mvebu:luci-proto-ncm \
    !TARGET_mvebu:luci-proto-modemmanager \
    !TARGET_mvebu:luci-proto-ppp \
    omr-update \
    rng-tools \
    openvpn-openssl \
    mmc-utils \
    libimobiledevice \
    comgt \
    kmod-random-core \
    ca-bundle openssl-util \
    dejavu-fonts-ttf-DejaVuSerif dejavu-fonts-ttf-DejaVuSerif-Bold dejavu-fonts-ttf-DejaVuSerif-Italic dejavu-fonts-ttf-DejaVuSerif-BoldItalic \
    iputils-tracepath netcat adb-enablemodem \
    (TARGET_x86||TARGET_x86_64):kmod-iwlwifi (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl1000 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl100 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl105 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl135 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl2000 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl2030 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl3160 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl3168 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl5000 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl5150 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl6000g2 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl6000g2a (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl6000g2b (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl6050 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl7260 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl7265 (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl7265d (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl8260c (TARGET_x86||TARGET_x86_64):iwlwifi-firmware-iwl8265 \
    (TARGET_x86||TARGET_x86_64):kmod-e1000 (TARGET_x86||TARGET_x86_64):kmod-e1000e (TARGET_x86||TARGET_x86_64):kmod-igb (TARGET_x86||TARGET_x86_64):kmod-ne2k-pci (TARGET_x86||TARGET_x86_64):kmod-r8169 (TARGET_x86||TARGET_x86_64):kmod-8139too (TARGET_x86||TARGET_x86_64):kmod-bnx2 \
    TARGET_mvebu:kmod-mwlwifi TARGET_mvebu:mwlwifi-firmware-88w8864 TARGET_mvebu:mwlwifi-firmware-88w8897 TARGET_mvebu:mwlwifi-firmware-88w8964 TARGET_mvebu:mwlwifi-firmware-88w8997 \
    !TARGET_mvebu:kmod-usb-serial !TARGET_mvebu:kmod-usb-serial-option !TARGET_mvebu:kmod-usb-serial-wwan !TARGET_mvebu:usb-modeswitch !TARGET_mvebu:uqmi \
    !TARGET_mvebu:umbim !TARGET_mvebu:kmod-mii !TARGET_mvebu:kmod-usb-net !TARGET_mvebu:kmod-usb-wdm !TARGET_mvebu:kmod-usb-net-qmi-wwan !TARGET_mvebu:kmod-usb-net-cdc-mbim !TARGET_mvebu:umbim \
    !TARGET_mvebu:kmod-usb-net-huawei-cdc-ncm !TARGET_mvebu:kmod-usb-net-rndis !TARGET_mvebu:kmod-usb-net-cdc-ether !TARGET_mvebu:kmod-usb-net-ipheth !TARGET_mvebu:usbmuxd \
    kmod-rt2800-usb kmod-rtl8xxxu kmod-rtl8192cu kmod-net-rtl8192su \
    !TARGET_mvebu:luci-proto-qmi wpad-basic kmod-mt7601u kmod-rtl8187 \
    luci-app-mlvpn mlvpn 464xlat !TARGET_mvebu:kmod-usb-net-smsc75xx kmod-zram kmod-swconfig swconfig kmod-ipt-nat kmod-ipt-nat6 luci-app-https-dns-proxy kmod-tcp-nanqinlang iptables-mod-ipopt ss \
    luci-app-acl block-mount blockd fstools luci-app-shutdown libwebp luci-proto-gre

OMR_SUPPORTED_LANGS := en

define Package/$(PKG_NAME)
SECTION:=OMR
CATEGORY:=OpenMPTCProuter
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p)) $(foreach lang,$(OMR_SUPPORTED_LANGS),+LUCI_LANG_$(lang):luci-i18n-base-$(lang))
TITLE:=OpenMPTCProuter Mini Package
endef

define Package/$(PKG_NAME)/description
OpenMPTCProuter Mini package
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
endef


$(eval $(call BuildPackage,$(PKG_NAME)))
