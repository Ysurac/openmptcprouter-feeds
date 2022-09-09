include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-hyfi-bridge
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_VERSION:=g3cfe593
endif

PKG_BUILD_DEPENDS += qca-ssdk
include $(INCLUDE_DIR)/package.mk

QCAHYFI_BRIDGE_MAKE_OPTS:= \
        CROSS_COMPILE=$(KERNEL_CROSS) \
        ARCH=$(LINUX_KARCH) \
        HYBRID_MC_MLD=1 \
        KERNELPATH=$(LINUX_SRC_DIR) \
        KBUILDPATH=$(LINUX_DIR) \
        KERNELRELEASE=$(LINUX_RELEASE) \
        MDIR=$(PKG_BUILD_DIR) \
        STAGING_DIR=$(STAGING_DIR)

ifeq ($(CONFIG_PACKAGE_qca-plc-serv),y)
        QCAHYFI_BRIDGE_MAKE_OPTS += PLC_SUPPORT_NF=1
endif

ifeq ($(CONFIG_HYFI_DISABLE_SSDK_SUPPORT),y)
    QCAHYFI_BRIDGE_MAKE_OPTS+= DISABLE_SSDK_SUPPORT=1
endif

ifneq ($(CONFIG_PACKAGE_kmod-emesh-sp),)
    QCAHYFI_BRIDGE_MAKE_OPTS += HYFI_BRIDGE_EMESH_ENABLE=1
endif

QCAHYBRID_MODULE_LIST:=$(PKG_BUILD_DIR)/hyfi-bridging.ko

define KernelPackage/qca-hyfi-bridge
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=Hy-Fi Bridging Netfilter Module
  KCONFIG:= \
    CONFIG_NETFILTER=y \
    CONFIG_BRIDGE_NETFILTER=y
  DEPENDS:=+LINUX_5_4:kmod-qca-ssdk-nohnat +PACKAGE_kmod-emesh-sp:kmod-emesh-sp
  FILES:= $(strip $(QCAHYBRID_MODULE_LIST))
  AUTOLOAD:=$(call AutoLoad,51,hyfi-bridging)
  SUBMENU:=Hy-Fi features
endef

define KernelPackage/qca-hyfi-bridge/description
  This package installs the Hy-Fi bridging Netfilter Module
endef

define KernelPackage/qca-hyfi-bridge/config
config HYFI_DISABLE_SSDK_SUPPORT
    bool "Disable SSDK support for IPQ platform"
    default n
    help
      This option disable SSDK support
endef

QCA_HYFI_BRIDGE_HEADERS= \
            $(PKG_BUILD_DIR)/hyfi-multicast/mc_api.h \
            $(PKG_BUILD_DIR)/hyfi-netfilter/hyfi_ecm.h \
            $(PKG_BUILD_DIR)/hyfi-netfilter/hyfi_api.h \
            $(PKG_BUILD_DIR)/hyfi-netfilter/hyfi_hash.h

ifneq ($(CONFIG_PACKAGE_kmod-qca-hyfi-bridge),)
define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/hyfibr
	$(foreach header_file,$(QCA_HYFI_BRIDGE_HEADERS), $(CP) $(header_file) $(1)/usr/include/hyfibr;)
endef
endif

define Build/Compile
       $(MAKE) -C $(LINUX_DIR) M=$(PKG_BUILD_DIR) $(strip $(QCAHYFI_BRIDGE_MAKE_OPTS))
endef

define KernelPackage/qca-hyfi-bridge/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/hyfi-bridging.init $(1)/etc/init.d/hyfi-bridging
endef

$(eval $(call KernelPackage,qca-hyfi-bridge))
