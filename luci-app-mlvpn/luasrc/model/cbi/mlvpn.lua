local net = require "luci.model.network".init()
local sys = require "luci.sys"
local ifaces = sys.net:devices()
local m, s, o

m = Map("mlvpn", translate("MLVPN"))

s = m:section(TypedSection, "mlvpn", translate("Settings"))
s.anonymous   = true
s.addremove = false

o = s:option(Flag, "enable", translate("Enable"))
o.rmempty     = false

o = s:option(Value, "timeout", translate("Timeout (s)"))
o.placeholder = "30"
o.default     = "30"
o.datatype    = "uinteger"
o.rmempty     = false

o = s:option(Value, "reorder_buffer_size", translate("Reorder buffer size"))
o.placeholder = "64"
o.default     = "64"
o.datatype    = "uinteger"
o.rmempty     = false

o = s:option(Value, "loss_tolerance", translate("Loss tolerance"))
o.placeholder = "50"
o.default     = "50"
o.datatype    = "uinteger"
o.rmempty     = false

o = s:option(Value, "host", translate("Remote host"))
o.placeholder = "128.128.128.128"
o.default     = "128.128.128.128"
o.datatype    = "host"
o.rmempty     = false

o = s:option(Value, "firstport", translate("First remote port"),translate("Interface will increase port used beginning with this"))
o.default     = "65201"
o.datatype    = "port"
o.rmempty     = false

o = s:option(Value, "password", translate("Password"))
o.password    = true
o.rmempty     = false


o = s:option(Value, "interface_name", translate("Interface name"))
o.placeholder = "mlvpn0"
o.default     = "mlvpn0"
o.rmempty     = false

--o = s:option(Value, "mode", translate("Mode"))
--o:value("client")
--o:value("server")
--o.default     = "client"
--o.rmempty     = false


--s = m:section(TypedSection, "interface", translate("Interfaces"))
--s.template_addremove = "mlvpn/cbi-select-add"
--s.addremove = true
--s.add_select_options = { }
--s.add_select_options[''] = ''
--for _, iface in ipairs(ifaces) do
--	if not (iface == "lo" or iface:match("^ifb.*")) then
--		s.add_select_options[iface] = iface
--	end
--end

--o = s:option(Value, "port", translate("Remote/Bind port"))
--o.placeholder = "65201"
--o.default     = "65201"
--o.datatype    = "port"

return m
