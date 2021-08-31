local net = require "luci.model.network".init()
local sys = require "luci.sys"
local ifaces = sys.net:devices()
local m, s, o
local uname = nixio.uname()

m = Map("network", translate("MPTCP"), translate("Networks MPTCP settings. Visit <a href='http://multipath-tcp.org/pmwiki.php/Users/ConfigureMPTCP'>http://multipath-tcp.org/pmwiki.php/Users/ConfigureMPTCP</a> for help."))

local unameinfo = nixio.uname() or { }

s = m:section(TypedSection, "globals")
o = s:option(ListValue, "multipath", translate("Multipath TCP"))
o:value("enable", translate("enable"))
o:value("disable", translate("disable"))
o = s:option(ListValue, "mptcp_checksum", translate("Multipath TCP checksum"))
o:value(1, translate("enable"))
o:value(0, translate("disable"))
o = s:option(ListValue, "mptcp_debug", translate("Multipath Debug"))
o:value(1, translate("enable"))
o:value(0, translate("disable"))
o = s:option(ListValue, "mptcp_path_manager", translate("Multipath TCP path-manager"), translate("Default is fullmesh"))
o:value("default", translate("default"))
o:value("fullmesh", "fullmesh")
if uname.release:sub(1,4) ~= "5.14" then
    o:value("ndiffports", "ndiffports")
    o:value("binder", "binder")
    if uname.release:sub(1,4) ~= "4.14" then
	o:value("netlink", translate("Netlink"))
    end
end
o = s:option(ListValue, "mptcp_scheduler", translate("Multipath TCP scheduler"))
o:value("default", translate("default"))
if uname.release:sub(1,4) ~= "5.14" then
    o:value("roundrobin", "round-robin")
    o:value("redundant", "redundant")
    if uname.release:sub(1,4) ~= "4.14" then
	o:value("blest", "BLEST")
	o:value("ecf", "ECF")
    end
end
if uname.release:sub(1,4) ~= "5.14" then
    o = s:option(Value, "mptcp_syn_retries", translate("Multipath TCP SYN retries"))
    o.datatype = "uinteger"
    o.rmempty = false
end
o = s:option(ListValue, "congestion", translate("Congestion Control"),translate("Default is cubic"))
local availablecong = sys.exec("sysctl -n net.ipv4.tcp_available_congestion_control | xargs -n1 | sort | xargs")
for cong in string.gmatch(availablecong, "[^%s]+") do
	o:value(cong, translate(cong))
end

if uname.release:sub(1,4) == "5.14" then
    o = s:option(Value, "mptcp_subflows", translate("specifies the maximum number of additional subflows allowed for each MPTCP connection"))
    o.datatype = "uinteger"
    o.rmempty = false
    o.default = 3
    
    o = s:option(Value, "mptcp_add_addr_accepted", translate("specifies the maximum number of ADD_ADDR suboptions accepted for each MPTCP connection"))
    o.datatype = "uinteger"
    o.rmempty = false
    o.default = 1
else
    o = s:option(Value, "mptcp_fullmesh_num_subflows", translate("Fullmesh subflows for each pair of IP addresses"))
    o.datatype = "uinteger"
    o.rmempty = false
    o.default = 1
    --o:depends("mptcp_path_manager","fullmesh")

    o = s:option(ListValue, "mptcp_fullmesh_create_on_err", translate("Re-create fullmesh subflows after a timeout"))
    o:value(1, translate("enable"))
    o:value(0, translate("disable"))
    --o:depends("mptcp_path_manager","fullmesh")

    o = s:option(Value, "mptcp_ndiffports_num_subflows", translate("ndiffports subflows number"))
    o.datatype = "uinteger"
    o.rmempty = false
    o.default = 1
    --o:depends("mptcp_path_manager","ndiffports")

    o = s:option(ListValue, "mptcp_rr_cwnd_limited", translate("Fill the congestion window on all subflows for round robin"))
    o:value("Y", translate("enable"))
    o:value("N", translate("disable"))
    o.default = "Y"
    --o:depends("mptcp_scheduler","roundrobin")

    o = s:option(Value, "mptcp_rr_num_segments", translate("Consecutive segments that should be sent for round robin"))
    o.datatype = "uinteger"
    o.rmempty = false
    o.default = 1
    --o:depends("mptcp_scheduler","roundrobin")
end

s = m:section(TypedSection, "interface", translate("Interfaces Settings"))
o = s:option(ListValue, "multipath", translate("Multipath TCP"), translate("One interface must be set as master"))
o:value("on", translate("enabled"))
o:value("off", translate("disabled"))
o:value("master", translate("master"))
o:value("backup", translate("backup"))
--o:value("handover", translate("handover"))
o.default = "off"


return m
