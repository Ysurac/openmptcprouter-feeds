--[[
LuCI - Lua Configuration Interface

Copyright (c) 2013 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

module("luci.controller.wsplc", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/wsplcd") then
		return
	end

	local page

	page = entry({"admin", "network", "wsplc"}, cbi("wsplc/wsplc"), _("HyFi Security"))
	page.dependent = true

end
