local m, s, o

if luci.sys.call("pgrep haproxy >/dev/null") == 0 then
	m = Map("haproxy-tcp", translate("HAProxy-TCP"), "%s - %s" %{translate("HAProxy-TCP"), translate("RUNNING")})
else
	m = Map("haproxy-tcp", translate("HAProxy-TCP"), "%s - %s" %{translate("HAProxy-TCP"), translate("NOT RUNNING")})
end

s = m:section(TypedSection, "general", translate("General Setting"),
	"<a target=\"_blank\" href=\"http://%s:%s\">%s</a>" %{
		luci.sys.exec("uci get network.lan.ipaddr | tr -d '\r\n'"),
		luci.sys.exec("uci get haproxy-tcp.general.admin_stats | tr -d '\r\n'"),
		translate("Status Admin")
		})
s.anonymous   = true

o = s:option(Flag, "enable", translate("Enable"))
o.rmempty     = false

o = s:option(Value, "startup_delay", translate("Startup Delay"))
o:value(0, translate("Not enabled"))
for _, v in ipairs({5, 10, 15, 25, 40}) do
	o:value(v, translate("%u seconds") %{v})
end
o.datatype = "uinteger"
o.default = 0
o.rmempty = false

o = s:option(Value, "admin_stats", "%s%s" %{translate("Status Admin"), translate("Port")})
o.placeholder = "7777"
o.default     = "7777"
o.datatype    = "port"
o.rmempty     = false

o = s:option(Value, "listen", translate("Listen Address:Port"))
o.placeholder = "0.0.0.0:6666"
o.default     = "0.0.0.0:6666"
o.rmempty     = false

o = s:option(Value, "timeout", translate("Timeout Connect (ms)"))
o.placeholder = "666"
o.default     = "666"
o.datatype    = "range(33, 10000)"
o.rmempty     = false

o = s:option(Value, "retries", translate("Retries"))
o.placeholder = "1"
o.default     = "1"
o.datatype    = "range(1, 10)"
o.rmempty     = false


o = s:option(DynamicList, "upstreams", translate("UpStream Server"), translate("e.g. [123.123.123.123:65101 weight 1 check]"))
o.placeholder = "123.123.123.123:65101 weight 1 check"
o.rmempty     = false

return m
