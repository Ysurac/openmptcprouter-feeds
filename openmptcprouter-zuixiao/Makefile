#
# Copyright (C) suyunfan
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openmptcprouter-zuixiao
PKG_VERSION:=0.14
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
    mptcp       \
    unbound-daemon unbound-control unbound-anchor \
    netifd      \
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
    libnetfilter-conntrack ip-full nstat \
    iptables-mod-iface iptables-mod-ipmark iptables-mod-hashlimit iptables-mod-condition iptables-mod-trace iptables-mod-conntrack-extra iptables-mod-account \
    kmod-nf-nat kmod-nf-nathelper kmod-nf-nathelper-extra iptables-mod-extra conntrack kmod-ipt-offload \
    iptables-mod-ipsec kmod-crypto-authenc kmod-ipsec kmod-ipsec4 kmod-ipt-ipsec \
    wireless-tools \
    libiwinfo-lua \
    ca-bundle ca-certificates \
    luci-mod-admin-full luci-app-firewall luci-app-glorytun-tcp luci-app-glorytun-udp luci-app-shadowsocks-libev luci-app-unbound luci-theme-openmptcprouter luci-theme-argon luci-base \
    luci-app-omr-tracker luci-app-omr-dscp \
    luci-app-sqm-autorate sqm-scripts-extra \
    luci-app-vnstat2 omr-quota luci-app-omr-quota \
    luci-app-mptcp luci-app-openmptcprouter luci-app-upnp \
    luci-app-wol luci-app-opkg \
    luci-app-uhttpd \
    luci-mod-rpc rpcd-mod-rpcsys rpcd-mod-file rpcd-mod-iwinfo \
    luci-app-openvpn \
    shadowsocks-libev-ss-server shadowsocks-libev-ss-tunnel \
    speedtestcpp \
    iftop \
    htop \
    nano \
    tcpdump \
    ethtool \
    iputils-ping \
    tracebox \
    !TARGET_mvebu:luci-proto-3g \
    !TARGET_mvebu:comgt-ncm !TARGET_mvebu:luci-proto-ncm \
    !TARGET_mvebu:luci-proto-modemmanager \
    !TARGET_mvebu:luci-proto-ppp \
    omr-update \
    rng-tools \
    openvpn-openssl \
    mmc-utils \
    libimobiledevice libimobiledevice-utils \
    comgt \
    kmod-random-core \
    kmod-netem \
    ca-bundle openssl-util \
    dejavu-fonts-ttf-DejaVuSerif dejavu-fonts-ttf-DejaVuSerif-Bold dejavu-fonts-ttf-DejaVuSerif-Italic dejavu-fonts-ttf-DejaVuSerif-BoldItalic \
    luci-app-snmpd \
    iputils-tracepath v2ray-plugin netcat simple-obfs \
    TARGET_mvebu:kmod-mwlwifi TARGET_mvebu:mwlwifi-firmware-88w8864 TARGET_mvebu:mwlwifi-firmware-88w8897 TARGET_mvebu:mwlwifi-firmware-88w8964 TARGET_mvebu:mwlwifi-firmware-88w8997 \
    !TARGET_mvebu:kmod-usb-serial !TARGET_mvebu:kmod-usb-serial-option !TARGET_mvebu:kmod-usb-serial-wwan !TARGET_mvebu:usb-modeswitch !TARGET_mvebu:uqmi \
    !TARGET_mvebu:umbim !TARGET_mvebu:kmod-mii !TARGET_mvebu:kmod-usb-net !TARGET_mvebu:kmod-usb-wdm !TARGET_mvebu:kmod-usb-net-qmi-wwan !TARGET_mvebu:kmod-usb-net-cdc-mbim !TARGET_mvebu:umbim \
    !TARGET_mvebu:kmod-usb-net-huawei-cdc-ncm !TARGET_mvebu:kmod-usb-net-rndis !TARGET_mvebu:kmod-usb-net-cdc-ether !TARGET_mvebu:kmod-usb-net-ipheth !TARGET_mvebu:usbmuxd !TARGET_mvebu:libusbmuxd \
    !TARGET_mvebu:luci-proto-qmi kmod-rtl8187 TARGET_r4s:kmod-r8168 (TARGET_x86||TARGET_x86_64):kmod-usb-net-rtl8152 \
    kmod-zram kmod-swconfig swconfig kmod-ipt-nat luci-app-https-dns-proxy kmod-tcp-nanqinlang (TARGET_x86_64||aarch64):kmod-tcp-bbr2 iptables-mod-ipopt igmpproxy ss iptraf-ng \
    luci-app-acl block-mount blockd fstools luci-app-shutdown libwebp luci-proto-gre tcptraceroute luci-proto-mbim luci-app-ttyd luci-mod-dashboard (TARGET_x86||TARGET_x86_64):rtl8192eu-firmware kmod-usb2 libustream-openssl (TARGET_x86||TARGET_x86_64):dmidecode kmod-bonding luci-proto-bonding \
    luci-theme-openwrt-2020 luci-proto-wireguard luci-app-wireguard kmod-crypto-lib-blake2s (TARGET_x86||TARGET_x86_64):kmod-r8125 TARGET_x86_64:kmod-atlantic \
    LINUX_5_15:mptcpd (TARGET_x86||TARGET_x86_64):kmod-igc kmod-mmc-spi kmod-macsec usbutils
#    !TARGET_mvebu:kmod-usb-net-smsc75xx
#    libnetfilter-conntrack ebtables ebtables-utils ip-full nstat \

#     luci-theme-bootstrap luci-theme-openwrt-2020 luci-theme-openwrt luci-app-status
#  luci-proto-bonding luci-app-statistics luci-proto-gre
#    softethervpn5-client softethervpn5-server luci-app-nginx-ha

#    luci-app-mlvpn ubond \
#     kmod-ath9k kmod-ath9k-htc

#    (TARGET_x86||TARGET_x86_64):open-vm-tools \
#    (!TARGET_mvebu&&!TARGET_mediatek):kmod-fb-tft-all \
#    lcd4linux-full
#    kmod-spi-gpio-custom 

#OMR_SUPPORTED_LANGS := ar bg bn_BD ca en fi fr de el he hi hu it ja mr ms nb_NO pl pt_BR pt ro ru es sv uk vi zh_Hans zh_Hant
#OMR_SUPPORTED_LANGS := ar bg ca cs de en fi fr de el he hi hu it ja ko mr ms no oc pl pt-br pt ro ru es sk sv tr uk vi zh-cn zh-tw
OMR_SUPPORTED_LANGS := en zh-cn zh-tw oc

define Package/$(PKG_NAME)
SECTION:=OMR
CATEGORY:=OpenMPTCProuter
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p)) $(foreach lang,$(OMR_SUPPORTED_LANGS),+LUCI_LANG_$(lang):luci-i18n-base-$(lang))
TITLE:=OpenMPTCProuter zuixiao Package
endef

define Package/$(PKG_NAME)/description
OpenMPTCProuter zuixiao package
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
endef


$(eval $(call BuildPackage,$(PKG_NAME)))
