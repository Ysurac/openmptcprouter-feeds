include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-fw2
PKG_BRANCH:=master
PKG_VERSION:=10
PKG_RELEASE:=1
PKG_MD5SUM:=skip

NSS_VER:=11.4
NSS_SOC:=AK
NSS_PROFILE:=R

PKG_SOURCE:=BIN-NSS.$(NSS_SOC).$(NSS_VER)-$(PKG_VERSION)-$(NSS_PROFILE).tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/NSS/NSS.FW/$(NSS_VER)/$(NSS_SOC)/$(PKG_VERSION)/
PKG_BUILD_DIR:=$(BUILD_DIR)/BIN-NSS.$(NSS_SOC).$(NSS_VER)-$(PKG_VERSION)-$(NSS_PROFILE)

include $(INCLUDE_DIR)/package.mk

define NssFirmware

  define Package/qca-nss-fw2-$(1)
    SECTION:=kernel
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    SUBMENU:=Network Devices
    DEPENDS:=@TARGET_ipq806x||TARGET_ipq_ipq806x
    TITLE:=NSS firmware binaries - $(1)
    PROVIDES:=qca-nss-fw2
    MENU:=1
  endef

  define Package/qca-nss-fw2-$(1)/description
  This package contains the NSS firmwares ($(1)) for QTI chipset
  endef

  define Package/qca-nss-fw2-$(1)/install
	$(INSTALL_DIR) $$(1)/lib/firmware/qca
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/$(2)0.bin $$(1)/lib/firmware/qca-nss0-$(1).bin
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/$(2)1.bin $$(1)/lib/firmware/qca-nss1-$(1).bin
  endef
  $$(eval $$(call BuildPackage,qca-nss-fw2-$(1)))
endef

Build/Compile=true

$(eval $(call NssFirmware,retail,retail_router))
