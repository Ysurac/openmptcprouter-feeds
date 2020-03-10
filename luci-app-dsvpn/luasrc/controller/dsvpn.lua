module("luci.controller.dsvpn", package.seeall)

function index()
	--entry({"admin", "openmptcprouter", "mlvpn"}, cbi("mlvpn"), _("DSVPN"))
	--entry({"admin", "services", "dsvpn"}, cbi("dsvpn"), _("DSVPN"))
	entry({"admin", "vpn", "dsvpn"}, cbi("dsvpn"), _("DSVPN"))
end
