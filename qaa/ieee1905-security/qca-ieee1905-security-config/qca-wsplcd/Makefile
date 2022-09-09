include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-wsplcd
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(BUILD_VARIANT)$(PKG)-$(PKG_VERSION)
include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -fpie
TARGET_LDFLAGS += -pie

WIFI_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_A:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_D:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_MIPS_UNIFIED:=PACKAGE_kmod-qca-wifi-unified-perf
WIFI_10_2_MIPS:=PACKAGE_kmod-qca-wifi-perf
WIFI_10_2_ARM:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_L:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_16M:=PACKAGE_kmod-qca-wifi-flash_16mb-profile
WIFI_PKGS:=$(WIFI_U)||$(WIFI_C)||$(WIFI_A)||$(WIFI_D)||$(WIFI_MIPS)||$(WIFI_MIPS_UNIFIED)||$(WIFI_10_2_MIPS)||$(WIFI_10_2_ARM)||$(WIFI_L)||$(WIFI_16M)
PKG_BUILD_DEPENDS:=$(WIFI_U):qca-wifi $(WIFI_C):qca-wifi $(WIFI_A):qca-wifi $(WIFI_D):qca-wifi $(WIFI_MIPS):qca-wifi \
	$(WIFI_MIPS_UNIFIED):qca-wifi $(WIFI_10_2_MIPS):qca-wifi $(WIFI_10_2_ARM):qca-wifi $(WIFI_L):qca-wifi $(WIFI_16M):qca-wifi

QCAWSPLCD_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        GWINCLUDE=$(STAGING_DIR)/usr/include/hyficommon \
        WPA2INCLUDE=$(STAGING_DIR)/usr/include/wpa2 \
        HYDINCLUDE=$(STAGING_DIR)/usr/include/hyd \
        STORAGEINCLUE=$(STAGING_DIR)/usr/include/storage \
        IEEE1905INCLUDE=$(STAGING_DIR)/usr/include/ieee1905 \
        PLCSRV=$(STAGING_DIR)/usr/include/plcserv \
        ATHDIR=$(STAGING_DIR)/usr/include \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
        EXTRA_LDFLAGS="$(TARGET_LDFLAGS)" \
        LIBSTORAGE_UCI=y \
        ARCH="$(ARCH)"

QCAWSPLCD_DEPENDS:=@$(WIFI_PKGS) +qca-ieee1905-init +libhyficommon +libstorage +libwpa2 +libieee1905 +libuci +libpthread +libwifisoncfg

QCAWSPLCD_DEPENDS+=+ENABLE_SON_MEMORY_DEBUG:qca-son-mem-debug

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
QCAWSPLCD_MAKE_OPTS+= \
	ENABLE_SON_MEMORY_DEBUG=y \
	SONMEMDEBUGINCLUDE=$(STAGING_DIR)/usr/include/son-mem-dbg
endif

ifeq ($(CONFIG_WSPLCD_SUPPORT_PLC),y)
QCAWSPLCD_MAKE_OPTS+= \
	WSPLCD_SUPPORT_PLC=y \
	QCAWSPLCD_DEPENDS+=+qca-plc-serv
endif

ifeq ($(CONFIG_WSPLCD_SUPPORT_CFG80211),y)
QCAWSPLCD_MAKE_OPTS+= \
	WSPLCD_SUPPORT_CFG80211=y
endif

ifneq ($(CONFIG_WSPLCD_SUPPORT_CALLTRACE),)
RSTRIP:=:
STRIP:=:
QCAWSPLCD_MAKE_OPTS+= \
	CALLTRACE_SUPPORT=y
endif

LOCAL_VARIANT=$(patsubst qca-wsplcd-%,%,$(patsubst qca-wsplcd-%,%,$(BUILD_VARIANT)))

ifeq ($(LOCAL_VARIANT),all)
QCAWSPLCD_MAKE_OPTS+= \
	ENABLE_SON=y \
	ENABLE_MAP=y
endif

ifeq ($(LOCAL_VARIANT),son)
QCAWSPLCD_MAKE_OPTS+= \
	ENABLE_SON=y
endif

ifeq ($(LOCAL_VARIANT),map)
QCAWSPLCD_MAKE_OPTS+= \
	ENABLE_MAP=y
endif

ifeq ($(LOCAL_VARIANT),init)
QCAWSPLCD_MAKE_OPTS+= \
	ENABLE_SON=y \
	ENABLE_MAP=y
