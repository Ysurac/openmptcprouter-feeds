include $(TOPDIR)/rules.mk

PKG:=minidump
PKG_NAME:=$(PKG)
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/minidump

include $(INCLUDE_DIR)/local-development.mk

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=Qualcomm Technologies, Inc. Proprietary software
  URL:=http://www.qualcomm.com
  MAINTAINER:=Qualcomm Technologies, Inc.
  TITLE:= QTI minidump
  DEPENDS:= @TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64||TARGET_ipq807x||TARGET_ipq60xx
endef

define Package/$(PKG_NAME)/description/Default
	Minidump Package Support
endef

TARGET_CFLAGS += -MMD -O2 -Wall -g -fpie
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include
TARGET_LDFLAGS += -pie
TARGET_CSRCS := minidump.c

define Build/Compile
$(MAKE) -C $(PKG_BUILD_DIR) \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	CSRCS="$(TARGET_CSRCS)"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/hotplug.d/minidump
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/minidump $(1)/usr/sbin/
	$(CP) ./files/minidump.conf $(1)/etc/config/minidump
	$(CP) ./files/00-minidump $(1)/etc/hotplug.d/minidump
endef

$(eval $(call BuildPackage,minidump))
