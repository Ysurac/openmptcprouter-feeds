#
# Copyright (C) 2016 chenhw2 <chenhw2@github.com>
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for nginx load balancing
LUCI_DEPENDS:=+nginx
KCONFIG:=CONFIG_NGINX_STREAM

PKG_LICENSE:=MIT

include ../luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
