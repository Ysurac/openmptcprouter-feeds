#
# Copyright (C) 2017 Yousong Zhou <yszhou4tech@gmail.com>
# Copyright (C) 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for shadowsocks-libev
LUCI_DEPENDS:=+shadowsocks-libev-config +shadowsocks-libev-ss-local +shadowsocks-libev-ss-redir +shadowsocks-libev-ss-rules +shadowsocks-libev-ss-server +shadowsocks-libev-ss-tunnel +simple-obfs

PKG_LICENSE:=Apache-2.0

include ../luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
