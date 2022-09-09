--[[
LuCI - Lua Configuration Interface

Copyright (c) 2014 Qualcomm Atheros, Inc.

All Rights Reserved.
Qualcomm Atheros Confidential and Proprietary.

]]--

local m, s = ...
------------------------------------------------------------------------------------------------
--Diagnostic Logging
------------------------------------------------------------------------------------------------
s = m:section(TypedSection, "DiagLog", translate("Diagnostic Logging"))
s.anonymous = true

e = s:option(Flag, "EnableLog", translate("Enable Diagnostic Logging"))
e.rmempty = false

vl = s:option(Value, "LogServerIP", translate("Server IP address"))
vl.datatype = "ipaddr"

vl = s:option(Value, "LogServerPort", translate("Server IP port"))
vl.datatype = "port"

li = s:option(ListValue, "LogLevelWlanIF", translate("Log Level for Wlan Interface"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"

li = s:option(ListValue, "LogLevelBandMon", translate("Log Level for Band Monitor"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"

li = s:option(ListValue, "LogLevelStaDB", translate("Log Level for Station Database"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"

li = s:option(ListValue, "LogLevelSteerExec", translate("Log Level for Steering Executor"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"

li = s:option(ListValue, "LogLevelStaMon", translate("Log Level for Station Monitor"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"

li = s:option(ListValue, "LogLevelEstimator", translate("Log Level for Estimator"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"

li = s:option(ListValue, "LogLevelDiagLog", translate("Log Level for Diagnostic Logging"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"

li = s:option(ListValue, "LogLevelMultiAP", translate("Log Level for Multi-AP"))
li:value("0", translate("DEBUG"))
li:value("1", translate("INFO"))
li:value("2", translate("DEMO"))
li:value("3", translate("NONE"))
li.default = "2"
