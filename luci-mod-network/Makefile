#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
# Copyright (C) 2020-2021 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the Apache License, Version 2.0 .
#
# From https://github.com/openwrt/luci/commit/bc2d7b5b1ae2f70aacca4d9a7597bef5ef75c8f1

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Network Administration
LUCI_DEPENDS:=+luci-base +libiwinfo-lua +rpcd-mod-iwinfo +luci-lib-uqr

PKG_LICENSE:=Apache-2.0

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

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

