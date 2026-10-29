#
# Copyright 2019-2020 ZHANG Zhao <Zhao.Zhang2@etu.univ-grenoble-alpes.fr>
# Copyright 2020 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the Apache License, Version 2.0 .
#
# Based on openwrt luci commit 4bfd1102236f7f737da4257ca7f6e56146fc80f6
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Dashboard Pages
LUCI_DEPENDS:=+luci-base +libiwinfo +ucode-mod-uloop

PKG_BUILD_DEPENDS:=iwinfo
PKG_LICENSE:=Apache-2.0

define Package/luci-mod-dashboard/conffiles
/etc/config/dashboard
endef

# Same date scheme as luci.mk, prefixed with 1 so the fork always sorts
# above the OpenWrt build and apk upgrade never replaces it
omr_fork_version=$(if $(DUMP),x,1$(strip $(shell \
	set -- $$(git log -1 --format="%ct %h" --abbrev=7 -- $(1) 2>/dev/null); \
	if [ -n "$$1" ]; then \
		printf '%s.%05d~%s' "$$(date --utc --date="@$$1" "+%y.%j")" "$$(($$1 % 86400))" "$$2"; \
	else \
		ts=$$(find $(1) -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -n1 | cut -d. -f1); \
		if [ -n "$$ts" ]; then \
			printf '%s.%05d' "$$(date --utc --date="@$$ts" "+%y.%j")" "$$(($$ts % 86400))"; \
		else \
			echo 0; \
		fi; \
	fi)))
PKG_VERSION:=$(call omr_fork_version,.)
PKG_PO_VERSION:=$(call omr_fork_version,po)

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

