include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-hyfi-iptv-helper
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_REV:=98e294d
PKG_VERSION:=g98e294d
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

WIFI_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_A:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_D:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_MIPS_UNIFIED:=PACKAGE_kmod-qca-wifi-unified-perf
WIFI_10_2_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_10_2_ARM:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_L:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_16M:=PACKAGE_kmod-qca-wifi-flash_16mb-profile
WIFI_PKGS:=$(WIFI_U)||$(WIFI_C)||$(WIFI_A)||$(WIFI_D)||$(WIFI_MIPS)||$(WIFI_MIPS_UNIFIED)||$(WIFI_10_2_MIPS)||$(WIFI_10_2_ARM)||$(WIFI_L)||$(WIFI_16M)
PKG_BUILD_DEPENDS:=$(WIFI_U):qca-wifi $(WIFI_C):qca-wifi $(WIFI_A):qca-wifi $(WIFI_D):qca-wifi $(WIFI_MIPS):qca-wifi \
	$(WIFI_MIPS_UNIFIED):qca-wifi $(WIFI_10_2_MIPS):qca-wifi $(WIFI_10_2_ARM):qca-wifi $(WIFI_L):qca-wifi $(WIFI_16M):qca-wifi

QCAHYFI_IPTV_HELPER_MAKE_OPTS:= \
        CROSS_COMPILE=$(KERNEL_CROSS) \
        ARCH=$(LINUX_KARCH) \
        KERNELPATH=$(LINUX_SRC_DIR) \
        KBUILDPATH=$(LINUX_DIR) \
        KERNELRELEASE=$(LINUX_RELEASE)

include $(INCLUDE_DIR)/package.mk

QCAHYBRID_MODULE_LIST:=$(PKG_BUILD_DIR)/hyfi-iptv-helper.ko

define KernelPackage/qca-hyfi-iptv-helper
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=IPTV on Wireless Interface Netfilter Module
  DEPENDS:=@$(WIFI_PKGS) +kmod-bridge
  KCONFIG:= \
    CONFIG_NETFILTER=y \
    CONFIG_BRIDGE_NETFILTER=y
  FILES:= $(strip $(QCAHYBRID_MODULE_LIST))
  SUBMENU:=Hy-Fi features
endef

define KernelPackage/qca-hyfi-iptv-helper/description
  This package installs the QCA Hy-Fi Netfilter for IPTV implementations on Wireless interface
endef

define Build/Compile
	$(MAKE) -C $(LINUX_DIR) M=$(PKG_BUILD_DIR) $(strip $(QCAHYFI_IPTV_HELPER_MAKE_OPTS))
endef

$(eval $(call KernelPackage,qca-hyfi-iptv-helper))
