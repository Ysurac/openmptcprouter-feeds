#!/bin/sh

# Secrets (passwords, keys, tokens, VLESS/VMess ids, PINs) lose their whole
# value: masking their last 6 characters left most of a key in what users
# paste in public bug reports. Addresses keep their first part, for debugging:
# the network of an IPv4 address, the first two hextets of an IPv6 one.
# The VPS addresses can be lists (several IPs of a server, the openvpn remote
# of each server): every element is masked, not only the last one.
# The awk stage does so for the VPS addresses (any .ip, the shadowsocks
# servers, the extra public IPs of the GRE tunnels, the endpoints of the
# per-WAN WireGuard and OpenVPN tunnels of every instance, omr_bonding_*
# included) and the static addresses of the interfaces: these were left in
# clear, or all of an IPv6 address but its last characters. An OpenVPN
# remote can carry a port and a protocol: only its host is masked. Private,
# link-local and ULA addresses say nothing about the user and a lot about
# LAN/WAN overlaps: they stay readable, as does a /prefix.
uci show | \
    sed -e "/^[^=]*\.[^.=]*\(password\|key\|secret\|psk\|pincode\|token\|user_id\|passphrase\)[^.=]*=/s/=.*/='xxxxxx'/" \
	-e "/detected_public_ipv4=/s/......$/xxxxxx'/" \
	-e "/detected_ss_ipv4=/s/......$/xxxxxx'/" \
	-e "/detected_public_ipv6=/s/......$/xxxxxx'/" \
	-e "/detected_ss_ipv6=/s/......$/xxxxxx'/" \
	-e "/publicip=/s/......$/xxxxxx'/" \
	-e "/publicip6=/s/......$/xxxxxx'/" \
	-e "/\.host=/s/......$/xxxxxx'/" \
	-e "/\.ipv6='[0-9a-fA-F]*:/s/'\([0-9a-fA-F]*:[0-9a-fA-F]*\)[^']*'/'\1:xxxxxx'/g" \
	-e "/external_ip=/s/......$/xxxxxx'/" \
	-e "/obfs_host=/s/..........$/xxxxxx'/" \
	-e "/vmess_address=/s/......$/xxxxxx'/" \
	-e "/vless_address=/s/......$/xxxxxx'/" \
	-e "/trojan_address=/s/......$/xxxxxx'/" \
	-e "/socks_address=/s/......$/xxxxxx'/" \
	-e "/vless_reality_address=/s/......$/xxxxxx'/" \
	-e "/ula_prefix=2/s/=.........../='xxxxxxxxxxx/" | \
    awk '
	function readable(a) {
		return a ~ /^(10|127)\./ || a ~ /^192\.168\./ ||
			a ~ /^172\.(1[6-9]|2[0-9]|3[01])\./ ||
			a ~ /^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\./ ||
			a ~ /^169\.254\./ || a == "0.0.0.0" || a == "::" || a == "::1" ||
			a ~ /^[fF][cCdD][0-9a-fA-F]*:/ || a ~ /^[fF][eE][89aAbB][0-9a-fA-F]*:/
	}
	function mask(a,   p, h) {
		p = ""
		if (match(a, /\/[0-9]+$/)) {
			p = substr(a, RSTART)
			a = substr(a, 1, RSTART - 1)
		}
		if (a == "" || readable(a))
			return a p
		if (a ~ /^[0-9a-fA-F]*:[0-9a-fA-F]*:/) {
			split(a, h, ":")
			return h[1] ":" h[2] ":xxxxxx" p
		}
		if (a ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
			split(a, h, ".")
			return h[1] "." h[2] ".xxxxxx" p
		}
		# a host name
		return (length(a) > 5 ? substr(a, 1, length(a) - 5) : "") "xxxxxx" p
	}
	{
		eq = index($0, "=")
		split(substr($0, 1, eq - 1), k, ".")
		v = substr($0, eq + 1)
		addr = k[3] == "ip" ||
			(k[1] == "network" && k[3] ~ /^(ipaddr|gateway|ip6addr|ip6gw|ip6prefix|peeraddr|endpoint_host)$/) ||
			(k[1] == "openvpn" && k[3] ~ /^(remote|local)$/) ||
			(k[1] ~ /^shadowsocks-(libev|rust)$/ && k[3] == "server" && k[2] ~ /^(sss|oip[0-9]+server$)/)
		label = k[1] ~ /^shadowsocks-(libev|rust)$/ && k[2] ~ /^oip[0-9]+server$/ && k[3] == "label"
		if (k[3] == "" || (!addr && !label) || v !~ /^'\''.*'\''$/) {
			print
			next
		}
		n = split(substr(v, 2, length(v) - 2), e, "'\'' '\''")
		out = ""
		for (i = 1; i <= n; i++) {
			# mask() calls match(): keep the split point out of RSTART
			if (addr && (sp = index(e[i], " ")))
				e[i] = mask(substr(e[i], 1, sp - 1)) substr(e[i], sp)
			else if (addr)
				e[i] = mask(e[i])
			else if (match(e[i], / [^ ]+$/))
				e[i] = substr(e[i], 1, RSTART) mask(substr(e[i], RSTART + 1))
			out = out (i > 1 ? "'\'' '\''" : "") e[i]
		}
		print substr($0, 1, eq) "'\''" out "'\''"
	}'
