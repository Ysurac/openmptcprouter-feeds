-- Copyright 2017 Yousong Zhou <yszhou4tech@gmail.com>
-- Licensed to the public under the Apache License 2.0.
--
module("luci.controller.shadowsocks-rust", package.seeall)

function index()
	entry({"admin", "proxy", "shadowsocks-rust"},
		alias("admin", "proxy", "shadowsocks-rust", "instances"),
		_("Shadowsocks-rust"), 10)

	entry({"admin", "proxy", "shadowsocks-rust", "instances"},
		view("shadowsocks-rust/instances"),
		_("Local Instances"), 10).leaf = true

	entry({"admin", "proxy", "shadowsocks-rust", "servers"},
		view("shadowsocks-rust/servers"),
		_("Remote Servers"), 20).leaf = true

	entry({"admin", "proxy", "shadowsocks-rust", "rules"},
		view("shadowsocks-rust/rules"),
		_("Redir Rules"), 30).leaf = true
end
