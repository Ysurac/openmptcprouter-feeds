local m, s, o
local fs = require "nixio.fs"
local jsonc = require "luci.jsonc" or nil
m = Map("zerotier")
s=m:section(NamedSection,"sample_config","zerotier")
s.anonymous=true
s.addremove=false
o = s:option(TextValue, "manualconfig")
o.rows = 20
o.wrap = "soft"
o.rmempty = true
o.cfgvalue = function(self, section)
	return fs.readfile("/etc/config/zero/local.conf")
end
o.write = function(self, section, value)
	fs.writefile("/etc/config/zero/local.conf", value:gsub("\r\n", "\n"))
end
o.validate=function(self, value)
	if jsonc == nil or jsonc.parse(value)~=nil then
		return value
	end
	return nil
end
o.description='<a href="https://www.zerotier.com/manual/" target="_blank">https://www.zerotier.com/manual/</a><br><a href="https://github.com/zerotier/ZeroTierOne/blob/db813db7e875c257e42c41ab8091c3df1e9300a5/service/README.md" target="_blank">https://github.com/zerotier/ZeroTierOne/blob/db813db7e875c257e42c41ab8091c3df1e9300a5/service/README.md</a>'
return m