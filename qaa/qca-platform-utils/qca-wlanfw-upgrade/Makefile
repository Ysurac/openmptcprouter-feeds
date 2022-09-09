include $(TOPDIR)/rules.mk

PKG_NAME:=qca-wlanfw-upgrade
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/qca-wlanfw-upgrade
  TITLE:=QCA Linux Wlan Firmware Upgrade script
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq807x||TARGET_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx||TARGET_ipq60xx_64||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64 +squashfs4
endef

define Package/qca-wlanfw-upgrade/description
  This package contains a wlan firmware upgrade script which can be used
  internally by QCA to update the wlan firmware components like q6 and m3 images.
endef

Build/Compile=true

define Package/qca-wlanfw-upgrade/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/wlanfw-upgrade.sh $(1)/usr/sbin
endef

$(eval $(call BuildPackage,qca-wlanfw-upgrade))
