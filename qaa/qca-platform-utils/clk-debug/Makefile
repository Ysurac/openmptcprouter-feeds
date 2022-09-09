include $(TOPDIR)/rules.mk

PKG_NAME:=clk-debug
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/clk-debug
  TITLE:=QCA Linux Clock Debug script
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
endef

define Package/clk-debug/description
  This package contains a Clock Debug script which can be used
  internally by QCA to check the status of Clocks easily and
  quickly.
endef

Build/Compile=true

define Package/clk-debug/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/clk-debug-ipq807x.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/clk-debug-ipq6018.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/clk-debug-ipq5018.sh $(1)/usr/sbin
	$(INSTALL_BIN) ./files/clk-dump.sh $(1)/usr/sbin
endef

$(eval $(call BuildPackage,clk-debug))
