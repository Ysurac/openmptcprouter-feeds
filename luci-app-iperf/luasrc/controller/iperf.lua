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
	server = tostring(server or "")
	if not server:match("^[%w_%-]+$") then
		luci.http.write_json({ error = "Invalid server" })
		return
	end
	local addr = uci:get("iperf",server,"host")
	local ports = uci:get("iperf",server,"ports")
	local user = uci:get("iperf",server,"user") or ""
	local password = uci:get("iperf",server,"password") or ""
	local key = uci:get("iperf",server,"key") or ""
	if not addr or not ports then
		luci.http.write_json({ error = "Invalid server" })
		return
	end
	parallel = tostring(parallel or "1"):match("^%d+$") or "1"
	omit = tostring(omit or "0"):match("^%d+$") or "0"
	transmit = tostring(transmit or "10"):match("^%d+$") or "10"
	bitrate = tostring(bitrate or "1M")
	if not bitrate:match("^[0-9]+[KMG]?$") then
		bitrate = "1M"
	end
	local options = {}
	if user ~= "" and password ~= "" and key ~= "" then
		luci.sys.call("printf %s " .. ut.shellquote(key) .. " | base64 -d > /tmp/iperf.pem")
		options[#options + 1] = "--username " .. ut.shellquote(user)
		options[#options + 1] = "--rsa-public-key-path /tmp/iperf.pem"
	end
	if mode == "udp" then
		options[#options + 1] = "-u -b " .. ut.shellquote(bitrate)
	end
	if updown == "download" or updown == "receive" then
		options[#options + 1] = "-R"
	end
	local ipv = "4"
	if proto == "ipv6" then
		ipv = "6"
	end
	
	local t={}
	for pt in ports:gmatch("([^,%s]+)") do
		if pt:match("^%d+$") then
			table.insert(t,pt)
		end
	end
	if #t == 0 then
		luci.http.write_json({ error = "Invalid server port" })
		return
	end
	local port = t[ math.random( #t ) ]
	options = table.concat(options, " ")
	if password ~= "" then
		iperf = io.popen("omr-iperf %s -P %s -%s -O %s -t %s -J -Z %s" % {ut.shellquote(server),parallel,ipv,omit,transmit,options})
	else
		iperf = io.popen("iperf3 -c %s -P %s -%s -p %s -O %s -t %s -J -Z %s" % {ut.shellquote(addr),parallel,ipv,port,omit,transmit,options})
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
