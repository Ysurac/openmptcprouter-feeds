-- Copyright 2018 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local fs  = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local testfullps = luci.sys.exec("ps --help 2>&1 | grep BusyBox") --check which ps do we have
local psstring = (string.len(testfullps)>0) and  "ps w" or  "ps axfw" --set command we use to get pid

local m = Map("glorytun", translate("Glorytun"))
local s = m:section( TypedSection, "glorytun", translate("Glorytun instances"), translate("Below is a list of configured Glorytun instances and their current state") )
s.template = "cbi/tblsection"
s.template_addremove = "glorytun/cbi-select-input-add"
s.addremove = true
s.add_select_options = { }
s.add_select_options[''] = ''
s.extedit = luci.dispatcher.build_url(
	"admin", "vpn", "glorytun", "settings", "%s"
)

uci:load("glorytun_recipes")
uci:foreach( "glorytun_recipes", "glorytun_recipe",
	function(section)
		s.add_select_options[section['.name']] =
			section['_description'] or section['.name']
	end
)

function s.getPID(section) -- Universal function which returns valid pid # or nil
	local pid = sys.exec("%s | grep -w %s | grep glorytun | grep -v grep | awk '{print $1}'" % { psstring,section} )
	if pid and #pid > 0 and tonumber(pid) ~= nil then
		return tonumber(pid)
	else
		return nil
	end
end

function s.parse(self, section)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)

	if recipe and not s.add_select_options[recipe] then
		self.invalid_cts = true
	else
		TypedSection.parse( self, section )
	end
end

function s.create(self, name)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)
	name = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".text"
	)
	if #name > 3 and not name:match("[^a-zA-Z0-9_]") then
		--uci:section(
		--	"glorytun", "glorytun", name,
		--	uci:get_all( "glorytun_recipes", recipe )
		--)
		local recipe_data = uci:get_all( "glorytun_recipes", recipe )
		uci:set("glorytun", name,"glorytun")
		local k, v
		for k, v in pairs(recipe_data) do
			uci:set("glorytun", name, k,v)
		end

		uci:delete("glorytun", name, "_role")
		uci:delete("glorytun", name, "_description")
		uci:commit("glorytun")
		uci:save("glorytun")

		luci.http.redirect( self.extedit:format(name) )
	elseif #name > 0 then
		self.invalid_cts = true
	end

	return 0
end


s:option( Flag, "enable", translate("Enabled") )

local active = s:option( DummyValue, "_active", translate("Started") )
function active.cfgvalue(self, section)
	local pid = s.getPID(section)
	if pid ~= nil then
		return (sys.process.signal(pid, 0))
			and translatef("yes (%i)", pid)
			or  translate("no")
	end
	return translate("no")
end

local updown = s:option( Button, "_updown", translate("Start/Stop") )
updown._state = false
updown.redirect = luci.dispatcher.build_url(
	"admin", "services", "glorytun"
)
function updown.cbid(self, section)
	local pid = s.getPID(section)
	self._state = pid ~= nil and sys.process.signal(pid, 0)
	self.option = self._state and "stop" or "start"
	return AbstractValue.cbid(self, section)
end
function updown.cfgvalue(self, section)
	self.title = self._state and "stop" or "start"
	self.inputstyle = self._state and "reset" or "reload"
end

local port = s:option( DummyValue, "port", translate("Port") )
function port.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val or "65001"
end
local dev = s:option( DummyValue, "dev", translate("Interface") )
function dev.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val or "tun"
end
local proto = s:option( DummyValue, "proto", translate("Protocol") )
function proto.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val or "tcp"
end

function updown.write(self, section, value)
	if self.option == "stop" then
		local pid = s.getPID(section)
		if pid ~= nil then
			sys.process.signal(pid,15)
		end
	else
		local type = proto.cfgvalue(self,section)
		luci.sys.call("/etc/init.d/glorytun-udp start %s" % section)
		luci.sys.call("/etc/init.d/glorytun start %s" % section)
	end
	luci.http.redirect( self.redirect )
end


return m
