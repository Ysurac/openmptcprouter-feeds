local fs = require "nixio.fs"
local conffile = "/etc/config/ipsec.users"

f = SimpleForm("custom", translate("IPSec VPN User List"), translate("Please refer to the following writing.account:password"))

t = f:field(TextValue, "conf")
t.rmempty = true
t.rows = 13
function t.cfgvalue()
	return fs.readfile(conffile) or ""
end

function f.handle(self, state, data)
	if state == FORM_VALID then
		if data.conf then
			fs.writefile(conffile, data.conf:gsub("\r\n", "\n"))
			luci.sys.call("/etc/init.d/ipsec reload")
			luci.sys.call("/etc/init.d/ipsec restart")
		end
	end
	return true
end

return f
