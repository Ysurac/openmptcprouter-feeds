-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Copyright 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.mptcp", package.seeall)

function index()
	entry({"admin", "network", "mptcp"}, alias("admin", "network", "mptcp", "settings"), _("MPTCP"))
	entry({"admin", "network", "mptcp", "settings"}, cbi("mptcp"), _("Settings"),2).leaf = true
	entry({"admin", "network", "mptcp", "bandwidth"}, template("mptcp/multipath"), _("Bandwidth"), 3).leaf = true
	entry({"admin", "network", "mptcp", "multipath_bandwidth"}, call("multipath_bandwidth")).leaf = true
	entry({"admin", "network", "mptcp", "interface_bandwidth"}, call("interface_bandwidth")).leaf = true
end

function interface_bandwidth(iface)
	luci.http.prepare_content("application/json")
	local bwc = io.popen("luci-bwc -i %q 2>/dev/null" % iface)
	if bwc then
		luci.http.write("[")
		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end
		luci.http.write("]")
		bwc:close()
	end
end

function multipath_bandwidth()
	local result = { };
	local uci = luci.model.uci.cursor()

	uci:foreach("network", "interface", function(s)
		local dev = s["ifname"] or ""
		if dev ~= "lo" and dev ~= "" then
			local multipath = s["multipath"] or "off"
			if multipath == "on" or multipath == "master" or multipath == "backup" or multipath == "handover" then
				result[dev] = "[" .. string.gsub((luci.sys.exec("luci-bwc -i %q 2>/dev/null" % dev)), '[\r\n]', '') .. "]"
			end
		end
	end)

	luci.http.prepare_content("application/json")
	luci.http.write_json(result)
end
