local net = require "luci.model.network".init()
local sys = require "luci.sys"
local ifaces = sys.net:devices()
local m, s, o

m = Map("dsvpn", translate("DSVPN"))

s = m:section(TypedSection, "dsvpn", translate("Settings"))
s.anonymous   = true
s.addremove = false

o = s:option(Flag, "enable", translate("Enable"))
o.rmempty     = false

o = s:option(Value, "host", translate("Remote host"))
o.placeholder = "128.128.128.128"
o.default     = "128.128.128.128"
o.datatype    = "host"
o.rmempty     = false

o = s:option(Value, "port", translate("Remote/Bind port"))
o.placeholder = "65011"
o.default     = "65011"
o.datatype    = "port"

o = s:option(Value, "key", translate("Key"))
o.password    = true
o.rmempty     = false


o = s:option(Value, "localip", translate("Local IP"),translate("Tunnel local IP"))
o.default     = "10.255.251.2"
o.datatype    = "host"

o = s:option(Value, "remoteip", translate("Remote IP"),translate("Tunnel remote IP"))
o.default     = "10.255.251.1"
o.datatype    = "host"

o = s:option(Value, "dev", translate("Interface name"))
o.placeholder = "tun0"
o.default     = "tun0"
o.rmempty     = false

return m
