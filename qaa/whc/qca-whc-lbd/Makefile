include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-whc-lbd
PKG_SOURCE_PROTO:=git
PKG_BRANCH:=whc/banana
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_VERSION:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
endif


include $(INCLUDE_DIR)/package.mk

WIFI_OPEN:=PACKAGE_kmod-mac80211
WIFI_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_A:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_D:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_10_2_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_10_2_ARM:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_MIPS_UNIFIED:=PACKAGE_kmod-qca-wifi-unified-perf
WIFI_L:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_16M:=PACKAGE_kmod-qca-wifi-flash_16mb-profile
WIFI_PKGS:=$(WIFI_U)||$(WIFI_C)||$(WIFI_A)||$(WIFI_D)||$(WIFI_MIPS)||$(WIFI_10_2_MIPS)||$(WIFI_10_2_ARM)||$(WIFI_MIPS_UNIFIED)||$(WIFI_OPEN)||$(WIFI_L)||$(WIFI_16M)

PKG_BUILD_DEPENDS:=$(WIFI_U):qca-wifi $(WIFI_C):qca-wifi $(WIFI_A):qca-wifi $(WIFI_D):qca-wifi \
	$(WIFI_10_2_MIPS):qca-wifi $(WIFI_10_2_ARM):qca-wifi $(WIFI_MIPS):qca-wifi \
	$(WIFI_MIPS_UNIFIED):qca-wifi $(WIFI_L):qca-wifi $(WIFI_16M):qca-wifi libhyficommon libieee1905

ifeq ($(CONFIG_LBD_SUPPORT_ATH10K),y)
TARGET_LDFLAGS+="-lnl-3"
TARGET_LDFLAGS+="-lnl-genl-3"

TARGET_CFLAGS+=-I$(STAGING_DIR)/usr/include/libnl3
endif


TARGET_CFLAGS += -fpie
TARGET_LDFLAGS += -pie

QCAWHCLBD_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        LBTOP=$(PKG_BUILD_DIR) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
        IEEE1905DIR=$(STAGING_DIR)/usr/include/ieee1905 \
        ATHDIR=$(STAGING_DIR)/usr/include \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        QCACFLAGS="$(TARGET_CFLAGS)"\
        QCALDFLAGS="-Wl,--gc-sections $(TARGET_LDFLAGS)"\
        KERNELVERSION=$(LINUX_VERSION) \
        STAGING_DIR=$(STAGING_DIR) \
	ARCH="$(ARCH)"

ifeq ($(CONFIG_LBD_SUPPORT_QSDK),y)
ifneq ($(CONFIG_PACKAGE_qca-wifison-ext-lib),)
QCAWHCLBD_MAKE_OPTS+=SONEVENTINCLUDE=$(STAGING_DIR)/usr/include/qca-wifison-ext-lib
QCAWHCLBD_MAKE_OPTS+=LBD_MODULE_SONEVENT=y
endif
endif

ifeq ($(CONFIG_LBD_SUPPORT_VHT160),y)
QCAWHCLBD_MAKE_OPTS+=LBD_SUPPORT_VHT160=y
endif

ifeq ($(CONFIG_LBD_SUPPORT_CFG80211),y)
QCAWHCLBD_MAKE_OPTS+=LBD_SUPPORT_CFG80211=y
endif

ifeq ($(CONFIG_LBD_SUPPORT_ATH10K),y)
QCAWHCLBD_MAKE_OPTS+=LBD_SUPPORT_ATH10K=y
endif

ifeq ($(CONFIG_LBD_SUPPORT_QSDK),y)
QCAWHCLBD_MAKE_OPTS+=LBD_SUPPORT_QSDK=y
endif

ifneq ($(CONFIG_LBD_SUPPORT_CALLTRACE),)
RSTRIP:=:
STRIP:=:
QCAWHCLBD_MAKE_OPTS += CALLTRACE_SUPPORT=y
endif

QCAWHCLBD_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
QCAWHCLBD_MAKE_OPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
QCAWHCLBD_MAKE_OPTS+=ENABLE_SON_MEMORY_DEBUG=y
endif

define Package/qca-whc-lbd/config
  source "$(SOURCE)/Config.in"
endef

define Package/qca-whc-lbd
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  DEPENDS=+LBD_SUPPORT_CALLTRACE:libunwind +qca-whc-init +libhyficommon +libpthread +@BUSYBOX_CONFIG_STAT \
	   +@BUSYBOX_CONFIG_FEATURE_STAT_FORMAT \
	   @$(WIFI_PKGS) +jansson +$(WIFI_OPEN):libnl \
	   +libwifisoncfg +SUPPORT_WIFISON_EXT_LIB:qca-wifison-ext-lib +libieee1905 \
	   $(QCAWHCLBD_DEPENDS)
  TITLE:=Whole Home Coverage Load Balancing daemon
  SUBMENU:=Whole Home Coverage features
endef

ifeq ($(CONFIG_LBD_SUPPORT_QSDK),y)
define Package/qca-wifison-ext-lib
  $(call Package/qca-whc-lbd)
  DEPENDS+=+SUPPORT_WIFISON_EXT_LIB:qca-wifison-ext-lib
endef
endif

define Package/qca-whc-lbd/description
  This package installs the Whole Home Coverage Load Balancing daemon
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/lib
	mkdir -p $(PKG_BUILD_DIR)/install/include
	mkdir -p $(PKG_BUILD_DIR)/install/sbin
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCAWHCLBD_MAKE_OPTS)) subdirs
endef

INSTALL_LIBS:= liblbcmnlibs
INSTALL_HEADERS=bandmon.h \
	bandmonCmn.h \
	diaglog.h \
	estimator.h \
	estimatorCmn.h \
	estimatorRCPIToPhyRate.h \
	estimatorInterferenceDetectionCurve.h \
	estimatorPollutionAccumulator.h \
	estimatorCircularBuffer.h \
	lb_assert.h \
	lb_common.h \
	lb_module.h \
	lb_profileSections.h \
	lbd_assert.h \
	lbd_types.h \
	persist.h \
	stadbEntry.h \
	stadb.h  \
	stadbCmn.h  \
	stamon.h \
	stamonCmn.h \
	steeralg.h \
	steeralgCmn.h \
	steerexec.h \
	steerexecImplCmn.h \
	wlanif.h \
	wlanifBSteerControl.h \
	wlanifBSteerControlCmn.h \
	wlanifBSteerEvents.h \
	wlanifLinkEvents.h \
	wlanifLinkEventsCmn.h

ifeq ($(CONFIG_LBD_SUPPORT_QSDK),y)
ifneq ($(CONFIG_PACKAGE_qca-wifison-ext-lib),)
INSTALL_HEADERS+=soneventService.h
endif
endif

define Package/qca-whc-lbd/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(INSTALL_DIR) $(1)/lib/functions/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/lbd $(1)/usr/sbin
	$(INSTALL_BIN) ./files/lbt $(1)/usr/sbin/lbt
	$(INSTALL_CONF) ./files/lbd.config $(1)/etc/config/lbd
ifeq ($(LINUX_VERSION),3.3.8)
	$(INSTALL_BIN) ./files/lbd_noprocd.init $(1)/etc/init.d/lbd
else
	$(INSTALL_BIN) ./files/lbd.init $(1)/etc/init.d/lbd
endif
	$(CP) ./files/lbd-config.sh $(1)/lib/functions/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/whc-wlb
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/whc-wlb)
endef

$(eval $(call BuildPackage,qca-whc-lbd))
