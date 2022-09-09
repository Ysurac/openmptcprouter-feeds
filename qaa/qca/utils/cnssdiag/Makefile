include $(TOPDIR)/rules.mk

PKG:=cnssdiag
PKG_NAME:=$(PKG)

LOCAL_SRC:=$(TOPDIR)/qca/src/common-tools
include $(INCLUDE_DIR)/local-development.mk


PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:= QCA cnssdiag utils
  DEPENDS:=+TARGET_ipq50xx:qca-diag +TARGET_ipq60xx:qca-diag +TARGET_ipq807x:qca-diag +TARGET_ipq_ipq807x:qca-diag +TARGET_ipq_ipq807x_64:qca-diag +TARGET_ipq_ipq60xx:qca-diag +TARGET_ipq_ipq60xx_64:qca-diag +TARGET_ipq_ipq50xx:qca-diag +TARGET_ipq_ipq50xx_64:qca-diag +libnl
endef

#MAKEOPTS+= \
	$(TARGET_CONFIGURE_OPTS) \
	COPTS="$(TARGET_CFLAGS)" \
	ATHEROSPATH=$(STAGING_DIR)/usr/include \
	ATH_SUPPORT_ICM=1 \
	ATH_SUPPORT_SPECTRAL=1 \
	QSDK_SPECTRAL=1
TARGET_CFLAGS += -MMD -O2 -Wall -g -DCNSS_DIAG_PLATFORM_WIN -I. -I$(STAGING_DIR)/usr/include/ -I$(STAGING_DIR)/usr/include/qca-diag -I$(STAGING_DIR)/usr/include/libnl -I$(STAGING_DIR)/usr/include/libnl3 -D_GNU_SOURCE -fpie
TARGET_LDFLAGS += -pie


ifeq ($(CONFIG_TARGET_ipq_ipq40xx),y)
  TARGET_CFLAGS += -DNO_DIAG_SUPPORT
else
  ifeq ($(CONFIG_TARGET_ipq_ipq806x),y)
    TARGET_CFLAGS += -DNO_DIAG_SUPPORT
  else
    TARGET_LDFLAGS += -ldiag -L$(STAGING_DIR)/usr/lib
  endif
endif

ifeq ($(CONFIG_PACKAGE_kmod-ath11k),y)
        TARGET_CFLAGS+=-DWIN_AP_HOST_OPEN=1
        TARGET_LDFLAGS += -lnl-3 -lnl-genl-3
endif

define Package/InstallDev
endef

define Build/Compile
$(MAKE) -C $(PKG_BUILD_DIR)/cnssdiag \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnssdiag/cnss_diag $(1)/usr/sbin
	$(INSTALL_BIN) ./files/cnss_diag.init   $(1)/etc/init.d/cnss_diag
	$(INSTALL_BIN) ./files/cnss_diag.config $(1)/etc/config/cnss_diag
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
