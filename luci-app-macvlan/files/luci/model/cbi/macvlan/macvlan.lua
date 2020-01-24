-- Copyright (C) 2019 X-WRT <dev@x-wrt.com>

local net = require "luci.model.network".init()
local ifaces = net:get_interfaces() or { net:get_interface() }

m = Map("macvlan", translate("Macvlan"), translate("You can configure Macvlan virtual interfaces base on the real itnerface you want."))

s = m:section(TypedSection, "macvlan", translate("Macvlan Settings"))
s.addremove = true
s.anonymous = false
s.template = "cbi/tblsection"

hn = s:option(Value, "ifname", translate("Interface"))
hn.rmempty  = false

for _, iface in ipairs(ifaces) do
	if iface:type() ~= "macvlan" then
		hn:value(iface:name(),"%s" % iface:name())
	end
end

return m
