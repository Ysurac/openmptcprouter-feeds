include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-hyd
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
PKG_REV:=4ce25fc
PKG_VERSION:=g4ce25fc
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(BUILD_VARIANT)$(PKG)_$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

WIFI_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_A:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_D:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_MIPS_UNIFIED:=PACKAGE_kmod-qca-wifi-unified-perf
WIFI_10_2_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_L:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_16M:=PACKAGE_kmod-qca-wifi-flash_16mb-profile
QCA_PLC:=PACKAGE_qca-plc-serv
WIFI_10_2_ARM:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_PKGS:=$(WIFI_U)||$(WIFI_C)||$(WIFI_A)||$(WIFI_D)||$(WIFI_MIPS)||$(WIFI_MIPS_UNIFIED)||$(WIFI_10_2_MIPS)||$(WIFI_10_2_ARM)||$(WIFI_L)||$(WIFI_16M)
PKG_BUILD_DEPENDS:=$(WIFI_U):qca-wifi $(WIFI_C):qca-wifi $(WIFI_A):qca-wifi $(WIFI_D):qca-wifi $(WIFI_MIPS):qca-wifi $(WIFI_L):qca-wifi $(WIFI_16M):qca-wifi \
	$(WIFI_MIPS_UNIFIED):qca-wifi $(WIFI_10_2_MIPS):qca-wifi $(WIFI_10_2_ARM):qca-wifi +qca-ssdk

TARGET_CFLAGS += \
        -I$(STAGING_DIR)/usr/include/plcserv/

TARGET_CFLAGS += -fpie
TARGET_LDFLAGS += -pie

QCAHYD_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        HYTOP=$(PKG_BUILD_DIR) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
        ATHDIR=$(STAGING_DIR)/usr/include \
        PLCSRV=$(STAGING_DIR)/usr/include/plcserv \
        HYFIDIR=$(STAGING_DIR)/usr/include/hyfibr \
        HYFIMCDIR=$(STAGING_DIR)/usr/include/hyfibr \
        HYFIBRLIBDIR=$(STAGING_DIR)/usr/include/libhyfibr \
        IEEE1905DIR=$(STAGING_DIR)/usr/include/ieee1905 \
        WPA2INCLUDE=$(STAGING_DIR)/usr/include/wpa2 \
        QCASSDKDIR=$(STAGING_DIR)/usr/include/qca-ssdk \
        QCACFLAGS="$(TARGET_CFLAGS)" \
        QCALDFLAGS="-Wl,--gc-sections $(TARGET_LDFLAGS)" \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        KERNELVERSION=$(LINUX_VERSION) \
        STAGING_DIR=$(STAGING_DIR) \
        ARCH="$(ARCH)"

ifneq ($(CONFIG_SUPPORT_WIFISON_EXT_LIB),)
QCAHYD_MAKE_OPTS+= \
	SONEVENTINCLUDE=$(STAGING_DIR)/usr/include/qca-wifison-ext-lib \
	HYD_MODULE_SONEVENT=y
endif

ifneq ($(CONFIG_HYD_SUPPORT_CFG80211),)
QCAHYD_MAKE_OPTS+= \
	LIBCFG80211_SUPPORT=y
endif

ifneq ($(CONFIG_HYD_GIGABIT_ETHERNET),)
QCAHYD_MAKE_OPTS+= \
	HYBRID_ETH_SPEED=1000
endif

ifneq ($(CONFIG_PACKAGE_qca-plc-serv),)
QCAHYD_MAKE_OPTS+= \
	HYD_MODULE_PLC=y
endif

ifneq ($(CONFIG_HYD_FAST_ETHERNET),)
QCAHYD_MAKE_OPTS+= \
	HYBRID_ETH_SPEED=100
endif

ifeq ($(CONFIG_PACKAGE_qca-vhyfid),y)
QCAHYD_MAKE_OPTS+= \
	GATEWAY_PROFILE_VHYFI=y
endif

ifeq ($(CONFIG_HYD_WIFI_LOAD_BALANCING),y)
QCAHYD_MAKE_OPTS+= \
	WHCWLBDIR=$(STAGING_DIR)/usr/include/whc-wlb \
	HYD_MODULE_WLB=y
endif

ifeq ($(CONFIG_HYD_SUPPORT_VHT160),y)
QCAHYD_MAKE_OPTS+= \
	HYD_SUPPORT_VHT160=y
endif

ifneq ($(CONFIG_HYD_SUPPORT_CALLTRACE),)
RSTRIP:=:
STRIP:=:
QCAHYD_MAKE_OPTS+= \
	CALLTRACE_SUPPORT=y
endif

