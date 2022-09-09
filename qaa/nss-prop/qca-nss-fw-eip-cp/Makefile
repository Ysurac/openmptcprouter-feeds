include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-fw-eip
PKG_BRANCH:=nss
PKG_VERSION:=2.8.1
PKG_RELEASE:=1
PKG_MD5SUM:=skip

EIP197_VER:=2.8.1

PKG_SOURCE:=BIN-EIP197.CP.$(EIP197_VER).tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/NSS/NSS.FW/EIP197.CP/$(EIP197_VER)
PKG_BUILD_DIR:=$(BUILD_DIR)/BIN-EIP197.CP.$(EIP197_VER)

include $(INCLUDE_DIR)/package.mk

define EIP197Firmware

  define Package/$(PKG_NAME)-$(1)
    SECTION:=kernel
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    SUBMENU:=Network Devices
    DEPENDS:=@TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx
    TITLE:=EIP197 firmware binaries - $(1)
    PROVIDES:=$(PKG_NAME)
    MENU:=1
  endef

  define Package/$(PKG_NAME)-$(1)/description
  This package contains the NSS firmwares ($(1)) for QCA chipset
  endef

  define Package/$(PKG_NAME)-$(1)/install
	$(INSTALL_DIR) $$(1)/lib/firmware/qca
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ifpp.bin $$(1)/lib/firmware/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ipue.bin $$(1)/lib/firmware/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ofpp.bin $$(1)/lib/firmware/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/opue.bin $$(1)/lib/firmware/
  endef
  $$(eval $$(call BuildPackage,$(PKG_NAME)-$(1)))
endef

Build/Compile=true

$(eval $(call EIP197Firmware,cp))
