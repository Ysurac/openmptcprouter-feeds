#
# Based on package from https://github.com/openwrt-develop/ndpi-netfilter/
# Copyright (C) 2018-2022 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ndpi-netfilter2
PKG_RELEASE:=4
#PKG_REV:=3deea541af037b663b1b83a055b80d9a06a0afd2
#PKG_REV:=5cf35a64c8296b69099d3bd4c8cb9222f3174901
PKG_REV:=761993583265cf9a022be1ad2d701e446bb91d42
PKG_VERSION:=4-$(PKG_REV)

PKG_SOURCE_PROTO:=git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/vel21ripn/nDPI.git
PKG_SOURCE_VERSION:=$(PKG_REV)

PKG_LICENSE:=GPL-2.0-or-later
PKG_LICENSE_FILES:=COPYING

PKG_BUILD_PARALLEL:=0
PKG_FORTIFY_SOURCE:=0

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/iptables-mod-ndpi
	SUBMENU:=Firewall
	SECTION:=net
	CATEGORY:=Network
	TITLE:=ndpi successor of OpenDPI
	URL:=http://www.ntop.org/products/ndpi/
#	DEPENDS:=+iptables +iptables-mod-conntrack-extra +kmod-ipt-ndpi +libpcap
#	DEPENDS:=+iptables +kmod-ipt-ndpi +libpcap @(LINUX_5_4||LINUX_5_15||TARGET_x86_64)
#	DEPENDS:=+iptables +kmod-ipt-ndpi +libpcap @(LINUX_5_4||LINUX_5_15) @!TARGET_ramips
	DEPENDS:=+iptables +kmod-ipt-ndpi +libpcap @!TARGET_ramips
	MAINTAINER:=Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
endef

define Package/iptables-mod-ndpi/description
  nDPI is a ntop-maintained superset of the popular OpenDPI library
endef

CONFIGURE_CMD=./autogen.sh
CONFIGURE_ARGS += --with-pic

MAKE_PATH:=ndpi-netfilter

MAKE_FLAGS += \
    KERNEL_DIR="$(LINUX_DIR)" \
    MODULES_DIR="$(TARGET_MODULES_DIR)" \
    NDPI_PATH=$(PKG_BUILD_DIR)/ndpi-netfilter \
    CONFIG_NDPI_HOOK="yes"

ifeq ($ARCH),aarch64)
    MAKE_FLAGS += ARCH="arm64"
else
    MAKE_FLAGS += ARCH="$(LINUX_KARCH)"
endif

define Build/Compile
#	(cd $(PKG_BUILD_DIR)/src/lib &&\
#	    gcc -g -O2 -fPIC -DPIC -DNDPI_LIB_COMPILATION -I../../src/include/ -I../../src/lib/third_party/include/ ndpi_network_list_compile.c -o ndpi_network_list_compile &&\
#	    ./ndpi_network_list_compile -o ndpi_network_list.c.inc ndpi_network_list_*.yaml)
	$(MAKE) $(MAKE_FLAGS) -C $(PKG_BUILD_DIR)/ndpi-netfilter
endef

define Package/iptables-mod-ndpi/install
	$(INSTALL_DIR) $(1)/usr/lib/iptables
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ndpi-netfilter/ipt/libxt_ndpi.so $(1)/usr/lib/iptables
endef

define KernelPackage/ipt-ndpi
	SUBMENU:=Netfilter Extensions
	TITLE:= nDPI net netfilter module
#	DEPENDS:=+kmod-nf-conntrack +kmod-nf-conntrack-netlink +kmod-ipt-compat-xtables +libpcap @(LINUX_5_4||LINUX_5_15||TARGET_x86_64)
#	DEPENDS:=+kmod-nf-conntrack +kmod-nf-conntrack-netlink +kmod-ipt-compat-xtables +libpcap @(LINUX_5_4||LINUX_5_15) @!TARGET_ramips
	DEPENDS:=+kmod-nf-conntrack +kmod-nf-conntrack-netlink +(LINUX_5_4||LINUX_6_1):kmod-ipt-compat-xtables +libpcap @!TARGET_ramips
#	DEPENDS:=+kmod-nf-conntrack +kmod-nf-conntrack-netlink +kmod-ipt-compat-xtables +libpcap
	KCONFIG:=CONFIG_NF_CONNTRACK_LABELS=y \
	    CONFIG_NETFILTER_XT_MATCH_CONNLABEL=y
	FILES:= $(PKG_BUILD_DIR)/ndpi-netfilter/src/xt_ndpi.ko
	AUTOLOAD:=$(call AutoProbe,xt_ndpi)
#	MODPARAMS.xt_ndpi:=ndpi_enable_flow=1
	KCONFIG:=\
	    CONFIG_NDPI_HOOK=y \
	    CONFIG_NF_CONNTRACK=y \
	    CONFIG_NF_CONNTRACK_LABELS=y \
	    CONFIG_NETFILTER_XT_MATCH_CONNLABEL=y \
	    CONFIG_UNUSED_SYMBOLS=y
endef

$(eval $(call BuildPackage,iptables-mod-ndpi))
$(eval $(call KernelPackage,ipt-ndpi))
