local math  = require "math"
local sys   = require "luci.sys"
local json  = require("luci.json")
local fs    = require("nixio.fs")
local net   = require "luci.model.network".init()
local ucic  = luci.model.uci.cursor()
local ipc = require "luci.ip"
module("luci.controller.status", package.seeall)

function index()
	entry({"admin", "system", "status"}, alias("admin", "system", "status", "server"), _("Settings"), 1)
	entry({"admin", "system", "status","server"}, template("status/server"),_('Settings'),1).leaf = true
	entry({"admin", "system", "status","status"}, template("status/wanstatus"),_('Status'),2).leaf = true
	entry({"admin", "system", "status","server_add"}, post("server_add"))
	entry({"admin", "system", "status", "interfaces_status"}, call("interfaces_status")).leaf = true
	entry({"admin", "system", "status", "multipath_bandwidth"}, call("multipath_bandwidth")).leaf = true
	entry({"admin", "system", "status", "interface_bandwidth"}, call("interface_bandwidth")).leaf = true
end

function server_add()
	local serversnb = 0
	local servers = luci.http.formvaluetable("server")
	for server, _ in pairs(servers) do
		local server_ip = luci.http.formvalue("%s.server_ip" % server) or ""
		local master = luci.http.formvalue("master") or ""

		-- OpenMPTCProuter VPS
		local openmptcprouter_vps_key = luci.http.formvalue("%s.openmptcprouter_vps_key" % server) or ""
		local openmptcprouter_vps_username = luci.http.formvalue("%s.openmptcprouter_vps_username" % server) or ""
		ucic:set("openmptcprouter",server,"server")
		ucic:set("openmptcprouter",server,"username",openmptcprouter_vps_username)
		ucic:set("openmptcprouter",server,"password",openmptcprouter_vps_key)
		if master == server or (master == "" and serversnb == 0) then
			ucic:set("openmptcprouter",server,"get_config","1")
			ucic:set("openmptcprouter",server,"master","1")
			ucic:set("openmptcprouter",server,"backup","0")
		else
			ucic:set("openmptcprouter",server,"get_config","0")
			ucic:set("openmptcprouter",server,"master","0")
			ucic:set("openmptcprouter",server,"backup","1")
		end
		if server_ip ~= "" then
			serversnb = serversnb + 1
		end
		ucic:set("openmptcprouter",server,"disabled",openmptcprouter_vps_disabled)
		ucic:set("openmptcprouter",server,"ip",server_ip)
		ucic:set("openmptcprouter",server,"port","65500")
		ucic:save("openmptcprouter")
	end

	local ss_servers_nginx = {}
	local ss_servers_ha = {}
	local vpn_servers = {}
	local k = 0
	local ss_ip

	for server, _ in pairs(servers) do
		local master = luci.http.formvalue("master") or ""
		local server_ip = luci.http.formvalue("%s.server_ip" % server) or ""
		-- We have an IP, so set it everywhere
		if server_ip ~= "" and luci.http.formvalue("%s.openmptcprouter_vps_disabled" % server) ~= "1" then
			-- Check if we have more than one IP, in this case use Nginx HA
			if serversnb > 1 then
				if master == server then
					ss_ip=server_ip
					ucic:set("shadowsocks-libev","sss0","server",server_ip)
					ucic:set("glorytun","vpn","host",server_ip)
					ucic:set("dsvpn","vpn","host",server_ip)
					ucic:set("mlvpn","general","host",server_ip)
					ucic:set("ubond","general","host",server_ip)
					luci.sys.call("uci -q del openvpn.omr.remote")
					luci.sys.call("uci -q add_list openvpn.omr.remote=" .. server_ip)
					ucic:set("qos","serverin","srchost",server_ip)
					ucic:set("qos","serverout","dsthost",server_ip)
				end
				k = k + 1
				ucic:set("nginx-ha","ShadowSocks","enable","0")
				ucic:set("nginx-ha","VPN","enable","0")
				ucic:set("haproxy-tcp","general","enable","0")
				ucic:set("openmptcprouter","settings","ha","1")
			else
				ucic:set("openmptcprouter","settings","ha","0")
				ucic:set("nginx-ha","ShadowSocks","enable","0")
				ucic:set("nginx-ha","VPN","enable","0")
				ucic:set("shadowsocks-libev","sss0","server",server_ip)
				ucic:set("glorytun","vpn","host",server_ip)
				ucic:set("dsvpn","vpn","host",server_ip)
				ucic:set("mlvpn","general","host",server_ip)
				ucic:set("ubond","general","host",server_ip)
				luci.sys.call("uci -q del openvpn.omr.remote")
				luci.sys.call("uci -q add_list openvpn.omr.remote=" .. server_ip)
				ucic:set("qos","serverin","srchost",server_ip)
				ucic:set("qos","serverout","dsthost",server_ip)
			end
		end
	end
	ucic:save("qos")
	ucic:commit("qos")
	ucic:save("nginx-ha")
	ucic:commit("nginx-ha")
	ucic:save("openvpn")
	ucic:commit("openvpn")
	ucic:save("mlvpn")
	ucic:save("ubond")
	ucic:commit("mlvpn")
	ucic:save("dsvpn")
	ucic:commit("dsvpn")
	ucic:save("glorytun")
	ucic:commit("glorytun")
	ucic:save("shadowsocks-libev")
	ucic:commit("shadowsocks-libev")
	luci.sys.call("(env -i /bin/ubus call network reload) >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/omr-tracker stop >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/mptcp restart >/dev/null 2>/dev/null")
	if openmptcprouter_vps_key ~= "" then
	    luci.sys.call("/etc/init.d/openmptcprouter-vps restart >/dev/null 2>/dev/null")
	    os.execute("sleep 2")
	end
	luci.sys.call("/etc/init.d/shadowsocks-libev restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/glorytun restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/glorytun-udp restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/mlvpn restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/ubond restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/openvpn restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/dsvpn restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/omr-tracker start >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/omr-6in4 restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/mptcpovervpn restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/vnstat restart >/dev/null 2>/dev/null")
	luci.http.redirect(luci.dispatcher.build_url("admin/system/status/status"))
