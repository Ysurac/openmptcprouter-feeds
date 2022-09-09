include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=LinuxART2
PKG_VERSION:=CS10.2v4.9.455
PKG_RELEASE:=1

PKG_BRANCH:=$(basename $(PKG_VERSION))
PKG_SOURCE:=$(PKG_NAME)$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/cnss_win/santaclara/dev01/ART2/$(PKG_NAME)$(PKG_BRANCH)/$(PKG_NAME)$(PKG_VERSION)
PKG_MD5SUM:=9607e35711cba23d247b642cd726bcc5

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

#########################################################
############ ART DRIVER BUILD CONFIGURATION ############
#########################################################

ifeq ($(CONFIG_TARGET_ar71xx), y)
TARGET_CFLAGS+=-fpie
else
TARGET_CFLAGS+=-Wall -Werror -fpie
endif
TARGET_LDFLAGS+=-pie

export C_FLAGS:=$(TARGET_CFLAGS)
export LD_FLAGS:=$(TARGET_LDFLAGS)

ART2_APP_OPTS+= \
	$(TARGET_CONFIGURE_OPTS) \
	ART_ROOT=$(PKG_BUILD_DIR) \
	WORKAREA=$(PKG_BUILD_DIR) \
	TOOL_PREFIX=$(TARGET_CROSS)

ifeq ($(BUILD_VARIANT),netlink)
ART2_APP_OPTS+=USE_NETLINK=1
endif

EXTRA_CFLAGS+=	\
	-DUSE_PLATFORM_FRAMEWORK=1 \
	-DCFG_64BIT=0 \
	-I$(PKG_BUILD_DIR) \
	-I$(PKG_BUILD_DIR)/driver/linux/modules/include \

ifneq ($(CONFIG_DEBUG),)
ART2_APP_OPTS+= \
	GDB=1
endif

ifeq (y, $(findstring y, $(CONFIG_TARGET_ipq)$(CONFIG_TARGET_ipq806x)$(CONFIG_TARGET_ipq_ipq806x)$(CONFIG_TARGET_ipq40xx)$(CONFIG_TARGET_ipq_ipq40xx)$(CONFIG_TARGET_ipq807x)$(CONFIG_TARGET_ipq_ipq807x)$(CONFIG_TARGET_ipq807x_64)$(CONFIG_TARGET_ipq_ipq807x_64)))
ART2_APP_OPTS+=AKRONITE=1
EXTRA_CFLAGS+=-DAKRONITE_ART
endif

ifeq ($(CONFIG_TARGET_ar71xx), y)
EXTRA_CFLAGS+= -DAP83 -DWASP
endif

define KernelPackage/art2/Default
    SECTION:=QCA
    CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
    URL:=http://www.qca.qualcomm.com
    MAINTAINER:=Qualcomm Atheros
    TITLE:=$(1) - QCA ART Driver & tools
    DEPENDS:=@!TARGET_ipq50xx @!TARGET_ipq807x_generic @!TARGET_ipq_ipq807x_64 @!TARGET_ipq_ipq60xx_64 @!TARGET_ipq_ipq50xx_64 +libpthread +libc +librt
    FILES:=$(PKG_BUILD_DIR)/driver/linux/modules/art.$(LINUX_KMOD_SUFFIX)
endef

define KernelPackage/art2/Description/Default
    This package contains a driver for ART and the tools to use it:
      - art.ko
      - nart.out
      - NART related libs
    It has been build specifically for $(1)
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		SUBDIRS="$(PKG_BUILD_DIR)/driver/linux/modules" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
		modules
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(ART2_APP_OPTS)) \
		-f makefile.nart all
endef

define KernelPackage/art2/install/Default
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/nartbuild/*.out $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/nartbuild/*.so $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/BoardData/*.bin $(1)/usr/sbin
	$(INSTALL_BIN) ./files/art.init $(1)/etc/init.d/art
endef

define KernelPackage/art2
$(call KernelPackage/art2/Default)
  DEPENDS+=libnl-tiny
endef

define KernelPackage/art2/Description
$(call KernelPackage/art2/Description/Default)
endef

define KernelPackage/art2/config
$(call KernelPackage/art2/config/Default)
endef

define KernelPackage/art2/install
$(call KernelPackage/art2/install/Default,$(1))
endef

$(eval $(call KernelPackage,art2))

define KernelPackage/art2-netlink
$(call KernelPackage/art2/Default,netlink)
  VARIANT:=netlink
  DEPENDS+=libnl-tiny
endef

define KernelPackage/art2-netlink/Description
$(call KernelPackage/art2/Description/Default)
endef

define KernelPackage/art2-netlink/config
$(call KernelPackage/art2/config/Default,-netlink)
endef

define KernelPackage/art2-netlink/install
$(call KernelPackage/art2/install/Default,$(1))
endef

$(eval $(call KernelPackage,art2-netlink))
