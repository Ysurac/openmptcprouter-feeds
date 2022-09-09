include $(TOPDIR)/rules.mk

PKG_NAME:=libwifisoncfg
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

WIFI_OPEN:=PACKAGE_kmod-mac80211
WIFI_10_4_U:=PACKAGE_kmod-qca-wifi-10.4-unified-profile
WIFI_10_4_A:=PACKAGE_kmod-qca-wifi-10.4-akronite-perf
WIFI_10_4_D:=PACKAGE_kmod-qca-wifi-10.4-dakota-perf
WIFI_10_4_MIPS:=PACKAGE_kmod-qca-wifi-10.4-perf
WIFI_10_4_MIPS_UNIFIED:=PACKAGE_kmod-qca-wifi-10.4-unified-perf
WIFI_10_2_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_11_0_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_11_0_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_11_0_A:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_11_0_D:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_11_0_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_11_0_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_11_0_ARM:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_11_0_MIPS_UNIFIED:=PACKAGE_kmod-qca-wifi-unified-perf
WIFI_11_0_LOWMEM:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_11_0_16M:=PACKAGE_kmod-qca-wifi-flash_16mb-profile
PKG_BUILD_DEPENDS:=$(WIFI_11_0_U):qca-wifi $(WIFI_11_0_C):qca-wifi $(WIFI_11_0_A):qca-wifi $(WIFI_11_0_D):qca-wifi \
        $(WIFI_11_0_MIPS):qca-wifi $(WIFI_11_0_ARM):qca-wifi $(WIFI_11_0_MIPS):qca-wifi \
        $(WIFI_11_0_MIPS_UNIFIED):qca-wifi $(WIFI_11_0_LOWMEM):qca-wifi $(WIFI_11_0_16M):qca-wifi \
        $(WIFI_10_4_U):qca-wifi-10.4 $(WIFI_10_4_A):qca-wifi-10.4 $(WIFI_10_4_D):qca-wifi-10.4 $(WIFI_10_4_MIPS):qca-wifi-10.4 \
        $(WIFI_10_4_MIPS_UNIFIED):qca-wifi-10.4 $(WIFI_10_2_MIPS):qca-wifi $(WIFI_10_2_ARM):qca-wifi $(WIFI_OPEN):mac80211

LIBWIFISONCFG_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

define Package/libwifisoncfg
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=Libwifisoncfg Library
  DEPENDS:= +qca-cfg80211 +libhyficommon +libnl $(LIBWIFISONCFG_DEPENDS)
  SUBMENU:=Lib WiFi-SON Configuration
endef

define Package/libwifisoncfg/config
  source "$(SOURCE)/Config.in"
endef

define Package/libwifisoncfg/description
  This Package contains the WiFi-SON Configuration layer support
endef

define Package/libwifisoncfg/install
	$(INSTALL_DIR) $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/install/lib/libwifisoncfg.so $(1)/usr/lib/
endef

ifeq ($(CONFIG_WIFISON_SUPPORT_QSDK),y)
TARGET_CFLAGS += \
		 -I$(STAGING_DIR)/usr/include/ \
		 -I$(STAGING_DIR)/usr/include/libxml2 \
		 -I$(STAGING_DIR)/usr/include/libnl \
		 -I$(STAGING_DIR)/usr/lib/ \
		 -D_GNU_SOURCE=1 -D__USE_GNU=1 -D__WIN__=1

TARGET_LDFLAGS += \
		  -lnl-3 -lnl-genl-3 -lxml2

WIFISON_CFG_MAKEOPTS:= \
        TOOLPREFIX=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/include/ \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
	EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
	EXTRA_LDFLAGS="$(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install

ifeq ($(CONFIG_LIBCFG80211_SUPPORT),y)
WIFISON_CFG_MAKEOPTS+=LIBCFG80211_SUPPORT=y
endif


ifeq ($(CONFIG_WIFISON_SUPPORT_QSDK),y)
WIFISON_CFG_MAKEOPTS+=WIFISON_SUPPORT_QSDK=y
endif

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
WIFISON_CFG_MAKEOPTS+=ENABLE_SON_MEMORY_DEBUG=y
WIFISON_CFG_MAKEOPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(WIFISON_CFG_MAKEOPTS))
endef

INSTALL_LIBS:= libwifisoncfg
INSTALL_HEADERS= wlanif_cmn.h
endif

ifeq ($(CONFIG_WIFISON_SUPPORT_ATH10K),y)
ATH10KLDFLAGS+="-lnl-3"
ATH10KLDFLAGS+="-lnl-genl-3"

TARGET_CFLAGS += \
		 -I$(STAGING_DIR)/usr/include/ \
                 -I$(STAGING_DIR)/usr/include/libnl3 \
                 -I$(STAGING_DIR)/usr/include/libnl \
		 -D_GNU_SOURCE=1 -D__USE_GNU=1 -D__WIN__=1

TARGET_LDFLAGS += \
		  -lnl-3 -lnl-genl-3

WIFISON_ATH10K_MAKEOPTS:= \
        TOOLPREFIX=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/include/ \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
	EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
	EXTRA_LDFLAGS="-Wl,--gc-sections $(ATH10KLDFLAGS) $(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install


ifeq ($(CONFIG_WIFISON_SUPPORT_ATH10K),y)
WIFISON_ATH10K_MAKEOPTS+=WIFISON_SUPPORT_ATH10K=y
WIFISON_ATH10K_MAKEOPTS+=SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install
	mkdir -p $(PKG_BUILD_DIR)/install/lib/
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR)/ $(strip $(WIFISON_ATH10K_MAKEOPTS))
endef

INSTALL_LIBS:= libwifisoncfg
INSTALL_HEADERS= wlanif_cmn.h sonlib_cmn.h ieee80211_band_steering_api.h sonlib_ath10k_CommandParser.h
endif


define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/wifisoncfg
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include)
endef

$(eval $(call BuildPackage,libwifisoncfg))
