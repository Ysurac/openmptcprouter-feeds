local tools = require "luci.tools.status"
local sys   = require "luci.sys"
local json  = require("luci.json")
local fs    = require("nixio.fs")
local net   = require "luci.model.network".init()
local ucic = luci.model.uci.cursor()
module("luci.controller.openmptcprouter", package.seeall)

function index()
--	entry({"admin", "openmptcprouter"}, firstchild(), _("OpenMPTCProuter"), 19).index = true
--	entry({"admin", "openmptcprouter", "wizard"}, template("openmptcprouter/wizard"), _("Wizard"), 1).leaf = true
--	entry({"admin", "openmptcprouter", "wizard_add"}, post("wizard_add")).leaf = true
	entry({"admin", "system", "openmptcprouter"}, alias("admin", "system", "openmptcprouter", "wizard"), _("OpenMPTCProuter"), 1)
	entry({"admin", "system", "openmptcprouter", "wizard"}, template("openmptcprouter/wizard"), _("Settings Wizard"), 1)
	entry({"admin", "system", "openmptcprouter", "wizard_add"}, post("wizard_add"))
	entry({"admin", "system", "openmptcprouter", "status"}, template("openmptcprouter/wanstatus"), _("Status"), 2).leaf = true
	entry({"admin", "system", "openmptcprouter", "interfaces_status"}, call("interfaces_status")).leaf = true
	entry({"admin", "system", "openmptcprouter", "settings"}, template("openmptcprouter/settings"), _("Advanced Settings"), 3).leaf = true
	entry({"admin", "system", "openmptcprouter", "settings_add"}, post("settings_add")).leaf = true
	entry({"admin", "system", "openmptcprouter", "update_vps"}, post("update_vps")).leaf = true
end

function interface_from_device(dev)
	for _, iface in ipairs(net:get_networks()) do
		local ifacen = iface:name()
		local ifacename = ucic:get("network",ifacen,"ifname")
		if ifacename == dev then
			return ifacen
		end
	end
	return ""
end