endif

define Package/qca-wsplcd/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  DEPENDS:=+WSPLCD_SUPPORT_CALLTRACE:libunwind $(QCAWSPLCD_DEPENDS)
  TITLE:=IEEE 1905.1 AP Auto-Configuration daemon
  SUBMENU:=IEEE1905.1 features
endef

define Package/qca-wsplcd/Default/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/ucpkgen $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/etc/athx100.conf $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d
ifeq ($(LINUX_VERSION),3.3.8)
	$(INSTALL_BIN) ./files/wsplcd_no_procd.init $(1)/etc/init.d/wsplcd
else
	$(INSTALL_BIN) ./files/wsplcd.init $(1)/etc/init.d/wsplcd
endif

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/wsplcd.config $(1)/etc/config/wsplcd
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) ./files/uci2cfg.sh $(1)/sbin/uci2cfg.sh
	$(INSTALL_DIR) $(1)/etc/hotplug.d/button
	$(INSTALL_BIN) ./files/wsplcd.button $(1)/etc/hotplug.d/button/40-wsplcd

endef

# COMMON PACKAGE

define Package/qca-wsplcd-init
	$(call Package/qca-wsplcd/Default)
	TITLE+= (Common package files)
	VARIANT:=init
endef

define Package/qca-wsplcd-init/description
	This package installs the IEEE 1905.1 AP Auto-Configuration daemon init package files for SON and MAP execution
endef

define Package/qca-wsplcd-init/config
	source "$(SOURCE)/Config.in"
endef


# SINGLE PACKAGE (SON + MAP)

define Package/qca-wsplcd
	$(call Package/qca-wsplcd/Default)
	TITLE+= (with SON and MAP features)
	VARIANT:=all
endef

define Package/qca-wsplcd/description
	This package installs the IEEE 1905.1 AP Auto-Configuration daemon (SON and MAP): Wi-Fi credential cloning over backbone network (e.g. HomePlugAV, Ethernet, Wi-Fi)
endef

define Package/qca-wsplcd/config
	source "$(SOURCE)/Config.in"
endef

# SON PACKAGE

define Package/qca-wsplcd-son
	$(call Package/qca-wsplcd/Default)
	DEPENDS+=+qca-wsplcd-init
	TITLE+= (with SON features)
	VARIANT:=son
endef

define Package/qca-wsplcd-son/description
	This package installs the IEEE 1905.1 AP Auto-Configuration SON daemon: Wi-Fi credential cloning over backbone network (e.g. HomePlugAV, Ethernet, Wi-Fi)
endef

define Package/qca-wsplcd-son/config
	source "$(SOURCE)/Config.in"
endef

# MAP PACKAGE

define Package/qca-wsplcd-map
	$(call Package/qca-wsplcd/Default)
	DEPENDS+=+qca-wsplcd-init
	TITLE+= (with MAP features)
	VARIANT:=map
endef

define Package/qca-wsplcd-map/description
	This package installs the IEEE 1905.1 AP Auto-Configuration MAP daemon: Wi-Fi credential cloning over backbone network (e.g. HomePlugAV, Ethernet, Wi-Fi)
endef

define Package/qca-wsplcd-map/config
	source "$(SOURCE)/Config.in"
endef

# ============

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/etc
	mkdir -p $(PKG_BUILD_DIR)/install/sbin
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCAWSPLCD_MAKE_OPTS)) install
endef

define Package/qca-wsplcd/install
	$(call Package/qca-wsplcd/Default/install, $(1))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/wsplcd $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/wsplcd/map/templates
	$(INSTALL_CONF) ./files/scheme-*.conf $(1)/etc/wsplcd/map/templates
endef

define Package/qca-wsplcd-son/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/wsplcd-son $(1)/usr/sbin
endef

define Package/qca-wsplcd-map/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/wsplcd-map $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/wsplcd/map/templates
	$(INSTALL_CONF) ./files/scheme-*.conf $(1)/etc/wsplcd/map/templates
endef

define Package/qca-wsplcd-init/install
	$(call Package/qca-wsplcd/Default/install, $(1))
endef

$(eval $(call BuildPackage,qca-wsplcd))
$(eval $(call BuildPackage,qca-wsplcd-son))
$(eval $(call BuildPackage,qca-wsplcd-map))
$(eval $(call BuildPackage,qca-wsplcd-init))
