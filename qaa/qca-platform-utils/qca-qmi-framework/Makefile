
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-qmi-framework
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


define Package/qca-qmi-framework
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:=QCA Linux QMI framework software
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq807x||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64||TARGET_ipq50xx \
	   +libpthread
endef

define Package/qca-qmi-framework/Description
  This package contains a Linux qmi framework for the user space
endef

define Package/qca-qrtr
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:=QCA Linux QMI framework software
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq807x||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64||TARGET_ipq50xx \
	   +libpthread
endef

define Package/qca-qrtr/Description
  This package contains a qrtr user space application
endef


TARGET_CFLAGS += \
	-I$(LINUX_DIR)/include/uapi/ \
	-I$(LINUX_DIR)/include/

define Build/InstallDev
	$(INSTALL_DIR) $(1)
	mkdir -p $(1)/usr/include
	mkdir -p $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/inc/*.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/qcci/inc/*.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/common/inc/*.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/lib/*.so $(1)/usr/lib/
endef

define Package/qca-qrtr/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/qrtr/qrtr-cfg $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/qrtr/qrtr-ns $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/qrtr/qrtr-lookup $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/qrtr.init $(1)/etc/init.d/qrtr
endef

define Package/qca-qmi-framework/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lib/libqmi_common_so.so $(1)/usr/lib/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lib/libqmi_cci.so $(1)/usr/lib/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lib/libqmi_qrtr_cci.so $(1)/usr/lib/
endef

$(eval $(call BuildPackage,qca-qrtr))
$(eval $(call BuildPackage,qca-qmi-framework))

define KernelPackage/testssr
  TITLE:=TEST SSR-RPROC driver
  KCONFIG:=CONFIG_IPQ_SUBSYSTEM_RESTART_TEST
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq807x||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64||TARGET_ipq50xx

  FILES:= $(LINUX_DIR)/drivers/soc/qcom/testssr.ko
endef

define KernelPackage/testssr/description
  This driver provides support for the testing of SSR-RPROC.
endef

$(eval $(call KernelPackage,testssr))

define KernelPackage/qmi-test-app
  TITLE:=Add QMI ping_pong test application
  KCONFIG:=CONFIG_MSM_TEST_QMI_CLIENT
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq807x||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64||TARGET_ipq50xx
  FILES:=$(LINUX_DIR)/drivers/soc/qcom/qmi_test.ko
endef

define KernelPackage/qmi-test-app/description
  Add QMI ping_pong test application
endef

$(eval $(call KernelPackage,qmi-test-app))
