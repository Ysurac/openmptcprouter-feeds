include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG:=qca-wifi
PKG_NAME:=$(PKG)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://qca-git01.qualcomm.com:29418/wifi/$(PKG_NAME).git
PKG_BRANCH:=master
PKG_RELEASE:=1

DRIVER_PATH:=$(TOPDIR)/qca/src/qca-wifi
# legacy and hawkeye header files.
FW_INCLUDE_PATH:=$(TOPDIR)/dl/include
FW_COMMON_INCLUDE_PATH:=$(TOPDIR)/dl/wlan/fwcommon/include
FW_INTERFACE_TOOLS_PATH:=$(TOPDIR)/dl/wlan/fwcommon/fw_interface/tools/
FW_HDR_INCLUDE_PATH:=$(TOPDIR)/qca/src/qca-wifi/cmn_dev/fw_hdr
HALPHY_TOOLS_PATH:=$(TOPDIR)/dl/wlan/halphy_tools

include $(INCLUDE_DIR)/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
CUSTOM_DIRECTORY?=0
ifeq ($(CUSTOM_DIRECTORY),1)
  PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(BUILD_VARIANT)/$(PKG_NAME)
else
  PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(BUILD_VARIANT)/$(PKG_NAME)-$(PKG_VERSION)
endif
PKG_ASLR_PIE:=0

COPY_TO_BUILD_DIR:=$(shell cp -fpR -u --verbose $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/)
include $(INCLUDE_DIR)/package.mk

FW_10_2_4:=qca-wifi-fw-10.2.4
FW_10_4:=qca-wifi-fw-10.4
FW_HK:=qca-hk
FW_Cyp:=qca-cyp

FW:=$(FW_10_2_4) $(FW_10_4) $(FW_HK) $(FW_Cyp)


ifeq ($(CONFIG_TARGET_ipq_ipq807x_QSDK_Deluxe),y)
export COPY_6290_HEADER:=1
endif

ifeq ($(CONFIG_TARGET_ipq_ipq60xx)$(CONFIG_TARGET_ipq_ipq60xx_64)$(CONFIG_TARGET_ipq60xx),y)
export ENABLE_6018_HEADER:=1
endif

ifeq ($(CONFIG_TARGET_ipq_ipq50xx)$(CONFIG_TARGET_ipq_ipq50xx_64)$(CONFIG_TARGET_ipq50xx),y)
export ENABLE_QCA5018_HEADER:=1
endif

ifeq ($(CONFIG_WHUNT),y)
export CONFIG_WHUNT=1
export QCA_SINGLE_WIFI_3_0=1
endif

ifeq ($(CONFIG_GCC_USE_VERSION_7),y)
export QCA_GCC_7_SUPPORT=1
endif

#Set QCAWLAN_MAKEOPTS according to selected BUILD_VARIANT and platform
ifneq ($(KERNEL_BUILD_DIR),)
export DRIVER_PATH
include $(DRIVER_PATH)/config.mk
endif

#########################################################
############ WLAN DRIVER BUILD CONFIGURATION ############
#########################################################

ifeq ($(CONFIG_KERNEL_KASAN),y)
	export QDF_TIMER_MULTIPLIER_FRAC=1
endif

ifeq ($(CONFIG_LINUX_5_4),y)
export QCA_WIFI_KERNEL_VERSION_5_4=1
endif

ifeq ($(ARCH),mips)
BIG_ENDIAN_HOST=1
endif
ifeq ($(ARCH),arm)
BIG_ENDIAN_HOST=0
endif

ifneq ($(CONFIG_TARGET_ipq)$(CONFIG_TARGET_ipq806x),)
	QCA_PLATFORM="ipq806x"
else
	QCA_PLATFORM="$(ARCH_PACKAGES)"
endif

QCAWLAN_MODULE_NAME:= $(notdir $(basename $(strip $(QCAWLAN_MODULE_LIST))))

#########################################################
##################### CONFIG RULES ######################
#########################################################

