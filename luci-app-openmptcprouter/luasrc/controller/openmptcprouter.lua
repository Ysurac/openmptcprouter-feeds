local tools = require "luci.tools.status"
local sys   = require "luci.sys"
local json  = require("luci.json")
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
end

function wizard_add()
	local add_interface = luci.http.formvalue("add_interface") or ""
	local gostatus = true
	if add_interface ~= "" then
		local i = 1
		ucic:foreach("network", "interface", function(s)
			local sectionname = s[".name"]
			if sectionname:match("^wan(%d+)$") then
				i = i + 1
			end
		end)
		local defif = ucic:get("network","wan1","ifname") or "eth0"
		ucic:set("network","wan" .. i,"interface")
		ucic:set("network","wan" .. i,"ifname",defif)
		ucic:set("network","wan" .. i,"proto","static")
		ucic:set("network","wan" .. i,"type","macvlan")
		ucic:set("network","wan" .. i,"ip4table","wan")
		ucic:set("network","wan" .. i,"multipath","on")
		ucic:set("network","wan" .. i,"defaultroute","0")
		ucic:save("network")
		ucic:commit("network")
		-- Dirty way to add new interface to firewall...
		luci.sys.call("uci -q add_list firewall.@zone[1].network=wan" .. i)

		luci.sys.call("/etc/init.d/macvlan restart >/dev/null 2>/dev/null")
		gostatus = false
	end

	local delete_intf = luci.http.formvaluetable("delete")
	if delete_intf ~= "" then
		for intf, _ in pairs(delete_intf) do
			ucic:delete("network",intf)
			ucic:delete("network",intf .. "_dev")
			ucic:save("network")
			ucic:commit("network")
		end
		gostatus = false
	end
	
	local server_ip = luci.http.formvalue("server_ip")

	-- Set ShadowSocks settings
	local shadowsocks_key = luci.http.formvalue("shadowsocks_key")
	if shadowsocks_key ~= "" then
		ucic:set("shadowsocks-libev","sss0","server",server_ip)
		ucic:set("shadowsocks-libev","sss0","key",shadowsocks_key)
		ucic:set("shadowsocks-libev","sss0","method","aes-256-cfb")
		ucic:set("shadowsocks-libev","sss0","server_port","65101")
		ucic:set("shadowsocks-libev","sss0","disabled",0)
		ucic:save("shadowsocks-libev")
		ucic:commit("shadowsocks-libev")
	end

	-- Set Glorytun TCP settings
	local glorytun_key = luci.http.formvalue("glorytun_key")
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

	-- Set interfaces settings
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
	if gostatus then
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
	luci.sys.exec("sed -i 's:^net.ipv4.tcp_keepalive_time = [0-9]*:net.ipv4.tcp_keepalive_time=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % tcp_keepalive_time)
	
	-- Disable IPv6
	local disable_ipv6 = luci.http.formvalue("disable_ipv6") or 0
	luci.sys.exec("sysctl -w net.ipv6.conf.all.disable_ipv6=%s" % disable_ipv6)
	luci.sys.exec("sed -i 's:^net.ipv6.conf.all.disable_ipv6 = [0-9]*:net.ipv6.conf.all.disable_ipv6=%s:' /etc/sysctl.d/zzz_openmptcprouter.conf" % disable_ipv6)
	ucic:set("firewall",ucic:get_first("firewall","defaults"),"disable_ipv6",disable_ipv6)
	ucic:save("firewall")
	ucic:commit("firewall")
	if disable_ipv6 == 1 then
		ucic:set("shadowsocks-libev","hi","local_address","0.0.0.0")
	else
		ucic:set("shadowsocks-libev","hi","local_address","::")
	end
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
	local ip
	if dump and dump['ipv4-address'] then
		local _, ipv4address
		for _, ipv4address in ipairs(dump['ipv4-address']) do
			ip = dump['ipv4-address'][_].address
		end
	end
	return ip
end

-- This function come from OverTheBox by OVH with very small changes
function interfaces_status()
	local ut      = require "luci.util"
	local ntm     = require "luci.model.network".init()
	local uci     = require "luci.model.uci".cursor()

	local mArray = {}

	-- OpenMPTCProuter info
	mArray.openmptcprouter = {}
	mArray.openmptcprouter["version"] = ut.trim(sys.exec("cat /etc/os-release | grep VERSION= | sed -e 's:VERSION=::'"))
	-- Check that requester is in same network
	mArray.openmptcprouter["service_addr"] = uci:get("shadowsocks", "proxy", "server") or "0.0.0.0"
	mArray.openmptcprouter["local_addr"] = uci:get("network", "lan", "ipaddr")

	-- shadowsocksaddr
	mArray.openmptcprouter["ss_addr"] = sys.exec("curl -s -4 --socks5 127.0.0.1:1111 -m 2 http://ip.openmptcprouter.com")
	-- wanaddr
	mArray.openmptcprouter["wan_addr"] = sys.exec("wget -4 -qO- -T 1 http://ip.openmptcprouter.com")

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
	if string.find(sys.exec("/usr/bin/pgrep '^(/usr/sbin/)?glorytun(-udp)?$'"), "%d+") then
		mArray.openmptcprouter["tun_service"] = true
		mArray.openmptcprouter["tun_ip"] = get_ip("glorytun")
		local tunnel_ping_test = ut.trim(sys.exec("ping -W 1 -c 1 10.0.0.1 | grep '100% packet loss'"))
		if tunnel_ping_test == "" then
			mArray.openmptcprouter["tun_state"] = 'UP'
		else
			mArray.openmptcprouter["tun_state"] = 'DOWN'
		end

	end
	
	mArray.openmptcprouter["socks_service"] = false
	if string.find(sys.exec("/usr/bin/pgrep ss-redir"), "%d+") then
		mArray.openmptcprouter["socks_service"] = true
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
	    local gateway = section['gateway'] or ""
	    local multipath = section['multipath']

	    --if not ipaddr or not gateway then return end
	    -- Don't show if0 in the overview
	    --if interface == "lo" then return end

	    local ifname = section['ifname'] or ""
	    --if multipath == "off" and not ifname:match("^tun.*") then return end
	    if multipath == "off" then return end

	    local asn

	    local connectivity
	    local multipath_state = ut.trim(sys.exec("multipath " .. ifname .. " | grep deactivated"))
	    if multipath_state == "" and ifname ~= "" then
		    connectivity = 'OK'
	    else
		    connectivity = 'ERROR'
	    end

	    local gw_ping
	    if gateway ~= "" then
		    local gw_ping_test = ut.trim(sys.exec("ping -W 1 -c 1 " .. gateway .. " | grep '100% packet loss'"))
		    if gw_ping_test == "" then
			    gw_ping = 'UP'
		    else
			    gw_ping = 'DOWN'
			    if connectivity == "OK" then
				connectivity = 'WARNING'
			    end
		    end
	    end

	    local publicIP = "-"

	    local latency = "-"

	    local data = {
		label = section['label'] or interface,
		    name = interface,
		    link = net:adminlink(),
		    ifname = ifname,
		    ipaddr = ipaddr,
		    gateway = gateway,
		    multipath = section['multipath'],
		    status = connectivity,
		    wanip = publicIP,
		    latency = latency,
		    whois = asn and asn.as_description or "unknown",
		    qos = section['trafficcontrol'],
		    download = section['download'],
		    upload = section['upload'],
		    gw_ping = gw_ping,
	    }

	    if ifname:match("^tun.*") then
		    table.insert(mArray.tunnels, data);
	    else
		    table.insert(mArray.wans, data);
	    end
	end)

	luci.http.prepare_content("application/json")
	luci.http.write_json(mArray)
end