include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-wifi-fw
PKG_VERSION:=WLAN.BL.3.15-00023-S-1
PKG_FOLDER:=WLAN.BL.3.15
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)$(BUILD_VARIANT)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/cnss_win/santaclara/dev01/$(PKG_FOLDER)/$(PKG_VERSION)/src
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)$(BUILD_VARIANT)-$(PKG_VERSION)
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

PKG_HALPHY_NAME:=halphy
PKG_HALPHY_SOURCE:=qca-wifi-fw-src-component-halphy_tools-$(PKG_VERSION).tgz

define Download/halphy
  FILE:=$(PKG_HALPHY_SOURCE)
  VERSION:=$(PKG_VERSION)
  URL:=$(PKG_SOURCE_URL)
  MD5SUM:=skip
endef
$(eval $(call Download,halphy))

PKG_FW_CMN:=qca-wifi-fw-src-component-cmn-$(PKG_VERSION).tgz
PKG_HALPHY_SOURCE:=qca-wifi-fw-src-component-halphy_tools-$(PKG_VERSION).tgz

define Build/Prepare
	$(TAR) xzvf $(TOPDIR)/dl/$(PKG_FW_CMN) -C $(TOPDIR)/dl
	$(TAR) xzvf $(TOPDIR)/dl/$(PKG_HALPHY_SOURCE) -C $(TOPDIR)/dl
endef

define WifiFirmware
  define Package/$(PKG_NAME)-hw2-10.4-asic
    SECTION:=QCA
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    URL:=http://www.qca.qualcomm.com
    MAINTAINER:=Qualcomm Atheros
    TITLE:=QCA Wifi Firmware$(1)
    DEPENDS:=@TARGET_ipq_ipq806x
    VARIANT:=$(2)
    PKGARCH:=all
  endef

  define Package/$(PKG_NAME)-hw4-10.4-asic
    SECTION:=QCA
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    URL:=http://www.qca.qualcomm.com
    MAINTAINER:=Qualcomm Atheros
    TITLE:=QCA Wifi Firmware$(1)
    VARIANT:=$(2)
    PKGARCH:=all
  endef

  define Package/$(PKG_NAME)-hw5-10.4-asic
    SECTION:=QCA
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    URL:=http://www.qca.qualcomm.com
    MAINTAINER:=Qualcomm Atheros
    TITLE:=QCA Wifi Firmware$(1)
    DEPENDS:=@TARGET_ipq_ipq40xx
    VARIANT:=$(2)
    PKGARCH:=all
  endef

  define Package/$(PKG_NAME)-hw11-10.4-asic
    SECTION:=QCA
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    URL:=http://www.qca.qualcomm.com
    MAINTAINER:=Qualcomm Atheros
    TITLE:=QCA Wifi Firmware$(1)
    DEPENDS:=@TARGET_ipq_ipq40xx||TARGET_ipq_ipq806x
    VARIANT:=$(2)
    PKGARCH:=all
  endef

  define Package/$(PKG_NAME)$(1)/description
    This package contains the qca-wifi firmware used in 10.x drivers
  endef

  define Package/$(PKG_NAME)$(1)/install
	$(INSTALL_DIR) $$(1)/lib/firmware/$(3)
	$(HOST_TAR) jxvf $(DL_DIR)/$(PKG_SOURCE) -C $$(1)/lib/firmware/$(3) --strip-components=1
  endef


 $$(eval $$(call BuildPackage,$(PKG_NAME)$(1)))

endef

Build/Compile=true

$(eval $(call WifiFirmware,-hw2-10.4-asic,-AR900B_hw_2,AR900B/hw.2))
$(eval $(call WifiFirmware,-hw4-10.4-asic,-QCA9984_hw_1,QCA9984/hw.1))
$(eval $(call WifiFirmware,-hw5-10.4-asic,-IPQ4019_hw_1,IPQ4019/hw.1))
$(eval $(call WifiFirmware,-hw11-10.4-asic,-QCA9888_hw_2,QCA9888/hw.2))
