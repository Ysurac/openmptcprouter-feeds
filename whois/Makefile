
include $(TOPDIR)/rules.mk

PKG_NAME:=whois
PKG_VERSION:=5.4.3
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(BUILD_VARIANT)/$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)_$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=http://ftp.debian.org/debian/pool/main/w/whois
PKG_HASH:=fefa84029f70985db19743e51c4a8b318a169426babeaa824a27110c26090fc3
PKG_CAT:=xzcat

PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/whois
  SECTION:=net
  CATEGORY:=Network
  TITLE:=WHOIS commandline utility
  URL:=http://ftp.debian.org/debian/pool/main/w/whois
  MAINTAINER:=Kihamo <dev@kihamo.ru>
endef

define Package/whois/description
  Utility to display information from WHOIS servers
endef

define Package/whois/conffiles
/etc/whois.conf
endef

MAKE_FLAGS += \
	prefix=$(PKG_BUILD_DIR)

define Package/whois/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/whois $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/whois.conf $(1)/etc/whois.conf
endef

$(eval $(call BuildPackage,whois))

