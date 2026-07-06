#
# Copyright (C) 2025 CyberMind.fr (SecuBox Integration)
#
# This is free software, licensed under the GNU General Public License v3.
#
# nDPId - Lightweight Deep Packet Inspection Daemon
# Builds nDPId with bundled libndpi (requires >= 5.0, OpenWrt has 4.8)
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ndpid
PKG_VERSION:=1.7.2
PKG_RELEASE:=1

# Use git dev branch for latest libndpi compatibility
# Version 1.7 (Oct 2023) has API incompatibilities with current libndpi
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/utoni/nDPId.git
PKG_SOURCE_VERSION:=84285ae42d8f70c976a6ee9be6ceb935aa215b18
PKG_MIRROR_HASH:=skip

PKG_MAINTAINER:=CyberMind <contact@cybermind.fr>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=COPYING

PKG_BUILD_PARALLEL:=1

# Out-of-source build required by nDPId
CMAKE_BINARY_SUBDIR:=build

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

NINJA := MAKEFLAGS="" $(STAGING_DIR_HOST)/bin/ninja \
	$(if $(findstring c,$(OPENWRT_VERBOSE)),-v)

define Build/Prepare
	$(call Build/Prepare/Default)
	$(SED) 's|MAKE_PROGRAM=.*CMAKE_MAKE_PROGRAM.*|MAKE_PROGRAM=make|' \
		$(PKG_BUILD_DIR)/CMakeLists.txt
endef

define Package/ndpid
  SECTION:=net
  CATEGORY:=Network
  TITLE:=nDPId - Lightweight Deep Packet Inspection Daemon
  URL:=https://github.com/utoni/nDPId
  DEPENDS:=+libpcap +libjson-c +libpthread +zlib +libstdcpp
endef

define Package/ndpid/description
  nDPId is a set of daemons and tools to capture, process and classify
  network traffic using nDPI. It provides a lightweight alternative to
  netifyd with a microservice architecture.

  Components:
  - nDPId: Traffic capture and DPI daemon
  - nDPIsrvd: Event distribution broker

  Note: Builds with bundled libndpi 5.x (OpenWrt feeds have 4.8 which is too old)
endef

define Package/ndpid/conffiles
/etc/config/ndpid
/etc/ndpid.conf
endef

# Build with bundled nDPI (fetches and builds libndpi automatically)
CMAKE_OPTIONS += \
	-DBUILD_NDPI=ON \
	-DENABLE_SYSTEMD=OFF \
	-DENABLE_ZLIB=ON \
	-DBUILD_EXAMPLES=OFF \
	-DBUILD_DAEMON=ON \
	-DENABLE_MEMORY_PROFILING=OFF \
	-DENABLE_SANITIZER=OFF \
	-DENABLE_COVERAGE=OFF

define Package/ndpid/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/nDPId $(1)/usr/sbin/ndpid
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/nDPIsrvd $(1)/usr/sbin/ndpisrvd

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/nDPId-test $(1)/usr/bin/ndpid-test 2>/dev/null || true

	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_CONF) ./files/ndpid.conf $(1)/etc/ndpid.conf

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/ndpid.config $(1)/etc/config/ndpid

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ndpid.init $(1)/etc/init.d/ndpid
	$(INSTALL_BIN) ./files/ndpisrvd.init $(1)/etc/init.d/ndpisrvd

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/90-ndpid-defaults $(1)/etc/uci-defaults/

	$(INSTALL_DIR) $(1)/usr/share/ndpid
	$(INSTALL_DATA) ./files/functions.sh $(1)/usr/share/ndpid/

	# Generate protocols.json from bundled nDPI source at build time.
	# Fall back to the pre-generated static file when nDPI source is not found
	# (e.g. when the package is installed without rebuilding nDPId from source).
	NDPI_MAIN=$$(find $(PKG_BUILD_DIR) -name "ndpi_main.c" -path "*/lib/*" 2>/dev/null | head -1); \
	if [ -n "$$NDPI_MAIN" ]; then \
		NDPI_SRC=$$(echo "$$NDPI_MAIN" | sed 's|/src/lib/ndpi_main.c||'); \
		python3 $(CURDIR)/files/gen-protocols.py "$$NDPI_SRC" $(1)/usr/share/ndpid/protocols.json; \
	else \
		$(INSTALL_DATA) ./files/protocols.json $(1)/usr/share/ndpid/protocols.json; \
	fi
endef

$(eval $(call BuildPackage,ndpid))
