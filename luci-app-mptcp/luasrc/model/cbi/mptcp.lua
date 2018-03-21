local net = require "luci.model.network".init()
local sys = require "luci.sys"
local ifaces = sys.net:devices()
local m, s, o

m = Map("network", translate("MPTCP"), translate("Networks MPTCP settings"))

s = m:section(TypedSection, "globals")
local mtcpg = s:option(ListValue, "multipath", translate("Multipath TCP"))
mtcpg:value("enable", translate("enable"))
mtcpg:value("disable", translate("disable"))
local mtcpck = s:option(ListValue, "mptcp_checksum", translate("Multipath TCP checksum"))
mtcpck:value("enable", translate("enable"))
mtcpck:value("disable", translate("disable"))
local mtcppm = s:option(ListValue, "mptcp_path_manager", translate("Multipath TCP path-manager"))
mtcppm:value("default", translate("default"))
mtcppm:value("fullmesh", translate("fullmesh"))
mtcppm:value("ndiffports", translate("ndiffports"))
mtcppm:value("blinder", translate("blinder"))
local mtcpsch = s:option(ListValue, "mptcp_scheduler", translate("Multipath TCP scheduler"))
mtcpsch:value("default", translate("default"))
mtcpsch:value("roundrobin", translate("round-robin"))
mtcpsch:value("redundant", translate("redundant"))
local mtcpsyn = s:option(Value, "mptcp_syn_retries", translate("Multipath TCP SYN retries"))
mtcpsyn.datatype = "uinteger"
mtcpsyn.rmempty = false
local congestion = s:option(ListValue, "congestion", translate("Congestion Control"))
local availablecong = sys.exec("sysctl net.ipv4.tcp_available_congestion_control | awk -F'= ' '{print $NF}'")
for cong in string.gmatch(availablecong, "[^%s]+") do
	congestion:value(cong, translate(cong))
end

s = m:section(TypedSection, "interface", translate("Interfaces Settings"))
mptcp = s:option(ListValue, "multipath", translate("Multipath TCP"), translate("One interface must be set as master"))
mptcp:value("on", translate("enabled"))
mptcp:value("off", translate("disabled"))
mptcp:value("master", translate("master"))
mptcp:value("backup", translate("backup"))
mptcp:value("handover", translate("handover"))
mptcp.default = "off"


return m
