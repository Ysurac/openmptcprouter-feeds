local ucic = uci.cursor()
module("luci.controller.omr-bypass", package.seeall)

function index()
	entry({"admin", "services", "omr-bypass"}, alias("admin", "services", "omr-bypass", "index"), _("OMR-Bypass"))
	entry({"admin", "services", "omr-bypass", "index"}, template("omr-bypass/bypass"))
	entry({"admin", "services", "omr-bypass", "add"}, post("bypass_add"))
end

function bypass_add()
	local hosts = luci.http.formvalue("cbid.omr-bypass.hosts")
	if (type(hosts) ~= "table") then
		hosts = {hosts}
	end
	local ipset = ""
	for _, k in pairs(hosts) do
		if k ~= "" then
			ipset = ipset .. '/' .. k
		end
	end
	ucic:set_list("dhcp",ucic:get_first("dhcp","dnsmasq"),"ipset",ipset .. "/ss_rules_dst_bypass")
	ucic:save("dhcp")
	ucic:commit("dhcp")
	luci.sys.exec("/etc/init.d/dnsmasq restart")
	luci.http.redirect(luci.dispatcher.build_url("admin/services/omr-bypass"))
	return
end