-- Copyright 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Licensed to the public under the Apache License 2.0.

local ipc = require "luci.ip"
local sys = require "luci.sys"
local net = require "luci.model.network".init()
local ifaces = net:get_interfaces() or { net:get_interface() }

m = Map("omr-bypass", translate("Bypass"), translate("Here you can bypass ShadowSocks and VPN. If you set Interface to Default this use any working interface."))

s = m:section(TypedSection, "domains", translate("Domains"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

hn = s:option(Value, "name", translate("Domain"))
hn.datatype = "hostname"
hn.optional = false
hn.rmempty  = true

ifd = s:option(Value, "interface", translate("Interface"))
ifd.rmempty  = true

s = m:section(TypedSection, "ips", translate("IPs and Networks"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

ip = s:option(Value, "ip", translate("IP"))
ip.datatype = "ipaddr"
ip.rmempty  = true
ip.optional = false

ifi = s:option(Value, "interface", translate("Interface"))
ifi.rmempty  = true

s = m:section(TypedSection, "macs", translate("<abbr title=\"Media Access Control\">MAC</abbr>-Address"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

mac = s:option(Value, "mac", translate("MAC-Address"))
mac.datatype = "list(macaddr)"
mac.rmempty  = true
mac.optional = false

function mac.cfgvalue(self, option)
	local val = Value.cfgvalue(self, section)
	return ipc.checkmac(val) or val
end

sys.net.host_hints(function(m, v4, v6, name)
	if m then
		mac:value(m, "%s (%s)" %{m, name or v4 or v6})
	end
end)

ifm = s:option(Value, "interface", translate("Interface"))
ifm.rmempty  = true

s = m:section(TypedSection, "dpis", translate("Protocols"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

dpi = s:option(Value, "proto", translate("Protocol"))
dpi.rmempty  = true
dpi.optional = false
local protos = {}
for l in io.lines("/proc/net/xt_ndpi/proto") do
	local a,b,c,d = l:match('(%w+) (%w+)')
	if b ~= "2" and not string.match(b,"custom") then
		table.insert(protos,b)
	end
end
table.sort(protos)
for _,b in ipairs(protos) do
	dpi:value(b,"%s" % tostring(b))
end

ifp = s:option(ListValue, "interface", translate("Interface"))
ifp.rmempty  = true

ifd.default = "all"
ifi.default = "all"
ifp.default = "all"
ifm.default = "all"
ifd:value("all",translate("Default"))
ifi:value("all",translate("Default"))
ifp:value("all",translate("Default"))
ifm:value("all",translate("Default"))
for _, iface in ipairs(ifaces) do
	if iface:is_up() then
		ifd:value(iface:name(),"%s" % iface:name())
		ifi:value(iface:name(),"%s" % iface:name())
		ifp:value(iface:name(),"%s" % iface:name())
		ifm:value(iface:name(),"%s" % iface:name())
	end
end

return m
