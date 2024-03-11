# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME := netxen-nic
PKG_RELEASE := 1

PKG_SOURCE := $(LINUX_SOURCE)
PKG_SOURCE_URL := $(LINUX_SITE)
PKG_HASH := $(LINUX_KERNEL_HASH)

PKG_LICENSE := GPL-2.0

PKG_FLAGS := nonshared
PKG_BUILD_PARALLEL := 1

include $(INCLUDE_DIR)/package.mk

TAR_CMD=$(HOST_TAR) -C $(1) --strip-components=1 $(TAR_OPTIONS)

define Build/Compile
    $(KERNEL_MAKE) \
	$(PKG_JOBS) \
	CONFIG_NETXEN_NIC=m \
	M=$(PKG_BUILD_DIR)/drivers/net/ethernet/qlogic/netxen \
	modules
endef

KernelPackage/hooks := :

define KernelPackage/netxen-nic
  TITLE := NetXen Multi port (1/10) Gigabit Ethernet NIC
  KCONFIG := CONFIG_NETXEN_NIC=m
  FILES := $(PKG_BUILD_DIR)/drivers/net/ethernet/qlogic/netxen/netxen_nic.ko
  AUTOLOAD := $(call AutoProbe,netxen_nic)
  DEPENDS := @PCI_SUPPORT +netxen-firmware
endef
$(eval $(call KernelPackage,netxen-nic))