end


function interfaces_status()
	local ut = require "luci.util"
	local mArray = ut.ubus("openmptcprouter", "status", {}) or {_=0}
	if mArray ~= nil and mArray.openmptcprouter ~= nil then
		mArray.openmptcprouter["remote_addr"] = luci.http.getenv("REMOTE_ADDR") or ""
		mArray.openmptcprouter["remote_from_lease"] = false
	--	local leases=dhcp_leases_common(4)
	--	for _, value in pairs(leases) do
	--		if value["ipaddr"] == mArray.openmptcprouter["remote_addr"] then
	--			mArray.openmptcprouter["remote_from_lease"] = true
	--			mArray.openmptcprouter["remote_hostname"] = value["hostname"]
	--		end
	--	end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(mArray)
end

-- This function come from modules/luci-bbase/luasrc/tools/status.lua from old OpenWrt
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.
local function dhcp_leases_common(family)
    local rv = { }
    local nfs = require "nixio.fs"
    local sys = require "luci.sys"
    local leasefile = "/tmp/dhcp.leases"

    ucic:foreach("dhcp", "dnsmasq",
        function(s)
	    if s.leasefile and nfs.access(s.leasefile) then
	        leasefile = s.leasefile
	        return false
	    end
        end)

    local fd = io.open(leasefile, "r")
    if fd then
	while true do
	    local ln = fd:read("*l")
	    if not ln then
		break
	    else
		local ts, mac, ip, name, duid = ln:match("^(%d+) (%S+) (%S+) (%S+) (%S+)")
		local expire = tonumber(ts) or 0
		if ts and mac and ip and name and duid then
		    if family == 4 and not ip:match(":") then
			rv[#rv+1] = {
			    expires  = (expire ~= 0) and os.difftime(expire, os.time()),
			    macaddr  = ipc.checkmac(mac) or "00:00:00:00:00:00",
			    ipaddr   = ip,
			    hostname = (name ~= "*") and name
			}
		    elseif family == 6 and ip:match(":") then
			rv[#rv+1] = {
			    expires  = (expire ~= 0) and os.difftime(expire, os.time()),
			    ip6addr  = ip,
			    duid     = (duid ~= "*") and duid,
			    hostname = (name ~= "*") and name
			}
		    end
		end
	    end
	end
	fd:close()
    end

    local lease6file = "/tmp/hosts/odhcpd"
    ucic:foreach("dhcp", "odhcpd",
        function(t)
	    if t.leasefile and nfs.access(t.leasefile) then
	        lease6file = t.leasefile
	        return false
	    end
    end)
    local fd = io.open(lease6file, "r")
    if fd then
	while true do
	    local ln = fd:read("*l")
	    if not ln then
		break
	    else
		local iface, duid, iaid, name, ts, id, length, ip = ln:match("^# (%S+) (%S+) (%S+) (%S+) (-?%d+) (%S+) (%S+) (.*)")
		local expire = tonumber(ts) or 0
		if ip and iaid ~= "ipv4" and family == 6 then
		    rv[#rv+1] = {
		        expires  = (expire >= 0) and os.difftime(expire, os.time()),
		        duid     = duid,
		        ip6addr  = ip,
		        hostname = (name ~= "-") and name
		    }
		elseif ip and iaid == "ipv4" and family == 4 then
		    rv[#rv+1] = {
		        expires  = (expire >= 0) and os.difftime(expire, os.time()),
		        macaddr  = sys.net.duid_to_mac(duid) or "00:00:00:00:00:00",
		        ipaddr   = ip,
		        hostname = (name ~= "-") and name
		    }
		end
	    end
	end
	fd:close()
    end

    if family == 6 then
	local _, lease
	local hosts = sys.net.host_hints()
	for _, lease in ipairs(rv) do
	    local mac = sys.net.duid_to_mac(lease.duid)
	    local host = mac and hosts[mac]
	    if host then
		if not lease.name then
		    lease.host_hint = host.name or host.ipv4 or host.ipv6
		elseif host.name and lease.hostname ~= host.name then
		    lease.host_hint = host.name
		end
	    end
	end
    end

    return rv
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

