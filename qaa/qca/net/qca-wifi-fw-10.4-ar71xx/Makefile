# Copyright (c) 2015 Qualcomm Atheros, Inc..
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-wifi-fw
PKG_VERSION:=WLAN.BL.3.15-00023-S-1
PKG_FOLDER:=WLAN.BL.3.15
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)$(BUILD_VARIANT)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/cnss_win/santaclara/dev01/$(PKG_FOLDER)/$(PKG_VERSION)/src
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)$(BUILD_VARIANT)-$(PKG_VERSION)
include $(INCLUDE_DIR)/package.mk


PKG_CMN_NAME:=fwcommon
PKG_CMN_SOURCE:=qca-wifi-fw-src-component-cmn-$(PKG_VERSION).tgz

define Download/fwcommon
  FILE:=$(PKG_CMN_SOURCE)
  VERSION:=$(PKG_VERSION)
  URL:=$(PKG_SOURCE_URL)
endef
$(eval $(call Download,fwcommon))

PKG_HALPHY_NAME:=halphy
PKG_HALPHY_SOURCE:=qca-wifi-fw-src-component-halphy_tools-$(PKG_VERSION).tgz

define Download/halphy
  FILE:=$(PKG_HALPHY_SOURCE)
  VERSION:=$(PKG_VERSION)
  URL:=$(PKG_SOURCE_URL)
endef
$(eval $(call Download,halphy))

PKG_FW_CMN:=qca-wifi-fw-src-component-cmn-$(PKG_VERSION).tgz
PKG_HALPHY_SOURCE:=qca-wifi-fw-src-component-halphy_tools-$(PKG_VERSION).tgz

define Build/Prepare
	$(TAR) xzvf $(TOPDIR)/dl/$(PKG_FW_CMN) -C $(TOPDIR)/dl
	$(TAR) xzvf $(TOPDIR)/dl/$(PKG_HALPHY_SOURCE) -C $(TOPDIR)/dl
endef

define WifiFirmware
 define Package/$(PKG_NAME)$(1)
    SECTION:=QCA
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    URL:=http://www.qca.qualcomm.com
    MAINTAINER:=Qualcomm Atheros
    TITLE:=QCA Wifi Firmware$(1)
    DEPENDS:=@TARGET_ar71xx
    VARIANT:=$(2)
    PKGARCH:=all
  endef

  define Package/$(PKG_NAME)$(1)/description
    This package contains the qca-wifi firmware used in 10.x drivers
  endef

  define Package/$(PKG_NAME)-hw7-10.4-asic/install
	$(INSTALL_DIR) $$(1)/lib/firmware/$(3)
	$(HOST_TAR) jxvf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/.filenames $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.codeswap.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_AR900B_CUS239_5G_v2_001.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_AR900B_CUS260_2G_v2_002.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boarddata_0.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boarddata_1.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/otp.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.codeswap.bin $$(1)/lib/firmware/$(3)
  endef

  define Package/$(PKG_NAME)-hw8-10.4-asic/install
	$(INSTALL_DIR) $$(1)/lib/firmware/$(3)
	$(HOST_TAR) jxvf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.codeswap.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/otp.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boarddata_0.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.codeswap.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_1_0_QCA9888_5G_Y9484.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_1_0_QCA9888_5G_Y9582.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_1_0_QCA9888_5G_Y9690.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_1_0_QCA9888_5G_Y9484_Y.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_1_0_QCA9888_5G_Y9582_Y.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_1_0_QCA9888_5G_Y9690_Y.bin $$(1)/lib/firmware/$(3)
  endef

  define Package/$(PKG_NAME)-hw9-10.4-asic/install
	$(INSTALL_DIR) $$(1)/lib/firmware/$(3)
	$(HOST_TAR) jxvf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/.filenames $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.codeswap.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/otp.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boarddata_0.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boarddata_1.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_QCA9984_CUS238_5G_v1_003.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_QCA9984_CUS239_5G_v1_001.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_QCA9984_CUS240_2G_v1_004.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_QCA9984_CUS260_2G_v1_002.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_QCA9986_CAS05_3x3_80M_5G_v1_015.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_QCA9988_CAS04_4x4_80M_5G_v1_016.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.codeswap.bin $$(1)/lib/firmware/$(3)
  endef

  define Package/$(PKG_NAME)-hw10-10.4-asic/install
	$(INSTALL_DIR) $$(1)/lib/firmware/$(3)
	$(HOST_TAR) jxvf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/athwlan.codeswap.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/otp.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boarddata_0.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boarddata_1.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/utf.codeswap.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_2_0_QCA9888_5G_Y9484.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_2_0_QCA9888_5G_Y9582.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_2_0_QCA9888_5G_Y9690.bin $$(1)/lib/firmware/$(3)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/boardData_2_0_QCA9888_5G_YA105.bin $$(1)/lib/firmware/$(3)
  endef


 $$(eval $$(call BuildPackage,$(PKG_NAME)$(1)))

endef

Build/Compile=true

$(eval $(call WifiFirmware,-hw7-10.4-asic,-AR900B_hw_2,AR900B/hw.2))
$(eval $(call WifiFirmware,-hw9-10.4-asic,-QCA9984_hw_1,QCA9984/hw.1))
$(eval $(call WifiFirmware,-hw10-10.4-asic,-QCA9888_hw_2,QCA9888/hw.2))
