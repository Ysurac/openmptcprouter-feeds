local ucic = luci.model.uci.cursor()
local dt = require "luci.cbi.datatypes"
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
	local domains_ipset = ""
	local ip_ipset = {}
	for _, k in pairs(hosts) do
		if k ~= "" then
			if dt.ipmask(k) then
				table.insert(ip_ipset, k)
			else
				domains_ipset = domains_ipset .. '/' .. k
			end
		end
	end
	ucic:set_list("omr-bypass","ips","ip",ip_ipset)

	local dpi = luci.http.formvalue("cbid.omr-bypass.dpi")
	if dpi ~= "" then
		if (type(dpi) ~= "table") then
			dpi = {dpi}
		end
		ucic:set_list("omr-bypass","dpi","proto",dpi)
	else
		ucic:delete("omr-bypass","dpi","proto")
	end

	local interface = luci.http.formvalue("cbid.omr-bypass.interface") or ""
	ucic:set("omr-bypass","defaults","ifname",interface)
	
	ucic:save("omr-bypass")
	ucic:commit("omr-bypass")
	ucic:set_list("dhcp",ucic:get_first("dhcp","dnsmasq"),"ipset",domains_ipset .. "/ss_rules_dst_bypass_all")
	ucic:save("dhcp")
	ucic:commit("dhcp")
	luci.sys.exec("/etc/init.d/dnsmasq reload")
	luci.sys.exec("/etc/init.d/omr-bypass restart")
	luci.http.redirect(luci.dispatcher.build_url("admin/services/omr-bypass"))
	return
end