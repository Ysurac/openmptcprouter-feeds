--[[
LuCI - Lua Configuration Interface

Copyright (c) 2013 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

local m, s = ...
s = m:section(TypedSection, "wsplcd", translate("Advanced Settings - IEEE1905.1 Security"))
s.anonymous = true

li = s:option(ListValue, "WPSMethod", translate("WPS Method"))
li:value("WPS_M2", translate("WPS_M2"))
li:value("WPS_M8", translate("WPS_M8"))
li.default = "WPS_M2"

li = s:option(ListValue, "TXMode", translate("TX Mode of M2"))
li:value("WPS_TX_ENCRYPTED", translate("Encrypted"))
li:value("WPS_TX_NONE", translate("Non-encrypted"))
li.default = "WPS_TX_ENCRYPTED"

li = s:option(ListValue, "RXMode", translate("RX Mode of M2"))
li:value("WPS_RX_ENCRYPTED", translate("Encrypted"))
li:value("WPS_RX_EITHER", translate("Encrypted or Non-encrypted"))
li.default = "WPS_RX_ENCRYPTED"

li = s:option(ListValue, "ConfigSta", translate("Configure Station"))
li:value("1", translate("Yes"))
li:value("0", translate("No"))
li.default = "1"

vl = s:option(Value, "SearchTimeout", translate("Search Interval"))
vl.datatype = "uinteger"

v = s:option(Value, "WPSSessionTimeout", translate("WPS Session Timeout"))
v.datatype = "uinteger"

v = s:option(Value, "WPSRetransmitTimeout", translate("WPS Retransmission Timeout"))
v.datatype = "uinteger"

v = s:option(Value, "WPSPerMessageTimeout", translate("WPS Per-Message Timeout"))
v.datatype = "uinteger"

v = s:option(Value, "PushButtonTimeout", translate("Push Button Timeout"))
v.datatype = "uinteger"

v = s:option(Value, "PBSearchTimeout", translate("PB Search Interval"))
v.datatype = "uinteger"

v = s:option(Value, "SSIDSuffix", translate("SSID Suffix (demo mode)"))
v.datatype = "string"

l = s:option(ListValue, "DebugLevel", translate("Debug Level"))
l:value("ERROR", translate("ERROR"))
l:value("INFO", translate("INFO"))
l:value("DEBUG", translate("DEBUG"))
l:value("DUMP", translate("DUMP"))
l.default = "INFO"

l = s:option(ListValue, "BandSel", translate("DB Band Adaptation"))
l:value("1", translate("Enable"))
l:value("0", translate("Disable"))
l.default = "1"

l = s:option(ListValue, "BandChoice", translate("DB Preferred Band"))
l:value("5G", translate("5G"))
l:value("2G", translate("2G"))
l.default = "5G"

v = s:option(Value, "RMCollectTimeout", translate("DB Mode Time Window"))
v.datatype = "uinteger"

l = s:option(ListValue, "DeepClone", translate("Deep Cloning"))
l:value("1", translate("Enable"))
l:value("0", translate("Disable"))
l.default = "1"

l = s:option(ListValue, "DeepCloneNoBSSID", translate("Deep Cloning Without BSSID"))
l:value("1", translate("Enable"))
l:value("0", translate("Disable"))
l.default = "0"

l = s:option(ListValue, "ManageVAPInd", translate("Manage VAP Independent Mode"))
l:value("1", translate("Enable"))
l:value("0", translate("Disable"))
l.default = "1"

l = s:option(ListValue, "WPAPassphraseType", translate("UCPK-Generated WLAN Passphrase Length"))
l:value("LONG", translate("Long"))
l:value("SHORT", translate("Short"))
l.default = "LONG"

v = s:option(Value, "WaitAllBandsSecs", translate("Maximum number of seconds to wait until APAC completes on all bands"))
v.datatype = "uinteger"

s = m:section(TypedSection, "wsplcd", translate("Advanced Settings - HYFI 1.0"))
s.anonymous = true

l = s:option(ListValue, "APCloning", translate("HYFI 1.0 AP Cloning"))
l:value("1", translate("Enable"))
l:value("0", translate("Disable"))
l.default = "0"

v = s:option(Value, "CloneTimeout", translate("AP Cloning Timeout"))
v.datatype = "uinteger"

v = s:option(Value, "RepeatTimeout", translate("Repeat Timeout"))
v.datatype = "uinteger"

v = s:option(Value, "InternalTimeout", translate("Internal Timeout"))
v.datatype = "uinteger"

