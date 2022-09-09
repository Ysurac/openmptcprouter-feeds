
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-time-services
PKG_SOURCE_PROTO:=git
PKG_BRANCH:=master
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_VERSION:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
endif
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/qca-time-services
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:=QCA Time Services software
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq807x||TARGET_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx \
	   +libpthread +qca-qmi-framework
endef

define Package/qca-time-services/Description
  This packages is responsible to sync the time between Q6 and APSS
endef

TARGET_LDFLAGS += -lqmi_common_so -lqmi_cci
define Package/qca-time-services/install
	mkdir -p $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/time-services-app $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,qca-time-services))
