local net = require "luci.model.network".init()
local sys = require "luci.sys"
local ifaces = sys.net:devices()
local m, s, o
local uname = nixio.uname()

m = Map("network", translate("MPTCP"), translate("Networks MPTCP settings. Visit <a href='http://multipath-tcp.org/pmwiki.php/Users/ConfigureMPTCP'>http://multipath-tcp.org/pmwiki.php/Users/ConfigureMPTCP</a> for help."))

local unameinfo = nixio.uname() or { }

s = m:section(TypedSection, "globals")
local mtcpg = s:option(ListValue, "multipath", translate("Multipath TCP"))
mtcpg:value("enable", translate("enable"))
mtcpg:value("disable", translate("disable"))
local mtcpck = s:option(ListValue, "mptcp_checksum", translate("Multipath TCP checksum"))
mtcpck:value(1, translate("enable"))
mtcpck:value(0, translate("disable"))
local mtcpck = s:option(ListValue, "mptcp_debug", translate("Multipath Debug"))
mtcpck:value(1, translate("enable"))
mtcpck:value(0, translate("disable"))
local mtcppm = s:option(ListValue, "mptcp_path_manager", translate("Multipath TCP path-manager"), translate("Default is fullmesh"))
mtcppm:value("default", translate("default"))
mtcppm:value("fullmesh", translate("fullmesh"))
mtcppm:value("ndiffports", translate("ndiffports"))
mtcppm:value("binder", translate("binder"))
if uname.release:sub(1,4) ~= "4.14" then
	mtcppm:value("netlink", translate("Netlink"))
end
local mtcpsch = s:option(ListValue, "mptcp_scheduler", translate("Multipath TCP scheduler"))
mtcpsch:value("default", translate("default"))
mtcpsch:value("roundrobin", translate("round-robin"))
mtcpsch:value("redundant", translate("redundant"))
if uname.release:sub(1,4) ~= "4.14" then
	mtcpsch:value("blest", translate("BLEST"))
	mtcpsch:value("ecf", translate("ECF"))
end
local mtcpsyn = s:option(Value, "mptcp_syn_retries", translate("Multipath TCP SYN retries"))
mtcpsyn.datatype = "uinteger"
mtcpsyn.rmempty = false
local congestion = s:option(ListValue, "congestion", translate("Congestion Control"),translate("Default is bbr"))
local availablecong = sys.exec("sysctl -n net.ipv4.tcp_available_congestion_control | xargs -n1 | sort | xargs")
for cong in string.gmatch(availablecong, "[^%s]+") do
	congestion:value(cong, translate(cong))
end
local mtcpfm_subflows = s:option(Value, "mptcp_fullmesh_num_subflows", translate("Fullmesh subflows for each pair of IP addresses"))
mtcpfm_subflows.datatype = "uinteger"
mtcpfm_subflows.rmempty = false
local mtcpfm_createonerr = s:option(ListValue, "mptcp_fullmesh_create_on_err", translate("Re-create fullmesh subflows after a timeout"))
mtcpfm_createonerr:value(1, translate("enable"))
mtcpfm_createonerr:value(0, translate("disable"))

local mtcpnd_subflows = s:option(Value, "mptcp_ndiffports_num_subflows", translate("ndiffports subflows number"))
mtcpnd_subflows.datatype = "uinteger"
mtcpnd_subflows.rmempty = false

s = m:section(TypedSection, "interface", translate("Interfaces Settings"))
mptcp = s:option(ListValue, "multipath", translate("Multipath TCP"), translate("One interface must be set as master"))
mptcp:value("on", translate("enabled"))
mptcp:value("off", translate("disabled"))
mptcp:value("master", translate("master"))
mptcp:value("backup", translate("backup"))
--mptcp:value("handover", translate("handover"))
mptcp.default = "off"


return m
