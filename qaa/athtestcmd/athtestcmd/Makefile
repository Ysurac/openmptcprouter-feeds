
include $(TOPDIR)/rules.mk
PKG:=athtestcmd
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_BRANCH:=master
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk

include $(INCLUDE_DIR)/package.mk

define Package/athtestcmd
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:= QCA TLVCMD(athtestcmd) Driver & tools
  DEPENDS:=+librt +libnl-tiny
  URL:=http://www.qca.qualcomm.com
  VARIANT:=ath10k
endef

define Package/athtestcmd/description
  athtestcmd command support for ath10k
endef

define Package/athtestcmd-lith
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:= QCA TLVCMD(qcatestcmd) Driver & tools
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq807x||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq60xx||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64
  URL:=http://www.qca.qualcomm.com
  VARIANT:=lithium
endef

define Package/athtestcmd-lith/description
  qcatestcmd command support for lithium
endef

define Package/athtestcmd-lith-nl
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:= QCA TLVCMD(qcatestcmd) Driver & tools
  DEPENDS:=@TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq_ipq50xx||TARGET_ipq_ipq50xx_64 +libnl +libtcmd
  URL:=http://www.qca.qualcomm.com
  VARIANT:=lithium-netlink
endef

define Package/athtestcmd-lith-nl/description
  qcatestcmd command support for lithium-netlink
endef

ifeq ($(BUILD_VARIANT),ath10k)
TARGET_CPPFLAGS += \
        -I$(STAGING_DIR)/usr/include/libnl-tiny
endif

ifeq ($(BUILD_VARIANT),lithium-netlink)
export $(BUILD_VARIANT)
endif

define Build/Compile/lithium-netlink
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR)/lithium/tools/testcmd \
	-f makefile.linux \
	TOOLPREFIX="$(TARGET_CROSS)" \
	LIBS="$(TARGET_LDFLAGS)" \
	WLAN_TOP=$(PKG_BUILD_DIR)/$(BUILD_VARIANT)
endef

define Build/Compile/lithium
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR)/lithium/tools/testcmd \
	-f makefile.linux \
	TOOLPREFIX="$(TARGET_CROSS)" \
	LIBS="$(TARGET_LDFLAGS)" \
	WLAN_TOP=$(PKG_BUILD_DIR)/$(BUILD_VARIANT)
endef

define Build/Compile/ath10k
	CFLAGS="$(TARGET_CPPFLAGS) $(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR)/ath10k/testcmd_tlv \
	TOOLPREFIX="$(TARGET_CROSS)" \
	LIBS="$(TARGET_LDFLAGS)" \
	WLAN_TOP=$(PKG_BUILD_DIR)/$(BUILD_VARIANT) \
	all
endef

define Build/Compile
	$(Build/Compile/$(BUILD_VARIANT))
endef

define Package/athtestcmd/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ath10k/testcmd_tlv/Linux/athtestcmd $(1)/usr/sbin
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ath10k/testcmd_tlv/Linux/*.so $(1)/lib
endef

define Package/athtestcmd-lith/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lithium/tools/testcmd/Linux/qcatestcmd $(1)/usr/sbin
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/lithium/tools/testcmd/Linux/*.so $(1)/usr/lib
endef

define Package/athtestcmd-lith-nl/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lithium/tools/testcmd/Linux/qcatestcmd $(1)/usr/sbin
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/lithium/tools/testcmd/Linux/*.so $(1)/usr/lib
endef

$(eval $(call BuildPackage,athtestcmd))
$(eval $(call BuildPackage,athtestcmd-lith))
$(eval $(call BuildPackage,athtestcmd-lith-nl))

