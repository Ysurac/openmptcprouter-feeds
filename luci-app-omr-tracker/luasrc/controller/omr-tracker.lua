module("luci.controller.omr-tracker", package.seeall)

function index()
  entry(
    {"admin", "services", "omr-tracker"},
    cbi("omr-tracker"), _("OMR-Tracker"), 55)
end
