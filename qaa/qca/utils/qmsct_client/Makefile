include $(TOPDIR)/rules.mk

PKG:=qmsct_client
PKG_NAME:=$(PKG)
PKG_RELEASE:=1

LOCAL_SRC:=$(TOPDIR)/qca/src/common-tools/qmsct_client

include $(INCLUDE_DIR)/local-development.mk

ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_VERSION:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
endif

#PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros
  TITLE:= QCA qmsct_client utils
  DEPENDS:= @TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64
endef

define Package/$(PKG_NAME)/description/Default
	Qmsct Client application
endef

TARGET_CFLAGS += -MMD -O2 -Wall -g
TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include
TARGET_CFLAGS += -fpie
TARGET_LDFLAGS += -pie

define Build/Compile
$(MAKE) -C $(PKG_BUILD_DIR) \
	CC="$(TARGET_CC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/$(PKG_NAME)/install
        $(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/qmsct_client $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,qmsct_client))
