include $(TOPDIR)/rules.mk

PKG_NAME:=qca-mad
PKG_RELEASE:=1

include $(INCLUDE_DIR)/local-development.mk

ifeq ($(DUMP)$(PKG_VERSION),)
PKG_REV:=2117e2f
PKG_VERSION:=g2117e2f
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

WIFI_U:=PACKAGE_kmod-qca-wifi-unified-profile
WIFI_C:=PACKAGE_kmod-qca-wifi-custc-profile
WIFI_A:=PACKAGE_kmod-qca-wifi-akronite-perf
WIFI_D:=PACKAGE_kmod-qca-wifi-dakota-perf
WIFI_L:=PACKAGE_kmod-qca-wifi-lowmem-profile
WIFI_PKGS:=$(WIFI_U)||$(WIFI_C)||$(WIFI_A)||$(WIFI_D)||$(WIFI_L)

PKG_BUILD_DEPENDS:=$(WIFI_U):qca-wifi $(WIFI_C):qca-wifi $(WIFI_A):qca-wifi $(WIFI_D):qca-wifi \
        $(WIFI_L):qca-wifi libhyficommon libieee1905

TARGET_CFLAGS += -fpie \
	-I$(STAGING_DIR)/usr/include/ \
	-I$(STAGING_DIR)/usr/include/libxml2 \
	-I$(STAGING_DIR)/usr/include/libnl3 \
	-I$(STAGING_DIR)/usr/include/libnl
TARGET_LDFLAGS += -pie

QCAMAD_MAKE_OPTS:= \
        CROSS=$(TARGET_CROSS) \
        GWLIB=$(STAGING_DIR)/usr/lib \
        MATOP=$(PKG_BUILD_DIR) \
        GWINCLUDE=$(STAGING_DIR)/usr/include/qca/ \
        HYFICMNDIR=$(STAGING_DIR)/usr/include/hyficommon \
        IEEE1905DIR=$(STAGING_DIR)/usr/include/ieee1905 \
        ATHDIR=$(STAGING_DIR)/usr/include \
        INSTALL_ROOT=$(PKG_BUILD_DIR)/install \
        QCACFLAGS="$(TARGET_CFLAGS)"\
        QCALDFLAGS="-Wl,--gc-sections $(TARGET_LDFLAGS)"\
        KERNELVERSION=$(LINUX_VERSION) \
        STAGING_DIR=$(STAGING_DIR)

define Package/qca-mad
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  DEPENDS:=+libieee1905 +libnl +qca-cfg80211 +libhyficommon +libpthread +jansson
  TITLE:=Mesh Application Daemon
  SUBMENU:=Dataelements and ieee1905
endef

define Package/qca-mad/description
  This package installs the Mesh Application Daemon
endef

QCAMAD_HEADERS= \

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)/install/lib
	mkdir -p $(PKG_BUILD_DIR)/install/include
	mkdir -p $(PKG_BUILD_DIR)/install/sbin
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCAMAD_MAKE_OPTS)) subdirs
endef

define Package/qca-mad/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/mesh_app $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/install/sbin/de_nb_client $(1)/usr/sbin
	$(INSTALL_BIN) ./files/mat $(1)/usr/sbin/mat
	$(INSTALL_CONF) ./files/mesh_app.config $(1)/etc/config/mesh_app
	$(INSTALL_BIN) ./files/mesh_app.init $(1)/etc/init.d/mesh_app
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/mesh_app
	$(foreach header_file,$(QCA_HYD_HEADERS), $(CP) $(header_file) $(1)/usr/include/mesh_app;)
endef

$(eval $(call BuildPackage,qca-mad))
