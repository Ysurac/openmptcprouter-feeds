include $(TOPDIR)/rules.mk

PKG_NAME:=libbpf
PKG_VERSION:=556e0a0
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://github.com/libbpf/libbpf.git
PKG_SOURCE_VERSION:=556e0a0def956ece0476d99ccb0570ee4ecd4d23
PKG_MAINTAINER:=Yannick Chabanois (Ycarus) <ycarus@zugaina.org>

PKG_SOURCE_PROTO:=git

include $(INCLUDE_DIR)/package.mk

define Package/libbpf
  SECTION:=net
  CATEGORY:=Network
  TITLE:=libbpf
  DEPENDS:=+libstdcpp +libelf1
endef

define Package/libbpf/description
  libbpf
endef

EXTRA_CPPFLAGS += -fpermissive -Wno-variadic-macros

TARGET_CFLAGS += -DCOMPAT_NEED_REALLOCARRAY

define Build/Configure
endef

define Build/Compile
	BUILD_SHARED=y $(MAKE) -C $(PKG_BUILD_DIR)/src \
	    CC="$(TARGET_CC)" \
	    CFLAGS="$(TARGET_CFLAGS)" \
	    LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/src/libbpf.so $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include/bpf
	$(CP) $(PKG_BUILD_DIR)/src/*.h $(1)/usr/include/bpf
endef

define Package/libbpf/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/src/libbpf.so $(1)/usr/lib
endef

$(eval $(call BuildPackage,libbpf))
