--[[
LuCI - Lua Configuration Interface

Copyright (c) 2014 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

module("luci.controller.whc", package.seeall)

function index()
	if nixio.fs.access("/etc/config/lbd") then
        entry({"admin", "network", "whc"},
              alias("admin", "network", "whc", "lbd"),
              _("Whole Home Coverage"), 60)
    elseif nixio.fs.access("/etc/config/repacd") then
        entry({"admin", "network", "whc"},
              alias("admin", "network", "whc", "repacd"),
              _("Whole Home Coverage"), 60)
    end

    if nixio.fs.access("/etc/config/lbd") then
        entry({"admin", "network", "whc", "lbd"},
              cbi("whc/lbd"),
              _("Load Balancing Settings"), 10).leaf = true
    end

    if nixio.fs.access("/etc/config/repacd") then
        entry({"admin", "network", "whc", "repacd"},
              cbi("whc/repacd"),
              _("Range Extender Settings"), 20).leaf = true
    end
end