function wizard_add()
	local gostatus = true
	-- Add new server
	local add_server = luci.http.formvalue("add_server") or ""
	local add_server_name = luci.http.formvalue("add_server_name") or ""
	if add_server ~= "" and add_server_name ~= "" then
		ucic:set("openmptcprouter",add_server_name:gsub("[^%w_]+","_"),"server")
		gostatus = false
	end

	-- Remove existing server
	local delete_server = luci.http.formvaluetable("deleteserver") or ""
	if delete_server ~= "" then
		for serverdel, _ in pairs(delete_server) do
			luci.sys.call("uci -q del openmptcprouter." .. serverdel)
			gostatus = false
		end
	end

	-- Add new interface
	local add_interface = luci.http.formvalue("add_interface") or ""
	local add_interface_ifname = luci.http.formvalue("add_interface_ifname") or ""
	if add_interface ~= "" then
		local i = 1
		local multipath_master = false
		ucic:foreach("network", "interface", function(s)
			local sectionname = s[".name"]
			if sectionname:match("^wan(%d+)$") then
				i = i + 1
			end
			if ucic:get("network",sectionname,"multipath") == "master" then
				multipath_master = true
			end
		end)
		local defif = "eth0"
		if add_interface_ifname == "" then
			local defif1 = ucic:get("network","wan1_dev","ifname") or ""
			if defif1 ~= "" then
				defif = defif1
			end
		else
			defif = add_interface_ifname
		end
		
		local ointf = interface_from_device(defif) or ""
		if ointf ~= "" then
			if ucic:get("network",ointf,"type") == "" then
				ucic:set("network",ointf,"type","macvlan")
			end
		end
		
		ucic:set("network","wan" .. i,"interface")
		ucic:set("network","wan" .. i,"ifname",defif)
		ucic:set("network","wan" .. i,"proto","static")
		if ointf ~= "" then
			ucic:set("network","wan" .. i,"type","macvlan")
		end
		ucic:set("network","wan" .. i,"ip4table","wan")
		if multipath_master then
			ucic:set("network","wan" .. i,"multipath","on")
		else
			ucic:set("network","wan" .. i,"multipath","master")
		end
		ucic:set("network","wan" .. i,"defaultroute","0")
		ucic:reorder("network","wan" .. i, i + 2)
		ucic:save("network")
		ucic:commit("network")

		ucic:set("qos","wan" .. i,"interface")
		ucic:set("qos","wan" .. i,"classgroup","Default")
		ucic:set("qos","wan" .. i,"enabled","0")
		ucic:set("qos","wan" .. i,"upload","4000")
		ucic:set("qos","wan" .. i,"download","100000")
		ucic:save("qos")
		ucic:commit("qos")

		ucic:set("sqm","wan" .. i,"queue")
		ucic:set("sqm","wan" .. i,"interface",defif)
		ucic:set("sqm","wan" .. i,"qdisc","fq_codel")
		ucic:set("sqm","wan" .. i,"script","simple.qos")
		ucic:set("sqm","wan" .. i,"qdisc_advanced","0")
		ucic:set("sqm","wan" .. i,"linklayer","none")
		ucic:set("sqm","wan" .. i,"enabled","0")
		ucic:set("sqm","wan" .. i,"debug_logging","0")
		ucic:set("sqm","wan" .. i,"verbosity","5")
		ucic:set("sqm","wan" .. i,"download","0")
		ucic:set("sqm","wan" .. i,"upload","0")
		ucic:save("sqm")
		ucic:commit("sqm")
		
		luci.sys.call("uci -q add_list vnstat.@vnstat[-1].interface=" .. defif)
		luci.sys.call("uci -q commit vnstat")

		-- Dirty way to add new interface to firewall...
		luci.sys.call("uci -q add_list firewall.@zone[1].network=wan" .. i)
		luci.sys.call("uci -q commit firewall")

		luci.sys.call("/etc/init.d/macvlan restart >/dev/null 2>/dev/null")
		gostatus = false
	end

	-- Remove existing interface
	local delete_intf = luci.http.formvaluetable("delete") or ""
	if delete_intf ~= "" then
		for intf, _ in pairs(delete_intf) do
			local defif = ucic:set("network",intf,"ifname")
			ucic:delete("network",intf)
			ucic:delete("network",intf .. "_dev")
			ucic:save("network")
			ucic:commit("network")
			ucic:delete("sqm",intf)
			ucic:save("sqm")
			ucic:commit("sqm")
			ucic:delete("qos",intf)
			ucic:save("qos")
			ucic:commit("qos")
			luci.sys.call("uci -q del_list vnstat.@vnstat[-1].interface=" .. defif)
			gostatus = false
		end
	end

	-- Set interfaces settings
	local interfaces = luci.http.formvaluetable("intf")
	for intf, _ in pairs(interfaces) do
		local proto = luci.http.formvalue("cbid.network.%s.proto" % intf) or "static"
		local ipaddr = luci.http.formvalue("cbid.network.%s.ipaddr" % intf) or ""
		local netmask = luci.http.formvalue("cbid.network.%s.netmask" % intf) or ""
		local gateway = luci.http.formvalue("cbid.network.%s.gateway" % intf) or ""
		if proto ~= "other" then
			ucic:set("network",intf,"proto",proto)
		end
		ucic:set("network",intf,"ipaddr",ipaddr)
		ucic:set("network",intf,"netmask",netmask)
		ucic:set("network",intf,"gateway",gateway)

		local downloadspeed = luci.http.formvalue("cbid.sqm.%s.download" % intf) or "0"
		local uploadspeed = luci.http.formvalue("cbid.sqm.%s.upload" % intf) or "0"
		if downloadspeed ~= "0" and uploadspeed ~= "0" then
			ucic:set("sqm",intf,"download",downloadspeed)
			ucic:set("sqm",intf,"upload",uploadspeed)
			ucic:set("sqm",intf,"enabled","1")
			ucic:set("qos",intf,"download",downloadspeed)
			ucic:set("qos",intf,"upload",uploadspeed)
			ucic:set("qos",intf,"enabled","1")
		else
			ucic:set("sqm",intf,"download","0")
			ucic:set("sqm",intf,"upload","0")
			ucic:set("sqm",intf,"enabled","0")
			ucic:set("qos",intf,"download","0")
			ucic:set("qos",intf,"upload","0")
			ucic:set("qos",intf,"enabled","0")
		end
	end
	ucic:save("sqm")
	ucic:commit("sqm")
	ucic:save("qos")
	ucic:commit("qos")
	ucic:save("network")
	ucic:commit("network")

	-- Enable/disable IPv6
	local disable_ipv6 = "0"
	local enable_ipv6 = luci.http.formvalue("enableipv6") or "0"
	if enable_ipv6 == "0" then 
		disable_ipv6 = "1"
	end
	set_ipv6_state(disable_ipv6)
	
	-- Get VPN set by default
	local default_vpn = luci.http.formvalue("default_vpn") or "glorytun_tcp"
	local vpn_port = ""
	local vpn_intf = ""
	if default_vpn:match("^glorytun.*") then
		vpn_port = 65001
		vpn_intf = "tun0"
	elseif default_vpn == "mlvpn" then
		vpn_port = 65201
		vpn_intf = "mlvpn0"
	elseif default_vpn == "openvpn" then
		vpn_port = 65301
		vpn_intf = "tun0"
	end
	if vpn_intf ~= "" then
		ucic:set("network","omrvpn","ifname",vpn_intf)
		ucic:save("network")
		ucic:commit("network")
	end

	-- Retrieve all server settings
	local getconf = 0
	local serversnb = 0
	local servers = luci.http.formvaluetable("server")
	for server, _ in pairs(servers) do
		local server_ip = luci.http.formvalue("%s.server_ip" % server) or ""
		local backup = luci.http.formvalue("%s.backup" % server) or "0"

		-- OpenMPTCProuter VPS
		local openmptcprouter_vps_key = luci.http.formvalue("%s.openmptcprouter_vps_key" % server) or ""
		ucic:set("openmptcprouter",server,"server")
		ucic:set("openmptcprouter",server,"username","openmptcprouter")
		ucic:set("openmptcprouter",server,"password",openmptcprouter_vps_key)
		if backup == "0" and getconf == 0 then
			ucic:set("openmptcprouter",server,"get_config","1")
			getconf = getconf + 1
		else
			ucic:set("openmptcprouter",server,"get_config","0")
		end
		ucic:set("openmptcprouter",server,"ip",server_ip)
		ucic:set("openmptcprouter",server,"backup",backup)
		ucic:set("openmptcprouter",server,"port","65500")
		ucic:save("openmptcprouter")
		if server_ip ~= "" then
			serversnb = serversnb + 1
		end
	end

	local ss_servers_nginx = {}
	local ss_servers_ha = {}
	local vpn_servers = {}
	local k = 0
	local ss_ip

	for server, _ in pairs(servers) do
		local server_ip = luci.http.formvalue("%s.server_ip" % server) or ""
		local backup = luci.http.formvalue("%s.backup" % server) or "0"
		-- We have an IP, so set it everywhere
		if server_ip ~= "" then
			-- Check if we have more than one IP, in this case use Nginx HA
			if serversnb > 1 then
				if backup == "0" then
					ss_ip=server_ip
					table.insert(ss_servers_nginx,server_ip .. ":65101 max_fails=2 fail_timeout=20s")
					table.insert(ss_servers_ha,server_ip .. ":65101 check")
					if vpn_port ~= "" then
						table.insert(vpn_servers,server_ip .. ":" .. vpn_port .. " max_fails=2 fail_timeout=20s")
					end
				else
					table.insert(ss_servers_nginx,server_ip .. ":65101 backup")
					table.insert(ss_servers_ha,server_ip .. ":65101 backup")
					if vpn_port ~= "" then
						table.insert(vpn_servers,server_ip .. ":" .. vpn_port .. " backup")
					end
				end
				k = k + 1
				ucic:set("nginx-ha","ShadowSocks","enable","1")
				ucic:set("nginx-ha","VPN","enable","1")
				ucic:set("nginx-ha","ShadowSocks","upstreams",ss_servers_nginx)
				ucic:set("nginx-ha","VPN","upstreams",vpn_servers)
				ucic:set("haproxy-tcp","general","enable","0")
				ucic:set("haproxy-tcp","general","upstreams",ss_servers_ha)
				server_ip = "127.0.0.1"
				--ucic:set("shadowsocks-libev","sss0","server",ss_ip)
			else
				ucic:set("nginx-ha","ShadowSocks","enable","0")
				ucic:set("nginx-ha","VPN","enable","0")
				--ucic:set("shadowsocks-libev","sss0","server",server_ip)
				--ucic:set("openmptcprouter","vps","ip",server_ip)
				--ucic:save("openmptcprouter")
			end
			ucic:set("shadowsocks-libev","sss0","server",server_ip)
			ucic:set("glorytun","vpn","host",server_ip)
			ucic:set("mlvpn","general","host",server_ip)
			luci.sys.call("uci -q del openvpn.omr.remote")
			luci.sys.call("uci -q add_list openvpn.omr.remote=" .. server_ip)
			ucic:set("qos","serverin","srchost",server_ip)
			ucic:set("qos","serverout","dsthost",server_ip)
		end
	end

	ucic:save("qos")
	ucic:commit("qos")
	ucic:save("nginx-ha")
	ucic:commit("nginx-ha")
	ucic:save("openvpn")
	ucic:commit("openvpn")
	ucic:save("mlvpn")
	ucic:commit("mlvpn")
	ucic:save("glorytun")
	ucic:commit("glorytun")
	ucic:save("shadowsocks-libev")
	ucic:commit("shadowsocks-libev")


	-- Set ShadowSocks settings
	local shadowsocks_key = luci.http.formvalue("shadowsocks_key")
	local shadowsocks_disable = luci.http.formvalue("disableshadowsocks") or "0"
	if shadowsocks_key ~= "" then
		ucic:set("shadowsocks-libev","sss0","key",shadowsocks_key)
		ucic:set("shadowsocks-libev","sss0","method","chacha20")
		ucic:set("shadowsocks-libev","sss0","server_port","65101")
		ucic:set("shadowsocks-libev","sss0","disabled",shadowsocks_disable)
		ucic:save("shadowsocks-libev")
		ucic:commit("shadowsocks-libev")
	else
		ucic:set("shadowsocks-libev","sss0","key","")
		ucic:set("shadowsocks-libev","sss0","disabled",shadowsocks_disable)
		ucic:save("shadowsocks-libev")
		ucic:commit("shadowsocks-libev")
		luci.sys.call("/etc/init.d/shadowsocks rules_down >/dev/null 2>/dev/null")
	end

	-- Set Glorytun settings
	if default_vpn:match("^glorytun.*") then
		ucic:set("glorytun","vpn","enable",1)
	else
		ucic:set("glorytun","vpn","enable",0)
	end

	local glorytun_key = luci.http.formvalue("glorytun_key")
	if glorytun_key ~= "" then
		ucic:set("glorytun","vpn","port","65001")
		ucic:set("glorytun","vpn","key",glorytun_key)
		ucic:set("glorytun","vpn","mptcp",1)
		ucic:set("glorytun","vpn","chacha20",1)
		if default_vpn == "glorytun_udp" then
			ucic:set("glorytun","vpn","proto","udp")
		else
			ucic:set("glorytun","vpn","proto","tcp")
		end
	else
		ucic:set("glorytun","vpn","key","")
		ucic:set("glorytun","vpn","enable",0)
		ucic:set("glorytun","vpn","proto","tcp")
	end
	ucic:save("glorytun")
	ucic:commit("glorytun")

	-- Set MLVPN settings
	if default_vpn == "mlvpn" then
		ucic:set("mlvpn","general","enable",1)
	else
		ucic:set("mlvpn","general","enable",0)
	end

	local mlvpn_password = luci.http.formvalue("mlvpn_password")
	if mlvpn_password ~= "" then
		ucic:set("mlvpn","general","password",mlvpn_password)
		ucic:set("mlvpn","general","firstport","65201")
		ucic:set("mlvpn","general","interface_name","mlvpn0")
	else
		--ucic:set("mlvpn","general","enable",0)
		ucic:set("mlvpn","general","password","")
	end
	ucic:save("mlvpn")
	ucic:commit("mlvpn")

	-- Set OpenVPN settings
	local openvpn_key = luci.http.formvalue("openvpn_key")
	if openvpn_key ~= "" then
		local openvpn_key_path = "/etc/luci-uploads/openvpn.key"
		local fp
		luci.http.setfilehandler(
			function(meta, chunk, eof)
				if not fp and meta and meta.name == "openvpn_key" then
					fp = io.open(openvpn_key_path, "w")
				end
				if fp and chunk then
					fp:write(chunk)
				end
				if fp and eof then
					fp:close()
				end
			end)
		ucic:set("openvpn","omr","secret",openvpn_key_path)
	end

	if default_vpn == "openvpn" then
		ucic:set("openvpn","omr","enabled",1)
	else
		ucic:set("openvpn","omr","enabled",0)
	end
	ucic:save("openvpn")
	ucic:commit("openvpn")

	-- OpenMPTCProuter VPS
	--local openmptcprouter_vps_key = luci.http.formvalue("openmptcprouter_vps_key") or ""
	--ucic:set("openmptcprouter","vps","username","openmptcprouter")
	--ucic:set("openmptcprouter","vps","password",openmptcprouter_vps_key)
	--ucic:set("openmptcprouter","vps","get_config","1")
	local shadowsocks_disable = luci.http.formvalue("disableshadowsocks") or "0"
	ucic:set("openmptcprouter","settings","shadowsocks_disable",shadowsocks_disable)
	ucic:set("openmptcprouter","settings","vpn",default_vpn)
	ucic:delete("openmptcprouter","settings","master_lcintf")
	ucic:save("openmptcprouter")
	ucic:commit("openmptcprouter")

	-- Restart all
	luci.sys.call("(env -i /bin/ubus call network reload) >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/mptcp restart >/dev/null 2>/dev/null")
	if openmptcprouter_vps_key ~= "" then
		luci.sys.call("/etc/init.d/openmptcprouter-vps restart >/dev/null 2>/dev/null")
		os.execute("sleep 2")
	end
	luci.sys.call("/etc/init.d/shadowsocks restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/glorytun restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/glorytun-udp restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/mlvpn restart >/dev/null 2>/dev/null")
	luci.sys.call("/etc/init.d/openvpn restart >/dev/null 2>/dev/null")
	if gostatus == true then
		luci.http.redirect(luci.dispatcher.build_url("admin/system/openmptcprouter/status"))
	else
		luci.http.redirect(luci.dispatcher.build_url("admin/system/openmptcprouter/wizard"))
	end
	return
