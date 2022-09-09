--[[
LuCI - Lua Configuration Interface

Copyright (c) 2013 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

local enabled_prev = nil
local uci = require "luci.model.uci"

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

m = Map("wsplcd", translate("HyFi Security Settings"),
	translate("Security configuration of HyFi networks "))

m.on_before_save = function()
	local uci_r = uci.cursor()
	enabled_prev = uci_r:get("wsplcd", "config", "HyFiSecurity")
end

m.on_after_commit = function()
	local enabled_new = nil

	enabled_new = m.uci:get("wsplcd", "config", "HyFiSecurity")
	if (enabled_new == "1" and enabled_prev == "0") then
		fork_exec("/etc/init.d/wsplcd start")
	else
		fork_exec("/etc/init.d/wsplcd restart")
	end
end

s = m:section(NamedSection, "config", translate("Basic Settings"))
s.anonymous = true

e = s:option(Flag, "HyFiSecurity", translate("Enable"))
e.rmempty = false

e = s:option(Flag, "MapEnable", translate("Multi-AP SIG Enable"))
e.rmempty = false

li = s:option(ListValue, "RunMode", translate("1905.1 Configuration Role"))
li:value("REGISTRAR", translate("Registrar"))
li:value("ENROLLEE", translate("Enrollee"))
li:value("NONE", translate("None"))
li.default = "ENROLLEE"

li = s:option(ListValue, "DesignatedPBAP", translate("Designated Push Button AP"))
li:value("1", translate("Selected"))
li:value("0", translate("Not selected"))
li.default = "1"

vl = s:option(Value, "MapPolicyFile", translate("AL MAC-specific Multi-AP BSS Instantiation Policy File"))
vl.datatype = "string"

vl = s:option(Value, "MapGenericPolicyFile", translate("Generic Multi-AP BSS Instantiation Policy File"))
vl.datatype = "string"

vl = s:option(Value, "MapMaxBss", translate("Maximum supported BSSes per radio in Multi-AP Mode"))
vl.datatype = "uinteger"

vl = s:option(Value, "NetworkKey1905", translate("1905.1 UCPK"))
vl.datatype = "string"

vl = s:option(Value, "UCPKSalt", translate("1905.1 UCPK Salt"))
vl.datatype = "string"

function ucpkgen()
	local ucpk = m.uci:get("wsplcd", "config", "NetworkKey1905")
	local salt = m.uci:get("wsplcd", "config", "UCPKSalt")
	local keytype = m.uci:get("wsplcd", "config", "WPAPassphraseType")
	local wpapsk = ""
	local plcnmk = ""

	if ucpk and ucpk:len() > 0 then
		local cmd
		local fp
		cmd = "ucpkgen"
		if keytype and keytype:len() > 0 then
			if keytype == "SHORT" then
				cmd = cmd .. " -s"
			else
				cmd = cmd .. " -l"
			end
		end

		if salt and salt:len() > 0 then
			cmd = cmd .. " -n \"" .. salt .. "\""
		end

		cmd = cmd .. " \"" .. ucpk .. "\""
		fp = io.popen(cmd)
		if fp then
			local lines
			lines = fp:read("*all")
			_,_,wpapsk = lines:find("WPA PSK%s+:(%x+)")
			_,_,plcnmk = lines:find("1901 NMK%s+:(%x+)")
			fp:close()
		end
	end
	return wpapsk, plcnmk
end

vl = s:option(Value, "WPAPSK", translate("WPA PSK"))
function vl.cfgvalue(self, section)
	local wpapsk = ucpkgen()
        return wpapsk
end
function vl.write(self, section, value)
end

vl = s:option(Value, "1901NMK", translate("1901 NMK"))
function vl.cfgvalue(self, section)
	local plcnmk
	_,plcnmk = ucpkgen()
        return plcnmk
end
function vl.write(self, section, value)
end

js = s:option(DummyValue, "script", translate("script for Wsplc"))
js.template = "wsplc/dview_js"

local form, ferr = loadfile(luci.util.libpath() .. "/model/cbi/wsplc/advanced.lua")
if form then
	bt = s:option(DummyValue, "showadv", translate("show advanced"))
	bt.template = "wsplc/btn_adv"
	setfenv(form, getfenv(1))(m, s)
end

return m
