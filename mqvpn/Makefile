#
# Copyright (C) 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter project
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mqvpn
PKG_VERSION:=0.14.0
PKG_RELEASE:=3
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/Ysurac/mqvpn.git
PKG_SOURCE_VERSION:=93b0ed9324867473839c87d54afac92749ace73a
PKG_MIRROR_HASH:=skip

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0
# Disable cmake.mk's own configure/install steps — we drive cmake manually
PKG_USE_NINJA:=0
PKG_INSTALL:=0

include $(INCLUDE_DIR)/package.mk
# Include cmake.mk solely to get correctly-resolved absolute paths for
# CMAKE_AR and CMAKE_RANLIB (via TOOLCHAIN_BIN_DIRS / cmake_tool).
include $(INCLUDE_DIR)/cmake.mk

# xquic included in tarball via OpenWrt submodule handling
XQUIC_DIR  := $(PKG_BUILD_DIR)/third_party/xquic
XQUIC_BUILD:= $(XQUIC_DIR)/build

# BoringSSL built in-tree (not a submodule — cloned during Build/Prepare)
BSSL_DIR   := $(XQUIC_DIR)/third_party/boringssl
BSSL_BUILD := $(BSSL_DIR)/build

# Paths passed directly to xquic cmake (SSL_INC_PATH / SSL_LIB_PATH bypass find_library,
# avoiding CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY prepending the staging dir).
# BoringSSL outputs flat libs: build/libssl.a and build/libcrypto.a
# Semicolon separator is required for cmake list variables.
BSSL_INC  := $(BSSL_DIR)/include
BSSL_LIBS := $(BSSL_BUILD)/libssl.a;$(BSSL_BUILD)/libcrypto.a

MQVPN_BUILD:= $(PKG_BUILD_DIR)/build

# Common CMake cross-compilation flags
# CMAKE_AR and CMAKE_RANLIB come from cmake.mk (absolute paths via cmake_tool).
CMAKE_CROSS := \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR="$(ARCH)" \
	-DCMAKE_C_COMPILER="$(CMAKE_C_COMPILER)" \
	-DCMAKE_CXX_COMPILER="$(CMAKE_CXX_COMPILER)" \
	-DCMAKE_AR="$(CMAKE_AR)" \
	-DCMAKE_RANLIB="$(CMAKE_RANLIB)" \
	-DCMAKE_C_COMPILER_AR="$(CMAKE_AR)" \
	-DCMAKE_CXX_COMPILER_AR="$(CMAKE_AR)" \
	-DCMAKE_C_COMPILER_RANLIB="$(CMAKE_RANLIB)" \
	-DCMAKE_CXX_COMPILER_RANLIB="$(CMAKE_RANLIB)" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
	-DCMAKE_EXE_LINKER_FLAGS="$(TARGET_LDFLAGS)" \
	-DCMAKE_SHARED_LINKER_FLAGS="$(TARGET_LDFLAGS)" \
	-DCMAKE_FIND_ROOT_PATH="$(STAGING_DIR)" \
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER

define Package/mqvpn
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=mqvpn - QUIC-based VPN
  URL:=https://github.com/mp0rta/mqvpn
  DEPENDS:=+kmod-tun +libevent2
endef

define Package/mqvpn/description
  mqvpn is a VPN tunneling daemon built on QUIC via xquic and BoringSSL.
endef

define Package/mqvpn/conffiles
/etc/config/mqvpn
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	# xquic is already in the tarball (OpenWrt submodule handling)
	# BoringSSL is not a submodule of xquic — clone it
	if [ ! -f "$(BSSL_DIR)/CMakeLists.txt" ]; then \
		git clone --depth 1 https://github.com/google/boringssl.git "$(BSSL_DIR)"; \
	fi
endef

# Override cmake.mk's Build/Configure and Build/Install — we run cmake directly
# in Build/Compile and handle installation in Package/mqvpn/install.
define Build/Configure
endef

define Build/Install
endef

define Build/Compile
	# Wipe stale cmake caches so reconfiguration picks up updated toolchain vars
	rm -rf "$(BSSL_BUILD)" "$(XQUIC_BUILD)" "$(MQVPN_BUILD)"
	# --- 1. BoringSSL (static, fPIC) ---
	mkdir -p "$(BSSL_BUILD)"
	cmake -S "$(BSSL_DIR)" -B "$(BSSL_BUILD)" \
		$(CMAKE_CROSS) \
		-DBUILD_SHARED_LIBS=0 \
		-DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -fPIC" \
		-DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) -fPIC"
	+$(MAKE) -C "$(BSSL_BUILD)" ssl crypto

	# --- 2. xquic (points directly at the built BoringSSL headers/libs) ---
	mkdir -p "$(XQUIC_BUILD)"
	cmake -S "$(XQUIC_DIR)" -B "$(XQUIC_BUILD)" \
		$(CMAKE_CROSS) \
		-DCMAKE_BUILD_TYPE=Release \
		-DSSL_TYPE=boringssl \
		-DSSL_INC_PATH="$(BSSL_INC)" \
		-DSSL_LIB_PATH="$(BSSL_LIBS)" \
		-DXQC_ENABLE_BBR2=ON \
		-DCMAKE_C_FLAGS="$(TARGET_CFLAGS)" \
		-DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS)"
	+$(MAKE) -C "$(XQUIC_BUILD)"

	# --- 3. mqvpn ---
	mkdir -p "$(MQVPN_BUILD)"
	cmake -S "$(PKG_BUILD_DIR)" -B "$(MQVPN_BUILD)" \
		$(CMAKE_CROSS) \
		-DCMAKE_BUILD_TYPE=Release \
		-DXQUIC_BUILD_DIR="$(XQUIC_BUILD)" \
		-DBORINGSSL_BUILD_DIR="$(BSSL_BUILD)" \
		-DSSL_LIB="$(BSSL_BUILD)/libssl.a" \
		-DCRYPTO_LIB="$(BSSL_BUILD)/libcrypto.a" \
		-DBUILD_TESTING=OFF \
		-DCMAKE_C_FLAGS="$(TARGET_CFLAGS)" \
		-DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS)"
	+$(MAKE) -C "$(MQVPN_BUILD)"
endef

define Package/mqvpn/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(MQVPN_BUILD)/mqvpn $(1)/usr/sbin/mqvpn
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,mqvpn))