define KernelPackage/$(PKG_NAME)/Default
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:=QCA Wireless LAN Driver
  DEPENDS:=+libgcc +libc +wireless-tools +librt +kmod-cfg80211-linux +libroxml +libnl +qca-cfg80211 \
	  @(!(PACKAGE_kmod-ath&&PACKAGE_kmod-mac80211)) +TARGET_ipq_ipq807x:kmod-msm-mproc +TARGET_ipq_ipq807x_64:kmod-msm-mproc \
	  +TARGET_ipq_ipq60xx:kmod-msm-mproc +TARGET_ipq_ipq60xx_64:kmod-msm-mproc +TARGET_ipq_ipq50xx:kmod-msm-mproc +TARGET_ipq_ipq50xx_64:kmod-msm-mproc +WHUNT:qca-whunt-noship \
	  +!(LINUX_5_4||WHUNT||TARGET_ipq_ipq806x||TARGET_ipq_ipq40xx):qca-qrtr
  PKG_BUILD_DEPENDS+=$(FW) iproute2
  FILES:= $(strip $(QCAWLAN_MODULE_LIST))
  MENU:=1
  PROVIDES:=kmod-qca-wifi
ifeq ($(CONFIG_LINUX_5_4),y)
  AUTOLOAD :=$(call AutoLoad,51,mem_manager qdf asf umac qca_spectral qca_ol wifi_3_0 wifi_2_0 smart_antenna)
endif
endef

$(eval $(call RequireCommand,uuencode, \
	Please install sharutils which provides uuencode required for build \
))

define KernelPackage/$(PKG_NAME)/Description/Default
  This package contains a driver for QCA WLAN chipsets
  It also installs the QCA WLAN tools, such as:
  - wlanconfig
  - athstats
  - pktlogconf
  - ...
endef

define KernelPackage/$(PKG_NAME)/config/Default
if TARGET_ipq_ipq40xx
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ40xx platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ806x platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
endif
if TARGET_ar71xx
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for ar71xx platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for ar71xx platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
endif
if TARGET_ipq_ipq806x
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ806x platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ806x platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
endif
if (TARGET_ipq_ipq807x||TARGET_ipq807x_ipq807x_32)
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ807x platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ807x platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
   config WIFI_EMULATION_WIFI_3_0
	bool "Enable EMULATION_WIFI_3_0 support for Emulation platform"
	default n
	help
	   This option enables support for Emulation/VP WiFi 3.0 on RUMI
endif
if (TARGET_ipq_ipq807x_64||TARGET_ipq807x_generic)
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ807x 64bit platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ807x 64bit platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
   config WIFI_EMULATION_WIFI_3_0
	bool "Enable EMULATION_WIFI_3_0 support for Emulation platform"
	default n
	help
	   This option enables support for Emulation/VP WiFi 3.0 on RUMI
endif
if (TARGET_ipq_ipq60xx||TARGET_ipq60xx_ipq60xx_32)
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ60xx platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ60xx platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
   config WIFI_EMULATION_WIFI_3_0
	bool "Enable EMULATION_WIFI_3_0 support for Emulation platform"
	default n
	help
	   This option enables support for Emulation/VP WiFi 3.0 on RUMI
endif
if (TARGET_ipq_ipq60xx_64||TARGET_ipq60xx_generic)
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ60xx 64bit platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ60xx 64bit platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
   config WIFI_EMULATION_WIFI_3_0
	bool "Enable EMULATION_WIFI_3_0 support for Emulation platform"
	default n
	help
	   This option enables support for Emulation/VP WiFi 3.0 on RUMI
endif
if (TARGET_ipq_ipq50xx||TARGET_ipq50xx_ipq50xx_32)
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ50xx platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ50xx platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
   config WIFI_EMULATION_WIFI_3_0
	bool "Enable EMULATION_WIFI_3_0 support for Emulation platform"
	default n
	help
	   This option enables support for Emulation/VP WiFi 3.0 on RUMI
endif
if (TARGET_ipq_ipq50xx_64||TARGET_ipq50xx_generic)
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for IPQ50xx 64bit platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for IPQ50xx 64bit platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
   config WIFI_EMULATION_WIFI_3_0
	bool "Enable EMULATION_WIFI_3_0 support for Emulation platform"
	default n
	help
	   This option enables support for Emulation/VP WiFi 3.0 on RUMI
