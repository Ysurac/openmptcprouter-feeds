module("luci.controller.mlvpn", package.seeall)

function index()
	--entry({"admin", "openmptcprouter", "mlvpn"}, cbi("mlvpn"), _("MLVPN"))
	entry({"admin", "services", "mlvpn"}, cbi("mlvpn"), _("MLVPN"))
end
