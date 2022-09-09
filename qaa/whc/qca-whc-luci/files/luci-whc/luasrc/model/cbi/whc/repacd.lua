--[[
LuCI - Lua Configuration Interface

@@-COPYRIGHT-START-@@

Copyright (c) 2015-2019 Qualcomm Technologies, Inc.

All Rights Reserved.
Confidential and Proprietary - Qualcomm Technologies, Inc.

2015-2016 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

Not a Contribution.

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008-2011 Jo-Philipp Wich <xm@subsignal.org>
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0

@@-COPYRIGHT-END-@@

]]--

local enabled_prev = nil
local uci = require "luci.model.uci"

function has_repacd()
	if not nixio.fs.access("/etc/init.d/repacd") then
		return false
	else
		return true
	end
end

function fork_exec(command)
        local pid = nixio.fork()
        if pid > 0 then
                return
        elseif pid == 0 then
                -- change to root dir
                nixio.chdir("/")

                -- patch stdin, out, err to /dev/null
                local null = nixio.open("/dev/null", "w+")
                if null then
                        nixio.dup(null, nixio.stderr)
                        nixio.dup(null, nixio.stdout)
                        nixio.dup(null, nixio.stdin)
                        if null:fileno() > 2 then
                                null:close()
                        end
                end

                -- replace with target command
                nixio.exec("/bin/sh", "-c", command)
        end
end

m = Map("repacd", translate("WHC - Range Extender Placement and Auto-configuration Daemon Settings"),
	translate("Configuration of WHC Range Extender Features "))

m.on_before_save = function()
	local uci_r = uci.cursor()
	enabled_prev = uci_r:get("repacd", "repacd", "Enable")
end

m.on_after_commit = function()
	local enabled_new = nil
	enabled_new = m.uci:get("repacd", "repacd", "Enable")
	if (enabled_new == "0") then
		fork_exec("/etc/init.d/repacd stop")
	elseif (enabled_prev == "0") then
		fork_exec("/etc/init.d/repacd start")
	else
		fork_exec("/etc/init.d/repacd restart")
	end
end

------------------------------------------------------------------------------------------------
--Basic Settings
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "repacd", "basic", translate("Basic Settings"))
s.anonymous = true

e = s:option(Flag, "Enable", translate("RE Placement and Auto-Configuration Enable"))
e.rmempty = false

vl = s:option(Value, "ManagedNetwork", translate("Network to extend"))
vl.datatype = "string"

li = s:option(ListValue, "DeviceType", translate("Primary device purpose"))
li:value("RE", translate("Range extender"))
li:value("Client", translate("Client"))
li.default = "RE"

li = s:option(ListValue, "GatewayConnectedMode", translate("Mode when connected to gateway"))
li:value("AP", translate("Access Point"))
li:value("CAP", translate("Central Access Point"))
li.default = "AP"

li = s:option(ListValue, "ConfigREMode", translate("Method of range extension"))
li:value("auto", translate("Automatic selection"))
li:value("son", translate("Wi-Fi Self-Organizing Network (SON)"))
li:value("wds", translate("Wi-Fi Distribution System (WDS)"))
li:value("qwrap", translate("QWRAP"))
li:value("extap", translate("Extender AP"))
li.default = "auto"

li = s:option(ListValue, "DefaultREMode", translate("Interoperable RE mode to use"))
li:value("qwrap", translate("QWRAP"))
li:value("extap", translate("Extender AP"))
li.default = "qwrap"

e = s:option(Flag, "EnableSteering", translate("Enable steering in WDS mode"))
e.rmempty = false

e = s:option(Flag, "EnableSON", translate("Enable switching into full Wi-Fi SON mode"))
e.rmempty = false

e = s:option(Flag, "ManageMCSD", translate("Manage the Multicast Services Daemon (mcsd)"))
e.rmempty = false

e = s:option(Flag, "BlockDFSChannels", translate("Do not operate on DFS channels"))
e.rmempty = false

vl = s:option(Value, "LinkCheckDelay", translate("Link check delay (s)"))
vl.datatype = "uinteger"

e = s:option(Flag, "TrafficSeparationEnabled", translate("Enable multi-ssid and traffic separation in SON mode"))
e.rmempty = false

vl = s:option(Value, "NetworkGuest", translate("Guest network bridge name"))
vl.datatype = "string"

li = s:option(ListValue, "NetworkGuestBackhaulInterface", translate("Guest network's backhaul interface"))
li:value("2.4G", translate("2.4GHz"))
li:value("5G", translate("5GHz"))
li:value("both", translate("Both"))
li.default = "both"

------------------------------------------------------------------------------------------------
--Multi-AP Basic Settings
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "MAPConfig", "MAPConfig", translate("Multi-AP Basic Settings"))
s.anonymous = true

e = s:option(Flag, "Enable", translate("Enable Multi-AP Topology Optimization Algorithm"))
e.rmempty = false

e = s:option(Flag, "FirstConfigRequired", translate("Create all VAPs from scratch"))
e.rmempty = false

vl = s:option(Value, "BSSInstantiationTemplate", translate("wsplcd Template that controls how BSSes are instantiated"))
vl.datatype = "string"

vl = s:option(Value, "FronthaulSSID", translate("SSID to use for fronthaul BSSes"))
vl.datatype = "string"

vl = s:option(Value, "FronthaulKey", translate("PSK to use for fronthaul BSSes (or empty for open mode)"))
vl.datatype = "string"

vl = s:option(Value, "BackhaulSSID", translate("SSID to use for backhaul BSSes"))
vl.datatype = "string"

vl = s:option(Value, "BackhaulKey", translate("PSK to use for backhaul BSSes (or empty for open mode)"))
vl.datatype = "string"

vl = s:option(Value, "BackhaulSuffix", translate("Suffix to append when generating backhaul SSID"))
vl.datatype = "string"

e = s:option(Flag, "EnableSmartMonitorMode", translate("Create smart monitor VAPs"))
e.rmempty = false

------------------------------------------------------------------------------------------------
--Advanced Settings / Diagnostic Logging Settings
------------------------------------------------------------------------------------------------
js = s:option(DummyValue, "script", translate("script for WHC"))
js.template = "whc/repacd_dview_js"

local form_adv, ferr_adv = loadfile(luci.util.libpath() .. "/model/cbi/whc/repacd_advanced.lua")
if form_adv then
	bt = s:option(DummyValue, "showrepacdadv", translate("show advanced"))
	bt.template = "whc/repacd_btn_adv"
	setfenv(form_adv, getfenv(1))(m, s)
end

return m
