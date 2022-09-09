--[[
LuCI - Lua Configuration Interface

Copyright (c) 2013 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

local acd_enabled_prev = nil
local hyfi_enabled_prev = nil
local vhyfi_enabled_prev = nil
local uci = require "luci.model.uci"

function isvhyfi()
	local vhyfi = true
	local fd = io.open("/tmp/sysinfo/board_name", "r")
	if fd then
		local ln = fd:read("*l")
		if (ln and (ln == "reh132" or
			ln == "aph131" or
			ln == "aph126" or
			ln == "aph128" )) then
			vhyfi = false
		end
		fd:close()
	end

	if (vhyfi == false) then
		return false
	end

	if not nixio.fs.access("/etc/init.d/vhyfid") then
		return false
	end

	return true
end

function has_acd()
	if not nixio.fs.access("/etc/init.d/acd") then
		return false
	else
		return true
	end
end

function has_wan()
	local uci_r = uci.cursor()
	local wanif
	wanif = uci_r:get("network", "wan", "ifname")

	if (wanif  == nil) then
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

if (isvhyfi()) then
m1 = Map("vhyfid", translate("Virtual HyFi Settings"),
	translate("Configuration of Virtual HyFi networks "))

m1.on_before_save = function()
	local uci_r = uci.cursor()
	vhyfi_enabled_prev = uci_r:get("vhyfid", "config", "Enable")
end

s = m1:section(TypedSection, "config", translate("Virtual Hy-Fi Settings"))
s.anonymous = true


e = s:option(Flag, "Enable", translate("Virtual Hy-Fi Feature"))
e.rmempty = false

vl = s:option(Value, "PLCHFIDList", translate("HFID List"))
vl.datatype = "string"

vl = s:option(Value, "PLCOUIList", translate("OUI List"))
vl.datatype = "string"

--[[li = s:option(ListValue, "AllowPLCFwUpdate", translate("Allow PLC Firmware Update"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "1"
--]]

li = s:option(ListValue, "DisableHyFiIfNoManufacturerMatch", translate("Disable Virtual Hy-Fi if Manufacturer not Matching"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "1"
end

m2 = Map("hyd", translate("HyFi Network Settings"),
	translate("Configuration of HyFi networks "))
m2:chain("acd")

m2.on_before_save = function()
	local uci_r = uci.cursor()
	if (has_acd()) then
		acd_enabled_prev = uci_r:get("acd", "config", "AutoConfigEnable")
	end
	hyfi_enabled_prev = uci_r:get("hyd", "config", "Enable")
end

m2.on_after_commit = function()
	local command = ""
	local acd_enabled_new
	local hyfi_enabled_new
	local vhyfi_enabled_new
	local hyfi_control

	if (has_acd()) then
		acd_enabled_new=m2.uci:get("acd", "config", "AutoConfigEnable")
		if (acd_enabled_new == "0") then
			command = "/etc/init.d/acd stop; "
		elseif (acd_enabled_prev == "0") then
			command = "/etc/init.d/acd start; "
		else
			command = "/etc/init.d/acd restart; "
		end
        end

	if (isvhyfi()) then
		vhyfi_enabled_new = m2.uci:get("vhyfid", "config", "Enable")
		if (vhyfi_enabled_new == "0") then
			command = command .. "/etc/init.d/vhyfid stop; "
		elseif (vhyfi_enabled_prev == "0") then
			command = command .. "/etc/init.d/vhyfid start; "
		else
			command = command .. "/etc/init.d/vhyfid restart; "
		end
	end

	hyfi_control =  m2.uci:get("hyd", "config", "Control")
	if (hyfi_control == "manual" ) then
		hyfi_enabled_new = m2.uci:get("hyd", "config", "Enable")
		if (hyfi_enabled_new == "0") then
			command = command .. "/etc/init.d/hyd stop"
			command = command .. "/etc/init.d/hyfi-bridging stop"
			command = command .. "uci set mcsd.config.Enable=1; "
			command = command .. "uci commit; "
			command = command .. "/etc/init.d/mcsd start; "
		elseif (hyfi_enabled_prev == "0") then
			command = command .. "uci set mcsd.config.Enable=0; "
			command = command .. "uci commit; "
			command = command .. "/etc/init.d/mcsd stop; "
			command = command .. "/etc/init.d/hyfi-bridging start"
			command = command .. "/etc/init.d/hyd start"
		else
			command = command .. "uci set mcsd.config.Enable=0; "
			command = command .. "uci commit; "
			command = command .. "/etc/init.d/mcsd stop; "
			command = command .. "/etc/init.d/hyd stop; "
			command = command .. "/etc/init.d/hyfi-bridging restart; "
			command = command .. "/etc/init.d/hyd start"
		end
	end

	fork_exec(command)
end

s = m2:section(TypedSection, "config", translate("Basic Hy-Fi Settings"))
s.anonymous = true


li = s:option(ListValue, "Enable", translate("Hy-Fi Feature"))
li:value("Enable", translate("Enable"))
li:value("Auto", translate("Auto"))
li:value("Disable", translate("Disable"))

function li.cfgvalue(self, section)
	local hyd_control
	local hyfi_status
	local vhyfi_enable
	local hyd_enable

	if (isvhyfi() == true) then
		vhyfi_enable = m2.uci:get("vhyfid", "config", "Enable")
	else
		vhyfi_enable = "0"
	end

	if (vhyfi_enable == "1") then
		hyd_control = m2.uci:get("hyd", "config", "Control")
		if (hyd_control == "auto") then
			hyfi_status = "Auto"
		else
			hyfi_status = "Enable"
		end
	else
		hyd_enable = m2.uci:get("hyd", "config", "Enable")
		if (hyd_enable == "0") then
			hyfi_status = "Disable"
		else
			hyfi_status = "Enable"
		end
	end

	return hyfi_status
end

function li.write(self, section, value)
	local vhyfi_enable
	local hyd_enable
	local hyd_control

	if (isvhyfi() == true) then
		vhyfi_enable = m2.uci:get("vhyfid", "config", "Enable")
	else
		vhyfi_enable = "0"
	end


	if (vhyfi_enable == "1") then
		if (value == "Auto") then
			hyd_enable = "0"
			hyd_control = "auto"
		else
			hyd_enable = "1"
			hyd_control = "manual"
		end
	else
		if (value == "Enable") then
			hyd_enable = "1"
			hyd_control = "manual"
		else
			hyd_enable = "0"
			hyd_control = "manual"
		end
	end

	m2.uci:set("hyd", "config", "Enable", hyd_enable)
	m2.uci:set("hyd", "config", "Control", hyd_control)
end

if (has_acd()) then
e = s:option(Flag, "AutoConfigEnable", translate("Hy-Fi Auto Configuration"))
e.rmempty = false
function e.cfgvalue(self, section)
	return m2.uci:get("acd", section, self.option)
end

function e.write(self, section, value)
	local vhyfi_enable = "0"
	local hyd_enable = "0"

	if (isvhyfi() == true) then
		vhyfi_enable = m2.uci:get("vhyfid", "config", "Enable")
	end

	hyd_enable = m2.uci:get("hyd", "config", "Enable")

	if (hyfi_enable == "0" and hyd_enable == "0") then
		value = 0
	end
	m2.uci:set("acd", section, self.option, value)
end
end

li = s:option(ListValue, "Mode", translate("Hy-Fi Configuration Mode"))
if (has_wan()) then
	li:value("HYROUTER", translate("Hy-Fi Enabled Router"))
else
	li:value("HYROUTER", translate("Hy-Fi Enabled GW-Bridge"))
	li:value("HYCLIENT", translate("Hy-Fi Enabled Range-Extender"))
end
li.default = "1"

js = s:option(DummyValue, "script", translate("script for Hyfi"))
js.template = "hyfi/dview_js"

local form, ferr = loadfile(luci.util.libpath() .. "/model/cbi/hyfi/advanced.lua")
if form then
	bt = s:option(DummyValue, "showadv", translate("show advanced"))
	bt.template = "hyfi/btn_adv"
	setfenv(form, getfenv(1))(m2, s)
end

if (m1 ~= nil) then
	return m1, m2
else
	return m2
end
