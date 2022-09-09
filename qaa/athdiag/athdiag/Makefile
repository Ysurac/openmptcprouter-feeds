include $(TOPDIR)/rules.mk
PKG:=athdiag
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_BRANCH:=master
PKG_RELEASE:=1

ifeq ($(CONFIG_WIFI_TARGET_WIFI_2_0),y)
export WIFI_TARGET_2_0:=1
endif

include $(INCLUDE_DIR)/local-development.mk
TARGET_LDFLAGS += $(if $(CONFIG_USE_EGLIBC),-lrt) -pie
TARGET_CFLAGS += -fpie -Wall -Werror

include $(INCLUDE_DIR)/package.mk

FW_hw2_asic:=qca-wifi-fw-hw2-10.4-asic

define Package/athdiag
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:= QCA ATHDIAG(athdiag) Driver & tools
  URL:=http://www.qca.qualcomm.com
  PKG_BUILD_DEPENDS+=$(FW_hw2_asic)
endef

define Package/athdiag/description
  athdiag command support for ath10k
endef

define Build/Compile
	CFLAGS="$(TARGET_CFLAGS)" \
	$(MAKE) -C $(PKG_BUILD_DIR)/ \
	TOOLPREFIX="$(TARGET_CROSS)" \
	LIBS="$(TARGET_LDFLAGS)" \
	DL_DIR="$(DL_DIR)" \
	WLAN_TOP=$(PKG_BUILD_DIR) \
	all
endef

define Package/athdiag/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/athdiag $(1)/usr/sbin
	#$(INSTALL_DATA) $(PKG_BUILD_DIR)/testcmd_tlv/Linux/*.so $(1)/lib
endef

$(eval $(call BuildPackage,athdiag))