endif

if TARGET_x86_64
   config WIFI_TARGET_WIFI_2_0
	bool "Enable WIFI_2_0 support for x86 platform"
	default y
	help
	   This option enables support for WiFi 2.0 in boards
   config WIFI_TARGET_WIFI_3_0
	bool "Enable WIFI_3_0 support for x86 platform"
	default y
	help
	   This option enables support for WiFi 3.0 in boards
endif
config WIFI_MEM_DEBUG
    bool "Enable WiFi memory debug support"
    default n
    help
       This option enables memory debug support in WiFi modules
config WLAN_REF_ID_TRACE
    bool "Enable wlan objmgr ref trace"
    default n
    help
       This option objmgr ref debug support in WiFi modules
config WIFI_CE_TASKLET_DEBUG
    bool "Enable Wifi CE tasklet debug support"
    default n
    help
       This option enables ce tasklet debug support in Wifi modules
config WIFI_LOG_UTILS
    bool "Enable logging through user space application"
    default n
    help
       This enables sending host driver logs to user space application (cnss_diag)
config WIFI_VDEV_PEER_PROT_COUNT
    bool "Enable per-peer protocol counts"
    default n
    help
       This tracks selected protocol packets per peer and maintains count entering and exiting driver on both tx and rx side
config WIFI_VDEV_PEER_PROT_TESTING
    bool "Enable per-peer protocol counts"
    default n
    help
       This tracks selected protocol packets per peer and maintains count entering and exiting driver on both tx and rx side
config WLAN_IOT_SIM_SUPPORT
    bool "Enable iot simulation feature"
    default n
    help
       This enables iot simulation feature
endef

#########################################################
################### INSTALLDEV RULES ####################
#########################################################
define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include/qca-wifi
	$(MAKE) -C $(PKG_BUILD_DIR) INSTALL_DEST="$(STAGING_DIR)/usr/include/" install_headers
	$(CP) $(TOPDIR)/qca/src/qca-hostap/src/drivers/nl80211_copy.h $(STAGING_DIR)/usr/include
	$(CP) -f $(DRIVER_PATH)/component_dev/qca_mscs/inc/qca_mscs_if.h $(STAGING_DIR)/usr/include/qca-wifi
	$(CP) -f $(DRIVER_PATH)/component_dev/qca_mesh_latency/inc/qca_mesh_latency_if.h $(STAGING_DIR)/usr/include/qca-wifi
endef

#########################################################
################# BUILD/INSTALL RULES ###################
#########################################################
Hooks/Prepare/Pre += qca-wifi_update_patches_version
define qca-wifi_update_patches_version

	[ ! -h patches ] || rm patches
	[ ! -d patches-$(PKG_BRANCH) ] || \
		ln -s patches-$(PKG_BRANCH) patches
endef

