--[[
LuCI - Lua Configuration Interface

Copyright (c) 2013 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

module("luci.controller.hyfi", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/hyd") then
		return
	end

	local page

	page = entry({"admin", "network", "hyfi"}, cbi("hyfi/hyfi"), _("HyFi Network"))
	page.dependent = true

end
