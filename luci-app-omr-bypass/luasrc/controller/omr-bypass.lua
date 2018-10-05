local ucic = luci.model.uci.cursor()
local dt = require "luci.cbi.datatypes"
module("luci.controller.omr-bypass", package.seeall)

function index()
	entry({"admin", "services", "omr-bypass"}, alias("admin", "services", "omr-bypass", "index"), _("OMR-Bypass"))
	--entry({"admin", "services", "omr-bypass", "index"}, template("omr-bypass/bypass"))
	entry({"admin", "services", "omr-bypass", "index"}, cbi("omr-bypass"))
end
