include $(TOPDIR)/rules.mk

PKG_NAME:=sierra-cm
PKG_VERSION:=SLQS03.03.10.bin
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/CoreWLAN/Components/NBU/LTE-IPQ/$(PKG_NAME)/$(PKG_VERSION)/src
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_VERSION)
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
   SECTION:=utils
   CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
   URL:=http://www.qca.qualcomm.com
   MAINTAINER:=Qualcomm Atheros
   TITLE:=LTE Connection Manager for Sierra
   DEPENDS:=@TARGET_ipq806x||TARGET_ipq_ipq40xx +kmod-sierra-driver
endef

define Package/$(PKG_NAME)/description
   This package contains the LTE Connection Manager for Sierra EM7455
endef

TARGET_CFLAGS += \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/include

TARGET_LDFLAGS += \
	-L$(STAGING_DIR)/lib

MAKE_FLAGS += \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"


define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/SampleApps/QCA_Connection_Manager
	$(CP) $(PKG_BUILD_DIR)/SampleApps/Connection_Manager/* $(PKG_BUILD_DIR)/SampleApps/QCA_Connection_Manager/
	$(CP) ./src/connectionmgr.c $(PKG_BUILD_DIR)/SampleApps/QCA_Connection_Manager/src/
	$(MAKE_FLAGS) \
	make -C $(PKG_BUILD_DIR)/SampleApps MYFLAGS="-l gcc_eh -L$(PKG_BUILD_DIR)/build/lib/arm"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/lib/lte-cm
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/SampleApps/QCA_Connection_Manager/bin/connectionmgrarm \
			$(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/bin/arm/slqssdk $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/sierra-cm $(1)/usr/bin/lte-cm
	$(INSTALL_BIN) ./files/usr/bin/channel_avoidance.sh $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/lte_apn_setup.sh $(1)/usr/bin/
	$(INSTALL_DATA) ./files/etc/config/sierra-cm $(1)/etc/config/
	$(INSTALL_DATA) ./files/usr/lib/lte-cm/lte_channel_table.txt $(1)/usr/lib/lte-cm
endef

$(eval $(call BuildPackage,sierra-cm))
