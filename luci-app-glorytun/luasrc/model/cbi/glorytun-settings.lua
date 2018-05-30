-- Copyright 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

require("luci.ip")
require("luci.model.uci")


local basicParams = {
	--
	-- Widget, Name, Default(s), Description
	--

	{ Flag,"enable",0, translate("Enable") },
	{ Value,"port",65001, translate("TCP port # for both local and remote") },
	{ Value,"dev","tun0", translate("Interface name") },
	{ Value,"host","vpnserver.example.org", translate("Remote host name or ip address") },
	{ Value,"localip","192.168.99.2", translate("Local tunnel ip address") },
	{ Value,"remoteip","192.168.99.1", translate("Remote tunnel ip address") },
	{ Value,"key","secretkey", translate("The secret key") },
	{ ListValue,"proto",{ "tcp", "udp" }, translate("Protocol") },
	{ Flag,"listener",0, translate("Server mode") },

	{ Value,"bind","", translate("Bind address") },
	--{ Value,"bind-backup","", translate("Bind backup") },
	{ Value,"bindport",65002, translate("Bind port") },
	{ Value,"mtu",1500, translate("MTU") },
	{ Flag,"mtuauto",0, translate("MTU auto") },

	{ Flag,"mptcp",0, translate("MPTCP") },
	{ Flag,"chacha20",0, translate("Use ChaCha20 stream cipher") }
}


local m = Map("glorytun")
local p = m:section( SimpleSection )

p.template = "glorytun/pageswitch"
p.mode     = "settings"
p.instance = arg[1]


local s = m:section( NamedSection, arg[1], "glorytun" )

for _, option in ipairs(basicParams) do
	local o = s:option(
		option[1], option[2],
		option[2], option[4]
	)
	
	o.optional = true

	if option[1] == DummyValue then
		o.value = option[3]
	else
		if option[1] == DynamicList then
			function o.cfgvalue(...)
				local val = AbstractValue.cfgvalue(...)
				return ( val and type(val) ~= "table" ) and { val } or val
			end
		end

		if type(option[3]) == "table" then
			if o.optional then o:value("", "-- remove --") end
			for _, v in ipairs(option[3]) do
				v = tostring(v)
				o:value(v)
			end
			o.default = tostring(option[3][1])
		else
			o.default = tostring(option[3])
		end
	end

	for i=5,#option do
		if type(option[i]) == "table" then
			o:depends(option[i])
		end
	end
end

return m

