
module("luci.controller.ipsec-server", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/ipsec") then
		return
	end

	entry({"admin", "vpn", "ipsec-server"},alias("admin", "vpn", "ipsec-server", "basic"),_("IPSec VPN Server"), 10).dependent = false
	entry({"admin", "vpn", "ipsec-server", "basic"},cbi("ipsec-server/ipsec-server"),_("Basic"), 10).leaf = true
	entry({"admin", "vpn", "ipsec-server", "user"},form("ipsec-server/userlist"),_("User"), 20).leaf = true
	entry({"admin", "vpn", "ipsec-server","status"},call("act_status")).leaf=true
end

function act_status()
  local e={}
  e.running=luci.sys.call("pgrep ipsec >/dev/null")==0
  luci.http.prepare_content("application/json")
  luci.http.write_json(e)
end
