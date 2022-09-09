include $(TOPDIR)/rules.mk

PKG_NAME:=dashboard
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/dashboard
  TITLE:=QCA Linux Dashboard script
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
endef

define Package/dashboard/description
  This package contains a shell script which can be used
  internally by QCA to print the system information
  quickly without accessing system entries one by one
endef

Build/Compile=true

define Package/dashboard/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/dashboard.sh $(1)/usr/sbin
endef

$(eval $(call BuildPackage,dashboard))
