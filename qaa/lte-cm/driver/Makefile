include $(TOPDIR)/rules.mk

PKG_NAME:=sierra-driver
PKG_VERSION:=S2.25N2.36
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/CoreWLAN/Components/NBU/LTE-IPQ/$(PKG_NAME)/$(PKG_VERSION)/src
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_VERSION)
include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define KernelPackage/$(PKG_NAME)
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:=Kernel gobi drivers for Sierra Connection Manager
  DEPENDS:=@TARGET_ipq806x||TARGET_ipq_ipq40xx +kmod-usb-net +kmod-usb-serial
  FILES:= $(PKG_BUILD_DIR)/GobiNet/GobiNet.ko $(PKG_BUILD_DIR)/GobiSerial/GobiSerial.ko
  AUTOLOAD:=$(call AutoLoad,81,GobiNet GobiSerial)
endef

define KernelPackage/$(PKG_NAME)/description
  This package contains the Sierra gobinet and gobiserial modules for Sierra Connection Manager
endef

MAKE_FLAGS += \
        CROSS_COMPILE="$(TARGET_CROSS)"

define Build/Compile
	$(MAKE_FLAGS) \
	make -C $(PKG_BUILD_DIR)/GobiNet/ KDIR=$(LINUX_DIR) ARCH=$(LINUX_KARCH)
	$(MAKE_FLAGS) \
	make -C $(PKG_BUILD_DIR)/GobiSerial/ KDIR=$(LINUX_DIR) ARCH=$(LINUX_KARCH)
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
