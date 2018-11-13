local uci = luci.model.uci.cursor()
local ut = require "luci.util"

module("luci.controller.iperf", package.seeall)

function index()
	--entry({"admin", "openmptcprouter", "iperf"}, cbi("iperf"), _("iperf"))
	entry({"admin", "services", "iperf"}, alias("admin", "services", "iperf", "test"), _("iPerf"),8)
	entry({"admin", "services", "iperf", "test"}, template("iperf/test"), nil,1)
	entry({"admin", "services", "iperf", "run_test"}, post("run_test")).leaf = true
end

function run_test(server,proto,mode,updown,omit,parallel,transmit,bitrate)
	luci.http.prepare_content("text/plain")
	local iperf
	local addr = uci:get("iperf",server,"host")
	local ports = uci:get("iperf",server,"ports")
	local ipv = "4"
	if proto == "ipv6" then
		local ipv = "6"
	end
	
	local t={}
	for pt in ports:gmatch("([^,%s]+)") do
		table.insert(t,pt)
	end
	local port = t[ math.random( #t ) ]
	if mode == "tcp" then
		if updown == "upload" then
			iperf = io.popen("iperf3 -c %s -P %s -%s -p %s -O %s -t %s -J" % {ut.shellquote(addr),parallel,ipv,port,omit,transmit})
		else
			iperf = io.popen("iperf3 -c %s -P %s -%s -p %s -O %s -R -t %s -J" % {ut.shellquote(addr),parallel,ipv,port,omit,transmit})
		end
	else
		if updown == "upload" then
			iperf = io.popen("iperf3 -c %s -P %s -%s -p %s -O %s -t %s -u -b %sm -J" % {ut.shellquote(addr),parallel,ipv,port,omit,transmit,bitrate})
		else
			iperf = io.popen("iperf3 -c %s -P %s -%s -p %s -O %s -R -t %s -u -b %sm -J" % {ut.shellquote(addr),parallel,ipv,port,omit,transmit,bitrate})
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