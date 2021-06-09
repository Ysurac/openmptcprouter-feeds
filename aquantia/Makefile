include $(TOPDIR)/rules.mk

PKG_NAME:=kmod-aquantia
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define KernelPackage/phy-aquantia
  SUBMENU:=Network Devices
  TITLE:=aQuantia device support
  DEPENDS:=@PCI_SUPPORT @TARGET_x86_64 +kmod-i2c-core +kmod-i2c-algo-bit +kmod-ptp +kmod-hwmon-core +kmod-libphy
  KCONFIG:=CONFIG_AQUANTIA_PHY
  HIDDEN:=1
  FILES:=$(LINUX_DIR)/drivers/net/phy/aquantia.ko
  AUTOLOAD:=$(call AutoProbe,aquantia)
endef

define KernelPackage/phy-aquantia/description
 Kernel modules for aQuantia Ethernet adapters.
endef

define KernelPackage/atlantic
  SUBMENU:=Network Devices
  TITLE:=aQuantia AQtion(tm) Support
  DEPENDS:=@PCI_SUPPORT @TARGET_x86_64 +kmod-i2c-core +kmod-i2c-algo-bit +kmod-ptp +kmod-phy-aquantia
  KCONFIG:=CONFIG_AQTION
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/aquantia/atlantic/atlantic.ko
  AUTOLOAD:=$(call AutoProbe,atlantic)
endef

define KernelPackage/atlantic/description
 Kernel modules for the aQuantia AQtion(tm) Ethernet card
endef

define Build/Compile
endef

$(eval $(call KernelPackage,phy-aquantia))
$(eval $(call KernelPackage,atlantic))