ifeq ($(CONFIG_HYD_SUPPORT_BREAKPAD),y)
QCAHYD_MAKE_OPTS+=QCACFLAGS+=" -DINCLUDE_BREAKPAD -g3"
QCAHYD_MAKE_OPTS+=QCALDFLAGS+=" -lbreakpad_qcawrapper"
endif

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
QCAHYD_MAKE_OPTS+= \
	ENABLE_SON_MEMORY_DEBUG=y \
	SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

ifneq ($(CONFIG_PACKAGE_qca-mad),)
QCAHYD_MAKE_OPTS+= \
	HYD_SUPPORT_DESERVICE=y
endif
ifneq ($(CONFIG_HYD_DPP_ONBOARD_ENABLE),)
QCAHYD_MAKE_OPTS+= \
       MAP_SUPPORT_DPP_ENABLE=y
endif


QCAHYD_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

__busybox_have_default:=$(shell $(SH_FUNC) grep '^CONFIG_BUSYBOX_DEFAULT_HAVE_DOT_CONFIG' $(TOPDIR)/.config)
ifeq ($(__busybox_have_default),)
BUSYBOX_SYM:=CONFIG
else
BUSYBOX_SYM:=DEFAULT
endif

LOCAL_VARIANT=$(patsubst qca-hyd-%,%,$(patsubst qca-hyd-%,%,$(BUILD_VARIANT)))

ifeq ($(LOCAL_VARIANT),all)
QCAHYD_MAKE_OPTS+= \
	ENABLE_SON=y \
	ENABLE_MAP=y
endif

ifeq ($(LOCAL_VARIANT),son)
QCAHYD_MAKE_OPTS+= \
	ENABLE_SON=y
endif

ifeq ($(LOCAL_VARIANT),map)
QCAHYD_MAKE_OPTS+= \
	ENABLE_MAP=y
endif

ifeq ($(LOCAL_VARIANT),init)
QCAHYD_MAKE_OPTS+= \
	ENABLE_SON=y \
	ENABLE_MAP=y
endif

ifeq ($(LOCAL_VARIANT),plc)
QCAHYD_MAKE_OPTS+= \
	ENABLE_SON=y \
	ENABLE_MAP=y
endif

ifeq ($(LOCAL_VARIANT),sonplc)
QCAHYD_MAKE_OPTS+= \
	ENABLE_SON=y
endif

INSTALL_LIBS:= libpluginManager libpsService libmcfwdtblwlan5g libmcfwdtblwlan2g libmcfwdtblwlan6g libmcfwdtbleswitch

define Package/qca-hyd/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  DEPENDS+=+HYD_SUPPORT_CALLTRACE:libunwind @$(WIFI_PKGS) +qca-ieee1905-init +kmod-qca-hyfi-bridge +qca-libhyfi-bridge +libieee1905 +libubus +libubox \
	   +qca-hyctl +libhyficommon +SUPPORT_WIFISON_EXT_LIB:qca-wifison-ext-lib +libwifisoncfg +libpthread +libuci +libwpa2 +@BUSYBOX_$(BUSYBOX_SYM)_STAT \
	   +@BUSYBOX_$(BUSYBOX_SYM)_FEATURE_STAT_FORMAT +HYD_WIFI_LOAD_BALANCING:qca-whc-lbd \
	   +jansson +HYD_SUPPORT_BREAKPAD:breakpad-wrapper $(QCAHYD_DEPENDS)
  TITLE:=Hy-Fi Path-Selection daemon
  SUBMENU:=Hy-Fi features
endef

define Package/qca-hyd/Default/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(if $(INSTALL_LIBS),$(CP) $(foreach lib,$(INSTALL_LIBS),$(PKG_BUILD_DIR)/install/lib/$(lib).so) $(1)/usr/lib)
	$(INSTALL_BIN) ./files/hyt $(1)/usr/sbin/hyt
	$(INSTALL_CONF) ./files/hyd.config $(1)/etc/config/hyd
ifeq ($(LINUX_VERSION),3.3.8)
	$(INSTALL_BIN) ./files/hyd_noprocd.init $(1)/etc/init.d/hyd
else
	$(INSTALL_BIN) ./files/hyd.init $(1)/etc/init.d/hyd
endif
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./files/hyd.hotplug $(1)/etc/hotplug.d/net/30-hyd
endef

# HYD COMMON

define Package/qca-hyd-init
	$(call Package/qca-hyd/Default)
	TITLE+= (Common package files)
	VARIANT:=init
endef

define Package/qca-hyd-init/description
	This package installs the Hy-Fi Path-Selection daemon init package files for SON and MAP execution
	support.
endef


# SINGLE PACKAGE (MAP + SON) =============================