function string.split(input, delimiter)
	input = tostring(input)
	delimiter = tostring(delimiter)
	if (delimiter=='') then return false end
	local pos,arr = 0, {}
	-- for each divider found
	for st,sp in function() return string.find(input, delimiter, pos, true) end do
		table.insert(arr, string.sub(input, pos, st - 1))
		pos = sp + 1
	end
	table.insert(arr, string.sub(input, pos))
	return arr
end

function multipath_bandwidth()
	local result = { };
	local uci = luci.model.uci.cursor()
	local res={ };
	local str="";
	local tmpstr="";

	uci:foreach("network", "interface", function(s)
		local intname = s[".name"]
		local label = s["label"]
		local dev = get_device(intname)
		if dev == "" then
			dev = get_device(s["ifname"])
		end
		local multipath = s["multipath"] or ""
		if dev ~= "lo" and dev ~= "" then
			if multipath == "" then
				multipath = uci:get("openmptcprouter", intname, "multipath") or ""
			end
			if multipath == "" then
				multipath = "off"
			end
			if multipath == "on" or multipath == "master" or multipath == "backup" or multipath == "handover" then
				local bwc = luci.sys.exec("luci-bwc -i %q 2>/dev/null" % dev) or ""
				local bwc = luci.sys.exec("luci-bwc -i %q 2>/dev/null" % dev) or ""
				if bwc ~= nil then
					--result[dev] = "[" .. string.gsub(bwc, '[\r\n]', '') .. "]"
					if label ~= nil then
						result[intname .. " (" .. label .. ")" ] = "[" .. string.gsub(bwc, '[\r\n]', '') .. "]"
					else
						result[intname] = "[" .. string.gsub(bwc, '[\r\n]', '') .. "]"
					end
				else
					if label ~= nil then
						result[intname .. " (" .. label .. ")" ] = "[]"
					else
						result[intname] = "[]"
					end
				end
			end
		end
	end)

	res["total"]={ };
	for i=1,60 do
		res["total"][i]={}
		for j=1,5 do
			res["total"][i][j]=0
		end
	end

	for key,value in pairs(result) do
		res[key]={}
		value=(string.gsub(value, "^%[%[", ""))
		value=(string.gsub(value, "%]%]", ""))
		local temp1 = string.split(value, "],")
		if temp1[2] ~= nil then
			res[key][1]=temp1[1]
			for i=2,60 do
				res[key][i]={}
				if temp1[i] ~= nil then
					res[key][i]=(string.gsub(temp1[i], "%[", " "))
				end
			end
			for i=1,60 do
				res[key][i] = string.split(res[key][i], ",")
				for j=1,5 do
					if "string"== type(res[key][i][j]) then
						res[key][i][j]= tonumber(res[key][i][j])
					end
					if "string"==type(res["total"][i][j]) then
						res["total"][i][j]= tonumber(res["total"][i][j])
					end
					if j ==1 then
						if res[key][i][j] ~= nil then
							res["total"][i][j] = res[key][i][j]
						else
							res["total"][i][j] = 0
						end
					else
						if res[key][i][j] ~= nil then
							res["total"][i][j] = res["total"][i][j] + res[key][i][j]
						end
					end
				end
			end
		end
	end
	for i=1,60 do
		for j=1,5 do
			if "number"== type(res["total"][i][j]) then
				res["total"][i][j]= tostring(res["total"][i][j])
			end
		end
	end
	for i=1,60 do
		if i == 60 then
			tmpstr = "["..table.concat(res["total"][i], ",")
		else
			tmpstr = "["..table.concat(res["total"][i], ",").."],"
		end
		str  = str..tmpstr
	end
	str  = "["..str.."]]"
	result["total"]=str

	luci.http.prepare_content("application/json")
	luci.http.write_json(result)
end


function get_device(interface)
    local dump = require("luci.util").ubus("network.interface.%s" % interface, "status", {})
    if dump ~= nil then
	return dump['l3_device']
    else
	return ""
    end
end