--[[
LuCI - Lua Configuration Interface

Copyright (c) 2014-2017 Qualcomm Technologies, Inc.

/* Not a Contribution.
 * Apache license notifications and license are retained
 * for attribution purposes only.
 */

All Rights Reserved.
Confidential and Proprietary - Qualcomm Technologies, Inc.

2014-2016 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Copyright 2012 Daniel Golle <dgolle@allnet.de>
-- Licensed to the public under the Apache License 2.0.

]]--

local enabled_prev = nil
local uci = require "luci.model.uci"

function has_lbd()
	if not nixio.fs.access("/etc/init.d/lbd") then
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

m = Map("lbd", translate("WHC Load Balancing Daemon Settings"),
	translate("Configuration of WHC Load Balancing Features"))

m.on_before_save = function()
	local uci_r = uci.cursor()
	enabled_prev = uci_r:get("lbd", "config", "Enable")
end

m.on_after_commit = function()
	local enabled_new = nil
	enabled_new = m.uci:get("lbd", "config", "Enable")
	if (enabled_new == "0") then
		fork_exec("/etc/init.d/lbd stop")
	elseif (enabled_prev == "0") then
		fork_exec("/etc/init.d/lbd start")
	else
		fork_exec("/etc/init.d/lbd restart")
	end
end

------------------------------------------------------------------------------------------------
--Basic Settings
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "config", "basic", translate("Basic Settings"))
s.anonymous = true

e = s:option(Flag, "Enable", translate("Band Steering Enable"))
e.rmempty = false
vl = s:option(Value, "MatchingSSID", translate("SSID to match"))
vl.datatype = "string"
vl = s:option(Flag, "PHYBasedPrioritization", translate("Whether to consider client's PHY capabilities first when sorting candidates for idle steering or offloading"))
vl.rmempty = false
e = s:option(Flag, "BlacklistOtherESS", translate("Whether to install blacklist rules on Other ESS"))
e.rmempty = false
e = s:option(Flag, "InactDetectionFromTx", translate("Whether to use Tx for inactivity detection"))
e.rmempty = false
e = s:option(Flag, "ClientClassificationEnable", translate("Enable Client Classification"))
e.rmempty = false

------------------------------------------------------------------------------------------------
--Station Database Setting
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "StaDB", "StaDB", translate("Station Database"))
s.anonymous = true

e = s:option(Flag, "IncludeOutOfNetwork", translate("Include out-of-network devices"))
e.rmempty = false
e = s:option(Flag, "TrackRemoteAssoc", translate("Track remote associations"))
e.rmempty = false
e = s:option(Flag, "MarkAdvClientAsDualBand", translate("Mark 11k/v capable devices as dual band"))
e.rmempty = false

------------------------------------------------------------------------------------------------
--Idle Steering Setting
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "IdleSteer", "IdleSteer", translate("Idle Steering Settings"))
s.anonymous = true

vl = s:option(Value, "RSSISteeringPoint_DG", translate("RSSI value indicating a node associated on 5 GHz should be steered to 2.4 GHz (dB)"))
vl.datatype = "uinteger"
vl = s:option(Value, "RSSISteeringPoint_UG", translate("RSSI value indicating a node associated on 2.4 GHz should be steered to 5 GHz (dB)"))
vl.datatype = "uinteger"
vl_inact_idle = s:option(Value, "NormalInactTimeout", translate("Normal Inactive timer (s)"))
vl_inact_idle.datatype = "uinteger"
vl_inact_overload = s:option(Value, "OverloadInactTimeout", translate("Overload Inactive timer (s)"))
vl_inact_overload.datatype = "uinteger"

function validate_inact_interval(interval, idle_threshold, overload_threshold)
	if (tonumber(interval) <= tonumber(overload_threshold)) and
           (tonumber(interval) <= tonumber(idle_threshold)) then
		return interval
	else
		return nil, "Inactivity check interval cannot be longer than the timer value"
	end
end

vl_inact_freq = s:option(Value, "InactCheckInterval", translate("Inactive Check Frequency (s)"))
vl_inact_freq.datatype = "uinteger"
function vl_inact_freq.validate(self, value, section)
	local idle = vl_inact_idle:formvalue(section)
	local overload = vl_inact_overload:formvalue(section)
	return validate_inact_interval(value, idle, overload)
end

------------------------------------------------------------------------------------------------
--Active Steering Setting
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "ActiveSteer", "ActiveSteer", translate("Active Steering Settings"))
s.anonymous = true

