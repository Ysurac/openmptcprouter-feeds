local uci = luci.model.uci.cursor()
local ut = require "luci.util"

module("luci.controller.iperf", package.seeall)

function index()
	--entry({"admin", "openmptcprouter", "iperf"}, cbi("iperf"), _("iperf"))
	entry({"admin", "services", "iperf"}, alias("admin", "services", "iperf", "test"), _("iperf"),1)
	entry({"admin", "services", "iperf", "test"}, template("iperf/test"), nil,1)
	entry({"admin", "services", "iperf", "run_test"}, post("run_test")).leaf = true
end

function run_test(server,proto,mode,updown)
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
		if updown == "upload" then
			iperf = io.popen("iperf3 -c %s -P 10 -4 -p %s -O 3 -t 6 -J" % {ut.shellquote(addr),port})
		else
			iperf = io.popen("iperf3 -c %s -P 10 -4 -p %s -O 3 -R -t 6 -J" % {ut.shellquote(addr),port})
		end
	else
		if updown == "upload" then
			iperf = io.popen("iperf3 -c %s -P 10 -6 -p %s -O 3 -t 6 -J" % {ut.shellquote(addr),port})
		else
			iperf = io.popen("iperf3 -c %s -P 10 -6 -p %s -O 3 -R -t 6 -J" % {ut.shellquote(addr),port})
		end
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