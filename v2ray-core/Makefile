#
# Copyright (C) 2019 Xingwang Liao
# Copyright (C) 2020 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-core
PKG_VERSION:=4.43.0
PKG_RELEASE:=1

#PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/v2fly/v2ray-core/archive/refs/tags/
PKG_HASH:=f27b8fe8e1e102b0297339ee368c8b650fde0f949e0d90e1229ff6744f99ba0f

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Yannick Chabanois <ycarus@zugaina.org>

PKG_CONFIG_DEPENDS := \
	CONFIG_V2RAY_JSON_V2CTL \
	CONFIG_V2RAY_JSON_INTERNAL \
	CONFIG_V2RAY_JSON_NONE \
	CONFIG_V2RAY_EXCLUDE_V2CTL \
	CONFIG_V2RAY_EXCLUDE_ASSETS \
	CONFIG_V2RAY_COMPRESS_UPX \
	CONFIG_V2RAY_DISABLE_NONE \
	CONFIG_V2RAY_DISABLE_CUSTOM \
	CONFIG_V2RAY_DISABLE_DNS \
	CONFIG_V2RAY_DISABLE_LOG \
	CONFIG_V2RAY_DISABLE_POLICY \
	CONFIG_V2RAY_DISABLE_REVERSE \
	CONFIG_V2RAY_DISABLE_ROUTING \
	CONFIG_V2RAY_DISABLE_STATISTICS \
	CONFIG_V2RAY_DISABLE_BLACKHOLE_PROTO \
	CONFIG_V2RAY_DISABLE_DNS_PROXY \
	CONFIG_V2RAY_DISABLE_DOKODEMO_PROTO \
	CONFIG_V2RAY_DISABLE_FREEDOM_PROTO \
	CONFIG_V2RAY_DISABLE_MTPROTO_PROXY \
	CONFIG_V2RAY_DISABLE_HTTP_PROTO \
	CONFIG_V2RAY_DISABLE_SHADOWSOCKS_PROTO \
	CONFIG_V2RAY_DISABLE_SOCKS_PROTO \
	CONFIG_V2RAY_DISABLE_VMESS_PROTO \
	CONFIG_V2RAY_DISABLE_TCP_TRANS \
	CONFIG_V2RAY_DISABLE_MKCP_TRANS \
	CONFIG_V2RAY_DISABLE_WEBSOCKET_TRANS \
	CONFIG_V2RAY_DISABLE_HTTP2_TRANS \
	CONFIG_V2RAY_DISABLE_DOMAIN_SOCKET_TRANS \
	CONFIG_V2RAY_DISABLE_QUIC_TRANS

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

GO_PKG:=github.com/v2fly/v2ray-core/v4
GO_PKG_LDFLAGS:=-s -w

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/v2ray-core
  TITLE:=A platform for building proxies
  URL:=https://www.v2fly.org
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Project V
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle +protobuf
endef

define Package/v2ray-core/config
	source "$(SOURCE)/Config.in"
endef

define Package/v2ray-core/description
Project V is a set of network tools that help you to build your own computer network.
It secures your network connections and thus protects your privacy.

  This package contains v2ray, v2ctl and v2ray-assets.
endef

V2RAY_SED_ARGS:=

ifeq ($(CONFIG_V2RAY_JSON_INTERNAL),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/main\/json"/\/\/ &/; \
	/\/\/ _ "github.com\/v2fly\/v2ray-core\/v4\/main\/jsonem"/s/\/\/ //;
else ifeq ($(CONFIG_V2RAY_JSON_NONE),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/main\/json"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_CUSTOM),y)

ifeq ($(CONFIG_V2RAY_DISABLE_DNS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/dns"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_LOG),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/log"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/log\/command"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_POLICY),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/policy"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_REVERSE),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/reverse"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_ROUTING),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/router"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_STATISTICS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/stats"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/app\/stats\/command"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_BLACKHOLE_PROTO),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/blackhole"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_DNS_PROXY),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/dns"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_DOKODEMO_PROTO),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/dokodemo"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_FREEDOM_PROTO),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/freedom"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_MTPROTO_PROXY),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/mtproto"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_HTTP_PROTO),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/http"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_SHADOWSOCKS_PROTO),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/shadowsocks"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_SOCKS_PROTO),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/socks"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_VMESS_PROTO),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/vmess\/inbound"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/proxy\/vmess\/outbound"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_TCP_TRANS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/tcp"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_MKCP_TRANS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/kcp"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_WEBSOCKET_TRANS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/websocket"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_HTTP2_TRANS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/http"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/headers\/http"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_DOMAIN_SOCKET_TRANS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/domainsocket"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_QUIC_TRANS),y)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/quic"/\/\/ &/;
endif

