include $(TOPDIR)/rules.mk

PKG:=ath11k-qdss
PKG_NAME:=$(PKG)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64
  TITLE:=QCA ath11k qdss configuration binary
endef

define Package/ath11k-qdss/description
  This Package contains ath11k qdss configuration binary
endef

Build/Compile=true

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_BIN) ./files/qdss_trace_config.bin $(1)/lib/firmware
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
