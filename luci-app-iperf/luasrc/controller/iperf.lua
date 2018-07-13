local uci = luci.model.uci.cursor()
local ut = require "luci.util"

module("luci.controller.iperf", package.seeall)

function index()
	--entry({"admin", "openmptcprouter", "iperf"}, cbi("iperf"), _("iperf"))
	entry({"admin", "services", "iperf"}, alias("admin", "services", "iperf", "test"), _("iperf"),1)
	entry({"admin", "services", "iperf", "test"}, template("iperf/test"), nil,1)
	entry({"admin", "services", "iperf", "run_test"}, post("run_test")).leaf = true
end

function run_test(server,proto,mode)
	luci.http.prepare_content("text/plain")
	local iperf
	local addr = uci:get("iperf",server,"host")
	local ports = uci:get("iperf",server,"ports")
	local t={}
	for pt in ports:gmatch("([^,%s]+)") do
		table.insert(t,pt)
	end
	local port = t[ math.random( #t ) ]
	if proto == "ipv4" then
		iperf = io.popen("iperf3 -c %s -P 10 -4 -p %s -J" % {ut.shellquote(addr),port})
		--iperf = io.popen("iperf3 -c bouygues.iperf.fr -P 10 -4 -J")
	else
		iperf = io.popen("iperf3 -c %s -P 10 -6 -p %s -J" % {ut.shellquote(addr),port})
	end
	if iperf then
		while true do
			local ln = iperf:read("*l")
			if not ln then break end
			luci.http.write(ln)
			luci.http.write("\n")
		end
	end
	return
end