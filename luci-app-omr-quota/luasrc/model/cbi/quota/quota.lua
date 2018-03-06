-- Copyright 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Licensed to the public under the Apache License 2.0.

local fs = require "nixio.fs"
local net = require "luci.model.network".init()
local sys = require "luci.sys"
local ifaces = sys.net:devices()

m = Map("omr-quota", translate("Quota"), translate("Set quota, when quota is reached interface state is set to down"))

s = m:section(TypedSection, "interface", translate("Interfaces"))
s.addremove = true
s.anonymous = false

e = s:option(Flag, "enabled", translate("Enable"))
e.rmempty = false

intf = s:option(ListValue, "interface", translate("Interface name"))
for _, iface in ipairs(ifaces) do
	if not (iface == "lo" or iface:match("^ifb.*")) then
		intf:value(iface)
	end
end
intf.rmempty = false

tx = s:option(Value, "txquota", translate("TX quota (kbit)"))
tx.datatype = "uinteger"

rx = s:option(Value, "rxquota", translate("RX quota (kbit)"))
rx.datatype = "uinteger"

tt = s:option(Value, "ttquota", translate("TX+RX quota (kbit)"))
tt.datatype = "uinteger"

itv = s:option(Value, "interval", translate("Interval between check (s)"))
itv.datatype = "uinteger"

return m
