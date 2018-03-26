local ucic = uci.cursor()
module("luci.controller.openmptcprouter", package.seeall)

function index()
--	entry({"admin", "openmptcprouter"}, firstchild(), _("OpenMPTCProuter"), 19).index = true
--	entry({"admin", "openmptcprouter", "wizard"}, template("openmptcprouter/wizard"), _("Wizard"), 1).leaf = true
--	entry({"admin", "openmptcprouter", "wizard_add"}, post("wizard_add")).leaf = true
	entry({"admin", "system", "openmptcprouter"}, template("openmptcprouter/wizard"), _("Settings Wizard"), 1)
	entry({"admin", "system", "openmptcprouter", "wizard_add"}, post("wizard_add"))
end

function wizard_add()
	local server_ip = luci.http.formvalue("server_ip")
	local shadowsocks_key = luci.http.formvalue("shadowsocks_key")
	local glorytun_key = luci.http.formvalue("glorytun_key")
	if shadowsocks_key ~= "" then
		ucic:set("shadowsocks-libev","sss0","server",server_ip)
		ucic:set("shadowsocks-libev","sss0","key",shadowsocks_key)
		ucic:set("shadowsocks-libev","sss0","method","aes-256-cfb")
		ucic:set("shadowsocks-libev","sss0","server_port","65101")
		ucic:set("shadowsocks-libev","sss0","disabled",0)
		ucic:save("shadowsocks-libev")
		ucic:commit("shadowsocks-libev")
	end
	if glorytun_key ~= "" then
		ucic:set("glorytun","vpn","host",server_ip)
		ucic:set("glorytun","vpn","port","65001")
		ucic:set("glorytun","vpn","key",glorytun_key)
		ucic:set("glorytun","vpn","enable",1)
		ucic:set("glorytun","vpn","mptcp",1)
		ucic:set("glorytun","vpn","chacha20",1)
		ucic:set("glorytun","vpn","proto","tcp")
		ucic:save("glorytun")
		ucic:commit("glorytun")
	end

	local interfaces = luci.http.formvaluetable("intf")
	for intf, _ in pairs(interfaces) do
		local ipaddr = luci.http.formvalue("cbid.network.%s.ipaddr" % intf)
		local netmask = luci.http.formvalue("cbid.network.%s.netmask" % intf)
		local gateway = luci.http.formvalue("cbid.network.%s.gateway" % intf)
		ucic:set("network",intf,"ipaddr",ipaddr)
		ucic:set("network",intf,"netmask",netmask)
		ucic:set("network",intf,"gateway",gateway)
	end
	ucic:save("network")
	ucic:commit("network")
	luci.sys.call("(env -i /bin/ubus call network reload) >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/glorytun restart >/dev/null 2>/dev/null")
	luci.http.redirect(luci.dispatcher.build_url("admin/network/network"))
	return
end