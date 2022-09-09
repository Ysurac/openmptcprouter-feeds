--[[
LuCI - Lua Configuration Interface

Copyright (c) 2013, 2017-2019 Qualcomm Technologies, Inc.
All Rights Reserved.
Confidential and Proprietary - Qualcomm Technologies, Inc.

2013 Qualcomm Atheros, Inc.
All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

local m, s = ...
------------------------------------------------------------------------------------------------
--Advanced Hy-Fi
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "hy", translate("Advanced Hy-Fi Settings"))
s.anonymous = true

li = s:option(ListValue, "LoadBalancingSeamless", translate("Load-balancing seamless path switching"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "1"

vl = s:option(Value, "MaxLBReordTimeout", translate("Max LB reordering timeout"))
vl.datatype = "uinteger"

li = s:option(ListValue, "StrictIEEE1905Mode", translate("Strict IEEE 1905.1 Mode"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "1"
function li.cfgvalue(self, section)
        return m.uci:get(m.config, "IEEE1905Settings", self.option)
end
function li.write(self, section, value)
        m.uci:set(m.config, "IEEE1905Settings", self.option, value)
end

li = s:option(ListValue, "GenerateLLDP", translate("Generate LLDP packets"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "1"
function li.cfgvalue(self, section)
        return m.uci:get(m.config, "IEEE1905Settings", self.option)
end
function li.write(self, section, value)
        m.uci:set(m.config, "IEEE1905Settings", self.option, value)
end

li = s:option(ListValue, "AvoidDupRenew", translate("Avoid Duplicate Renew packets Upstream"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "0"
function li.cfgvalue(self, section)
        return m.uci:get(m.config, "IEEE1905Settings", self.option)
end
function li.write(self, section, value)
        m.uci:set(m.config, "IEEE1905Settings", self.option, value)
end

li = s:option(ListValue, "AvoidDupTopologyNotification", translate("Avoid Duplicate Topology Notification packets Upstream"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "0"
function li.cfgvalue(self, section)
        return m.uci:get(m.config, "IEEE1905Settings", self.option)
end
function li.write(self, section, value)
        m.uci:set(m.config, "IEEE1905Settings", self.option, value)
end

li = s:option(ListValue, "V1Compat", translate("Hy-Fi 1.0 Compatibility Mode"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "1"
function li.cfgvalue(self, section)
        return m.uci:get(m.config, "HCPSettings", self.option)
end
function li.write(self, section, value)
        m.uci:set(m.config, "HCPSettings", self.option, value)
end

li = s:option(ListValue, "ConstrainTCPMedium", translate("Constrain TCP-ACK streams to the same medium as their primary TCP-DATA stream"))
li:value("1", translate("Enable"))
li:value("0", translate("Disable"))
li.default = "1"

vl = s:option(Value, "HActiveMaxAge", translate("Maximum age of a H-Active entry before it will be aged out (ms)"))
vl.datatype = "uinteger"

li = s:option(ListValue, "ForwardingMode", translate("Hy-Fi Netfilter forwarding mode"))
li:value("APS", translate("APS"))
li:value("SINGLE", translate("No Hybrid Tables"))
li:value("MCAST", translate("Multicast Only"))
li.default = "APS"

vl = s:option(Value, "ExtraQueryResponseTime", translate("IGMP Extra Query response time"))
vl.datatype = "uinteger"
------------------------------------------------------------------------------------------------
--Auto Configuration
------------------------------------------------------------------------------------------------
if nixio.fs.access("/etc/init.d/acd") then
function acdValue(section, option, title)
	vl = section:option(Value, option, translate(title))
	vl.datatype = "uinteger"
	vl.cfgvalue = function (self, section)
	        return m.uci:get("acd", "config", self.option)
		end
	vl.write    = function (self, section, value)
	        m.uci:set("acd", "config", self.option, value)
		end
	return vl
end

function acdEnableList(section, option, title)
	li = section:option(ListValue, option, translate(title))
	li:value("1", translate("Enable"))
	li:value("0", translate("Disable"))
	li.default = "1"
	li.cfgvalue = function (self, section)
	        return m.uci:get("acd", "config", self.option)
		end
	li.write    = function (self, section, value)
	        m.uci:set("acd", "config", self.option, value)
		end
	return li
end

s = m:section(TypedSection, "hy", translate("Advanced Auto-Configuration Settings"))
s.anonymous = true

acdValue(s, "HCSecsBetweenDHCPRequestPackets", "Interval Between DHCP Discovery Messages (sec)")
acdValue(s, "HRSecsBetweenDHCPRequestPackets", "HR Number of Seconds Between DHCP Retries")
acdValue(s, "HRSecsBetweenStateContinuityCheck", "HR Maintenance Interval Between DHCP Discovery Messages (sec)")
acdValue(s, "HRMaxTriesWaitingForDHCPResponse", "HR Max Number of DHCP Retries")
acdValue(s, "HCMaxTxTriesBeforeGettingIPAddr", "Re-Check IP Address on Every N Retries")
acdValue(s, "SecsBetweenChecksForCableConnection", "Link Status Check Interval (sec)")
acdValue(s, "AcdDebugLevel", "Debug Level")
acdEnableList(s, "DisableHCMode", "Hybrid Client Always in Range Extender Mode")
acdEnableList(s, "DisableWDSSTAInHREMode", "Disable local WDS station in Range Extender Mode")
end

------------------------------------------------------------------------------------------------
--General WLAN Path Characterization Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "PathChWlan", translate("General WLAN Path Characterization Setting"))
s.anonymous = true
vl = s:option(Value, "UseWHCAlgorithm", translate("Use the WHC algorithm to calculate link capacity"))
vl.datatype = "uinteger"
vl = s:option(Value, "NumUpdatesUntilStatsValid", translate("Number of capacity updates to receive after link change before considered valid"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--WLAN 5G Path Characterization Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "PathChWlan", translate("WLAN 5G Path Characterization Setting"))
s.anonymous = true
vl = s:option(Value, "UpdatedStatsInterval_W5", translate("UpdatedStatsInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "StatsAgedOutInterval_W5", translate("StatsAgedOutInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxMediumUtilization_W5", translate("MaxMediumUtilization"))
vl.datatype = "uinteger"
vl = s:option(Value, "MediumChangeThreshold_W5", translate("MediumChangeThreshold"))
vl.datatype = "uinteger"
vl = s:option(Value, "LinkChangeThreshold_W5", translate("LinkChangeThreshold"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxMediumUtilizationForLC_W5", translate("MaxMediumUtilizationForLC"))
vl.datatype = "uinteger"
vl = s:option(Value, "CPULimitedTCPThroughput_W5", translate("CPULimitedTCPThroughput"))
vl.datatype = "uinteger"
vl = s:option(Value, "CPULimitedUDPThroughput_W5", translate("CPULimitedUDPThroughput"))
vl.datatype = "uinteger"
vl = s:option(Value, "PHYRateThresholdForMU_W5", translate("PHYRateThresholdForMU"))
vl.datatype = "uinteger"
vl = s:option(Value, "ProbePacketInterval_W5", translate("ProbePacketInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "ProbePacketSize_W5", translate("ProbePacketSize"))
vl.datatype = "uinteger"
vl = s:option(Value, "EnableProbe_W5", translate("EnableProbe"))
vl.datatype = "uinteger"
vl = s:option(Value, "AssocDetectionDelay_W5", translate("AssocDetectionDelay"))
vl.datatype = "uinteger"
vl = s:option(Value, "ScalingFactorHighRate_W5", translate("Rate above which ScalingFactorHigh is used"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--WLAN 6G Path Characterization Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "PathChWlan", translate("WLAN 6G Path Characterization Setting"))
s.anonymous = true
vl = s:option(Value, "UpdatedStatsInterval_W6", translate("UpdatedStatsInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "StatsAgedOutInterval_W6", translate("StatsAgedOutInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxMediumUtilization_W6", translate("MaxMediumUtilization"))
vl.datatype = "uinteger"
vl = s:option(Value, "MediumChangeThreshold_W6", translate("MediumChangeThreshold"))
vl.datatype = "uinteger"
vl = s:option(Value, "LinkChangeThreshold_W6", translate("LinkChangeThreshold"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxMediumUtilizationForLC_W6", translate("MaxMediumUtilizationForLC"))
vl.datatype = "uinteger"
vl = s:option(Value, "CPULimitedTCPThroughput_W6", translate("CPULimitedTCPThroughput"))
vl.datatype = "uinteger"
vl = s:option(Value, "CPULimitedUDPThroughput_W6", translate("CPULimitedUDPThroughput"))
vl.datatype = "uinteger"
vl = s:option(Value, "PHYRateThresholdForMU_W6", translate("PHYRateThresholdForMU"))
vl.datatype = "uinteger"
vl = s:option(Value, "ProbePacketInterval_W6", translate("ProbePacketInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "ProbePacketSize_W6", translate("ProbePacketSize"))
vl.datatype = "uinteger"
vl = s:option(Value, "EnableProbe_W6", translate("EnableProbe"))
vl.datatype = "uinteger"
vl = s:option(Value, "AssocDetectionDelay_W6", translate("AssocDetectionDelay"))
vl.datatype = "uinteger"
vl = s:option(Value, "ScalingFactorHighRate_W6", translate("Rate above which ScalingFactorHigh is used"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--WLAN 2G Path Characterization Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "PathChWlan", translate("WLAN 2.4G Path Characterization Setting"))
s.anonymous = true
vl = s:option(Value, "UpdatedStatsInterval_W2", translate("UpdatedStatsInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "StatsAgedOutInterval_W2", translate("StatsAgedOutInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxMediumUtilization_W2", translate("MaxMediumUtilization"))
vl.datatype = "uinteger"
vl = s:option(Value, "MediumChangeThreshold_W2", translate("MediumChangeThreshold"))
vl.datatype = "uinteger"
vl = s:option(Value, "LinkChangeThreshold_W2", translate("LinkChangeThreshold"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxMediumUtilizationForLC_W2", translate("MaxMediumUtilizationForLC"))
vl.datatype = "uinteger"
vl = s:option(Value, "CPULimitedTCPThroughput_W2", translate("CPULimitedTCPThroughput"))
vl.datatype = "uinteger"
vl = s:option(Value, "CPULimitedUDPThroughput_W2", translate("CPULimitedUDPThroughput"))
vl.datatype = "uinteger"
vl = s:option(Value, "PHYRateThresholdForMU_W2", translate("PHYRateThresholdForMU"))
vl.datatype = "uinteger"
vl = s:option(Value, "ProbePacketInterval_W2", translate("ProbePacketInterval"))
vl.datatype = "uinteger"
vl = s:option(Value, "ProbePacketSize_W2", translate("ProbePacketSize"))
vl.datatype = "uinteger"
vl = s:option(Value, "EnableProbe_W2", translate("EnableProbe"))
vl.datatype = "uinteger"
vl = s:option(Value, "AssocDetectionDelay_W2", translate("AssocDetectionDelay"))
vl.datatype = "uinteger"
vl = s:option(Value, "ScalingFactorHighRate_W2", translate("Rate above which ScalingFactorHigh is used"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--PLC Path Characterization Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "PathChPlc", translate("PLC Path Characterization Setting"))
s.anonymous = true
vl = s:option(Value, "MaxMediumUtilization", translate("MaxMediumUtilization"))
vl.datatype = "uinteger"

vl = s:option(Value, "MediumChangeThreshold", translate("MediumChangeThreshold"))
vl.datatype = "uinteger"

vl = s:option(Value, "LinkChangeThreshold", translate("LinkChangeThreshold"))
vl.datatype = "uinteger"

vl = s:option(Value, "StatsAgedOutInterval", translate("StatsAgedOutInterval"))
vl.datatype = "uinteger"

vl = s:option(Value, "UpdateStatsInterval", translate("UpdateStatsInterval"))
vl.datatype = "uinteger"

vl = s:option(Value, "EntryExpirationInterval", translate("EntryExpirationInterval"))
vl.datatype = "uinteger"

vl = s:option(Value, "MaxMediumUtilizationForLC", translate("MaxMediumUtilizationForLC"))
vl.datatype = "uinteger"

vl = s:option(Value, "LCThresholdForUnreachable", translate("LCThresholdForUnreachable"))
vl.datatype = "uinteger"

vl = s:option(Value, "LCThresholdForReachable", translate("LCThresholdForReachable"))
vl.datatype = "uinteger"

vl = s:option(Value, "HostPLCInterfaceSpeed", translate("HostPLCInterfaceSpeed"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Stream Estimation Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "HSPECEst", translate("Stream Estimation Setting"))
s.anonymous = true

vl = s:option(Value, "UpdateHSPECInterval", translate("UpdateHSPECInterval"))
vl.datatype = "uinteger"

vl = s:option(Value, "NotificationThresholdLimit", translate("NotificationThresholdLimit"))
vl.datatype = "uinteger"

vl = s:option(Value, "NotificationThresholdPercentage", translate("NotificationThresholdPercentage"))
vl.datatype = "uinteger"

vl = s:option(Value, "AlphaNumerator", translate("AlphaNumerator"))
vl.datatype = "uinteger"

vl = s:option(Value, "AlphaDenominator", translate("AlphaDenominator"))
vl.datatype = "uinteger"

vl = s:option(Value, "LocalFlowRateThreshold", translate("LocalFlowRateThreshold"))
vl.datatype = "uinteger"

vl = s:option(Value, "LocalFlowRatioThreshold", translate("LocalFlowRatioThreshold"))
vl.datatype = "uinteger"

vl = s:option(Value, "MaxHActiveEntries", translate("Maximum number of H-Active entries supported in user-space"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Topology Discovery Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "Topology", translate("Topology Discovery Setting"))
s.anonymous = true

vl = s:option(Value, "ND_UPDATE_INTERVAL", translate("ND_UPDATE_INTERVAL"))
vl.datatype = "uinteger"

vl = s:option(Value, "BD_UPDATE_INTERVAL", translate("BD_UPDATE_INTERVAL"))
vl.datatype = "uinteger"

vl = s:option(Value, "HOLDING_TIME", translate("HOLDING_TIME"))
vl.datatype = "uinteger"

vl = s:option(Value, "TIMER_LOW_BOUND", translate("TIMER_LOW_BOUND"))
vl.datatype = "uinteger"

vl = s:option(Value, "TIMER_UPPER_BOUND", translate("TIMER_UPPER_BOUND"))
vl.datatype = "uinteger"

vl = s:option(Value, "MSGID_DELTA", translate("MSGID_DELTA"))
vl.datatype = "uinteger"

vl = s:option(Value, "HA_AGING_INTERVAL", translate("HA_AGING_INTERVAL"))
vl.datatype = "uinteger"

vl = s:option(Value, "ENABLE_TD3", translate("ENABLE_TD3"))
vl.datatype = "uinteger"

vl = s:option(Value, "ENABLE_BD_SPOOFING", translate("ENABLE_BD_SPOOFING"))
vl.datatype = "uinteger"

vl = s:option(Value, "NOTIFICATION_THROTTLING_WINDOW", translate("NOTIFICATION_THROTTLING_WINDOW"))
vl.datatype = "uinteger"

vl = s:option(Value, "PERIODIC_QUERY_INTERVAL", translate("PERIODIC_QUERY_INTERVAL"))
vl.datatype = "uinteger"

vl = s:option(Flag, "ENABLE_NOTIFICATION_UNICAST", translate("ENABLE_NOTIFICATION_UNICAST"))
vl.rmempty = false

------------------------------------------------------------------------------------------------
--Path Selection Setting
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "PathSelect", translate("Path Selection Setting"))
s.anonymous = true

vl = s:option(Value, "UpdateHDInterval", translate("UpdateHDInterval"))
vl.datatype = "uinteger"

vl = s:option(Value, "LinkCapacityThreshold", translate("LinkCapacityThreshold"))
vl.datatype = "uinteger"

vl = s:option(Value, "UDPInterfaceOrder", translate("UDPInterfaceOrder"))
vl.datatype = "string"

vl = s:option(Value, "NonUDPInterfaceOrder", translate("NonUDPInterfaceOrder"))
vl.datatype = "string"

vl = s:option(Value, "SerialflowIterations", translate("SerialflowIterations"))
vl.datatype = "uinteger"

vl = s:option(Value, "DeltaLCThreshold", translate("DeltaLCThreshold"))
vl.datatype = "uinteger"

vl = s:option(Flag, "EnableBadLinkStatsSwitchFlow", translate("EnableBadLinkStatsSwitchFlow"))
vl.rmempty = false

------------------------------------------------------------------------------------------------
--WLAN Manager Settings
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "Wlan", translate("WLAN Manager Settings"))
s.anonymous = true

vl = s:option(Value, "WlanCheckFreqInterval", translate("WlanCheckFreqInterval"))
vl.datatype = "uinteger"

vl = s:option(Value, "WlanALDNLNumOverride", translate("WlanALDNLNumOverride"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--LOG settings
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "LogSettings", translate("LOG settings"))
s.anonymous = true

vl = s:option(Value, "EnableLog", translate("EnableLog"))
vl.datatype = "uinteger"

vl = s:option(Value, "LogRestartIntervalSec", translate("LogRestartIntervalSec"))
vl.datatype = "uinteger"

vl = s:option(Value, "LogPCSummaryPeriodSec", translate("LogPCSummaryPeriodSec"))
vl.datatype = "uinteger"

vl = s:option(Value, "LogServerIP", translate("LogServerIP"))
vl.datatype = "ipaddr"

vl = s:option(Value, "LogServerPort", translate("LogServerPort"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogPCW2", translate("EnableLogPCW2"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogPCW5", translate("EnableLogPCW5"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogPCW6", translate("EnableLogPCW6"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogPCP", translate("EnableLogPCP"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogTD", translate("EnableLogTD"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogHE", translate("EnableLogHE"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogHETables", translate("EnableLogHETables"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogPS", translate("EnableLogPS"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableLogPSTables", translate("EnableLogPSTables"))
vl.datatype = "uinteger"

vl = s:option(Value, "LogHEThreshold1", translate("LogHEThreshold1"))
vl.datatype = "uinteger"

vl = s:option(Value, "LogHEThreshold2", translate("LogHEThreshold2"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Multi-AP Implementation settings
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "MultiAP", translate("Multi-AP Implementation settings"))
s.anonymous = true

vl = s:option(Flag, "EnableController", translate("EnableController"))
vl.rmempty = false

vl = s:option(Flag, "EnableAgent", translate("EnableAgent"))
vl.rmempty = false

vl = s:option(Flag, "EnableSigmaDUT", translate("EnableSigmaDUT"))
vl.rmempty = false

vl = s:option(Flag, "EnableMapV2", translate("EnableMapV2"))
vl.rmempty = false

vl = s:option(Value, "ClientAssocCtrlTimeoutSec", translate("ClientAssocCtrlTimeout (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "ClientAssocCtrlTimeoutUsec", translate("ClientAssocCtrlTimeout (us)"))
vl.datatype = "uinteger"

vl = s:option(Value, "ShortBlacklistTimeSec", translate("ShortBlacklistTime (s)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "AlwaysClearBlacklists", translate("AlwaysClearBlacklists"))
vl.rmempty = true

vl = s:option(Value, "ClientSteerTimeoutSec", translate("ClientSteerTimeout (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "ClientSteerTimeoutUsec", translate("ClientSteerTimeout (us)"))
vl.datatype = "uinteger"

vl = s:option(Value, "MetricsReportingInterval", translate("MetricsReportingInterval (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "RSSIHysteresis_W2", translate("RSSIHysteresis on 2.4 GHz"))
vl.datatype = "uinteger"

vl = s:option(Value, "RSSIHysteresis_W5", translate("RSSIHysteresis on 5 GHz"))
vl.datatype = "uinteger"

vl = s:option(Value, "RSSIHysteresis_W6", translate("RSSIHysteresis on 6 GHz"))
vl.datatype = "uinteger"

vl = s:option(Value, "LoadBalancingInterval", translate("LoadBalancingInterval (s)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "EnableChannelSelection", translate("EnableChannelSelection"))
vl.rmempty = false

vl = s:option(Value, "MinPreferredChannelIndex", translate("MinPreferredChannelIndex"))
vl.datatype = "uinteger"

vl = s:option(Value, "MaxPreferredChannelIndex", translate("MaxPreferredChannelIndex"))
vl.datatype = "uinteger"

vl = s:option(Flag, "EnableTopologyOpt", translate("EnableTopologyOpt"))
vl.rmempty = false

vl = s:option(Value, "TopologyOptCron", translate("TopologyOptCron"))
vl.datatype = "string"

vl = s:option(Value, "TopologyOptNewAgentDelay", translate("TopologyOptNewAgentDelay"))
vl.datatype = "uinteger"

vl = s:option(Value, "TopologyOptDelAgentDelay", translate("TopologyOptDelAgentDelay"))
vl.datatype = "uinteger"

vl = s:option(Value, "TopologyOptCollectionTime", translate("TopologyOptCollectionTime"))
vl.datatype = "uinteger"

vl = s:option(Value, "TopologyOptActivityMonitoringSecs", translate("TopologyOptActivityMonitoringSecs"))
vl.datatype = "uinteger"

vl = s:option(Value, "TopologyOptMinIncreasePercentage", translate("TopologyOptMinIncreasePercentage"))
vl.datatype = "and(uinteger(range(0, 100))"

vl = s:option(Flag, "TopologyOptAllowActiveSteer", translate("TopologyOptAllowActiveSteer"))
vl.rmempty = false

vl = s:option(Value, "TopologyOptMaxIdleWaitSecs", translate("TopologyOptMaxIdleWaitSecs"))
vl.datatype = "uinteger"

vl = s:option(Value, "TopologyOptSettlingTime", translate("TopologyOptSettlingTime"))
vl.datatype = "uinteger"

vl = s:option(Value, "UnassocMetricsRspWaitTimeSec", translate("UnassocMetricsRspWaitTime (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "UnassocMetricsRspMsgTimeout", translate("UnassocMetricsRspMsgTimeout (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "CBSDwellSplitMSec", translate("CBSDwellSplit (ms)"))
vl.datatype = "uinteger"

vl = s:option(Value, "CBSDelaySec", translate("CBSDelay (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "CBSStateResetSec", translate("CBSStateReset (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "BkScanIntervalMin", translate("BkScanInterval (minutes)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "EnableCronBasedBkScan", translate("EnableCronBasedBkScan"))
vl.rmempty = false

vl = s:option(Value, "BkScanCron", translate("BkScanCron"))
vl.datatype = "string"

vl = s:option(Flag, "UseCBSRankForHomeChan", translate("UseCBSRankForHomeChan"))
vl.rmempty = false

vl = s:option(Flag, "EnableChanPrefQuery", translate("EnableChanPrefQuery"))
vl.rmempty = false

vl = s:option(Value, "ChanPrefQueryCron", translate("ChanPrefQueryCron"))
vl.datatype = "string"

vl = s:option(Flag, "ChannelSelectionOnGlobalPref", translate("ChannelSelectionOnGlobalPref"))
vl.rmempty = false

vl = s:option(Flag, "ChannelSelectionDelaySec", translate("ChannelSelectionDelay (sec)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "ChanSupervisionMinDelaySec", translate("MinChannelSupervisionDelay(sec)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "ChanSupervisionMaxDelaySec", translate("MaxChannelSupervisionDelay (sec)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "ChanSupervisionMaxAttempts", translate("MaxChannelSupervisionAttempts"))
vl.datatype = "uinteger"

vl = s:option(Flag, "ChanSupervisionIntervalSec", translate("ChannelSupervisionInterval (sec)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "ChanSupervisionTolerate40MHzCoexRulesOn24GHz", translate("ChanSupervisionTolerate40MHzCoexRulesOn24GHz"))
vl.rmempty = false

vl = s:option(Flag, "ControllerChanSelection160MHz", translate("ControllerChanSelection160MHz"))
vl.rmempty = false

vl = s:option(Flag, "AgentChanSelection160MHz", translate("AgentChanSelection160MHz"))
vl.rmempty = false

vl = s:option(Flag, "ControllerChanSelection40MHzOn2G", translate("ControllerChanSelection40MHzOn2G"))
vl.rmempty = false

vl = s:option(Flag, "AgentChanSelection40MHzOn2G", translate("AgentChanSelection40MHzOn2G"))
vl.rmempty = false

vl = s:option(Flag, "ChanSelectionMinIncPercent", translate("ChannelSelectionMinIncPercent"))
vl.datatype = "uinteger"

vl = s:option(Flag, "AgentChanMismatchCheckInterval", translate("AgentChanMismatchCheckInterval"))
vl.datatype = "uinteger"

vl = s:option(Value, "UnassocRSSIAgeLimitSec", translate("UnassocRSSIAgeLimit (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "UnassocPeriodicQueryTimeSec", translate("UnassocPeriodicQueryTime (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "UnassocActiveClientTimeoutSec", translate("UnassocActiveClientTimeoutSec (s)"))
vl.datatype = "uinteger"

vl = s:option(Value, "UnassocMetricsDriverPollingTime", translate("UnassocMetricsDriverPollingTime (s)"))
vl.datatype = "uinteger"

vl = s:option(Flag, "EnableBootOnlyScan", translate("EnableBootOnlyScan"))
vl.rmempty = false

vl = s:option(Value, "ChanScanIntervalMin", translate("ChanScanIntervalMin (minutes)"))
vl.datatype = "uinteger"

vl = s:option(Value, "MapR1R2MixNotSupported", translate("MapR1R2MixNotSupported"))
vl.datatype = "uinteger"

vl = s:option(Value, "MapPFCompliant", translate("MapPFCompliant"))

vl = s:option(Value, "NumberOfVLANSupported", translate("NumberOfVLANSupported"))
vl.datatype = "uinteger"

vl = s:option(Value, "Map2TrafficSepEnabled", translate("Map2TrafficSepEnabled"))
vl.datatype = "uinteger"

vl = s:option(Value, "Map8021QPCP", translate("Map8021QPCP"))
vl.datatype = "uinteger"

vl = s:option(Value, "FronthaulSSIDPrimary", translate("FronthaulSSIDPrimary"))
vl.datatype = "string"

vl = s:option(Value, "VlanIDNwPrimary", translate("VlanIDNwPrimary"))
vl.datatype = "uinteger"

vl = s:option(Value, "FronthaulSSIDNwOne", translate("FronthaulSSIDNwOne"))
vl.datatype = "string"

vl = s:option(Value, "VlanIDNwOne", translate("VlanIDNwOne"))
vl.datatype = "uinteger"

vl = s:option(Value, "FronthaulSSIDNwTwo", translate("FronthaulSSIDNwTwo"))
vl.datatype = "string"

vl = s:option(Value, "VlanIDNwTwo", translate("VlanIDNwTwo"))
vl.datatype = "uinteger"

vl = s:option(Value, "FronthaulSSIDNwThree", translate("FronthaulSSIDNwThree"))
vl.datatype = "string"

vl = s:option(Value, "VlanIDNwThree", translate("VlanIDNwThree"))
vl.datatype = "uinteger"

vl = s:option(Value, "CombinedR1R2Backhaul", translate("CombinedR1R2Backhaul"))
vl.datatype = "uinteger"

vl = s:option(Value, "VlanNetworkPrimary", translate("VlanNetworkPrimary"))
vl.datatype = "string"

vl = s:option(Value, "EnableChannelScanRequest", translate("EnableChannelScanRequest"))
vl.datatype = "uinteger"

vl = s:option(Value, "EnableRptIndependentScan", translate("EnableRptIndependentScan"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Steering Message settings
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "SteerMsg", translate("Steering Message settings"))
s.anonymous = true

vl = s:option(Value, "AvgUtilReqTimeout", translate("AvgUtilReqTimeout"))
vl.datatype = "uinteger"

vl = s:option(Value, "LoadBalancingCompleteTimeout", translate("LoadBalancingCompleteTimeout"))
vl.datatype = "uinteger"

vl = s:option(Value, "RspTimeout", translate("RspTimeout"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Monitoring settings
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "Monitor", translate("Monitoring settings"))
s.anonymous = true

vl = s:option(Value, "MonitorTimer", translate("MonitorTimer"))
vl.datatype = "uinteger"

vl = s:option(Value, "MonitorResponseTimeout", translate("MonitorResponseTimeout"))
vl.datatype = "uinteger"
