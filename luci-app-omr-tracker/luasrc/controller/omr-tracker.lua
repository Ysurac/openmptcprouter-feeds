module("luci.controller.omr-tracker", package.seeall)

function index()
	--entry({"admin", "openmptcprouter", "omr-tracker"}, cbi("omr-tracker"), _("OMR-Tracker"))
	entry({"admin", "services", "omr-tracker"}, cbi("omr-tracker"), _("OMR-Tracker"))
end
