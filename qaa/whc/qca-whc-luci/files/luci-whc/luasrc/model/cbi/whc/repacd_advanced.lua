--[[
LuCI - Lua Configuration Interface

@@-COPYRIGHT-START-@@

Copyright (c) 2015-2019 Qualcomm Technologies, Inc.

All Rights Reserved.
Confidential and Proprietary - Qualcomm Technologies, Inc.

2015-2016 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

@@-COPYRIGHT-END-@@

]]--

local m, s = ...

------------------------------------------------------------------------------
--Gateway link monitoring settings
------------------------------------------------------------------------------
s = m:section(NamedSection, "GatewayLink", "GatewayLink", translate("Gateway Link Monitoring"))
s.anonymous = true

vl = s:option(Value, "ReachableConfirmationAttempts", translate("ARPs to send to GW over Ethernet to confirm connectivity"))
vl.datatype = "uinteger"

vl = s:option(Value, "ReachableConfirmationReplies", translate("Number of times the GW must reply to the reachability confirmation ARPs"))
vl.datatype = "uinteger"

vl = s:option(Value, "UnreachableMaxAttempts", translate("Number of lost GW pings before declaring it unreachable"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------
--Wi-Fi link monitoring settings
------------------------------------------------------------------------------
s = m:section(NamedSection, "WiFiLink", "WiFiLink", translate("Wi-Fi Link Monitoring"))
s.anonymous = true

vl = s:option(Value, "MinAssocCheckAutoMode", translate("Minimum association checks for auto-mode switching"))
vl.datatype = "uinteger"

vl = s:option(Value, "MinAssocCheckPostWPS", translate("Minimum association checks post Wi-Fi Protected Setup (WPS)"))
vl.datatype = "uinteger"

vl = s:option(Value, "MinAssocCheckPostBSSIDConfig", translate("Minimum association checks post BSSID Resolve complete in Daisy network"))
vl.datatype = "uinteger"

vl = s:option(Value, "WPSTimeout", translate("Wi-Fi Protected Setup (WPS) Timeout"))
vl.datatype = "uinteger"

vl = s:option(Value, "AssociationTimeout", translate("Association Timeout"))
vl.datatype = "uinteger"

vl = s:option(Value, "RSSINumMeasurements", translate("Number of RSSI measurements for coverage check"))
vl.datatype = "uinteger"

vl = s:option(Value, "RSSIThresholdFar", translate("RSSI value below which RE is considered too far from root AP"))
vl.datatype = "integer"

vl = s:option(Value, "RSSIThresholdNear", translate("RSSI value above which RE is considered too close to root AP"))
vl.datatype = "integer"

vl = s:option(Value, "RSSIThresholdMin", translate("Minimum RSSI value for a good link when operating in client mode"))
vl.datatype = "integer"

vl = s:option(Value, "2GBackhaulSwitchDownTime", translate("2.4G Backhaul Downtime, After this Backhaul switchover will start even to bad 5G Backhaul"))
vl.datatype = "integer"

vl = s:option(Value, "MaxMeasuringStateAttempts", translate("Max consectuive failed attempts for measuring rssi on 5g before it is considered as bad "))
vl.datatype = "integer"

e = s:option(Flag, "DaisyChain", translate("RE Daisy chain topology Enable, Enables Rate measurement and Disables RSSI measurement"))
e.rmempty = false

vl = s:option(Value, "RateNumMeasurements", translate("Number of Rate measurements for coverage check"))
vl.datatype = "uinteger"

vl = s:option(Value, "RateThresholdMin5GInPercent", translate("Percentage 5G Rate below which RE is considered too far from connected AP, triggers Best AP selection"))
vl.datatype = "uinteger"

vl = s:option(Value, "RateThresholdMax5GInPercent", translate("Percentage 5G Rate above which RE is considered too close to connected AP, triggers Best AP selection"))
vl.datatype = "uinteger"

vl = s:option(Value, "RateThresholdPrefer2GBackhaulInPercent", translate("Percentage 5G Rate below which RE will start bad link timer"))
vl.datatype = "uinteger"

vl = s:option(Value, "5GBackhaulBadlinkTimeout", translate("5G bad link Timeout, After this RE will bring down 5G and run 2G"))
vl.datatype = "uinteger"

vl = s:option(Value, "BSSIDAssociationTimeout", translate("BSSID Association Timeout, after this RE will look for new AP"))
vl.datatype = "uinteger"

vl = s:option(Value, "RateScalingFactor", translate("Rate Scaling factor to use for this hop"))
vl.datatype = "uinteger"

vl = s:option(Value, "5GBackhaulEvalTimeShort", translate("Short eval time for bring back up forcibly down 5g backhaul.its used only once per power cycle."))
vl.datatype = "integer"

vl = s:option(Value, "5GBackhaulEvalTimeLong", translate("Long eval time for bring back up forcibly down 5g backhaul.its used till power cycle."))
vl.datatype = "integer"

vl = s:option(Value, "2GBackhaulEvalTime", translate("Eval time for bring back up forcibly down 2.4g backhaul"))
vl.datatype = "integer"

e = s:option(Flag, "ManageVAPInd", translate("Allows REPACD to control the VAP independent option"))
e.rmempty = false

vl = s:option(Value, "PreferCAPSNRThreshold5G", translate("CAP SNR threshold for connecting to CAP irrespective of rate measurement"))
vl.datatype = "integer"

vl = s:option(Value, "MoveFromCAPSNRHysteresis5G", translate("SNR Hysteresis value to move away from CAP if already connected with CAP"))
vl.datatype = "integer"

------------------------------------------------------------------------------
--Multi-AP Topology Optimization Wi-Fi link monitoring settings
------------------------------------------------------------------------------
s = m:section(NamedSection, "MAPWiFiLink", "MAPWiFiLink", translate("Multi-AP Topology Optimization Wi-Fi Link Monitoring"))
s.anonymous = true

vl = s:option(Value, "MinAssocCheckPostWPS", translate("Minimum association checks post Wi-Fi Protected Setup (WPS)"))
vl.datatype = "uinteger"

vl = s:option(Value, "WPSTimeout", translate("Wi-Fi Protected Setup (WPS) Timeout"))
vl.datatype = "uinteger"

vl = s:option(Value, "AssociationTimeout", translate("Association Timeout"))
vl.datatype = "uinteger"

vl = s:option(Value, "BSSIDTimeout", translate("BSSID Timeout"))
vl.datatype = "uinteger"

vl = s:option(Value, "RSSINumMeasurements", translate("Number of RSSI measurements for bSTA link check"))
vl.datatype = "uinteger"

vl = s:option(Value, "BackhaulRSSIThreshold_2", translate("2.4 GHz Backhaul RSSI Threshold (dBm)"))
vl.datatype = "uinteger"

vl = s:option(Value, "BackhaulRSSIThreshold_5", translate("5 GHz Backhaul RSSI Threshold (dBm)"))
vl.datatype = "uinteger"

vl = s:option(Value, "BackhaulRSSIThreshold_offset", translate("Offset above 2.4 GHz Backhaul RSSI Threshold to trigger 5 GHz Re-evaluation"))
vl.datatype = "uinteger"

vl = s:option(Value, "Max5gAttempts", translate("Number of re-evaluations of 5 GHz bSTA before selecting 2.4 GHz bSTA"))
vl.datatype = "uinteger"

vl = s:option(Value, "MaxMeasuringStateAttempts", translate("Max consectuive failed attempts for measuring RSSI before moving on to next radio"))
vl.datatype = "integer"

e = s:option(Flag, "ForceBSSesDownOnAllBSTASwitches", translate("Force all BSSes down at startup when switching bSTA interfaces"))
e.rmempty = false

------------------------------------------------------------------------------
--PLC link monitoring settings
------------------------------------------------------------------------------
s = m:section(NamedSection, "PLCLink", "PLCLink", translate("PLC Link Monitoring"))
s.anonymous = true

vl = s:option(Value, "PLCBackhaulEvalTime", translate("Eval time for bring back up forcibly down PLC backhaul.its used till power cycle."))
vl.datatype = "integer"

------------------------------------------------------------------------------
--Backhaul Manager settings
------------------------------------------------------------------------------
s = m:section(NamedSection, "BackhaulMgr", "BackhaulMgr", translate("Backhaul Manager Monitoring"))
s.anonymous = true

e = s:option(Flag, "SelectOneBackHaulInterfaceInDaisy", translate("Enables or Disables the feature to select only one Backhaul Interface when Device is in Daisy Chain"))
e.rmempty = false

vl = s:option(Value, "BackHaulMgrRateNumMeasurements", translate("Number of Rate measurements to consider before selecting the best backhaul interface in Daisy Chain"))
vl.datatype = "uinteger"

vl = s:option(Value, "PLCLinkThresholdto2G", translate("In Daisy Chain when 5G link rate is zero (could mean 2G is connected), then select PLC interface if it's link rate is greater than Threshold Value"))
vl.datatype = "uinteger"

vl = s:option(Value, "SwitchInterfaceAfterCAPPingTimeouts", translate("Number of Ping Timeouts to CAP to switch from PLC to WLAN"))
------------------------------------------------------------------------------
--Fronthaul Manager settings
------------------------------------------------------------------------------
s = m:section(NamedSection, "FrontHaulMgr", "FrontHaulMgr", translate("FrontHaulMgr Manager Monitoring"))
s.anonymous = true

e = s:option(Flag, "ManageFrontAndBackHaulsIndependently", translate("Enables or Disables the feature to manage Fronthaul VAPs independently. REs Fronthaul VAPs will be brought up when CAP/GW is reachable."))
e.rmempty = false

vl = s:option(Value, "FrontHaulMgrTimeout", translate("REs Fronthaul VAPs will bringdown after timeout when CAP/GW is not reachable."))
vl.datatype = "uinteger"