define Package/qca-hyd
	$(call Package/qca-hyd/Default)
	TITLE+= (with SON and MAP features)
	VARIANT:=all
endef

define Package/qca-hyd/description
	This package installs the Hy-Fi Path-Selection daemon build with both SON and MAP features
endef

define Package/qca-hyd/config
	source "$(SOURCE)/Config.in"
endef

# SON PACKAGE =============================

define Package/qca-hyd-son
	$(call Package/qca-hyd/Default)
	DEPENDS+=+qca-hyd-init
	TITLE+= (with SON features)
	VARIANT:=son
endef

define Package/qca-hyd-son/description
	This package installs the Hy-Fi Path-Selection daemon build with SON
endef

# MAP PACKAGE =============================

define Package/qca-hyd-map
	$(call Package/qca-hyd/Default)
	DEPENDS+=+qca-hyd-init
	TITLE+= (with MAP features)
	VARIANT:=map
endef

define Package/qca-hyd-map/description
	This package installs the Hy-Fi Path-Selection daemon build with MAP
endef

# HYD PLC SON PACKAGE

define Package/qca-hyd-sonplc
	$(call Package/qca-hyd/Default)
	DEPENDS+=+qca-hyd-init +qca-plc-serv
	TITLE+= (with SON and PLC features)
	VARIANT:=sonplc
endef

define Package/qca-hyd-sonplc/description
	This package installs the Hy-Fi Path-Selection daemon build with SON and PLC features
endef

# HYD SON + MAP + PLC PACKAGE

define Package/qca-hyd-plc
	$(call Package/qca-hyd/Default)
	DEPENDS+=+qca-plc-serv
	TITLE+= (with SON/MAP and PLC features)
	VARIANT:=plc
endef

define Package/qca-hyd-plc/description
	This package installs the Hy-Fi Path-Selection daemon build with SON/MAP and PLC
	support.
endef

# qca-wifison-ext-lib package

define Package/qca-wifison-ext-lib
	$(call Package/qca-hyd/Default)
	DEPENDS+=+SUPPORT_WIFISON_EXT_LIB:qca-wifison-ext-lib
endef

QCA_HYD_HEADERS= \
                $(PKG_BUILD_DIR)/include/heServiceConfig.h   \
                $(PKG_BUILD_DIR)/include/logServiceConfig.h  \
                $(PKG_BUILD_DIR)/include/pcpServiceConfig.h  \
                $(PKG_BUILD_DIR)/include/pcwServiceConfig.h  \
                $(PKG_BUILD_DIR)/include/psServiceConfig.h   \
                $(PKG_BUILD_DIR)/include/tdServiceConfig.h   \
                $(PKG_BUILD_DIR)/include/wlanManagerConfig.h \
                $(PKG_BUILD_DIR)/include/hcpConfig.h \
                $(PKG_BUILD_DIR)/include/ieee1905Config.h

ifneq ($(shell [ -d $(LOCAL_SRC) ] && echo true),)
define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/hyd
	$(foreach header_file,$(QCA_HYD_HEADERS), $(CP) $(header_file) $(1)/usr/include/hyd;)
endef
endif


define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/lib
	mkdir -p $(PKG_BUILD_DIR)/install/include
	mkdir -p $(PKG_BUILD_DIR)/install/sbin
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCAHYD_MAKE_OPTS)) subdirs
endef

# install

define Package/qca-hyd/install
	$(call Package/qca-hyd/Default/install, $(1))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/hyd $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/hyd-map-cmd $(1)/usr/sbin/hyd-map-cmd
endef

define Package/qca-hyd-plc/install
	$(call Package/qca-hyd/Default/install, $(1))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/hyd $(1)/usr/sbin/
endef

define Package/qca-hyd-son/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/hyd-son $(1)/usr/sbin/
endef

define Package/qca-hyd-map/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/hyd/map/
	$(INSTALL_BIN) ./files/hyd-map-cmd $(1)/usr/sbin/hyd-map-cmd
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/hyd-map $(1)/usr/sbin/
	$(INSTALL_CONF) ./files/sp-rules.conf $(1)/etc/hyd/map/
endef

define Package/qca-hyd-sonplc/install
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/hyd-son $(1)/usr/sbin/
endef

define Package/qca-hyd-init/install
	$(call Package/qca-hyd/Default/install, $(1))
endef



# Customer install - TBD

$(eval $(call BuildPackage,qca-hyd))
$(eval $(call BuildPackage,qca-hyd-plc))
$(eval $(call BuildPackage,qca-hyd-son))
$(eval $(call BuildPackage,qca-hyd-map))
$(eval $(call BuildPackage,qca-hyd-sonplc))
$(eval $(call BuildPackage,qca-hyd-init))