define Build/Compile
		$(CP) $(TOPDIR)/qca/src/qca-hostap/src/drivers/nl80211_copy.h $(STAGING_DIR)/usr/include
		$(CP) -f $(DRIVER_PATH)/component_dev/tools/linux/cfg80211_ven_cmd.h $(STAGING_DIR)/usr/include
		export CONFIG_WIFI_TARGET_WIFI_2_0="$(CONFIG_WIFI_TARGET_WIFI_2_0)"; \
		export CONFIG_WIFI_TARGET_WIFI_3_0="$(CONFIG_WIFI_TARGET_WIFI_3_0)"; \
		export FW_INCLUDE_PATH="$(FW_INCLUDE_PATH)"; \
		export FW_COMMON_INCLUDE_PATH="$(FW_COMMON_INCLUDE_PATH)"; \
		export FW_INTERFACE_TOOLS_PATH="$(FW_INTERFACE_TOOLS_PATH)"; \
		export FW_HDR_INCLUDE_PATH="$(FW_HDR_INCLUDE_PATH)"; \
		export HALPHY_TOOLS_PATH="$(HALPHY_TOOLS_PATH)"; \
		export MAKE="$(MAKE)"; \
		export LINUX_VERSION="$(LINUX_VERSION)"; \
		export LINUX_DIR="$(LINUX_DIR)"; \
		export LINUX_SRC_DIR="$(LINUX_SRC_DIR)"; \
		export ARCH="$(ARCH)"; \
		export BUILD_VARIANT="$(BUILD_VARIANT)"; \
		export TARGET_CROSS="$(TARGET_CROSS)"; \
		export QCA_PLATFORM="$(QCA_PLATFORM)"; \
		export BIG_ENDIAN_HOST="$(BIG_ENDIAN_HOST)"; \
		export TARGET_CFLAGS="$(TARGET_CFLAGS)"; \
		export TARGET_LDFLAGS="$(TARGET_LDFLAGS) -lpthread -ldl"; \
		export CONFIG_WIFI_MEM_DEBUG="$(CONFIG_WIFI_MEM_DEBUG)"; \
		export CONFIG_WLAN_REF_ID_TRACE="$(CONFIG_WLAN_REF_ID_TRACE)"; \
		export CONFIG_WIFI_CE_TASKLET_DEBUG="$(CONFIG_WIFI_CE_TASKLET_DEBUG)"; \
		export CONFIG_WIFI_LOG_UTILS="$(CONFIG_WIFI_LOG_UTILS)"; \
		export CONFIG_WIFI_VDEV_PEER_PROT_COUNT="$(CONFIG_WIFI_VDEV_PEER_PROT_COUNT)"; \
		export CONFIG_WIFI_VDEV_PEER_PROT_TESTING="$(CONFIG_WIFI_VDEV_PEER_PROT_TESTING)"; \
		export CONFIG_WIFI_EMULATION_WIFI_3_0="$(CONFIG_WIFI_EMULATION_WIFI_3_0)"; \
		export CONFIG_WIFI_IPQ_MEM_PROFILE="$(CONFIG_KERNEL_IPQ_MEM_PROFILE)"; \
		export CONFIG_TARGET_ipq_ipq807x_64_QSDK_Enterprise="$(CONFIG_TARGET_ipq_ipq807x_64_QSDK_Enterprise)"; \
		export CONFIG_TARGET_ipq_ipq807x_QSDK_Enterprise="$(CONFIG_TARGET_ipq_ipq807x_QSDK_Enterprise)"; \
		export CONFIG_TARGET_ipq_ipq806x="$(CONFIG_TARGET_ipq_ipq806x)"; \
		export CONFIG_TARGET_ipq_ipq40xx="$(CONFIG_TARGET_ipq_ipq40xx)"; \
		export CONFIG_64BIT="$(CONFIG_64BIT)"; \
		export CONFIG_KERNEL_KASAN="$(CONFIG_KERNEL_KASAN)"; \
		export CONFIG_KERNEL_SKB_DEBUG="$(CONFIG_KERNEL_SKB_DEBUG)"; \
		export CONFIG_KERNEL_SLUB_DEBUG="$(CONFIG_KERNEL_SLUB_DEBUG)"; \
		export CONFIG_WLAN_IOT_SIM_SUPPORT="$(CONFIG_WLAN_IOT_SIM_SUPPORT)"; \
		export CONFIG_LOWMEM_FLASH="$(CONFIG_LOWMEM_FLASH)"; \
		export CONFIG_DEBUG="$(CONFIG_DEBUG)"; \
		$(MAKE) -C $(PKG_BUILD_DIR) src_prepare all_build
		$(CP) $(PKG_BUILD_DIR)/os/linux/tools/libqca_tools.so $(STAGING_DIR)/usr/lib/
ifneq ($(CONFIG_LOWMEM_FLASH),y)
		$(CP) $(PKG_BUILD_DIR)/os/linux/tools/libwlanfw_htt.so $(STAGING_DIR)/usr/lib/
		$(CP) $(PKG_BUILD_DIR)/os/linux/tools/libapstats.so $(STAGING_DIR)/usr/lib/
		$(CP) $(PKG_BUILD_DIR)/os/linux/tools/libwifistats.so $(STAGING_DIR)/usr/lib/
