-- Copyright 2018 - 2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.glorytun", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/glorytun") then
		return
	end
	--entry({"admin", "services", "glorytun"}, cbi("glorytun"), _("Glorytun") )
	--entry({"admin", "services", "glorytun", "settings"}, cbi("glorytun-settings"), nil ).leaf = true
	entry({"admin", "vpn", "glorytun"}, cbi("glorytun"), _("Glorytun") )
	entry({"admin", "vpn", "glorytun", "settings"}, cbi("glorytun-settings"), nil ).leaf = true
end
