include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-mcs
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_VERSION:=g31b5c5b
endif

QCA_MC_SNOOPING_MAKE_OPTS:= \
        CROSS_COMPILE=$(KERNEL_CROSS) \
        ARCH=$(LINUX_KARCH) \
        KERNELPATH=$(LINUX_SRC_DIR) \
        KBUILDPATH=$(LINUX_DIR) \
        KERNELRELEASE=$(LINUX_RELEASE) \
	CONFIG_SUPPORT_MLD=y \
        MDIR=$(PKG_BUILD_DIR) \
	STAGING_DIR=$(STAGING_DIR)

ifeq ($(CONFIG_PACKAGE_kmod-qca-ovsmgr),y)
QCA_MC_SNOOPING_MAKE_OPTS += CONFIG_SUPPORT_OVS=y
PKG_BUILD_DEPENDS := PACKAGE_kmod-qca-ovsmgr
endif

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-mcs
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=QCA Multicast Snooping Support
  DEPENDS:=+PACKAGE_kmod-qca-ovsmgr:kmod-qca-ovsmgr
  KCONFIG:=CONFIG_NETFILTER=y CONFIG_BRIDGE_NETFILTER=y
  FILES:=$(PKG_BUILD_DIR)/qca-mcs.ko
  AUTOLOAD:=$(call AutoLoad,52,qca-mcs)
endef

define KernelPackage/qca-mcs/description
  This package installs the IGMP/MLD Snooping Module
endef

QCA_MC_SNOOPING_HEADERS= \
            $(PKG_BUILD_DIR)/mc_api.h \
            $(PKG_BUILD_DIR)/mc_ecm.h \

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-mcs
	$(foreach header_file,$(QCA_MC_SNOOPING_HEADERS), $(CP) $(header_file) $(1)/usr/include/qca-mcs;)
endef

define Build/Compile
	$(MAKE) -C $(LINUX_DIR) M=$(PKG_BUILD_DIR) $(strip $(QCA_MC_SNOOPING_MAKE_OPTS))
endef

$(eval $(call KernelPackage,qca-mcs))
