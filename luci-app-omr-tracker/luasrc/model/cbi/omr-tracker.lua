local m, s, o

m = Map("omr-tracker", translate("OMR-Tracker"), translate("OMR-Tracker detect when a connection is down"))

s = m:section(TypedSection, "defaults", translate("Defaults Settings"))
s.anonymous   = true

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

o = s:option(ListValue, "type", translate("Type"), translate("Always ping gateway, then test connection by ping or dns. None mode only ping gateway."))
o:value("ping","ping")
o:value("dns","dns")
o:value("none","none")

o = s:option(DynamicList, "hosts", translate("Hosts"))
o.placeholder = "4.2.2.1"
o.default     = "4.2.2.1"
o.rmempty     = false

return m