ifeq ($(CONFIG_V2RAY_DISABLE_MKCP_TRANS)$(CONFIG_V2RAY_DISABLE_QUIC_TRANS),yy)
V2RAY_SED_ARGS += \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/headers\/noop"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/headers\/srtp"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/headers\/tls"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/headers\/utp"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/headers\/wechat"/\/\/ &/; \
	s/_ "github.com\/v2fly\/v2ray-core\/v4\/transport\/internet\/headers\/wireguard"/\/\/ &/;
endif

endif

GEOIP_VER:=latest
GEOIP_FILE:=geoip-$(GEOIP_VER).dat

define Download/geoip.dat
  URL:=https://github.com/v2ray/geoip/releases/$(GEOIP_VER)/download
  URL_FILE:=geoip.dat
  FILE:=$(GEOIP_FILE)
  HASH:=skip
endef

GEOSITE_VER:=latest
GEOSITE_FILE:=geosite-$(GEOSITE_VER).dat

define Download/geosite.dat
  URL:=https://github.com/v2ray/domain-list-community/releases/$(GEOSITE_VER)/download
  URL_FILE:=dlc.dat
  FILE:=$(GEOSITE_FILE)
  HASH:=skip
endef

define Build/Prepare
	$(Build/Prepare/Default)

ifneq ($(CONFIG_V2RAY_EXCLUDE_ASSETS),y)
	# move file to make sure download new file every build
	mv -f $(DL_DIR)/$(GEOIP_FILE) $(PKG_BUILD_DIR)/release/config/geoip.dat
	mv -f $(DL_DIR)/$(GEOSITE_FILE) $(PKG_BUILD_DIR)/release/config/geosite.dat
endif

	( \
		sed -i \
			's/\(version[[:space:]]*=[[:space:]]*"\).*\("\)/\1$(PKG_VERSION)\2/; \
			s/\(build[[:space:]]*=[[:space:]]*"\).*\("\)/\1OpenWrt R$(PKG_RELEASE)\2/' \
			$(PKG_BUILD_DIR)/core.go ; \
	)
ifneq ($(V2RAY_SED_ARGS),)
	( \
		sed -i \
			'$(V2RAY_SED_ARGS)' \
			$(PKG_BUILD_DIR)/main/distro/all/all.go ; \
	)
endif
endef

define Build/Compile
	$(eval GO_PKG_BUILD_PKG:=$(GO_PKG)/main)
	$(call GoPackage/Build/Compile)
	mv -f $(GO_PKG_BUILD_BIN_DIR)/main $(GO_PKG_BUILD_BIN_DIR)/v2ray

ifeq ($(CONFIG_V2RAY_COMPRESS_UPX),y)
	upx --ultra-brute $(GO_PKG_BUILD_BIN_DIR)/v2ray
endif

ifneq ($(CONFIG_V2RAY_EXCLUDE_V2CTL),y)
	$(eval GO_PKG_BUILD_PKG:=$(GO_PKG)/infra/control/main)
	$(call GoPackage/Build/Compile)
	mv -f $(GO_PKG_BUILD_BIN_DIR)/main $(GO_PKG_BUILD_BIN_DIR)/v2ctl

ifeq ($(CONFIG_V2RAY_COMPRESS_UPX),y)
	upx --ultra-brute $(GO_PKG_BUILD_BIN_DIR)/v2ctl
endif
endif
endef

define Package/v2ray-core/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))

	$(INSTALL_DIR) $(1)/usr/bin

	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/v2ray $(1)/usr/bin
	$(CP) ./files/* $(1)/

ifneq ($(CONFIG_V2RAY_EXCLUDE_V2CTL),y)
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/v2ctl $(1)/usr/bin
endif

ifneq ($(CONFIG_V2RAY_EXCLUDE_ASSETS),y)
	$(INSTALL_DATA) \
		$(PKG_BUILD_DIR)/release/config/{geoip,geosite}.dat \
		$(1)/usr/bin
endif
endef

ifneq ($(CONFIG_V2RAY_EXCLUDE_ASSETS),y)
$(eval $(call Download,geoip.dat))
$(eval $(call Download,geosite.dat))
endif

$(eval $(call GoBinPackage,v2ray-core))
$(eval $(call BuildPackage,v2ray-core))