else
ifeq ($(CONFIG_DEBUG),y)
		$(CP) $(PKG_BUILD_DIR)/os/linux/tools/libwlanfw_htt.so $(STAGING_DIR)/usr/lib/
		$(CP) $(PKG_BUILD_DIR)/os/linux/tools/libapstats.so $(STAGING_DIR)/usr/lib/
		$(CP) $(PKG_BUILD_DIR)/os/linux/tools/libwifistats.so $(STAGING_DIR)/usr/lib/
endif
endif
endef

define KernelPackage/$(PKG_NAME)/install/Default
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/lib
	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_DIR) $(1)/lib/wifi/debug
	$(INSTALL_DIR) $(1)/lib/sbin
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_DIR) $(1)/ini
	$(INSTALL_DIR) $(1)/ini/internal
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/data/vendor/wifi
	$(INSTALL_DIR) $(1)/etc/hotplug.d/ieee80211
	$(INSTALL_DIR) $(1)/etc/hotplug.d/firmware

	$(INSTALL_DATA) ./files/qcawifi.sh $(1)/lib/wifi
	$(INSTALL_BIN) ./files/boot-ftm $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/diag_socket_app $(1)/etc/init.d/

	$(INSTALL_BIN) ./files/counters_wlan_prompt_akronite.sh $(1)/lib/wifi/debug
	$(INSTALL_BIN) ./files/counters_wlan_prompt_Dakota.sh $(1)/lib/wifi/debug
	$(INSTALL_BIN) ./files/counters_wlan_prompt_hawkeye.sh $(1)/lib/wifi/debug

	echo $(QCAWLAN_MODULE_NAME) | sed 's, ,\n,g' > $(1)/lib/wifi/qca-wifi-modules

	$(INSTALL_DATA) ./files/qcawificfg80211.sh $(1)/lib/wifi
	$(INSTALL_DATA) ./files/wifi-fw.hotplug $(1)/etc/hotplug.d/firmware/11-wifi-fw
	$(INSTALL_CONF) ./files/qcacfg80211.config $(1)/etc/config/qcacfg80211
	$(INSTALL_DATA) ./files/qcawifi_countrycode.txt $(1)/lib/wifi
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cfg80211_configs/cfg80211tool $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cfg80211_configs/*.xml $(1)/lib/wifi
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/umac/son/cfg80211_configs/*.xml $(1)/lib/wifi
	ln -s /usr/sbin/cfg80211tool $(1)/usr/sbin/cfg80211tool_mesh

	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/wifi_nss.upgrade $(1)/lib/upgrade/keep.d/wifi_nss

	$(INSTALL_BIN) ./files/wifi_try $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/wifi_try $(1)/lib/sbin/

	$(INSTALL_CONF) ./files/ssid-steering.config $(1)/etc/config/ssid-steering
	$(INSTALL_BIN) ./files/ssid_steering.init $(1)/etc/init.d/ssid_steering

	$(INSTALL_BIN) ./files/wifi_hw_mode $(1)/usr/sbin/

	$(INSTALL_CONF) ./files/ini/*.ini $(1)/ini/
	$(INSTALL_CONF) ./files/ini/internal/*.ini $(1)/ini/internal/
	$(INSTALL_DATA) ./files/tools_config $(1)/lib/wifi
#ifeq ($(CONFIG_LINUX_5_4),y)
#	$(INSTALL_DATA) ./files/qcawifi-config-cmd $(1)/etc/hotplug.d/ieee80211/01-qcawifi-detect
#endif

	[ ! -d files-$(PKG_BRANCH) ] || \
		$(CP) ./files-$(PKG_BRANCH)/* $(1)/
	export INSTALL_BIN="$(INSTALL_BIN)"; \
	export INSTALL_DATA="$(INSTALL_DATA)"; \
	export CONFIG_WIFI_TARGET_WIFI_2_0="$(CONFIG_WIFI_TARGET_WIFI_2_0)"; \
	export CONFIG_WIFI_TARGET_WIFI_3_0="$(CONFIG_WIFI_TARGET_WIFI_3_0)"; \
	$(MAKE) -C $(PKG_BUILD_DIR) QCAWLAN_TOOL_LIST="$(QCAWLAN_TOOL_LIST)" INSTALL_BIN_DEST="$(1)/usr/sbin" INSTALL_LIB_DEST="$(1)/usr/lib" tools_installonly
endef
define KernelPackage/$(PKG_NAME)/install/Lowmem
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/lib
	$(INSTALL_DIR) $(1)/lib/wifi
	$(INSTALL_DIR) $(1)/lib/wifi/debug
	$(INSTALL_DIR) $(1)/lib/sbin
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_DIR) $(1)/ini
	$(INSTALL_DIR) $(1)/ini/internal
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/data/vendor/wifi
	$(INSTALL_DIR) $(1)/etc/hotplug.d/firmware

	echo $(QCAWLAN_MODULE_NAME) | sed 's, ,\n,g' > ./files/qca-wifi-modules
	$(INSTALL_DATA) ./files/qca-wifi-modules $(1)/lib/wifi

	$(INSTALL_DATA) ./files/qcawificfg80211.sh $(1)/lib/wifi
	$(INSTALL_DATA) ./files/wifi-fw.hotplug $(1)/etc/hotplug.d/firmware/11-wifi-fw
	$(INSTALL_CONF) ./files/qcacfg80211.config $(1)/etc/config/qcacfg80211
	$(INSTALL_DATA) ./files/qcawifi_countrycode.txt $(1)/lib/wifi
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cfg80211_configs/cfg80211tool $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cfg80211_configs/*.xml $(1)/lib/wifi
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/umac/son/cfg80211_configs/*.xml $(1)/lib/wifi
	ln -s /usr/sbin/cfg80211tool $(1)/usr/sbin/cfg80211tool_mesh
ifeq ($(CONFIG_PACKAGE_qca-diag),y)
	$(INSTALL_BIN) ./files/diag_socket_app $(1)/etc/init.d/
endif

	$(INSTALL_CONF) ./files/ini/global.ini $(1)/ini/
	$(INSTALL_CONF) ./files/ini/internal/global_i.ini $(1)/ini/internal/

	$(INSTALL_CONF) ./files/ini/QCA5018.ini $(1)/ini/
	$(INSTALL_CONF) ./files/ini/internal/QCA5018_i.ini $(1)/ini/internal/
	$(INSTALL_CONF) ./files/ini/QCN9000.ini $(1)/ini/
	$(INSTALL_CONF) ./files/ini/internal/QCN9000_i.ini $(1)/ini/internal/

	$(INSTALL_CONF) ./files/ini/QCN6122.ini $(1)/ini/
	$(INSTALL_CONF) ./files/ini/internal/QCN6122_i.ini $(1)/ini/internal/

	$(INSTALL_DATA) ./files/tools_config $(1)/lib/wifi
	[ ! -d files-$(PKG_BRANCH) ] || \
		$(CP) ./files-$(PKG_BRANCH)/* $(1)/
	export INSTALL_BIN="$(INSTALL_BIN)"; \
	export INSTALL_DATA="$(INSTALL_DATA)"; \
	export CONFIG_WIFI_TARGET_WIFI_2_0="$(CONFIG_WIFI_TARGET_WIFI_2_0)"; \
	export CONFIG_WIFI_TARGET_WIFI_3_0="$(CONFIG_WIFI_TARGET_WIFI_3_0)"; \
	$(MAKE) -C $(PKG_BUILD_DIR) QCAWLAN_TOOL_LIST="$(QCAWLAN_TOOL_LIST)" INSTALL_BIN_DEST="$(1)/usr/sbin" INSTALL_LIB_DEST="$(1)/usr/lib" tools_installonly
endef

#########################################################
################# VARIANTS DEFINITION ###################
#########################################################
ifeq ($(CONFIG_TARGET_ipq)$(CONFIG_TARGET_ipq807x)$(CONFIG_TARGET_ipq60xx)$(CONFIG_TARGET_ipq50xx),y)
subtarget:=$(SUBTARGET)
else
subtarget:=$(CONFIG_TARGET_BOARD)
endif

ifeq ($(subtarget),$(filter $(subtarget),ipq806x ipq807x ipq807x_64 generic ipq807x_32 ipq60xx ipq60xx_64 ipq50xx ipq50xx_64 ipq50xx_32))
 QCA_NSS_ENABLED:=1
 export QCA_NSS_ENABLED
endif

# Default variant (Akronite only)
define KernelPackage/$(PKG_NAME)-akronite-perf
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=akronite-perf
  DEPENDS+=@TARGET_ipq806x +TARGET_ipq806x:kmod-qca-nss-drv
endef

define KernelPackage/$(PKG_NAME)-akronite-perf/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

ifneq ($(CONFIG_TARGET_ipq806x),)
define KernelPackage/$(PKG_NAME)-akronite-perf/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-akronite-perf)
endef
endif

define KernelPackage/$(PKG_NAME)-akronite-perf/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-akronite-perf))

# Emulation variant for ipq806x
define KernelPackage/$(PKG_NAME)-akronite-perf-emu
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=akronite-perf-emu
  DEPENDS+=@TARGET_ipq806x +TARGET_ipq806x:kmod-qca-nss-drv
endef

define KernelPackage/$(PKG_NAME)-akronite-perf-emu/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

ifneq ($(CONFIG_TARGET_ipq806x),)
define KernelPackage/$(PKG_NAME)-akronite-perf-emu/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-akronite-perf-emu)
endef
endif

define KernelPackage/$(PKG_NAME)-akronite-perf-emu/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-akronite-perf-emu))

# Perf variant
define KernelPackage/$(PKG_NAME)-perf
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=perf
  DEPENDS+=@TARGET_ar71xx
endef

define KernelPackage/$(PKG_NAME)-perf/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

ifneq ($(CONFIG_TARGET_ar71xx),)
define KernelPackage/$(PKG_NAME)-perf/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-perf)
endef
endif

define KernelPackage/$(PKG_NAME)-perf/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-perf))

# New datapath variant
define KernelPackage/$(PKG_NAME)-unified-perf
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=unified-perf
  DEPENDS+=@TARGET_ar71xx
endef

define KernelPackage/$(PKG_NAME)-unified-perf/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

ifneq ($(CONFIG_TARGET_ar71xx),)
define KernelPackage/$(PKG_NAME)-unified-perf/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-unified-perf)
endef
endif

define KernelPackage/$(PKG_NAME)-unified-perf/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-unified-perf))

# Dakota variant
define KernelPackage/$(PKG_NAME)-dakota-perf
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=dakota-perf
  DEPENDS+=@TARGET_ipq806x||TARGET_ipq +TARGET_ipq806x:kmod-qca-nss-drv
endef

define KernelPackage/$(PKG_NAME)-dakota-perf/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

ifneq ($(CONFIG_TARGET_ipq806x)$(CONFIG_TARGET_ipq),)
define KernelPackage/$(PKG_NAME)-dakota-perf/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-dakota-perf)
endef
endif

define KernelPackage/$(PKG_NAME)-dakota-perf/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-dakota-perf))

# Unified variant
define KernelPackage/$(PKG_NAME)-unified-profile
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=unified-profile
  DEPENDS+=@TARGET_ipq806x||TARGET_ar71xx||TARGET_ipq||TARGET_ipq807x||TARGET_ipq60xx||TARGET_ipq50xx||TARGET_x86 \
	   +TARGET_ipq_ipq806x:kmod-qca-nss-drv +TARGET_ipq_ipq807x:kmod-qca-nss-drv \
	   +TARGET_ipq_ipq807x_64:kmod-qca-nss-drv +TARGET_ipq_ipq60xx:kmod-qca-nss-drv \
	   +TARGET_ipq_ipq60xx_64:kmod-qca-nss-drv +TARGET_ipq_ipq50xx:kmod-qca-nss-drv \
	   +TARGET_ipq_ipq50xx_64:kmod-qca-nss-drv +TARGET_ipq807x:kmod-qca-nss-drv \
	   +TARGET_ipq50xx:kmod-qca-nss-drv +TARGET_ipq60xx:kmod-qca-nss-drv \
	   +TARGET_ipq807x:qca-wifi-hk-fw-hw1-10.4-asic +TARGET_ipq60xx:qca-wifi-cyp-fw-hw1-11.0-asic
endef

define KernelPackage/$(PKG_NAME)-unified-profile/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

define KernelPackage/$(PKG_NAME)-unified-profile/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-unified-profile)
endef

define KernelPackage/$(PKG_NAME)-unified-profile/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-unified-profile))

# custc variant
define KernelPackage/$(PKG_NAME)-custc-profile
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=custc-profile
  DEPENDS+=@TARGET_ipq806x||TARGET_ar71xx||TARGET_ipq||TARGET_x86||TARGET_ipq60xx||TARGET_ipq807x \
	   +TARGET_ipq_ipq806x:kmod-qca-nss-drv +TARGET_ipq_ipq807x:kmod-qca-nss-drv \
	   +TARGET_ipq_ipq807x_64:kmod-qca-nss-drv +TARGET_ipq_ipq60xx:kmod-qca-nss-drv \
	   +TARGET_ipq_ipq60xx_64:kmod-qca-nss-drv +TARGET_ipq_ipq50xx:kmod-qca-nss-drv \
	   +TARGET_ipq_ipq50xx_64:kmod-qca-nss-drv
endef

define KernelPackage/$(PKG_NAME)-custc-profile/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

define KernelPackage/$(PKG_NAME)-custc-profile/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-custc-profile)
endef

define KernelPackage/$(PKG_NAME)-custc-profile/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-custc-profile))

# IPQ8074 Lowmem variant
define KernelPackage/$(PKG_NAME)-lowmem-profile
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=lowmem-profile
  DEPENDS+=+TARGET_ipq_ipq807x:kmod-qca-nss-drv \
	   +TARGET_ipq_ipq50xx:kmod-qca-nss-drv \
	   +TARGET_ipq50xx:kmod-qca-nss-drv \
	   +TARGET_ipq807x:kmod-qca-nss-drv
endef

define KernelPackage/$(PKG_NAME)-lowmem-profile/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

define KernelPackage/$(PKG_NAME)-lowmem-profile/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-lowmem-profile)
endef

define KernelPackage/$(PKG_NAME)-lowmem-profile/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-lowmem-profile))

# IPQ8074 flash_16mb  svariant
define KernelPackage/$(PKG_NAME)-flash_16mb-profile
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=flash_16mb-profile
  DEPENDS+=@TARGET_ipq||TARGET_ipq50xx \
	   +TARGET_ipq_ipq50xx:kmod-qca-nss-drv \
	   +TARGET_ipq50xx:kmod-qca-nss-drv
endef

define KernelPackage/$(PKG_NAME)-flash_16mb-profile/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

define KernelPackage/$(PKG_NAME)-flash_16mb-profile/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-flash_16mb-profile)
endef

define KernelPackage/$(PKG_NAME)-flash_16mb-profile/install
$(call KernelPackage/$(PKG_NAME)/install/Lowmem,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-flash_16mb-profile))

# Minimal Profile variant
define KernelPackage/$(PKG_NAME)-minimal-profile
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=minimal-profile
endef

define KernelPackage/$(PKG_NAME)-minimal-profile/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

define KernelPackage/$(PKG_NAME)-minimal-profile/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-minimal-profile)
endef

define KernelPackage/$(PKG_NAME)-minimal-profile/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-minimal-profile))

# Debug Profile variant
define KernelPackage/$(PKG_NAME)-debug-profile
$(call KernelPackage/$(PKG_NAME)/Default)
  VARIANT:=debug-profile
endef

define KernelPackage/$(PKG_NAME)-debug-profile/Description
$(call define KernelPackage/$(PKG_NAME)/Description/Default)
endef

define KernelPackage/$(PKG_NAME)-debug-profile/config
$(call KernelPackage/$(PKG_NAME)/config/Default,-debug-profile)
endef

define KernelPackage/$(PKG_NAME)-debug-profile/install
$(call KernelPackage/$(PKG_NAME)/install/Default,$(1))
endef
$(eval $(call KernelPackage,$(PKG_NAME)-debug-profile))
