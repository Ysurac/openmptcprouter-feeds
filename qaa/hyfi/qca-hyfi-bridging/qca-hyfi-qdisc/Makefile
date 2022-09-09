include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-hyfi-qdisc
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_VERSION:=g846e528
endif

QCAHYFI_QDISC_MAKE_OPTS:= \
        CROSS_COMPILE=$(KERNEL_CROSS) \
        ARCH=$(LINUX_KARCH) \
        KERNELPATH=$(LINUX_DIR) \
        KERNELRELEASE=$(LINUX_RELEASE)

include $(INCLUDE_DIR)/package.mk

QCAHYBRID_MODULE_LIST:=$(PKG_BUILD_DIR)/hyfi_qdisc.ko

define KernelPackage/qca-hyfi-qdisc
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=Hy-Fi Queue Discipline Module
  DEPENDS:=
  KCONFIG:=CONFIG_NET_SCHED=y
  FILES:= $(strip $(QCAHYBRID_MODULE_LIST))
  AUTOLOAD:=$(call AutoLoad,40,hyfi_qdisc)
  SUBMENU:=Hy-Fi features
endef

define KernelPackage/qca-hyfi-qdisc/description
  This package installs the QCA Hy-Fi QDISC for raising priority of IEEE 1905.1 and HomePlugAV MME packets
endef

define Build/Compile
	$(MAKE) -C $(LINUX_DIR) M=$(PKG_BUILD_DIR) $(strip $(QCAHYFI_QDISC_MAKE_OPTS))
endef

$(eval $(call KernelPackage,qca-hyfi-qdisc))