vl = s:option(Value, "TxRateXingThreshold_UG", translate("When the client Tx rate increases beyond this threshold, generate an indication (Kbps)"))
vl.datatype = "uinteger"
vl = s:option(Value, "RateRSSIXingThreshold_UG", translate("When evaluating a STA for rate-based upgrade steering, the RSSI must also be above this threshold (dB)"))
vl.datatype = "uinteger"
vl = s:option(Value, "TxRateXingThreshold_DG", translate("When the client Tx rate decreases beyond this threshold, generate an indication (Kbps)"))
vl.datatype = "uinteger"
vl = s:option(Value, "RateRSSIXingThreshold_DG", translate("When the client RSSI decreases beyond this threshold, generate an indication (dB)"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Offloading
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "Offload", "Offload", translate("Offloading Settings"))
s.anonymous = true

function validate_mu_period(period, interval_w2, interval_w5)
	if tonumber(interval_w2) > tonumber(period) or
           tonumber(interval_w5) > tonumber(period) then
		return nil, "Medium Utilization average period cannot be shorter than the check intervals"
	end
	return period
end

vl_mu_period = s:option(Value, "MUAvgPeriod", translate("Time to average before generating a new utilization report (s)"))
vl_mu_period.datatype = "uinteger"
function vl_mu_period.validate(self, value, section)
	local uci_r = uci.cursor()
	local interval_w2 = uci_r:get("lbd", "BandMonitor_Adv", "MUCheckInterval_W2")
	local interval_w5 = uci_r:get("lbd", "BandMonitor_Adv", "MUCheckInterval_W5")
	return validate_mu_period(value, interval_w2, interval_w5)
end

vl = s:option(Value, "MUOverloadThreshold_W2", translate("Medium utilization threshold for an overload condition on 2.4 GHz (%)"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "MUOverloadThreshold_W5", translate("Medium utilization threshold for an overload condition on 5 GHz (%)"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "MUSafetyThreshold_W2", translate("Medium utilization safety threshold for active steering to 2.4 GHz (%)"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "MUSafetyThreshold_W5", translate("Medium utilization saftey threshold for active steering to 5 GHz (%)"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "OffloadingMinRSSI", translate("Uplink RSSI (in dB) above which association will be considered safe"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--AP Steering
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "APSteer", "APSteer", translate("AP Steering Settings"))
s.anonymous = true

vl = s:option(Flag, "DisableSteeringInactiveLegacyClients", translate("DisableSteeringInactiveLegacyClients"))
vl.rmempty = false
vl = s:option(Flag, "DisableSteeringActiveLegacyClients", translate("DisableSteeringActiveLegacyClients"))
vl.rmempty = false
vl = s:option(Flag, "DisableSteering11kUnfriendlyClients", translate("DisableSteering11kUnfriendlyClients"))
vl.rmempty = false
vl_low_threshold = s:option(Value, "LowRSSIAPSteerThreshold_CAP", translate("RSSI value indicating a node associated on CAP is far enough to be steered to another AP"))
vl_low_threshold.datatype = "uinteger"
vl_low_threshold = s:option(Value, "LowRSSIAPSteerThreshold_RE", translate("RSSI value indicating a node associated on RE is far enough to be steered to another AP"))
vl_low_threshold.datatype = "uinteger"
vl = s:option(Value, "APSteerToRootMinRSSIIncThreshold", translate("The RSSI value (in dB) the target AP should exceed the serving AP to be considered for AP steering towards root"))
vl.datatype = "integer"
vl = s:option(Value, "APSteerToLeafMinRSSIIncThreshold", translate("The RSSI value (in dB) the target AP should exceed the serving AP to be considered for AP steering towards leaf"))
vl.datatype = "integer"
vl = s:option(Value, "APSteerToPeerMinRSSIIncThreshold", translate("The RSSI value (in dB) the target AP should exceed the serving AP to be considered for AP steering between peers"))
vl.datatype = "integer"
vl = s:option(Value, "DownlinkRSSIThreshold_W5", translate("The value (in dB) the target AP downlink should exceed to be considered to steer to 5 GH"))
vl.datatype = "integer"

------------------------------------------------------------------------------------------------
--Interference Avoidance Steering
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "IAS", "IAS", translate("Interference Avoidance Steering Settings"))
s.anonymous = true

vl = s:option(Value, "Enable_W2", translate("If cleared, will not perform any Interference Avoidance Steering from the 2.4GHz band"))
vl.rmempty = false
vl = s:option(Value, "Enable_W5", translate("If cleared, will not perform any Interference Avoidance Steering from the 5GHz band"))
vl.rmempty = false
vl = s:option(Value, "MaxPollutionTime", translate("Maximum time (in seconds) a BSS can be considered polluted with no further updates"))
vl.datatype = "uinteger"
vl = s:option(Value, "UseBestEffort", translate("If set, use best-effort mode (failures do not mark a STA as unfriendly) for IAS steering"))
vl.rmempty = false

------------------------------------------------------------------------------------------------
--Steer Executor Settings
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "SteerExec", "SteerExec", translate("Steering Executor Settings"))
s.anonymous = true
vl = s:option(Value, "SteeringProhibitTime", translate("Time to wait before steering a legacy client again after completing steering (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "BTMSteeringProhibitShortTime", translate("Time to wait before steering a client via BTM again after completing steering without sending an auth reject (s)"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Advanced Settings / Diagnostic Logging Settings
------------------------------------------------------------------------------------------------
js = s:option(DummyValue, "script", translate("script for WHC"))
js.template = "whc/lbd_dview_js"

local form_adv, ferr_adv = loadfile(luci.util.libpath() .. "/model/cbi/whc/lbd_advanced.lua")
if form_adv then
	bt = s:option(DummyValue, "showadv", translate("show advanced"))
	bt.template = "whc/lbd_btn_adv"
	setfenv(form_adv, getfenv(1))(m, s)
end

local form_diag, ferr_diag = loadfile(luci.util.libpath() .. "/model/cbi/whc/lbd_diaglog.lua")
if form_diag then
	bt = s:option(DummyValue, "showdiag", translate("show diagnostic logging"))
	bt.template = "whc/lbd_btn_diag"
	setfenv(form_diag, getfenv(1))(m, s)
end

return m
