
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-wifi-cyp-fw
PKG_VERSION:=IPQ6018-WLAN.HK.2.5.r4-00745-QCAHKSWPL_SILICONZ-1
PKG_RELEASE:=1
PKG_LABEL:=$(shell echo $(PKG_VERSION) | cut -d'-' -f2)
PKG_SPIN:=$(shell echo $(PKG_VERSION) | cut -d'-' -f4)

PKG_SOURCE:=qca-wifi-fw-QCA6018_v1.0-WLAN.HK.2.5.r4-00745-QCAHKSWPL_SILICONZ-1.tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/cnss_win/santaclara/dev01/WLAN.HK.2.2.1/$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
include $(INCLUDE_DIR)/package.mk
PKG_MD5SUM:=skip

PKG_CMN_NAME:=fwcommon
PKG_CMN_SOURCE:=qca-wifi-fw-src-component-cmn-$(PKG_VERSION).tgz

define Download/fwcommon
  FILE:=$(PKG_CMN_SOURCE)
  VERSION:=$(PKG_VERSION)
  URL:=$(PKG_SOURCE_URL)
endef
$(eval $(call Download,fwcommon))

PKG_FW_CMN:=qca-wifi-fw-src-component-cmn-$(PKG_VERSION).tgz

define Build/Prepare
        rm -rf $(TOPDIR)/dl/wlan/$PKG_CMN_NAME
	$(TAR) xzvf $(TOPDIR)/dl/$(PKG_FW_CMN) -C $(TOPDIR)/dl
endef


define WifiFirmware
  define Package/$(PKG_NAME)$(1)
    SECTION:=QCA
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    URL:=http://www.qca.qualcomm.com
    MAINTAINER:=Qualcomm Atheros
    TITLE:=QCA Wifi Firmware$(1)
    DEPENDS:=@TARGET_ipq60xx||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64
    VARIANT:=$(2)
    PKGARCH:=all
  endef

  define Package/$(PKG_NAME)$(1)/description
    This package contains the qca-wifi firmware($(1)) used in 11.x drivers
  endef

  define Package/$(PKG_NAME)-hw1-11.0-asic/install
	true
  endef

  $$(eval $$(call BuildPackage,$(PKG_NAME)$(1)))
endef

Build/Compile=true

$(eval $(call WifiFirmware,-hw1-11.0-asic,-QCACP_hw_1,QCA6018))
