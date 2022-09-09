include $(TOPDIR)/rules.mk

PKG_NAME:=gpio-debug
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/gpio-debug
  TITLE:=QCA Linux GPIO Debug script
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
endef

define Package/gpio-debug/description
  This package contains a GPIO Debug script which can be used
  internally by QCA to check the status of GPIO pins easily and
  quickly without involving manual calculations
endef

Build/Compile=true

define Package/gpio-debug/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/gpio-debug-ipq807x.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/gpio-debug-ipq40xx.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/gpio-debug-ipq806x.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/gpio-debug-ipq6018.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/gpio-debug-ipq5018.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/gpio-dump.sh $(1)/usr/sbin
endef

$(eval $(call BuildPackage,gpio-debug))
