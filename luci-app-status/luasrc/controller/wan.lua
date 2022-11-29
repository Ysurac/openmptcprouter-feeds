local math  = require "math"
local sys   = require "luci.sys"
local json  = require("luci.json")
local fs    = require("nixio.fs")
local net   = require "luci.model.network".init()
local ucic  = luci.model.uci.cursor()
local ipc = require "luci.ip"
module("luci.controller.wan", package.seeall)

function index()
	local ucic  = luci.model.uci.cursor()
	menuentry = "status"
	entry({"admin", "system", menuentry:lower()}, alias("admin", "system", menuentry:lower(), "wizard"), _(menuentry), 1)
	entry({"admin", "system", menuentry:lower(), "wizard"}, template("status/wan"), _("Settings Wizard"), 1)
	entry({"admin", "system", menuentry:lower(), "wizard_add"}, post("wizard_add"))
--	entry({"admin", "system", menuentry:lower(), "status"}, template("status/wanstatus"), _("Status"), 2).leaf = true
--	entry({"admin", "system", menuentry:lower(), "interfaces_status"}, call("interfaces_status")).leaf = true
--	entry({"admin", "system", menuentry:lower(), "settings"}, template("openmptcprouter/settings"), _("Advanced Settings"), 3).leaf = true
--	entry({"admin", "system", menuentry:lower(), "settings_add"}, post("settings_add"))
--	entry({"admin", "system", menuentry:lower(), "update_vps"}, post("update_vps"))
--	entry({"admin", "system", menuentry:lower(), "backup"}, template("openmptcprouter/backup"), _("Backup on server"), 3).leaf = true
--	entry({"admin", "system", menuentry:lower(), "backupgr"}, post("backupgr"))
--	entry({"admin", "system", menuentry:lower(), "debug"}, template("openmptcprouter/debug"), _("Show all settings"), 5).leaf = true
end

function interface_from_device(dev)
	for _, iface in ipairs(net:get_networks()) do
		local ifacen = iface:name()
		local ifacename = ""
		ifacename = ucic:get("network",ifacen,"device")
		if ifacename == "" then
			ifacename = ucic:get("network",ifacen,"ifname")
		end
		if ifacename == dev then
			return ifacen
		end
	end
	return ""
end

function uci_device_from_interface(intf)
	intfname = ucic:get("network",intf,"device")
	deviceuci = ""
	ucic:foreach("network", "device", function(s)
		if intfname == ucic:get("network",s[".name"],"name") then
		    deviceuci = s[".name"]
		end
	end)
	return deviceuci
end

