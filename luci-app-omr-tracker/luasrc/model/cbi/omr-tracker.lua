local net = require "luci.model.network".init()
local sys = require "luci.sys"
local m, s, o

m = Map("omr-tracker", translate("OMR-Tracker"))

s = m:section(TypedSection, "proxy", translate("Proxy tracker Settings"), translate("Detect if Proxy is down and stop traffic redirection over it."))
s.anonymous   = true
s.addremove = false

local sdata = m:get('proxy')
if not sdata then
	m:set('proxy', nil, 'proxy')
	m:set('proxy', 'enabled', "1")
end

o = s:option(Flag, "enabled", translate("Enable"), translate("When tracker is disabled, connection failover is also disabled"))
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

o = s:option(Value, "wait_test", translate("Wait after a failed test (s)"))
o.placeholder = "0"
o.default     = "0"
o.datatype    = "range(0, 100)"
o.rmempty     = false

o = s:option(DynamicList, "hosts", translate("Hosts"), translate("IPs or domains must be available over http"))
o.placeholder = "bing.com"
o.default     = { "bing.com", "google.com" }
o.rmempty     = false


s = m:section(TypedSection, "server", translate("Server tracker Settings"), translate("Detect if Server is down and use defined backup server in this case."))
s.anonymous   = true
s.addremove = false

local sdata = m:get('server')
if not sdata then
	m:set('server', nil, 'server')
	m:set('server', 'enabled', "1")
end

o = s:option(Flag, "enabled", translate("Enable"), translate("When tracker is disabled, server failover is also disabled"))
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

o = s:option(Value, "wait_test", translate("Wait after a failed test (s)"))
o.placeholder = "0"
o.default     = "0"
o.datatype    = "range(0, 100)"
o.rmempty     = false

s = m:section(TypedSection, "defaults", translate("Defaults Settings"), translate("OMR-Tracker create needed routes and detect when a connection is down or up"))
s.anonymous   = true

o = s:option(Flag, "enabled", translate("Enable"), translate("When tracker is disabled, connection failover is also disabled"))
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

o = s:option(Value, "wait_test", translate("Wait after a failed test (s)"))
o.placeholder = "0"
o.default     = "0"
o.datatype    = "range(0, 100)"
o.rmempty     = false

o = s:option(ListValue, "type", translate("Type"), translate("Always ping gateway, then test connection by ping, httping or dns. None mode only ping gateway."))
o:value("ping","ping")
o:value("httping","httping")
o:value("dns","dns")
o:value("none","none")

o = s:option(Flag, "server_http_test", translate("Server http test"), translate("Check if connection work with http by sending a request to server"))
o.optional    = false
o.rmempty     = false
o.default     = true
o.disabled    = 0
o.enabled     = 1

o = s:option(Flag, "mail_alert", translate("Mail alert"), translate("Send a mail when connection state change"))
o.optional    = false
o.rmempty     = false
o.default     = false
o.disabled    = 0
o.enabled     = 1

o = s:option(Flag, "restart_down", translate("Restart if down"), translate("Restart interface if detected as down"))
o.optional    = false
o.rmempty     = false
o.default     = false
o.disabled    = 0
o.enabled     = 1

o = s:option(DynamicList, "hosts", translate("Hosts"), translate("Must be IPs and not domains"))
o.placeholder = "4.2.2.1"
o.default     = { "4.2.2.1", "8.8.8.8" }
o.rmempty     = false

o = s:option(DynamicList, "hosts6", translate("Hosts IPv6"), translate("Must be IPs and not domains"))
o.placeholder = "2001:4860:4860::8844"
o.default     = { "2001:4860:4860::8888", "2001:4860:4860::8844" }
o.rmempty     = false

s = m:section(TypedSection, "interface", translate("Interfaces"))
s.template_addremove = "omr-tracker/cbi-select-add"
s.addremove = true
s.add_select_options = { }
s.add_select_options[''] = ''
for _, iface in ipairs(net:get_networks()) do
	if not (iface:name() == "loopback") then
		s.add_select_options[iface:name()] = iface:name()
	end
end

o = s:option(Flag, "enabled", translate("Enable"))
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

o = s:option(Value, "wait_test", translate("Wait after a failed test (s)"))
o.placeholder = "0"
o.default     = "0"
o.datatype    = "range(0, 100)"
o.rmempty     = false

o = s:option(ListValue, "type", translate("Type"), translate("Always ping gateway, then test connection by ping, httping or dns. None mode only ping gateway."))
o:value("ping","ping")
o:value("httping","httping")
o:value("dns","dns")
o:value("none","none")

o = s:option(Flag, "server_http_test", translate("Server http test"), translate("Check if connection work with http by sending a request to server"))
o.optional    = false
o.rmempty     = false
o.default     = true
o.disabled    = 0
o.enabled     = 1

o = s:option(Flag, "mail_alert", translate("Mail alert"), translate("Send a mail when connection status change. You need to configure e-mail settings <a href=\"/cgi-bin/luci/admin/services/mail\">here</a>."))
o.optional    = false
o.rmempty     = false
o.default     = false
o.disabled    = 0
o.enabled     = 1

o = s:option(Flag, "restart_down", translate("Restart if down"), translate("Restart interface if detected as down"))
o.optional    = false
o.rmempty     = false
o.default     = false
o.disabled    = 0
o.enabled     = 1

o = s:option(DynamicList, "hosts", translate("Hosts"), translate("Must be IPs and not domains"))
o.placeholder = "4.2.2.1"
o.default     = { "4.2.2.1", "8.8.8.8" }
o.rmempty     = false

o = s:option(DynamicList, "hosts6", translate("Hosts IPv6"), translate("Must be IPs and not domains"))
o.placeholder = "2001:4860:4860::8844"
o.rmempty     = false

return m
