local tools = require "luci.tools.status"
local sys   = require "luci.sys"
local json  = require("luci.json")
local fs    = require("nixio.fs")
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
	entry({"admin", "system", "openmptcprouter", "mptcp_check"}, template("openmptcprouter/mptcp_check"), _("MPTCP Support Check"), 3).leaf = true
	entry({"admin", "system", "openmptcprouter", "mptcp_check_trace"}, post("mptcp_check_trace")).leaf = true
end

function wizard_add()
	local add_interface = luci.http.formvalue("add_interface") or ""
	local gostatus = true
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
		local defif = ucic:get("network","wan1_dev","ifname") or "eth0"
		ucic:set("network","wan" .. i,"interface")
		ucic:set("network","wan" .. i,"ifname",defif)
		ucic:set("network","wan" .. i,"proto","static")
		ucic:set("network","wan" .. i,"type","macvlan")
		ucic:set("network","wan" .. i,"ip4table","wan")
		if multipath_master then
			ucic:set("network","wan" .. i,"multipath","on")
		else
			ucic:set("network","wan" .. i,"multipath","master")
		end
		ucic:set("network","wan" .. i,"defaultroute","0")
		ucic:save("network")
		ucic:commit("network")
		-- Dirty way to add new interface to firewall...
		luci.sys.call("uci -q add_list firewall.@zone[1].network=wan" .. i)
		luci.sys.call("uci -q commit firewall")

		luci.sys.call("/etc/init.d/macvlan restart >/dev/null 2>/dev/null")
		gostatus = false
	end

	local delete_intf = luci.http.formvaluetable("delete") or ""
	if delete_intf ~= "" then
		for intf, _ in pairs(delete_intf) do
			ucic:delete("network",intf)
			ucic:delete("network",intf .. "_dev")
			ucic:save("network")
			ucic:commit("network")
		end
		gostatus = false
	end

	-- Set interfaces settings
	local interfaces = luci.http.formvaluetable("intf")
	for intf, _ in pairs(interfaces) do
		local ipaddr = luci.http.formvalue("cbid.network.%s.ipaddr" % intf) or ""
		local netmask = luci.http.formvalue("cbid.network.%s.netmask" % intf) or ""
		local gateway = luci.http.formvalue("cbid.network.%s.gateway" % intf) or ""
		ucic:set("network",intf,"ipaddr",ipaddr)
		ucic:set("network",intf,"netmask",netmask)
		ucic:set("network",intf,"gateway",gateway)

		local downloadspeed = luci.http.formvalue("cbid.sqm.%s.download" % intf) or ""
		local uploadspeed = luci.http.formvalue("cbid.sqm.%s.upload" % intf) or ""
		if downloadspeed ~= "" and uploadspeed ~= "" then
			ucic:set("sqm",intf,"download",downloadspeed)
			ucic:set("sqm",intf,"upload",uploadspeed)
			ucic:set("sqm",intf,"enabled","1")
		else
			ucic:set("sqm",intf,"enabled","0")
		end
	end
	ucic:save("sqm")
	ucic:commit("sqm")
	ucic:save("network")
	ucic:commit("network")

	-- Enable/disable IPv6
	local disable_ipv6 = "0"
	local enable_ipv6 = luci.http.formvalue("enableipv6") or "1"
	if enable_ipv6 == "0" then 
		disable_pv6 = "1"
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
	ucic:set("openmptcprouter","settings","vpn",default_vpn)
	ucic:save("openmptcprouter")
	ucic:commit("openmptcprouter")

	-- Get all servers ips
	local server_ip = luci.http.formvalue("server_ip") or ""
	-- We have an IP, so set it everywhere
	if server_ip ~= "" then
		local ss_ip
		-- Check if we have more than one IP, in this case use Nginx HA
		if (type(server_ip) == "table") then
			local ss_servers = {}
			local vpn_servers = {}
			local k = 0
			for _, ip in pairs(server_ip) do
				if k == 0 then
					ss_ip=ip
					table.insert(ss_servers,ip .. ":65101 max_fails=3 fail_timeout=30s")
					if vpn_port ~= "" then
						table.insert(vpn_servers,ip .. ":" .. vpn_port .. " max_fails=3 fail_timeout=30s")
					end
					ucic:set("qos","serverin","srchost",ip)
					ucic:set("qos","serverout","dsthost",ip)
					ucic:save("qos")
					ucic:commit("qos")
				else
					table.insert(ss_servers,ip .. ":65101 backup")
					if vpn_port ~= "" then
						table.insert(vpn_servers,ip .. ":" .. vpn_port .. " backup")
					end
				end
				k = k + 1
			end
			ucic:set("nginx-ha","ShadowSocks","enable","1")
			ucic:set("nginx-ha","VPN","enable","1")
			ucic:set("nginx-ha","ShadowSocks","upstreams",ss_servers)
			ucic:set("nginx-ha","VPN","upstreams",vpn_servers)
			ucic:save("nginx-ha")
			ucic:commit("nginx-ha")
			server_ip = "127.0.0.1"
			ucic:set("shadowsocks-libev","sss0","server",ss_ip)
			ucic:save("shadowsocks-libev")
			ucic:commit("shadowsocks-libev")
		else
			ucic:set("nginx-ha","ShadowSocks","enable","0")
			ucic:set("nginx-ha","VPN","enable","0")
			ucic:set("qos","serverin","srchost",server_ip)
			ucic:set("qos","serverout","dsthost",server_ip)
			ucic:save("qos")
			ucic:commit("qos")
			ucic:set("shadowsocks-libev","sss0","server",server_ip)
			ucic:save("shadowsocks-libev")
			ucic:commit("shadowsocks-libev")
		end
		ucic:set("glorytun","vpn","host",server_ip)
		ucic:save("glorytun")
		ucic:commit("glorytun")
		ucic:set("mlvpn","general","host",server_ip)
		ucic:save("mlvpn")
		ucic:commit("mlvpn")
		luci.sys.call("uci -q del openvpn.omr.remote")
		luci.sys.call("uci -q add_list openvpn.omr.remote=" .. server_ip)
		ucic:save("openvpn")
		ucic:commit("openvpn")
		ucic:set("qos","serverin","srchost",server_ip)
		ucic:set("qos","serverout","dsthost",server_ip)
		ucic:save("qos")
		ucic:commit("qos")
	end

	-- Set ShadowSocks settings
	local shadowsocks_key = luci.http.formvalue("shadowsocks_key")
	if shadowsocks_key ~= "" then
		ucic:set("shadowsocks-libev","sss0","key",shadowsocks_key)
		ucic:set("shadowsocks-libev","sss0","method","chacha20")
		ucic:set("shadowsocks-libev","sss0","server_port","65101")
		ucic:set("shadowsocks-libev","sss0","disabled",0)
		ucic:save("shadowsocks-libev")
		ucic:commit("shadowsocks-libev")
	else
		ucic:set("shadowsocks-libev","sss0","key","")
		ucic:set("shadowsocks-libev","sss0","disabled",1)
		ucic:save("shadowsocks-libev")
		ucic:commit("shadowsocks-libev")
	end

	-- Set Glorytun settings
	if default_vpn:match("^glorytun.*") then
		ucic:set("glorytun","vpn","enable",1)
		ucic:save("glorytun")
		ucic:commit("glorytun")
	else
		ucic:set("glorytun","vpn","enable",0)
		ucic:save("glorytun")
		ucic:commit("glorytun")
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
		ucic:save("glorytun")
		ucic:commit("glorytun")
	else
		ucic:set("glorytun","vpn","key","")
		ucic:set("glorytun","vpn","enable",0)
		ucic:set("glorytun","vpn","proto","tcp")
		ucic:save("glorytun")
		ucic:commit("glorytun")
	end

	-- Set MLVPN settings
	if default_vpn == "mlvpn" then
		ucic:set("mlvpn","general","enable",1)
		ucic:save("mlvpn")
		ucic:commit("mlvpn")
	else
		ucic:set("mlvpn","general","enable",0)
		ucic:save("mlvpn")
		ucic:commit("mlvpn")
	end

	local mlvpn_password = luci.http.formvalue("mlvpn_password")
	if mlvpn_password ~= "" then
		ucic:set("mlvpn","general","password",mlvpn_password)
		ucic:set("mlvpn","general","firstport","65201")
		ucic:set("mlvpn","general","interface_name","mlvpn0")
		ucic:save("mlvpn")
		ucic:commit("mlvpn")
	else
		ucic:set("mlvpn","general","enable",0)
		ucic:set("mlvpn","general","password","")
		ucic:save("mlvpn")
		ucic:commit("mlvpn")
	end

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
		ucic:commit("openvpn")
	end

	if default_vpn == "openvpn" then
		ucic:set("openvpn","omr","enabled",1)
		ucic:save("openvpn")
		ucic:commit("openvpn")
	else
		ucic:set("openvpn","omr","enabled",0)
		ucic:save("openvpn")
		ucic:commit("openvpn")
	end

	luci.sys.call("(env -i /bin/ubus call network reload) >/dev/null 2>/dev/null")
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
	-- Set tcp_keepalive_time
	local tcp_keepalive_time = luci.http.formvalue("tcp_keepalive_time")
	luci.sys.exec("sysctl -w net.ipv4.tcp_keepalive_time=%s" % tcp_keepalive_time)
	luci.sys.exec("sed -i 's:^net.ipv4.tcp_keepalive_time=[0-9]*:net.ipv4.tcp_keepalive_time=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % tcp_keepalive_time)

	-- Set tcp_fin_timeout
	local tcp_fin_timeout = luci.http.formvalue("tcp_fin_timeout")
	luci.sys.exec("sysctl -w net.ipv4.tcp_fin_timeoute=%s" % tcp_fin_timeout)
	luci.sys.exec("sed -i 's:^net.ipv4.tcp_fin_timeout=[0-9]*:net.ipv4.tcp_fin_timeout=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % tcp_fin_timeout)
	
	-- Disable IPv6
	local disable_ipv6 = luci.http.formvalue("disable_ipv6") or 0
	set_ipv6_state(disable_ipv6)

	local obfs = luci.http.formvalue("obfs") or 0
	ucic:foreach("shadowsocks-libev", "ss_redir", function (section)
		ucic:set("shadowsocks-libev",section[".name"],"obfs",obfs)
	end)
	ucic:set("shadowsocks-libev","tracker","obfs",obfs)

	ucic:save("shadowsocks-libev")
	ucic:commit("shadowsocks-libev")
	
	-- Set CPU scaling minimum frequency
	local scaling_min_freq = luci.http.formvalue("scaling_min_freq") or ""
	if scaling_min_freq ~= "" then
		ucic:set("openmptcprouter","settings","scaling_min_freq",scaling_min_freq)
		ucic:save("openmptcprouter")
		ucic:commit("openmptcprouter")
	end

	-- Set CPU scaling maximum frequency
	local scaling_max_freq = luci.http.formvalue("scaling_max_freq") or ""
	if scaling_max_freq ~= "" then
		ucic:set("openmptcprouter","settings","scaling_max_freq",scaling_max_freq)
		ucic:save("openmptcprouter")
		ucic:commit("openmptcprouter")
	end

	-- Set CPU governor
	local scaling_governor = luci.http.formvalue("scaling_governor") or ""
	if scaling_governor ~= "" then
		ucic:set("openmptcprouter","settings","scaling_governor",scaling_governor)
		ucic:save("openmptcprouter")
		ucic:commit("openmptcprouter")
	end

	luci.sys.call("/etc/init.d/openmptcprouter restart >/dev/null 2>/dev/null")

	-- Done, redirect
	luci.http.redirect(luci.dispatcher.build_url("admin/system/openmptcprouter/settings"))
	return
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
-- Under GPL3+
function interfaces_status()
	local ut      = require "luci.util"
	local ntm     = require "luci.model.network".init()
	local uci     = require "luci.model.uci".cursor()

	local mArray = {}

	-- OpenMPTCProuter info
	mArray.openmptcprouter = {}
	mArray.openmptcprouter["version"] = ut.trim(sys.exec("cat /etc/os-release | grep VERSION= | sed -e 's:VERSION=::'"))

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
		-- shadowsocksaddr
		tracker_ip = uci:get("shadowsocks-libev","tracker","local_address") or ""
		local tracker_port = uci:get("shadowsocks-libev","tracker","local_port")
		if tracker_ip ~= "" then
			mArray.openmptcprouter["ss_addr"] = sys.exec("curl -s -4 --socks5 " .. tracker_ip .. ":" .. tracker_port .. " -m 3 http://ip.openmptcprouter.com")
			--mArray.openmptcprouter["ss_addr6"] = sys.exec("curl -s -6 --socks5 " .. tracker_ip .. ":" .. tracker_port .. " -m 3 http://ipv6.openmptcprouter.com")
		end
		-- wanaddr
		mArray.openmptcprouter["wan_addr"] = sys.exec("wget -4 -qO- -T 1 http://ip.openmptcprouter.com")
		if mArray.openmptcprouter["ipv6"] == "enabled" then
			mArray.openmptcprouter["wan_addr6"] = sys.exec("wget -6 -qO- -T 1 http://ipv6.openmptcprouter.com")
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
				local tunnel_ping_test = ut.trim(sys.exec("ping -W 1 -c 1 " .. peer .. " -I " .. tun_dev .. " | grep '100% packet loss'"))
				if tunnel_ping_test == "" then
					mArray.openmptcprouter["tun_state"] = "UP"
				else
					mArray.openmptcprouter["tun_state"] = "DOWN"
				end
				if mArray.openmptcprouter["ipv6"] == "enabled" then
					local tunnel_ping6_test = ut.trim(sys.exec("ping6 -W 1 -c 1 fe80::a00:1 -I 6in4-omr6in4 | grep '100% packet loss'"))
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

	-- overview status
	mArray.wans = {}
	mArray.tunnels = {}

	uci:foreach("network", "interface", function (section)
	    local interface = section[".name"]
	    local net = ntm:get_network(interface)
	    local ipaddr = net:ipaddr()
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
		    end
	    end
	    if connectivity ~= "ERROR" and gateway ~= "" then
		    local gw_ping_test = ut.trim(sys.exec("ping -W 1 -c 1 " .. gateway .. " | grep '100% packet loss'"))
		    if gw_ping_test ~= "" then
			    gw_ping = "DOWN"
			    if connectivity == "OK" then
				    connectivity = "WARNING"
			    end
		    end
	    else
		    gw_ping = "DOWN"
		    connectivity = "ERROR"
	    end
	    
	    local latency = ""
	    local server_ping = ""
	    if connectivity ~= "ERROR" and ifname ~= "" and gateway ~= "" and gw_ping ~= "DOWN" and ifname ~= nil and mArray.openmptcprouter["service_addr"] ~= "" then
		    local server_ping_test = sys.exec("ping -W 1 -c 1 -I " .. ifname .. " " .. mArray.openmptcprouter["service_addr"])
		    local server_ping_result = ut.trim(sys.exec("echo '" .. server_ping_test .. "' | grep '100% packet loss'"))
		    if server_ping_result ~= "" then
			    server_ping = "DOWN"
			    if connectivity == "OK" then
				connectivity = "WARNING"
			    end
		    else
			    server_ping = "UP"
			    latency = ut.trim(sys.exec("echo '" .. server_ping_test .. "' | cut -d '/' -s -f4 | cut -d '.' -f1"))
		    end
	    end

	    local multipath_available
	    if connectivity ~= "ERROR" and mArray.openmptcprouter["dns"] == true and ifname ~= nil and ifname ~= "" and gateway ~= "" and gw_ping == "UP" then
		    -- Test if multipath can work on the connection
		    local multipath_available_state = ""
		    if mArray.openmptcprouter["service_addr"] ~= "" then
			    multipath_available_state = ut.trim(sys.exec("omr-tracebox-mptcp " .. mArray.openmptcprouter["service_addr"] .. " " .. ifname .. " | grep 'MPTCP enabled'"))
		    else
			    multipath_available_state = ut.trim(sys.exec("omr-mptcp-intf " .. ifname .. " | grep 'you are MPTCP-capable'"))
		    end
		    if multipath_available_state ~= "" then
			    multipath_available = "OK"
		    else
			    if mArray.openmptcprouter["service_addr"] ~= "" then
				    multipath_available_state_wan = ut.trim(sys.exec("omr-mptcp-intf " .. ifname .. " | grep 'Nay, Nay, Nay'"))
			    else
				    multipath_available_state_wan = "none"
			    end
			    if multipath_available_state_wan == "" then
				    multipath_available = "OK"
				    mArray.openmptcprouter["server_mptcp"] = "disabled"
			    else
				    multipath_available = "ERROR"
				    if mArray.openmptcprouter["socks_service"] == true and connectivity == "OK" then
					    connectivity = "ERROR"
				    elseif connectivity == "OK" then
					    connectivity = "WARNING"
				    end
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

	    local publicIP = ut.trim(sys.exec("omr-ip-intf " .. ifname))
	    local whois = ""
	    if publicIP ~= "" then
		whois = ut.trim(sys.exec("whois " .. publicIP .. " | grep -i 'netname' | awk '{print $2}'"))
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
		whois = whois or "unknown",
		qos = section["trafficcontrol"],
		download = section["download"],
		upload = section["upload"],
		gw_ping = gw_ping,
		server_ping = server_ping,
		ipv6_discover = ipv6_discover,
		multipath_available = multipath_available,
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

function mptcp_check_trace(iface)
	luci.http.prepare_content("text/plain")
	local tracebox
	local uci    = require "luci.model.uci".cursor()
	local interface = get_device(iface)
	local server = uci:get("shadowsocks-libev", "sss0", "server") or ""
	if server == "" then return end
	if interface == "" then
		tracebox = io.popen("tracebox -s /usr/share/tracebox/omr-mptcp-trace.lua " .. server)
	else
		tracebox = io.popen("tracebox -s /usr/share/tracebox/omr-mptcp-trace.lua -i " .. interface .. " " .. server)
	end
	if tracebox then
		while true do
			local ln = tracebox:read("*l")
			if not ln then break end
			luci.http.write(ln)
			luci.http.write("\n")
		end
	end
	return
end

function set_ipv6_state(disable_ipv6)
	luci.sys.exec("sysctl -w net.ipv6.conf.all.disable_ipv6=%s" % disable_ipv6)
	luci.sys.exec("sed -i 's:^net.ipv6.conf.all.disable_ipv6=[0-9]*:net.ipv6.conf.all.disable_ipv6=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % disable_ipv6)
	ucic:set("firewall",ucic:get_first("firewall","defaults"),"disable_ipv6",disable_ipv6)
	ucic:save("firewall")
	ucic:commit("firewall")
	if disable_ipv6 == 1 then
		ucic:set("dhcp","lan","ra_default","0")
	else
		ucic:set("dhcp","lan","ra_default","1")
	end
	if disable_ipv6 == 1 then
		luci.sys.call("uci -q del dhcp.lan.dhcpv6")
		luci.sys.call("uci -q del dhcp.lan.ra")
		ucic:set("shadowsocks-libev","hi","local_address","0.0.0.0")
	else
		ucic:set("dhcp","lan","dhcpv6","server")
		ucic:set("dhcp","lan","ra","server")
		ucic:set("shadowsocks-libev","hi","local_address","::")
	end
	ucic:save("dhcp")
	ucic:commit("dhcp")
end