function wizard_add()
	local gostatus = true
	
	-- Force WAN zone firewall members to be a list
	local fwwan = sys.exec("uci -q get firewall.zone_wan.network")
	luci.sys.call("uci -q delete firewall.zone_wan.network")
	for interface in fwwan:gmatch("%S+") do
		luci.sys.call("uci -q add_list firewall.zone_wan.network=" .. interface)
	end
	ucic:save("firewall")
	
	-- Add new interface
	local add_interface = luci.http.formvalue("add_interface") or ""
	local add_interface_ifname = luci.http.formvalue("add_interface_ifname") or ""
	if add_interface ~= "" then
		local i = 1
		local multipath_master = false
		ucic:foreach("network", "interface", function(s)
			local sectionname = s[".name"]
			if sectionname:match("^wan(%d+)$") then
				if i <= tonumber(string.match(sectionname, '%d+')) then
					i = tonumber(string.match(sectionname, '%d+')) + 1
				end
			end
			if ucic:get("network",sectionname,"multipath") == "master" then
				multipath_master = true
			end
		end)
		local defif = "eth0"
		if add_interface_ifname == "" then
			local defif1 = ucic:get("network","wan1_dev","device") or ""
			if defif1 == "" then
				defif1 = ucic:get("network","wan1_dev","ifname") or ""
			end
			if defif1 ~= "" then
				defif = defif1
			end
		else
			defif = add_interface_ifname
		end
		
		local ointf = interface_from_device(defif) or ""
		local wanif = defif
		if ointf ~= "" then
			if ucic:get("network",ointf,"type") == "" then
				ucic:set("network",ointf,"type","macvlan")
				ucic:set("network",ointf,"device",ointf)
				ucic:set("network",ointf .. "_dev","device")
				ucic:set("network",ointf .. "_dev","type","macvlan")
				ucic:set("network",ointf .. "_dev","mode","vepa")
				ucic:set("network",ointf .. "_dev","ifname",defif)
				ucic:set("network",ointf .. "_dev","name",ointf)
			end
			wanif = "wan" .. i
		end
		
		ucic:set("network","wan" .. i,"interface")
		ucic:set("network","wan" .. i,"device",defif)
		ucic:set("network","wan" .. i,"proto","static")
		ucic:set("openmptcprouter","wan" .. i,"interface")
		if ointf ~= "" then
			ucic:set("network","wan" .. i,"type","macvlan")
			ucic:set("network","wan" .. i,"device","wan" .. i)
			ucic:set("network","wan" .. i,"masterintf",defif)
			ucic:set("network","wan" .. i .. "_dev","device")
			ucic:set("network","wan" .. i .. "_dev","type","macvlan")
			ucic:set("network","wan" .. i .. "_dev","mode","vepa")
			ucic:set("network","wan" .. i .. "_dev","ifname",defif)
			ucic:set("network","wan" .. i .. "_dev","name","wan" .. i)
			ucic:set("network","wan" .. i .. "_dev","txqueuelen","20")
		end
		ucic:set("network","wan" .. i,"ip4table","wan")
		if multipath_master then
			ucic:set("network","wan" .. i,"multipath","on")
			ucic:set("openmptcprouter","wan" .. i,"multipath","on")
		else
			ucic:set("network","wan" .. i,"multipath","master")
			ucic:set("openmptcprouter","wan" .. i,"multipath","master")
		end
		ucic:set("network","wan" .. i,"defaultroute","0")
		ucic:reorder("network","wan" .. i, i + 2)
		ucic:save("network")
		ucic:commit("network")
		ucic:save("openmptcprouter")
		ucic:commit("openmptcprouter")

		ucic:set("qos","wan" .. i,"interface")
		ucic:set("qos","wan" .. i,"classgroup","Default")
		ucic:set("qos","wan" .. i,"enabled","0")
		ucic:set("qos","wan" .. i,"upload","4000")
		ucic:set("qos","wan" .. i,"download","100000")
		ucic:save("qos")
		ucic:commit("qos")

		ucic:set("sqm","wan" .. i,"queue")
		if ointf ~= "" then
			ucic:set("sqm","wan" .. i,"interface","wan" .. i)
		else
			ucic:set("sqm","wan" .. i,"interface",defif)
		end
		ucic:set("sqm","wan" .. i,"qdisc","fq_codel")
		ucic:set("sqm","wan" .. i,"script","simple.qos")
		ucic:set("sqm","wan" .. i,"qdisc_advanced","0")
		ucic:set("sqm","wan" .. i,"linklayer","none")
		ucic:set("sqm","wan" .. i,"enabled","1")
		ucic:set("sqm","wan" .. i,"debug_logging","0")
		ucic:set("sqm","wan" .. i,"verbosity","5")
		ucic:set("sqm","wan" .. i,"download","0")
		ucic:set("sqm","wan" .. i,"upload","0")
		ucic:set("sqm","wan" .. i,"iqdisc_opts","autorate-ingress dual-dsthost")
		ucic:set("sqm","wan" .. i,"eqdisc_opts","dual-srchost")
		ucic:save("sqm")
		ucic:commit("sqm")
		
		luci.sys.call("uci -q add_list vnstat.@vnstat[-1].interface=" .. wanif)
		luci.sys.call("uci -q commit vnstat")

		-- Dirty way to add new interface to firewall...
		luci.sys.call("uci -q add_list firewall.zone_wan.network=wan" .. i)
		luci.sys.call("uci -q commit firewall")

		luci.sys.call("/etc/init.d/macvlan restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/vnstat restart >/dev/null 2>/dev/null")
		gostatus = false
	end

	-- Remove existing interface
	local delete_intf = luci.http.formvaluetable("delete") or ""
	if delete_intf ~= "" then
		for intf, _ in pairs(delete_intf) do
			local defif = ucic:get("network",intf,"ifname") or ""
			if defif == "" then
				defif = ucic:get("network",intf,"ifname")
			end
			ucic:delete("network",intf)
			if ucic:get("network",intf .. "_dev") ~= "" then
				ucic:delete("network",intf .. "_dev")
			end
			ucic:save("network")
			ucic:commit("network")
			ucic:delete("sqm",intf)
			ucic:save("sqm")
			ucic:commit("sqm")
			ucic:delete("qos",intf)
			ucic:save("qos")
			ucic:commit("qos")
			ucic:delete("openmptcprouter",intf)
			ucic:save("openmptcprouter")
			ucic:commit("openmptcprouter")
			if defif ~= nil and defif ~= "" then
				luci.sys.call("uci -q del_list vnstat.@vnstat[-1].interface=" .. defif)
			end
			luci.sys.call("uci -q commit vnstat")
			luci.sys.call("uci -q del_list firewall.zone_wan.network=" .. intf)
			luci.sys.call("uci -q commit firewall")
			gostatus = false
		end
	end
	-- Set wireless settings
	local wifi_interfaces = luci.http.formvaluetable("wifi")
	for wifi_intf, _ in pairs(wifi_interfaces) do
		local channel = luci.http.formvalue("cbid.wifi.%s.channel" % wifi_intf) or ""
		local name = luci.http.formvalue("cbid.wifi.%s.name" % wifi_intf) or ""
		local key = luci.http.formvalue("cbid.wifi.%s.key" % wifi_intf) or ""
		ucic:set("wireless",wifi_intf,"channel",channel)
		ucic:set("wireless","default_" .. wifi_intf,"ssid",name)
		ucic:set("wireless","default_" .. wifi_intf,"key",key)
	end
	ucic:save("wireless")
	ucic:commit("wireless")

	-- Set interfaces settings
	local interfaces = luci.http.formvaluetable("intf")
	for intf, _ in pairs(interfaces) do
		local label = luci.http.formvalue("cbid.network.%s.label" % intf) or ""
		local proto = luci.http.formvalue("cbid.network.%s.proto" % intf) or "static"
		local typeintf = luci.http.formvalue("cbid.network.%s.type" % intf) or ""
		local masterintf = luci.http.formvalue("cbid.network.%s.masterintf" % intf) or ""
		local ifname = luci.http.formvalue("cbid.network.%s.intf" % intf) or ""
		local vlan = luci.http.formvalue("cbid.network.%s.vlan" % intf) or ""
		local device_ncm = luci.http.formvalue("cbid.network.%s.device.ncm" % intf) or ""
		local device_qmi = luci.http.formvalue("cbid.network.%s.device.qmi" % intf) or ""
		local device_modemmanager = luci.http.formvalue("cbid.network.%s.device.modemmanager" % intf) or ""
		local ipaddr = luci.http.formvalue("cbid.network.%s.ipaddr" % intf) or ""
		local ip6addr = luci.http.formvalue("cbid.network.%s.ip6addr" % intf) or ""
		local netmask = luci.http.formvalue("cbid.network.%s.netmask" % intf) or ""
		local gateway = luci.http.formvalue("cbid.network.%s.gateway" % intf) or ""
		local ip6gw = luci.http.formvalue("cbid.network.%s.ip6gw" % intf) or ""
		local ipv6 = luci.http.formvalue("cbid.network.%s.ipv6" % intf) or "0"
		local apn = luci.http.formvalue("cbid.network.%s.apn" % intf) or ""
		local pincode = luci.http.formvalue("cbid.network.%s.pincode" % intf) or ""
		local delay = luci.http.formvalue("cbid.network.%s.delay" % intf) or ""
		local username = luci.http.formvalue("cbid.network.%s.username" % intf) or ""
		local password = luci.http.formvalue("cbid.network.%s.password" % intf) or ""
		local auth = luci.http.formvalue("cbid.network.%s.auth" % intf) or ""
		local mode = luci.http.formvalue("cbid.network.%s.mode" % intf) or ""
		local sqmenabled = luci.http.formvalue("cbid.sqm.%s.enabled" % intf) or "0"
		local sqmautorate = luci.http.formvalue("cbid.sqm.%s.autorate" % intf) or "0"
		local qosenabled = luci.http.formvalue("cbid.qos.%s.enabled" % intf) or "0"
		local multipath = luci.http.formvalue("cbid.network.%s.multipath" % intf) or "on"
		local lan = luci.http.formvalue("cbid.network.%s.lan" % intf) or "0"
		local ttl = luci.http.formvalue("cbid.network.%s.ttl" % intf) or ""
		if typeintf ~= "" then
			if typeintf == "normal" then
				typeintf = ""
			end
			ucic:set("network",intf,"type",typeintf)
		end
		if vlan ~= "" then
			ifname = ifname .. '.' .. vlan
		end
		if typeintf == "macvlan" and masterintf ~= "" then
			ucic:set("network",intf,"type","macvlan")
			ucic:set("network",intf .. "_dev","device")
			ucic:set("network",intf .. "_dev","type","macvlan")
			ucic:set("network",intf .. "_dev","ifname",masterintf)
			ucic:set("network",intf .. "_dev","mode","vepa")
			ucic:set("network",intf .. "_dev","name",intf)
			ucic:set("network",intf,"device",intf)
			ucic:set("network",intf,"masterintf",masterintf)
		elseif typeintf == "" and ifname ~= "" and (proto == "static" or proto == "dhcp" or proto == "dhcpv6") then
			ucic:set("network",intf,"device",ifname)
			if uci_device_from_interface(intf) == "" then
				ucic:set("network",intf .. "_dev","device")
				ucic:set("network",intf .. "_dev","name",ifname)
			end
		elseif typeintf == "" and device ~= "" and proto == "ncm" then
			ucic:set("network",intf,"device",device_ncm)
			if uci_device_from_interface(intf) == "" then
				ucic:set("network",intf .. "_dev","device")
				ucic:set("network",intf .. "_dev","name",device_ncm)
			end
		elseif typeintf == "" and device ~= "" and proto == "qmi" then
			ucic:set("network",intf,"device",device_qmi)
			if uci_device_from_interface(intf) == "" then
				ucic:set("network",intf .. "_dev","device")
				ucic:set("network",intf .. "_dev","name",device_qmi)
			end
		elseif typeintf == "" and device ~= "" and proto == "modemmanager" then
			ucic:set("network",intf,"device",device_manager)
			if uci_device_from_interface(intf) == "" then
				ucic:set("network",intf .. "_dev","device")
				ucic:set("network",intf .. "_dev","name",device_manager)
			end
		elseif typeintf == "" and ifname ~= "" and proto == "static" then
			ucic:set("network",intf,"device",ifname)
			if uci_device_from_interface(intf) == "" then
				ucic:set("network",intf .. "_dev","device")
				ucic:set("network",intf .. "_dev","name",ifname)
			end
		end
		if typeintf ~= "macvlan" then
			if ucic:get("network",intf .. "_dev","type") == "macvlan" then
				ucic:delete("network",intf .. "_dev","type")
				ucic:delete("network",intf .. "_dev","mode")
				ucic:delete("network",intf .. "_dev","ifname")
				ucic:delete("network",intf .. "_dev","macaddr")
			end
			ucic:delete("network",intf,"masterintf")
		end
		if proto == "pppoe" then
			ucic:set("network",intf,"pppd_options","persist maxfail 0")
		end
		if proto ~= "other" then
			ucic:set("network",intf,"proto",proto)
		end

		uci_device = uci_device_from_interface(intf)
		if uci_device == "" then
			uci_device = intf .. "_dev"
		end
		ucic:set("network",uci_device,"ttl",ttl)

		--ucic:set("network",intf,"apn",apn)
		--ucic:set("network",intf,"pincode",pincode)
		--ucic:set("network",intf,"delay",delay)
		--ucic:set("network",intf,"username",username)
		--ucic:set("network",intf,"password",password)
		--ucic:set("network",intf,"auth",auth)
		--ucic:set("network",intf,"mode",mode)
		--ucic:set("network",intf,"label",label)
		--ucic:set("network",intf,"ipv6",ipv6)
		if lan == "1" then
			ucic:set("network",intf,"multipath","off")
		else
			ucic:set("network",intf,"multipath",multipath)
			ucic:set("openmptcprouter",intf,"multipath",multipath)
		end
		ucic:set("network",intf,"defaultroute",0)
		ucic:set("network",intf,"peerdns",0)
		if ipaddr ~= "" then
			ucic:set("network",intf,"ipaddr",ipaddr:gsub("%s+", ""))
			ucic:set("network",intf,"netmask",netmask:gsub("%s+", ""))
			ucic:set("network",intf,"gateway",gateway:gsub("%s+", ""))
		else
			ucic:set("network",intf,"ipaddr","")
			ucic:set("network",intf,"netmask","")
			ucic:set("network",intf,"gateway","")
		end
		if ip6addr ~= "" then
			ucic:set("network",intf,"ip6addr",ip6addr:gsub("%s+", ""))
			ucic:set("network",intf,"ip6gw",ip6gw:gsub("%s+", ""))
		else
			ucic:set("network",intf,"ip6addr","")
			ucic:set("network",intf,"ip6gw","")
		end
		
		if proto == "dhcpv6" then
			ucic:set("network",intf,"reqaddress","try")
			ucic:set("network",intf,"reqprefix","no")
			ucic:set("network",intf,"iface_map","0")
			ucic:set("network",intf,"iface_dslite","0")
			ucic:set("network",intf,"iface_464xlate","0")
			ucic:set("network",intf,"ipv6","1")
		end

		ucic:delete("openmptcprouter",intf,"lc")
		ucic:save("openmptcprouter")

		--local multipathvpn = luci.http.formvalue("multipathvpn.%s.enabled" % intf) or "0"
		--ucic:set("openmptcprouter",intf,"multipathvpn",multipathvpn)
		--ucic:save("openmptcprouter")

	end
	-- Disable multipath on LAN, VPN and loopback
	ucic:set("network","loopback","multipath","off")
	ucic:set("network","lan","multipath","off")
	ucic:set("network","omr6in4","multipath","off")
	ucic:set("network","omrvpn","multipath","off")

	ucic:save("network")
	ucic:commit("network")

	ucic:save("network")
	ucic:commit("network")

	ucic:save("openmptcprouter")
	ucic:commit("openmptcprouter")

	-- Restart all
	menuentry = "status"
	if gostatus == true then
		--luci.sys.call("/etc/init.d/macvlan restart >/dev/null 2>/dev/null")
		luci.sys.call("(env -i /bin/ubus call network reload) >/dev/null 2>/dev/null")
		luci.sys.call("ip addr flush dev tun0 >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/omr-tracker stop >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/mptcp restart >/dev/null 2>/dev/null")
		--if openmptcprouter_vps_key ~= "" then
		--	luci.sys.call("/etc/init.d/openmptcprouter-vps restart >/dev/null 2>/dev/null")
		--	luci.sys.call("sleep 2")
		--end
		luci.sys.call("/etc/init.d/shadowsocks-libev restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/glorytun restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/glorytun-udp restart >/dev/null 2>/dev/null")
		--luci.sys.call("/etc/init.d/mlvpn restart >/dev/null 2>/dev/null")
		--luci.sys.call("/etc/init.d/ubond restart >/dev/null 2>/dev/null")
		--luci.sys.call("/etc/init.d/mptcpovervpn restart >/dev/null 2>/dev/null")
		--luci.sys.call("/etc/init.d/openvpn restart >/dev/null 2>/dev/null")
		--luci.sys.call("/etc/init.d/openvpnbonding restart >/dev/null 2>/dev/null")
		--luci.sys.call("/etc/init.d/dsvpn restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/omr-tracker start >/dev/null 2>/dev/null")
		--luci.sys.call("/etc/init.d/omr-6in4 restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/vnstat restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/v2ray restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/sqm-autorate restart >/dev/null 2>/dev/null")
		luci.sys.call("/etc/init.d/sysntpd restart >/dev/null 2>/dev/null")
		luci.http.redirect(luci.dispatcher.build_url("admin/system/" .. menuentry:lower() .. "/status"))
	else
		luci.http.redirect(luci.dispatcher.build_url("admin/system/" .. menuentry:lower() .. "/wizard"))
	end
	return
end

function get_device(interface)
	local dump = require("luci.util").ubus("network.interface.%s" % interface, "status", {})
	if dump ~= nil then
		if dump['l3_device'] ~= nil then
			return dump['l3_device']
		elseif dump['device'] ~= nil then
			return dump['device']
		else
			return ""
		end
	else
		return ""
	end
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

function interfaces_status()
	local ut = require "luci.util"
	--local mArray = ut.ubus("openmptcprouter", "status", {}) or {_=0}
	local mArray = luci.json.decode(ut.trim(sys.exec("/bin/ubus -t 600 -S call openmptcprouter status 2>/dev/null")))

	if mArray ~= nil and mArray.openmptcprouter ~= nil then
		mArray.openmptcprouter["remote_addr"] = luci.http.getenv("REMOTE_ADDR") or ""
		mArray.openmptcprouter["remote_from_lease"] = false
		local leases=dhcp_leases_common(4)
		for _, value in pairs(leases) do
			if value["ipaddr"] == mArray.openmptcprouter["remote_addr"] then
				mArray.openmptcprouter["remote_from_lease"] = true
				mArray.openmptcprouter["remote_hostname"] = value["hostname"]
			end
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(mArray)
end
