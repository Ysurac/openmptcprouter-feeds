include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/local-development.mk

PKG_NAME:=qca-son-cli
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

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

QCASONCLI_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        EXTRA_CFLAGS="$(TARGET_CFLAGS)"\
        EXTRA_LDFLAGS="-Wl,--gc-sections $(TARGET_LDFLAGS)"\
        STAGING_DIR=$(STAGING_DIR)

define Package/qca-son-cli/config
  source "$(SOURCE)/Config.in"
endef

SONCLI_DEPENDS:=@$(WIFI_PKGS) +libpthread +libnl +libnl-genl +libhyficommon +qca-cfg80211

ifeq ($(CONFIG_ENABLE_SON_MEMORY_DEBUG),y)
	QCASONCLI_MAKE_OPTS+=ENABLE_SON_MEMORY_DEBUG=y
endif

define Package/qca-son-cli
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  DEPENDS:=$(SONCLI_DEPENDS)
  TITLE:=SON stats daemon
  SUBMENU:=SON Statistics and Memory Utilization command line interface
endef

define Package/qca-son-cli/description
  This package installs the SON_CLI Tool
endef

define Package/qca-son-cli/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/lib/functions
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/son_cli $(1)/usr/sbin/
	@cp ./files/commands.sh $(1)/lib/functions/
endef

define Build/Compile
	$(INSTALL_DIR) -p $(PKG_BUILD_DIR)/install/sbin
	mkdir -p $(PKG_BUILD_DIR)/install/include/
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCASONCLI_MAKE_OPTS)) all
endef

INSTALL_HEADERS=meminfo.h

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/son-cli
	$(if $(INSTALL_HEADERS),$(CP) $(foreach header,$(INSTALL_HEADERS),$(PKG_BUILD_DIR)/install/include/$(header)) $(1)/usr/include/son-cli)
endef

$(eval $(call BuildPackage,qca-son-cli))