end

function settings_add()
	-- Redirects all ports from VPS to OpenMPTCProuter
	local redirect_ports = luci.http.formvalue("redirect_ports") or "0"
	ucic:set("openmptcprouter","vps","redirect_ports",redirect_ports)

	-- Set tcp_keepalive_time
	local tcp_keepalive_time = luci.http.formvalue("tcp_keepalive_time")
	luci.sys.exec("sysctl -w net.ipv4.tcp_keepalive_time=%s" % tcp_keepalive_time)
	luci.sys.exec("sed -i 's:^net.ipv4.tcp_keepalive_time=[0-9]*:net.ipv4.tcp_keepalive_time=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % tcp_keepalive_time)

	-- Set tcp_fin_timeout
	local tcp_fin_timeout = luci.http.formvalue("tcp_fin_timeout")
	luci.sys.exec("sysctl -w net.ipv4.tcp_fin_timeout=%s" % tcp_fin_timeout)
	luci.sys.exec("sed -i 's:^net.ipv4.tcp_fin_timeout=[0-9]*:net.ipv4.tcp_fin_timeout=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % tcp_fin_timeout)
	
	-- Disable IPv6
	local disable_ipv6 = luci.http.formvalue("disable_ipv6") or 0
	set_ipv6_state(disable_ipv6)

	-- Enable/disable obfs
	local obfs = luci.http.formvalue("obfs") or 0
	ucic:foreach("shadowsocks-libev", "ss_redir", function (section)
		ucic:set("shadowsocks-libev",section[".name"],"obfs",obfs)
	end)
	ucic:set("shadowsocks-libev","tracker","obfs",obfs)

	ucic:save("shadowsocks-libev")
	ucic:commit("shadowsocks-libev")

	-- Set master to dynamic or static
	local master_type = luci.http.formvalue("master_type") or "static"
	ucic:set("openmptcprouter","settings","master",master_type)

	-- Set CPU scaling minimum frequency
	local scaling_min_freq = luci.http.formvalue("scaling_min_freq") or ""
	if scaling_min_freq ~= "" then
		ucic:set("openmptcprouter","settings","scaling_min_freq",scaling_min_freq)
	end

	-- Set CPU scaling maximum frequency
	local scaling_max_freq = luci.http.formvalue("scaling_max_freq") or ""
	if scaling_max_freq ~= "" then
		ucic:set("openmptcprouter","settings","scaling_max_freq",scaling_max_freq)
	end

	-- Set CPU governor
	local scaling_governor = luci.http.formvalue("scaling_governor") or ""
	if scaling_governor ~= "" then
		ucic:set("openmptcprouter","settings","scaling_governor",scaling_governor)
	end

	ucic:save("openmptcprouter")
	ucic:commit("openmptcprouter")

	-- Apply all settings
	luci.sys.call("/etc/init.d/openmptcprouter restart >/dev/null 2>/dev/null")

	-- Done, redirect
	luci.http.redirect(luci.dispatcher.build_url("admin/system/openmptcprouter/settings"))
	return
end

function update_vps()
	-- Update VPS
	local update_vps = luci.http.formvalue("flash") or ""
	if update_vps ~= "" then
		ucic:foreach("openmptcprouter", "server", function(s)
			local serverip = ucic:get("openmptcprouter",s[".name"],"ip")
			local adminport = ucic:get("openmptcprouter",s[".name"],"port") or "65500"
			local token = uci:get("openmptcprouter",s[".name"],"token") or ""
			if token ~= "" then
				sys.exec('curl -4 --max-time 20 -s -k -H "Authorization: Bearer ' .. token .. '" https://' .. serverip .. ":" .. adminport .. "/update")
				luci.sys.call("/etc/init.d/openmptcprouter-vps restart >/dev/null 2>/dev/null")
				luci.http.redirect(luci.dispatcher.build_url("admin/system/openmptcprouter/status"))
				return
			end
		end)
	end
end

function get_ip(interface)
	local dump = require("luci.util").ubus("network.interface.%s" % interface, "status", {})
	local ip = ""
	if dump and dump['ipv4-address'] then
		local _, ipv4address
		for _, ipv4address in ipairs(dump['ipv4-address']) do
			ip = dump['ipv4-address'][_].address
		end
	end
	if ip == "" then
		local dump = require("luci.util").ubus("network.interface.%s_4" % interface, "status", {})
		if dump and dump['ipv4-address'] then
			local _, ipv4address
			for _, ipv4address in ipairs(dump['ipv4-address']) do
				ip = dump['ipv4-address'][_].address
			end
		end
	end
	return ip
end

function get_device(interface)
	local dump = require("luci.util").ubus("network.interface.%s" % interface, "status", {})
	return dump['l3_device']
end

function get_gateway(interface)
	local gateway = ""
	local dump = nil

	dump = require("luci.util").ubus("network.interface.%s" % interface, "status", {})

	if dump and dump.route then
		local _, route
		for _, route in ipairs(dump.route) do
			if dump.route[_].target == "0.0.0.0" then
				gateway = dump.route[_].nexthop
			end
		end
	end
	
	if gateway == "" then
		dump = require("luci.util").ubus("network.interface.%s_4" % interface, "status", {})

		if dump and dump.route then
			local _, route
			for _, route in ipairs(dump.route) do
				if dump.route[_].target == "0.0.0.0" then
					gateway = dump.route[_].nexthop
				end
			end
		end
	end
	return gateway
end

-- This function come from OverTheBox by OVH with some changes
-- Copyright 2015 OVH <OverTheBox@ovh.net>
-- Simon Lelievre (simon.lelievre@corp.ovh.com)
-- Sebastien Duponcheel <sebastien.duponcheel@ovh.net>
-- Modified by Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Under GPL3+
function interfaces_status()
	local ut      = require "luci.util"
	local ntm     = require "luci.model.network".init()
	local uci     = require "luci.model.uci".cursor()

	local mArray = {}

	-- OpenMPTCProuter info
	mArray.openmptcprouter = {}
	--mArray.openmptcprouter["version"] = ut.trim(sys.exec("cat /etc/os-release | grep VERSION= | sed -e 's:VERSION=::'"))
	mArray.openmptcprouter["version"] = uci:get("openmptcprouter", "settings", "version") or ut.trim(sys.exec("cat /etc/os-release | grep VERSION= | sed -e 's:VERSION=::' -e 's/^.//' -e 's/.$//'"))

	mArray.openmptcprouter["latest_version_omr"] = uci:get("openmptcprouter", "latest_versions", "omr") or ""
	mArray.openmptcprouter["latest_version_vps"] = uci:get("openmptcprouter", "latest_versions", "vps") or ""
	
	mArray.openmptcprouter["service_addr"] = uci:get("shadowsocks-libev", "sss0", "server") or ""
	mArray.openmptcprouter["local_addr"] = uci:get("network", "lan", "ipaddr")
	mArray.openmptcprouter["server_mptcp"] = ""
	-- dns
	mArray.openmptcprouter["dns"] = false
	local dns_test = sys.exec("dig openmptcprouter.com | grep 'ANSWER: 0'")
	if dns_test == "" then
		mArray.openmptcprouter["dns"] = true
	end

	mArray.openmptcprouter["ipv6"] = "disabled"
	if tonumber((sys.exec("sysctl net.ipv6.conf.all.disable_ipv6")):match(" %d+")) == 0 then
		mArray.openmptcprouter["ipv6"] = "enabled"
	end

	mArray.openmptcprouter["ss_addr"] = ""
	--mArray.openmptcprouter["ss_addr6"] = ""
	mArray.openmptcprouter["wan_addr"] = ""
	mArray.openmptcprouter["wan_addr6"] = ""
	local tracker_ip = ""
	if mArray.openmptcprouter["dns"] == true then
		-- wanaddr
		--mArray.openmptcprouter["wan_addr"] = uci:get("openmptcprouter","omr","public_detected_ipv4") or ""
		mArray.openmptcprouter["wan_addr"] = ut.trim(sys.exec("wget -4 -qO- -T 1 http://ip.openmptcprouter.com"))
		if mArray.openmptcprouter["wan_addr"] == "" then
			mArray.openmptcprouter["wan_addr"] = ut.trim(sys.exec("dig TXT +timeout=2 +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'\"' '{print $2}'"))
		end
		if mArray.openmptcprouter["wan_addr"] == "" then
			mArray.openmptcprouter["wan_addr"] = ut.trim(sys.exec("dig +timeout=2 +short myip.opendns.com @resolver1.opendns.com"))
		end
		if mArray.openmptcprouter["ipv6"] == "enabled" then
			mArray.openmptcprouter["wan_addr6"] = uci:get("openmptcprouter","omr","public_detected_ipv6") or ""
			if mArray.openmptcprouter["wan_addr6"] == "" then
				mArray.openmptcprouter["wan_addr6"] = ut.trim(sys.exec("wget -6 -qO- -T 1 http://ipv6.openmptcprouter.com"))
			end
		end
		-- shadowsocksaddr
		mArray.openmptcprouter["ss_addr"] = uci:get("openmptcprouter","omr","detected_ss_ipv4") or ""
		if mArray.openmptcprouter["ss_addr"] == "" then
			tracker_ip = uci:get("shadowsocks-libev","tracker","local_address") or ""
			if tracker_ip ~= "" then
				local tracker_port = uci:get("shadowsocks-libev","tracker","local_port")
				mArray.openmptcprouter["ss_addr"] = ut.trim(sys.exec("curl -s -4 --socks5 " .. tracker_ip .. ":" .. tracker_port .. " -m 2 http://ip.openmptcprouter.com"))
				--mArray.openmptcprouter["ss_addr6"] = sys.exec("curl -s -6 --socks5 " .. tracker_ip .. ":" .. tracker_port .. " -m 3 http://ipv6.openmptcprouter.com")
			end
		end
	end

	mArray.openmptcprouter["remote_addr"] = luci.http.getenv("REMOTE_ADDR") or ""
	mArray.openmptcprouter["remote_from_lease"] = false
	local leases=tools.dhcp_leases()
	for _, value in pairs(leases) do
		if value["ipaddr"] == mArray.openmptcprouter["remote_addr"] then
			mArray.openmptcprouter["remote_from_lease"] = true
			mArray.openmptcprouter["remote_hostname"] = value["hostname"]
		end
	end

	-- Get VPS info
	ucic:foreach("openmptcprouter", "server", function(s)
		local serverip = uci:get("openmptcprouter",s[".name"],"ip")
		if serverip ~= "" and (mArray.openmptcprouter["service_addr"] == serverip or serverip == mArray.openmptcprouter["wan_addr"]) then
			mArray.openmptcprouter["vps_omr_version"] = uci:get("openmptcprouter", s[".name"], "omr_version") or ""
			mArray.openmptcprouter["vps_kernel"] = uci:get("openmptcprouter",s[".name"],"kernel") or ""
			mArray.openmptcprouter["vps_machine"] = uci:get("openmptcprouter",s[".name"],"machine") or ""
			local adminport = uci:get("openmptcprouter",s[".name"],"port") or "65500"
			local token = uci:get("openmptcprouter",s[".name"],"token") or ""
			if token ~= "" then
				local vpsinfo_json = sys.exec('curl -4 --max-time 2 -s -k -H "Authorization: Bearer ' .. token .. '" https://' .. serverip .. ':' .. adminport .. '/status')
				if vpsinfo_json ~= "" and vpsinfo_json ~= nil then
					local status, vpsinfo = pcall(function() 
						return json.decode(vpsinfo_json)
					end)
					if status and vpsinfo.vps ~= nil then
						mArray.openmptcprouter["vps_loadavg"] = vpsinfo.vps.loadavg or ""
						mArray.openmptcprouter["vps_uptime"] = vpsinfo.vps.uptime or ""
						mArray.openmptcprouter["vps_mptcp"] = vpsinfo.vps.mptcp or ""
						mArray.openmptcprouter["vps_admin"] = true
					else
						uci:set("openmptcprouter",s[".name"],"admin_error","1")
						uci:delete("openmptcprouter",s[".name"],"token")
						uci:save("openmptcprouter",s[".name"])
						uci:commit("openmptcprouter",s[".name"])
						mArray.openmptcprouter["vps_admin"] = false
					end
				else
					mArray.openmptcprouter["vps_admin"] = false
				end
			else
				mArray.openmptcprouter["vps_admin"] = false
			end
		end
	end)

	-- Check openmptcprouter service are running
	mArray.openmptcprouter["tun_service"] = false
	mArray.openmptcprouter["tun_state"] = ""
	mArray.openmptcprouter["tun6_state"] = ""
	if string.find(sys.exec("/usr/bin/pgrep '^(/usr/sbin/)?glorytun(-udp)?$'"), "%d+") or string.find(sys.exec("/usr/bin/pgrep '^(/usr/sbin/)?mlvpn?$'"), "%d+") or string.find(sys.exec("/usr/bin/pgrep '^(/usr/sbin/)?openvpn?$'"), "%d+") then
		mArray.openmptcprouter["tun_service"] = true
		mArray.openmptcprouter["tun_ip"] = get_ip("omrvpn")
		local tun_dev = uci:get("network","omrvpn","ifname")
		if tun_dev == "" then
			tun_dev = get_device("omrvpn")
		end
		if tun_dev ~= "" then
			local peer = get_gateway("omrvpn")
			if peer == "" then
				peer = ut.trim(sys.exec("ip -4 r list dev " .. tun_dev .. " | grep kernel | awk '/proto kernel/ {print $1}' | grep -v / | tr -d '\n'"))
			end
			if peer ~= "" then
				local tunnel_ping_test = ut.trim(sys.exec("ping -w 1 -c 1 -I " .. tun_dev .. " " .. peer .. " | grep '100% packet loss'"))
				if tunnel_ping_test == "" then
					mArray.openmptcprouter["tun_state"] = "UP"
				else
					mArray.openmptcprouter["tun_state"] = "DOWN"
				end
				if mArray.openmptcprouter["ipv6"] == "enabled" then
					local tunnel_ping6_test = ut.trim(sys.exec("ping6 -w 1 -c 1 -I 6in4-omr6in4 fe80::a00:1 | grep '100% packet loss'"))
					if tunnel_ping6_test == "" then
						mArray.openmptcprouter["tun6_state"] = "UP"
					else
						mArray.openmptcprouter["tun6_state"] = "DOWN"
					end
				end
			else
				mArray.openmptcprouter["tun_state"] = "DOWN"
				mArray.openmptcprouter["tun6_state"] = "DOWN"
			end
		end
	end
	
	-- check Shadowsocks is running
	mArray.openmptcprouter["socks_service"] = false
	if string.find(sys.exec("/usr/bin/pgrep ss-redir"), "%d+") then
		mArray.openmptcprouter["socks_service"] = true
	end

	mArray.openmptcprouter["socks_service_enabled"] = true
	local ss_server = uci:get("shadowsocks-libev","sss0","disabled") or "0"
	if ss_server == "1" then
		mArray.openmptcprouter["socks_service_enabled"] = false
	end

	-- Add DHCP infos by parsing dnsmasq config file
	mArray.openmptcprouter.dhcpd = {}
	dnsmasq = ut.trim(sys.exec("cat /var/etc/dnsmasq.conf*"))
	for itf, range_start, range_end, mask, leasetime in dnsmasq:gmatch("range=[%w,!:-]*set:(%w+),(%d+\.%d+\.%d+\.%d+),(%d+\.%d+\.%d+\.%d+),(%d+\.%d+\.%d+\.%d+),(%w+)") do
		mArray.openmptcprouter.dhcpd[itf] = {}
		mArray.openmptcprouter.dhcpd[itf].interface = itf
		mArray.openmptcprouter.dhcpd[itf].range_start = range_start
		mArray.openmptcprouter.dhcpd[itf].range_end = range_end
		mArray.openmptcprouter.dhcpd[itf].netmask = mask
		mArray.openmptcprouter.dhcpd[itf].leasetime = leasetime
		mArray.openmptcprouter.dhcpd[itf].router = mArray.openmptcprouter["local_addr"]
		mArray.openmptcprouter.dhcpd[itf].dns = mArray.openmptcprouter["local_addr"]
	end
	for itf, option, value in dnsmasq:gmatch("option=(%w+),([%w:-]+),(%d+\.%d+\.%d+\.%d+)") do
		if mArray.openmptcprouter.dhcpd[itf] then
			if option == "option:router" or option == "6" then
				mArray.openmptcprouter.dhcpd[itf].router = value
			end
			if option == "option:dns-server" or option == "" then
				mArray.openmptcprouter.dhcpd[itf].dns = value
			end
		end
	end

	-- Parse mptcp kernel info
	local mptcp = {}
	local fullmesh = ut.trim(sys.exec("cat /proc/net/mptcp_fullmesh"))
	for ind, addressId, backup, ipaddr in fullmesh:gmatch("(%d+), (%d+), (%d+), (%d+\.%d+\.%d+\.%d+)") do
		mptcp[ipaddr] = {}
		mptcp[ipaddr].index = ind
		mptcp[ipaddr].id    = addressId
		mptcp[ipaddr].backup= backup
		mptcp[ipaddr].ipaddr= ipaddr
	end

	-- retrieve core temperature
	--mArray.openmptcprouter["core_temp"] = sys.exec("cat /sys/devices/platform/coretemp.0/hwmon/hwmon0/temp2_input 2>/dev/null"):match("%d+")
	mArray.openmptcprouter["loadavg"] = sys.exec("cat /proc/loadavg 2>/dev/null"):match("[%d%.]+ [%d%.]+ [%d%.]+")
	mArray.openmptcprouter["uptime"] = sys.exec("cat /proc/uptime 2>/dev/null"):match("[%d%.]+")


	if  mArray.openmptcprouter["service_addr"] ~= "" and mArray.openmptcprouter["service_addr"] ~= "127.0.0.1" then
		mArray.openmptcprouter["vps_status"] = "DOWN"
	else
		mArray.openmptcprouter["vps_status"] = "UP"
	end
	-- overview status
	mArray.wans = {}
	mArray.tunnels = {}
	allintf = {}

	uci:foreach("network", "interface", function (section)
	    local interface = section[".name"]
	    local net = ntm:get_network(interface)
	    local ipaddr = net:ipaddr() or ""
	    local gateway = section["gateway"] or ""
	    local multipath = section["multipath"]
	    local enabled = section["auto"]

	    --if not ipaddr or not gateway then return end
	    -- Don't show if0 in the overview
	    --if interface == "lo" then return end

	    local ifname = section["ifname"] or ""
	    if ifname == "" then
		ifname = get_device(interface)
	    end
	    duplicateif = false
	    if ifname ~= "" and ifname ~= nil then
		if allintf[ifname] then
		    connectivity = "ERROR"
		    duplicateif = true
		else
		    allintf[ifname] = true
		end
	    end

	    --if multipath == "off" and not ifname:match("^tun.*") then return end
	    if multipath == "off" then return end
	    
	    if enabled == "0" then return end

	    local connectivity

	    if ifname ~= "" and ifname ~= nil then
		    if fs.access("/sys/class/net/" .. ifname) then
			    local multipath_state = ut.trim(sys.exec("multipath " .. ifname .. " | grep deactivated"))
			    if multipath_state == "" then
				connectivity = "OK"
			    else
				connectivity = "ERROR"
			    end
		    else
			    connectivity = "ERROR"
		    end
	    else
		    connectivity = "ERROR"
	    end

	    if ipaddr == "" and ifname ~= nil then
		    ipaddr = ut.trim(sys.exec("ip -4 -br addr ls dev " .. ifname .. " | awk -F'[ /]+' '{print $3}' | tr -d '\n'"))
	    end
	    if ipaddr == "" and ifname ~= nil then
		    ipaddr = ut.trim(sys.exec("ip -4 addr show dev " .. ifname .. " | grep -m 1 inet | awk '{print $2}' | cut -d'/' -s -f1 | tr -d '\n'"))
	    end
	    if ipaddr == "" then
		    connectivity = "ERROR"
	    end

	    -- Detect WAN gateway status
	    local gw_ping = "UP"
	    if gateway == "" then
		    gateway = get_gateway(interface)
	    end
	    if connectivity ~= "ERROR" and gateway == "" and ifname ~= nil then
		    if fs.access("/sys/class/net/" .. ifname) then
			    gateway = ut.trim(sys.exec("ip -4 r list dev " .. ifname .. " | grep kernel | awk '/proto kernel/ {print $1}' | grep -v / | tr -d '\n'"))
			    if gateway == "" then
				gateway = ut.trim(sys.exec("ip -4 r list dev " .. ifname .. " | grep default | awk '{print $3}' | tr -d '\n'"))
			    end
		    end
	    end
	    if connectivity ~= "ERROR" and gateway ~= "" then
		    local gw_ping_test = ut.trim(sys.exec("ping -w 1 -c 1 " .. gateway .. " | grep '100% packet loss'"))
		    if gw_ping_test ~= "" then
			    gw_ping = "DOWN"
			    if connectivity == "OK" then
				    connectivity = "WARNING"
			    end
		    end
	    elseif gateway == "" then
		    gw_ping = "DOWN"
		    connectivity = "ERROR"
	    end
	    
	    local latency = ""
	    local server_ping = ""
	    if connectivity ~= "ERROR" and ifname ~= "" and gateway ~= "" and gw_ping ~= "DOWN" and ifname ~= nil and mArray.openmptcprouter["service_addr"] ~= "" then
		    local serverip = mArray.openmptcprouter["service_addr"]
		    if serverip == "127.0.0.1" then
			    serverip = mArray.openmptcprouter["wan_addr"]
		    end
		    if serverip ~= "" then
			    local server_ping_test = sys.exec("ping -w 1 -c 1 -I " .. ifname .. " " .. serverip)
			    local server_ping_result = ut.trim(sys.exec("echo '" .. server_ping_test .. "' | grep '100% packet loss'"))
			    if server_ping_result ~= "" then
				    server_ping = "DOWN"
				    if connectivity == "OK" then
					    connectivity = "WARNING"
				    end
			    else
				    mArray.openmptcprouter["vps_status"] = "UP"
				    server_ping = "UP"
				    latency = ut.trim(sys.exec("echo '" .. server_ping_test .. "' | cut -d '/' -s -f5 | cut -d '.' -f1"))
			    end
		    end
	    end

	    local multipath_available
	    if connectivity ~= "ERROR" and mArray.openmptcprouter["dns"] == true and ifname ~= nil and ifname ~= "" and gateway ~= "" and gw_ping == "UP" then
		    -- Test if multipath can work on the connection
		    local multipath_available_state = uci:get("openmptcprouter",interface,"mptcp_status") or ""
		    if multipath_available_state == "" then
			    --if mArray.openmptcprouter["service_addr"] ~= "" then
			    --    multipath_available_state = ut.trim(sys.exec("omr-tracebox-mptcp " .. mArray.openmptcprouter["service_addr"] .. " " .. ifname .. " | grep 'MPTCP disabled'"))
			    --else
				    multipath_available_state = ut.trim(sys.exec("omr-mptcp-intf " .. ifname .. " | grep 'Nay, Nay, Nay'"))
			    --end
		    else
			    multipath_available_state = ut.trim(sys.exec("echo '" .. multipath_available_state .. "' | grep 'MPTCP disabled'"))
		    end
		    if multipath_available_state == "" then
			    multipath_available = "OK"
		    else
			    multipath_available_state_wan = ut.trim(sys.exec("omr-mptcp-intf " .. ifname .. " | grep 'Nay, Nay, Nay'"))
			    if multipath_available_state_wan == "" then
				    multipath_available = "OK"
				    if mArray.openmptcprouter["service_addr"] ~= "" and mArray.openmptcprouter["service_addr"] ~= "127.0.0.1" then
					    mArray.openmptcprouter["server_mptcp"] = "disabled"
				    end
			    else
				    multipath_available = "ERROR"
				    connectivity = "WARNING"
			    end
		    end
	    else
		    multipath_available = "NO CHECK"
	    end

	    
	    -- Detect if WAN get an IPv6
	    local ipv6_discover = "NONE"
	    if ifname ~= nil and mArray.openmptcprouter["ipv6"] == "enabled" then
		    local ipv6_result = _ipv6_discover(ifname)
		    if type(ipv6_result) == "table" and #ipv6_result > 0 then
			    local ipv6_addr_test
			    for k,v in ipairs(ipv6_result) do
				    if v.RecursiveDnsServer then
					    if type(v.RecursiveDnsServer) ~= "table" then
						    ipv6_addr_test = sys.exec("ip -6 addr | grep " .. v.RecursiveDnsServer)
						    if ipv6_addr_test == "" then
							    ipv6_discover = "DETECTED"
							    if connectivity == "OK" then
								    connectivity = "WARNING"
							    end
						    end
					    end
				    end
			    end
		    end
	    end

	    local publicIP = uci:get("openmptcprouter",interface,"publicip") or ""
	    if ifname ~= nil and publicIP == "" then
		    publicIP = ut.trim(sys.exec("omr-ip-intf " .. ifname))
	    end
	    local whois = ""
	    if publicIP ~= "" then
		    whois = uci:get("openmptcprouter",interface,"asn") or ""
		    if whois == "" then
			    --whois = ut.trim(sys.exec("whois " .. publicIP .. " | grep -i 'netname' | awk '{print $2}'"))
			    whois = ut.trim(sys.exec("wget -4 -qO- -T 1 'http://api.iptoasn.com/v1/as/ip/" .. publicIP .. "' | jsonfilter -q -e '@.as_description'"))
		    end
	    end
	    
	    local mtu = uci:get("openmptcprouter",interface,"mtu") or ""
	    if mtu == "" and ifname ~= nil then
		    mtu = ut.trim(sys.exec("cat /sys/class/net/" .. ifname .. "/mtu | tr -d '\n'"))
	    end

	    local data = {
		label = section["label"] or interface,
		name = interface,
		link = net:adminlink(),
		ifname = ifname,
		ipaddr = ipaddr,
		gateway = gateway,
		multipath = section["multipath"],
		status = connectivity,
		wanip = publicIP,
		latency = latency,
		mtu = mtu,
		whois = whois or "unknown",
		qos = section["trafficcontrol"],
		download = section["download"],
		upload = section["upload"],
		gw_ping = gw_ping,
		server_ping = server_ping,
		ipv6_discover = ipv6_discover,
		multipath_available = multipath_available,
		duplicateif = duplicateif,
	    }

	    if ifname ~= nil and ifname:match("^tun.*") then
		    table.insert(mArray.tunnels, data);
	    elseif ifname ~= nil and ifname:match("^mlvpn.*") then
		    table.insert(mArray.tunnels, data);
	    else
		    table.insert(mArray.wans, data);
	    end
	end)

	luci.http.prepare_content("application/json")
	luci.http.write_json(mArray)
end

-- This come from OverTheBox by OVH
-- Copyright 2015 OVH <OverTheBox@ovh.net>
-- Simon Lelievre (simon.lelievre@corp.ovh.com)
-- Sebastien Duponcheel <sebastien.duponcheel@ovh.net>
-- Under GPL3+
function _ipv6_discover(interface)
	local result = {}

	--local ra6_list = (sys.exec("rdisc6 -nm " .. interface))
	local ra6_list = (sys.exec("rdisc6 -n1 -r1 " .. interface))
	-- dissect results
	local lines = {}
	local index = {}
	ra6_list:gsub('[^\r\n]+', function(c)
	    table.insert(lines, c)
	    if c:match("Hop limit") then
		    table.insert(index, #lines)
	    end
	end)
	local ra6_result = {}
	for k,v in ipairs(index) do
		local istart = v
		local iend = index[k+1] or #lines

		local entry = {}
		for i=istart,iend - 1 do
			local level = lines[i]:find('%w')
			local line = lines[i]:sub(level)

			local param, value
			if line:match('^from') then
				param, value = line:match('(from)%s+(.*)$')
			else
				param, value = line:match('([^:]+):(.*)$')
				-- Capitalize param name and remove spaces
				param = param:gsub("(%a)([%w_']*)", function(first, rest) return first:upper()..rest:lower() end):gsub("[%s-]",'')
				param = param:gsub("%.$", '')
				-- Remove text between brackets, seconds and spaces
				value = value:lower()
				value = value:gsub("%(.*%)", '')
				value = value:gsub("%s-seconds%s-", '')
				value = value:gsub("^%s+", '')
				value = value:gsub("%s+$", '')
			end

			if entry[param] == nil then
				entry[param] = value
			elseif type(entry[param]) == "table" then
				table.insert(entry[param], value)
			else
				old = entry[param]
				entry[param] = {}
				table.insert(entry[param], old)
				table.insert(entry[param], value)
			end
		end
		table.insert(ra6_result, entry)
	end
	return ra6_result
end

function set_ipv6_state(disable_ipv6)
	-- Disable/Enable IPv6 support
	luci.sys.exec("sysctl -w net.ipv6.conf.all.disable_ipv6=%s" % disable_ipv6)
	luci.sys.exec("sed -i 's:^net.ipv6.conf.all.disable_ipv6=[0-9]*:net.ipv6.conf.all.disable_ipv6=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % disable_ipv6)

	-- Disable/Enable IPv6 for firewall
	ucic:set("firewall",ucic:get_first("firewall","defaults"),"disable_ipv6",disable_ipv6)
	ucic:save("firewall")
	ucic:commit("firewall")

	-- Disable/Enable IPv6 in OpenMPTCProuter settings
	ucic:set("openmptcprouter","settings","disable_ipv6",disable_ipv6)
	ucic:commit("openmptcprouter")

	-- Disable/Enable route announce of IPv6
	if disable_ipv6 == "1" then
		ucic:set("dhcp","lan","ra_default","0")
	--else
	--	ucic:set("dhcp","lan","ra_default","1")
	end

	-- Disable/Enable IPv6 DHCP and change Shadowsocks listen address
	if disable_ipv6 == "1" then
		luci.sys.call("uci -q del dhcp.lan.dhcpv6")
		luci.sys.call("uci -q del dhcp.lan.ra")
		luci.sys.call("uci -q del dhcp.lan.ra_default")
		ucic:set("shadowsocks-libev","hi","local_address","0.0.0.0")
	else
	--	ucic:set("dhcp","lan","dhcpv6","server")
	--	ucic:set("dhcp","lan","ra","server")
	--	ucic:set("dhcp","lan","ra_default","1")
		ucic:set("shadowsocks-libev","hi","local_address","::")
	end
	ucic:save("dhcp")
	ucic:commit("dhcp")
	--if disable_ipv6 == "1" then
	--	luci.sys.exec("/etc/init.d/odhcpd stop >/dev/null 2>&1")
	--	luci.sys.exec("/etc/init.d/odhcpd disable >/dev/null 2>&1")
	--else
	--	luci.sys.exec("/etc/init.d/odhcpd start >/dev/null 2>&1")
	--	luci.sys.exec("/etc/init.d/odhcpd enable >/dev/null 2>&1")
	--end
end