-- Copyright 2018-2019 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
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

ifd = s:option(ListValue, "interface", translate("Interface"))
ifd.rmempty  = true

dn = s:option(Value,"note",translate("Note"))

s = m:section(TypedSection, "ips", translate("IPs and Networks"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

ip = s:option(Value, "ip", translate("IP"))
ip.datatype = "ipaddr"
ip.rmempty  = true
ip.optional = false

ifi = s:option(ListValue, "interface", translate("Interface"))
ifi.rmempty  = true

inn = s:option(Value,"note",translate("Note"))


s = m:section(TypedSection, "dest_port", translate("Ports destination"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

dp = s:option(Value, "dport", translate("port"))
dp.rmempty  = true
dp.optional = false

proto = s:option(ListValue, "proto", translate("Protocol"))
proto:value("all",translate("ALL"))
proto:value("tcp","TCP")
proto:value("udp","UDP")
proto:value("icmp","ICMP")
proto.rmempty  = true
proto.optional = false

ifdp = s:option(ListValue, "interface", translate("Interface"))
ifdp.rmempty  = true

dpn = s:option(Value,"note",translate("Note"))

s = m:section(TypedSection, "macs", translate("<abbr title=\"Media Access Control\">MAC</abbr>-Address"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

mac = s:option(Value, "mac", translate("Source MAC-Address"))
mac.datatype = "list(macaddr)"
mac.rmempty  = true
mac.optional = false

sys.net.host_hints(function(m, v4, v6, name)
	if m then
		mac:value(m, "%s (%s)" %{m, name or v4 or v6})
	end
end)

ifm = s:option(ListValue, "interface", translate("Interface"))
ifm.rmempty  = true

macn = s:option(Value,"note",translate("Note"))

s = m:section(TypedSection, "lan_ip", translate("Source lan IP address or network"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

ip = s:option(Value, "ip", translate("IP Address"))
ip.datatype = "ipaddr"
ip.rmempty  = true
ip.optional = false

ifl = s:option(ListValue, "interface", translate("Interface"))
ifl.rmempty  = true

lanipn = s:option(Value,"note",translate("Note"))

s = m:section(TypedSection, "asns", translate("<abbr tittle=\"Autonomous System Number\">ASN</abbr>"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

asn = s:option(Value, "asn", translate("ASN"))
asn.rmempty  = true
asn.optional = false

ifa = s:option(ListValue, "interface", translate("Interface"))
ifa.rmempty  = true

asnn = s:option(Value,"note",translate("Note"))

s = m:section(TypedSection, "dpis", translate("Protocols and services"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

dpi = s:option(ListValue, "proto", translate("Protocol/Service"))
dpi.rmempty  = true
dpi.optional = false
local xt_ndpi_available = nixio.fs.access("/proc/net/xt_ndpi/proto")
if xt_ndpi_available then
	local protos = {}
	for l in io.lines("/proc/net/xt_ndpi/proto") do
		local a,b,c,d = l:match('(%w+) (%w+)')
		if b ~= "2" and not string.match(b,"custom") then
			table.insert(protos,b)
		end
	end
	table.sort(protos, function(a, b) return a:upper() < b:upper() end)
	for _,b in ipairs(protos) do
		dpi:value(b,"%s" % tostring(b))
	end
end

ifp = s:option(ListValue, "interface", translate("Interface"))
ifp.rmempty  = true

psn = s:option(Value,"note",translate("Note"))


ifd.default = "all"
ifi.default = "all"
ifp.default = "all"
ifm.default = "all"
ifl.default = "all"
ifa.default = "all"
ifdp.default = "all"
ifd:value("all",translate("Default"))
ifi:value("all",translate("Default"))
ifp:value("all",translate("Default"))
ifm:value("all",translate("Default"))
ifl:value("all",translate("Default"))
ifa:value("all",translate("Default"))
ifdp:value("all",translate("Default"))
for _, iface in ipairs(ifaces) do
	if iface:is_up() then
		ifd:value(iface:name(),"%s" % iface:name())
		ifi:value(iface:name(),"%s" % iface:name())
		ifp:value(iface:name(),"%s" % iface:name())
		ifm:value(iface:name(),"%s" % iface:name())
		ifl:value(iface:name(),"%s" % iface:name())
		ifa:value(iface:name(),"%s" % iface:name())
		ifdp:value(iface:name(),"%s" % iface:name())
	end
end

return m
