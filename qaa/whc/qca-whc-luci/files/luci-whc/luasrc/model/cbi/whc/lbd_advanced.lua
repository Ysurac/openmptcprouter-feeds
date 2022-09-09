--[[
LuCI - Lua Configuration Interface

Copyright (c) 2014-2019 Qualcomm Technologies, Inc.

All Rights Reserved.
Confidential and Proprietary - Qualcomm Technologies, Inc.

2014-2016 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

local m, s = ...
------------------------------------------------------------------------------------------------
--Basic Settings - Advanced
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "config_Adv", "config_Adv", translate("Basic Advanced"))
s.anonymous = true

vl = s:option(Value, "AgeLimit", translate("Maximum number of seconds elapsed allowed for a 'recent' measurement"))
vl.datatype = "and(uinteger, range(0, 255))"

vl = s:option(Value, "BackhaulAgeLimit", translate("Maximum number of seconds elapsed allowed for a 'recent' backhaul capacity measurement"))
vl.datatype = "and(uinteger, range(0, 255))"

vl = s:option(Value, "LegacyClientAgeLimit", translate("Maximum number of seconds elapsed allowed for a 'recent' measurement for a legacy Client"))
vl.datatype = "and(uinteger, range(0, 255))"

vl = s:option(Flag, "AllowZeroAPInterfaces", translate("Whether running with 0 AP interfaces is permitted"))
vl.rmempty = false

------------------------------------------------------------------------------------------------
--Station database - Advanced
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "StaDB_Adv", "StaDB_Adv", translate("Station Database Advanced"))
s.anonymous = true

