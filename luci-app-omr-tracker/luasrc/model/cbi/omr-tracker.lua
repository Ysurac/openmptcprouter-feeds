local net = require "luci.model.network".init()
local sys = require "luci.sys"
local ifaces = sys.net:devices()
local m, s, o

m = Map("omr-tracker", translate("OMR-Tracker"), translate("OMR-Tracker detect when a connection is down and execute needed scripts"))

s = m:section(TypedSection, "defaults", translate("Defaults Settings"))
s.anonymous   = true

o = s:option(Flag, "enabled", translate("Enable"), translate("When tracker is disabled, connection failover is also disabled"))
o.default     = true
o.rmempty     = false

o = s:option(Value, "timeout", translate("Timeout (s)"))
o.placeholder = "1"
o.default     = "1"
o.datatype    = "range(1, 100)"
o.rmempty     = false

o = s:option(Value, "tries", translate("Tries"))
o.placeholder = "4"
o.default     = "4"
o.datatype    = "range(1, 10)"
o.rmempty     = false

o = s:option(Value, "interval", translate("Retry interval (s)"))
o.placeholder = "2"
o.default     = "2"
o.datatype    = "range(1, 100)"
o.rmempty     = false

o = s:option(ListValue, "type", translate("Type"), translate("Always ping gateway, then test connection by ping, httping or dns. None mode only ping gateway."))
o:value("ping","ping")
o:value("httping","httping")
o:value("dns","dns")
o:value("none","none")

o = s:option(DynamicList, "hosts", translate("Hosts"))
o.placeholder = "4.2.2.1"
o.default     = { "4.2.2.1", "8.8.8.8" }
o.rmempty     = false

s = m:section(TypedSection, "interface", translate("Interfaces"))
s.template_addremove = "omr-tracker/cbi-select-add"
s.addremove = true
s.add_select_options = { }
s.add_select_options[''] = ''
for _, iface in ipairs(ifaces) do
	if not (iface == "lo" or iface:match("^ifb.*")) then
		s.add_select_options[iface] = iface
	end
end

o = s:option(Flag, "enabled", translate("Enable"))
o.default     = true
o.rmempty     = false

o = s:option(Value, "timeout", translate("Timeout (s)"))
o.placeholder = "1"
o.default     = "1"
o.datatype    = "range(1, 100)"
o.rmempty     = false

o = s:option(Value, "tries", translate("Tries"))
o.placeholder = "4"
o.default     = "4"
o.datatype    = "range(1, 10)"
o.rmempty     = false

o = s:option(Value, "interval", translate("Retry interval (s)"))
o.placeholder = "2"
o.default     = "2"
o.datatype    = "range(1, 100)"
o.rmempty     = false

o = s:option(ListValue, "type", translate("Type"), translate("Always ping gateway, then test connection by ping, httping or dns. None mode only ping gateway."))
o:value("ping","ping")
o:value("httping","httping")
o:value("dns","dns")
o:value("none","none")

o = s:option(DynamicList, "hosts", translate("Hosts"))
o.placeholder = "4.2.2.1"
o.default     = { "4.2.2.1", "8.8.8.8" }
o.rmempty     = false


return m
