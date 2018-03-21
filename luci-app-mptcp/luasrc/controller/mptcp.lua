module("luci.controller.mptcp", package.seeall)

function index()
  entry(
    {"admin", "network", "mptcp"},
    cbi("mptcp"), _("MPTCP"), 55)
end
