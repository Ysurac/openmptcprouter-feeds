
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-wifi-hk-fw
PKG_VERSION:=IPQ8074-WLAN.HK.2.5.r4-00745-QCAHKSWPL_SILICONZ-1
PKG_RELEASE:=1
PKG_LABEL:=$(shell echo $(PKG_VERSION) | cut -d'-' -f2)
PKG_SPIN:=$(shell echo $(PKG_VERSION) | cut -d'-' -f4)

PKG_SOURCE:=qca-wifi-fw-QCA8074_v1.0-WLAN.HK.2.5.r4-00745-QCAHKSWPL_SILICONZ-1.tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/cnss_win/santaclara/dev01/WLAN.HK.2.5.r4/$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_MD5SUM:=skip

include $(INCLUDE_DIR)/package.mk

PKG_CMN_NAME:=fwcommon
PKG_CMN_SOURCE:=qca-wifi-fw-src-component-cmn-$(PKG_VERSION).tgz

define Download/fwcommon
  FILE:=$(PKG_CMN_SOURCE)
  VERSION:=$(PKG_VERSION)
  URL:=$(PKG_SOURCE_URL)
  MD5SUM:=skip
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
    DEPENDS:=@!TARGET_ipq_ipq60xx @!TARGET_ipq_ipq60xx_64 @!TARGET_ipq60xx
    VARIANT:=$(2)
    PKGARCH:=all
  endef

  define Package/$(PKG_NAME)$(1)/description
    This package contains the qca-wifi firmware($(1)) used in 10.x drivers
  endef

  define Package/$(PKG_NAME)-hw1-10.4-asic/install
	true
  endef

  $$(eval $$(call BuildPackage,$(PKG_NAME)$(1)))
endef

Build/Compile=true

$(eval $(call WifiFirmware,-hw1-10.4-asic,-QCAHK_hw_1,QCA8074))