vl = s:option(Value, "AgingSizeThreshold", translate("Size Threshold For Aging Timer"))
vl.datatype = "uinteger"
vl = s:option(Value, "AgingFrequency", translate("Aging Timer Frequency (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "OutOfNetworkMaxAge", translate("Max Age for Out-of-Network Client (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "InNetworkMaxAge", translate("Max Age for In-Network Client (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "NumNonServingBSSes", translate("Maximum number of non-serving BSSes can be stored when operating in MBSA mode"))
vl.datatype = "uinteger"
e = s:option(Flag, "PopulateNonServingPHYInfo", translate("Populate PHY capabilities on non-serving band"))
e.rmempty = false
vl = s:option(Value, "MinAssocAgeForStatsAssocUpdate", translate("Minimum association age for which to allow association update based on link stats (s)"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Station Monitor Setting - Advanced
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "StaMonitor_Adv", "StaMonitor_Adv", translate("Post-association steering decision maker"))
s.anonymous = true
vl = s:option(Value, "RSSIMeasureSamples_W2", translate("Number of RSSI measurements on 2.4 GHz band"))
vl.datatype = "uinteger"
vl = s:option(Value, "RSSIMeasureSamples_W5", translate("Number of RSSI measurements on 5 GHz band"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Band Monitor Settings - Advanced
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "BandMonitor_Adv", "BandMonitor_Adv", translate("Utilization Monitor Advanced Settings"))
s.anonymous = true

vl = s:option(Value, "ProbeCountThreshold", translate("Number of probe requests required for the RSSI averaging"))
vl.datatype = "uinteger"

vl_mu_interval_w2 = s:option(Value, "MUCheckInterval_W2", translate("The frequency to check medium utilization on 2.4 GHz (s)"))
vl_mu_interval_w2.datatype = "uinteger"
vl_mu_interval_w5 = s:option(Value, "MUCheckInterval_W5", translate("The frequency to check medium utilization on 5 GHz (s)"))
vl_mu_interval_w5.datatype = "uinteger"
vl = s:option(Value, "MUReportPeriod", translate("The frequency for CAP to query average utilization from RE"))
vl.datatype = "uinteger"
vl = s:option(Value, "LoadBalancingAllowedMaxPeriod", translate("The maximum time a node is allowed to perform active upgrade every time it is assigned"))
vl.datatype = "uinteger"
vl = s:option(Value, "NumRemoteChannels", translate("Maximum number of remote channels can be recorded when operating in MBSA mode"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Estimator Settings - Advanced
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "Estimator_Adv", "Estimator_Adv", translate("Rate estimation"))
s.anonymous = true
vl = s:option(Value, "RSSIDiff_EstW5FromW2", translate("Difference when estimating 5 GHz RSSI value from the one measured on 2.4 GHz"))
vl.datatype = "integer"
vl = s:option(Value, "RSSIDiff_EstW2FromW5", translate("Difference when estimating 2.4 GHz RSSI value from the one measured on 5 GHz"))
vl.datatype = "integer"
vl = s:option(Value, "ProbeCountThreshold", translate("Number of probe requests required for the RSSI averaging"))
vl.datatype = "uinteger"
vl = s:option(Value, "StatsSampleInterval", translate("Seconds between successive stats samples for estimating data rate"))
vl.datatype = "uinteger"
vl = s:option(Value, "BackhaulStationStatsSampleInterval", translate("Seconds between successive stats samples for estimating bSTA activity"))
vl.datatype = "uinteger"
vl = s:option(Value, "Max11kUnfriendly", translate("Maximum consecutive 11k failures used for backoff to Legacy Steering"))
vl.datatype = "uinteger"
vl = s:option(Value, "11kProhibitTimeShort", translate("Time to wait before sending a 802.11k beacon report request after last failed one (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "11kProhibitTimeLong", translate("Time to wait before sending a 802.11k beacon report request after last successful one (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "PhyRateScalingForAirtime", translate("Scaling factor (as percentage) for converting PHY rate to upper layer rate for airtime computations"))
vl.datatype = "uinteger"
vl = s:option(Flag, "EnableContinuousThroughput", translate("Continously measure throughput (for demo purposes only)"))
vl.rmempty = false
vl_bcnrpt_active_duration = s:option(Value, "BcnrptActiveDuration", translate("Active scan duration used in 802.11k Beacon Report (s)"))
vl_bcnrpt_active_duration.datatype = "uinteger"
vl_bcnrpt_passive_duration = s:option(Value, "BcnrptPassiveDuration", translate("Passive scan duration used in 802.11k Beacon Report request (s)"))
vl_bcnrpt_passive_duration.datatype = "uinteger"

vl_fast_bufsize = s:option(Value, "FastPollutionDetectBufSize", translate("Number of interference samples required to detect pollution"))
vl_fast_bufsize.datatype = "uinteger"
vl_normal_bufsize = s:option(Value, "NormalPollutionDetectBufSize", translate("Number of interference samples required to clear pollution or extend pollution"))
vl_normal_bufsize.datatype = "uinteger"
function vl_normal_bufsize.validate(self, value, section)
	local fast_bufsize = vl_fast_bufsize:formvalue(section)
	if (tonumber(value) >= tonumber(fast_bufsize)) then
		return value
	else
		return nil, "Fast pollution detect buffer size cannot be greater than the normal buffer size"
	end
end

vl_detect_threshold = s:option(Value, "PollutionDetectThreshold", translate("Minimum percentage of detected samples required to declare pollution"))
vl_detect_threshold.datatype = "and(uinteger, range(0, 100))"
vl_clear_threshold = s:option(Value, "PollutionClearThreshold", translate("Maximum percentage of detected samples allowed to clear pollution"))
vl_clear_threshold.datatype = "and(uinteger, range(0, 100))"
function vl_clear_threshold.validate(self, value, section)
	local detect_threshold = vl_detect_threshold:formvalue(section)
	if (tonumber(value) >= tonumber(detect_threshold)) then
		return nil, "Pollution clear threshold must be smaller than the detect threshold"
	else
		return value
	end
end

vl = s:option(Value, "InterferenceAgeLimit", translate("Maximum number of seconds elapsed allowed between two valid interference samples"))
vl.datatype = "uinteger"
vl = s:option(Value, "IASLowRSSIThreshold", translate("Minimum RSSI required for a data sample to be used to evaluate interference"))
vl.datatype = "uinteger"
vl = s:option(Value, "IASMaxRateFactor", translate("Scaling factor (as percentage) for maximum rate beyond which interference should never be detected"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "IASMinDeltaBytes", translate("Minimum increase in downlink byte count since last sample for the stats to qualify for detector logic"))
vl.datatype = "uinteger"
vl = s:option(Value, "IASMinDeltaPackets", translate("Minimum increase in downlink packet count since last sample for the stats to qualify for detector logic"))
vl.datatype = "uinteger"
vl = s:option(Value, "ActDetectMinInterval", translate("Minimum number of secs before making a client activity detection"))
vl.datatype = "uinteger"
vl = s:option(Value, "ActDetectMinPktPerSec", translate("Minimum number of packet per second to declare a client to be active"))
vl.datatype = "uinteger"
vl = s:option(Value, "BackhaulActDetectMinPktPerSec", translate("Minimum number of packet per second to declare a backhaul STA to be active"))
vl.datatype = "uinteger"

vl = s:option(Value, "LowPhyRateThreshold", translate("Threshold (in Mbps) below which to apply the low PHY rate scaling factor"))
vl.datatype = "uinteger"
vl = s:option(Value, "HighPhyRateThreshold_W2", translate("Threshold (in Mbps) on 2.4 GHz above which to apply the high PHY rate scaling factor"))
vl.datatype = "uinteger"
vl = s:option(Value, "HighPhyRateThreshold_W5", translate("Threshold (in Mbps) on 5 GHz above which to apply the high PHY rate scaling factor"))
vl.datatype = "uinteger"

vl = s:option(Value, "PhyRateScalingFactorLow", translate("Percentage by which to scale the PHY rate when operating in the low region"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "PhyRateScalingFactorMedium", translate("Percentage by which to scale the PHY rate when operating in the medium region"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "PhyRateScalingFactorHigh", translate("Percentage by which to scale the PHY rate when operating in the high region"))
vl.datatype = "and(uinteger, range(0, 100))"
vl = s:option(Value, "PhyRateScalingFactorTCP", translate("Percentage by which to scale the PHY rate when computing TCP capacity (in addition to region scaling)"))
vl.datatype = "and(uinteger, range(0, 100))"

------------------------------------------------------------------------------------------------
--Steer Executor Settings - Advanced
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "SteerExec_Adv", "SteerExec_Adv", translate("Steering Executor Advanced Settings"))
s.anonymous = true
vl = s:option(Value, "TSteering", translate("Maximum time for client to associate on target band before AP aborts steering (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "InitialAuthRejCoalesceTime", translate("Time to coalesce multiple authentication rejects down to a single one (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "AuthRejMax", translate("Max consecutive authentication rejects after which the device is marked as steering unfriendly"))
vl.datatype = "uinteger"
vl = s:option(Value, "SteeringUnfriendlyTime", translate("The base amount of time a device is considered steering unfriendly before another attempt (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxSteeringUnfriendly", translate("The maximum time used for backoff for steering unfriendly STAs.  Total amount of backoff is calculated as min(MaxSteeringUnfriendly, SteeringUnfriendlyTime * 2 ^ CountConsecutiveFailures) (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "TargetLowRSSIThreshold_W2", translate("RSSI threshold indicating 2.4 GHz band is not strong enough for association (dB)"))
vl.datatype = "uinteger"
vl = s:option(Value, "TargetLowRSSIThreshold_W5", translate("RSSI threshold indicating 5 GHz band is not strong enough for association (dB)"))
vl.datatype = "uinteger"
vl = s:option(Value, "BlacklistTime", translate("The amount of time (in seconds) before automatically removing the blacklist (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "BTMResponseTime", translate("The amount of time to wait for a BTM response (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "BTMAssociationTime", translate("The amount of time to wait for an association on the correct band after receiving a BTM response (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "BTMAlsoBlacklist", translate("If set to 1, will also setup blacklists when attempting to steer a client via BSS Transition Management"))
vl.datatype = "uinteger"
vl = s:option(Value, "BTMUnfriendlyTime", translate("The base amount of time a device is considered BTM-steering unfriendly before another attempt to steer via BTM (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxBTMUnfriendly", translate("The maximum time used for backoff for BTM unfriendly STAs.  Total amount of backoff is calculated as min(MaxBTMUnfriendly, BTMUnfriendlyTime * 2 ^ CountConsecutiveFailures) (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxBTMActiveUnfriendly", translate("The maximum time used for backoff for BTM STAs that fail active steering.  Total amount of backoff is calculated as min(MaxBTMActiveUnfriendly, BTMUnfriendlyTime * 2 ^ CountConsecutiveFailures) (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "MinRSSIBestEffort", translate("The minimum RSSI, below which lbd will only steer clients via best effort (no blacklists, failures do not mark as unfriendly) (dB)"))
vl.datatype = "uinteger"
vl = s:option(Value, "LowRSSIXingThreshold", translate("RSSI threshold to generate an indication when a client crosses it (dB)"))
vl.datatype = "uinteger"
vl = s:option(Flag, "StartInBTMActiveState", translate("If true, BTM capable clients start in the Active Steering friendly state (if false, they start in the Idle Steering state)"))
vl.rmempty = false
vl = s:option(Value, "Delay24GProbeRSSIThreshold", translate("The minimum RSSI threshold to delay probe responses in 2.4G band (dB)"))
vl.datatype = "uinteger"
vl = s:option(Value, "Delay24GProbeTimeWindow", translate("The time window within which probe responses will not be sent for configured count (s)"))
vl.datatype = "uinteger"
vl = s:option(Value, "Delay24GProbeMinReqCount", translate("The probe request count above which probe responses will be sent and all received within time window"))
vl.datatype = "uinteger"

------------------------------------------------------------------------------------------------
--Steer Algorithm Settings - Advanced
------------------------------------------------------------------------------------------------
s = m:section(NamedSection, "SteerAlg_Adv", "SteerAlg_Adv", translate("Steering Algorithm Advanced Settings"))
s.anonymous = true
vl = s:option(Value, "MinTxRateIncreaseThreshold", translate("Downlink rate (in Mbps) should exceed at least LowTxRateXingThreshold + this value when steering from 2.4GHz to 5GHz due to overload"))
vl.datatype = "uinteger"
vl = s:option(Value, "MaxSteeringTargetCount", translate("Maximum number of BSS candidates can be selected when steering a client"))
vl.datatype = "and(uinteger, range(1, 2))"
vl = s:option(Value, "APSteerMaxRetryCount", translate("Maximum number of extra steering attempts. Reset on association update."))
vl.datatype = "uinteger"
vl = s:option(Flag, "ApplyEstimatedAirTimeOnSteering", translate("Apply client's estimated air time when making steering decision"))
vl.rmempty = true
vl = s:option(Flag, "UsePathCapacityToSelectBSS", translate("Use end-to-end path capacity when selecting target BSS"))
vl.rmempty = true
