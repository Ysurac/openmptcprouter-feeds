local function uci_get(key)
	local f = io.popen("uci -q get " .. key)
	local v = f and f:read("*l") or ""
	if f then f:close() end
	return v or ""
end

-- Probe the port of the proxy in use: 65101 is shadowsocks-libev's, a VPS
-- may not run it or the path may treat it differently than the real one.
local port
local proxy = uci_get("openmptcprouter.settings.proxy")
if proxy:match("^shadowsocks%-rust") then
	port = uci_get("shadowsocks-rust.sss0.server_port")
elseif proxy == "shadowsocks" then
	port = uci_get("shadowsocks-libev.sss0.server_port")
end
port = tonumber(port) or 65101

-- tracebox's MPCAPABLE is MPTCP v0 (out-of-tree kernel), which the upstream
-- (v1, RFC 8684) kernel on the VPS ignores: build the 4-byte v1 SYN option
-- by hand (subtype 0 / version 1, flags H = HMAC-SHA256).
MPCAPABLE_V1 = TCPOption.new{kind=30, length=4, data={0x01, 0x01}}
pkt = ip{dst=to} / tcp{dst=port} / MPCAPABLE_V1
function cb(ttl, r_ip, mod)
	if r_ip == nil then
		r_ip = "*"
	end
	mod = tostring(mod)
	-- Crafter can't parse a 4-byte MP_CAPABLE quoted back in ICMP and shows
	-- it as raw bytes: that's the option kept, not stripped. The server's
	-- 12-byte SYN/ACK option likewise shows as "-TCPOption +...Capable".
	if mod:find("+RawLayer", 1, true) or mod:find("+TCPOptionMPTCPCapable", 1, true) then
		mod = mod:gsub("%-TCPOption ", ""):gsub("%+RawLayer ", "")
	end
	print(ttl .. ": " .. tostring(r_ip) .. " " .. mod)
end
print("Port: " .. port)
result = tracebox(pkt, {callback="cb"})
print("\nResult:\n" .. tostring(result))
-- The page's help text and omr-tracebox-mptcp key on these option names.
if result == nil then
	print("No reply from the server")
elseif not tostring(result):find("TCPOptionMPTCPCapable", 1, true) then
	print("-TCPOptionMPTCPCapable: no MPTCP in the server reply")
end
