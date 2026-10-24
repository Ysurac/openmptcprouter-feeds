{%
// v2r_rules_local_out (hook output, the router's own connections) makes the
// checks of v2r_rules_dst inline and goes to v2r_rules_local_forward, the
// redirect without the jump to omr_proxy_fw_<proto>: that firewall check of
// the LAN clients matches "fib daddr . mark oifname", which the kernel
// refuses in a chain the output hook reaches, and the whole check failed to
// load.
function get_local_verdict() {
	let v = o_local_default;
	let fwd = "goto v2r_rules_local_forward_" + proto;
	if (v == "checkdst") {
		return [
			"ip daddr @v2r_rules_dst_forward " + fwd,
			"ip6 daddr @v2r_rules6_dst_forward " + fwd,
			(o_dst_default == "forward") ? fwd : "accept"
		];
	} else if (v == "forward") {
		return [ fwd ];
	} else {
		return null;
	}
}

function get_src_default_verdict() {
	let v = o_src_default;
	if (v == "checkdst") {
		return "goto v2r_rules_dst_" + proto;
	} else if (v == "forward") {
		return "goto v2r_rules_forward_" + proto;
	} else {
		return "accept";
	}
}

function get_dst_default_verdict() {
	let v = o_dst_default;
	if (v == "forward") {
		return "goto v2r_rules_forward_" + proto;
	} else {
		return "accept";
	}
}

function get_ifnames() {
	let res = [];
	for (let ifname in split(o_ifnames, /[ \t\n]/)) {
		ifname = trim(ifname);
		if (ifname) push(res, ifname);
	}
	return res;
}

// The transparent proxies other than main_transparent_proxy
// (o_extra_rules: the public IPs of the VPS, see openmptcprouter-vps
// _get_gre_tunnel) take the sources (an IPv4 set, ingress interfaces) of
// the shadowsocks rules of the same public IP to their own inbound, ahead
// of the catch-all.
function extra_rules() {
	let res = [];
	for (let r in o_extra_rules) {
		let port = (proto == "tcp") ? r.tcp : r.udp;
		if (!port)
			continue;
		if (r.src)
			push(res, { match: "ip saddr @v2r_rules_src_forward_oip_" + r.name, port: port });
		let ifnames = [];
		for (let n in split(r.ifnames || "", /[ \t\n]/)) {
			n = trim(n);
			if (n) push(ifnames, n);
		}
		// IPv4 only, as the GRE tunnels
		if (length(ifnames))
			push(res, { match: "meta nfproto ipv4 iifname { " + join(", ", ifnames) + " }", port: port });
	}
	return res;
}

// fwmark 1 -> table 100 delivers the tproxied packets locally: only set up
// with a redirect to render, the init script removes it with the rules
let type, hook, priority, redir_port;
if (o_tproxy == "1") {
	if (proto == "tcp") {
		redir_port = o_redir_tcp_port;
	} else if (proto == "udp") {
		redir_port = o_redir_udp_port;
	}
	type = "filter";
	hook = "prerouting";
	priority = "mangle";
	if (redir_port && system("
		set -o errexit
		iprr() {
			while ip $1 rule del fwmark 1 lookup 100 2>/dev/null; do true; done
			      ip $1 rule add fwmark 1 lookup 100
			ip $1 route flush table 100 2>/dev/null || true
			ip $1 route add local default dev lo table 100
		}
		iprr -4
		iprr -6
	") != 0) {
		return ;
	}
} else {
	if (proto == "tcp") {
		type = "nat";
		hook = "prerouting";
		priority = 1;
		redir_port = o_redir_tcp_port;
	} else if (proto == "udp") {
		type = "filter";
		hook = "prerouting";
		priority = "mangle";
		redir_port = o_redir_udp_port;
		if (redir_port && system("
			set -o errexit
			iprr() {
				while ip $1 rule del fwmark 1 lookup 100 2>/dev/null; do true; done
				      ip $1 rule add fwmark 1 lookup 100
				ip $1 route flush table 100 2>/dev/null || true
				ip $1 route add local default dev lo table 100
			}
			iprr -4
			iprr -6
		") != 0) {
			return ;
		}
	} else {
		return;
	}
}
%}
{% if (redir_port): %}

chain v2r_rules_pre_{{ proto }} {
	type {{ type }} hook {{ hook }} priority {{ priority }};
	ip daddr @v2r_rules_remote_servers accept;
	ip6 daddr @v2r_rules6_remote_servers accept;
	meta l4proto {{ proto }}{%- let ifnames=get_ifnames(); if (length(ifnames)): %} iifname { {{join(", ", ifnames)}} }{% endif %} goto v2r_rules_pre_src_{{ proto }};
}

chain v2r_rules_pre_src_{{ proto }} {
	ip daddr @v2r_rules_dst_bypass_ accept;
	ip6 daddr @v2r_rules6_dst_bypass_ accept;
	goto v2r_rules_src_{{ proto }};
}

chain v2r_rules_src_{{ proto }} {
	ip saddr @v2r_rules_src_bypass accept;
	ip saddr @v2r_rules_src_forward goto v2r_rules_forward_{{ proto }};
	ip saddr @v2r_rules_src_checkdst goto v2r_rules_dst_{{ proto }};
	ip6 saddr @v2r_rules6_src_bypass accept;
	ip6 saddr @v2r_rules6_src_forward goto v2r_rules_forward_{{ proto }};
	ip6 saddr @v2r_rules6_src_checkdst goto v2r_rules_dst_{{ proto }};
	{{ get_src_default_verdict() }};
}

chain v2r_rules_dst_{{ proto }} {
	ip daddr @v2r_rules_dst_bypass accept;
	ip daddr @v2r_rules_remote_servers accept;
	ip daddr @v2r_rules_dst_forward goto v2r_rules_forward_{{ proto }};
	ip6 daddr @v2r_rules6_dst_bypass accept;
	ip6 daddr @v2r_rules6_remote_servers accept;
	ip6 daddr @v2r_rules6_dst_forward goto v2r_rules_forward_{{ proto }};
	{{ get_dst_default_verdict() }};
}

{%   if (proto == "tcp"): %}
{# Filled by /bin/blocklanfw (/usr/share/omr/proxy-fw.uc) after each firewall
   load: the firewall's forward rules, which a redirected connection never
   meets. What they would refuse is not redirected. -#}
chain omr_proxy_fw_{{ proto }} {
}

{%   let local_verdict = get_local_verdict(); if (o_tproxy == "1") local_verdict = null; %}
{%   for (let c in (local_verdict ? [ "forward", "local_forward" ] : [ "forward" ])): %}
chain v2r_rules_{{ c }}_{{ proto }} {
{%	if (c == "forward"): %}
	jump omr_proxy_fw_{{ proto }};
{%	endif %}
{%	for (let r in extra_rules()): %}
{%		if (o_tproxy == "1"): %}
	meta l4proto tcp {{ o_nft_tcp_extra }} {{ r.match }} meta mark set 1 tproxy ip to :{{ r.port }} accept;
{%		else %}
	meta l4proto tcp {{ o_nft_tcp_extra }} {{ r.match }} redirect to :{{ r.port }};
{%		endif %}
{%	endfor %}
{%	if (o_tproxy == "1"): %}
	meta l4proto tcp {{ o_nft_tcp_extra }} meta mark set 1 tproxy to :{{ redir_port }};
{%	else %}
	meta l4proto tcp {{ o_nft_tcp_extra }} redirect to :{{ redir_port }};
{%	endif %}
}
{%   endfor %}
{%   if (get_local_verdict()): %}
chain v2r_rules_local_out {
	type {{ type }} hook output priority -1;
	meta l4proto != tcp accept;
	ip daddr @v2r_rules_remote_servers accept;
	ip daddr @v2r_rules_dst_bypass_ accept;
	ip daddr @v2r_rules_dst_bypass accept;
	ip6 daddr @v2r_rules6_remote_servers accept;
	ip6 daddr @v2r_rules6_dst_bypass_ accept;
	ip6 daddr @v2r_rules6_dst_bypass accept;
{%	for (let v in local_verdict): %}
	{{ v }};
{%	endfor %}
}
{%     endif %}
{%   elif (proto == "udp"): %}
{# Filled by /bin/blocklanfw (/usr/share/omr/proxy-fw.uc) after each firewall
   load: the firewall's forward rules, which a redirected connection never
   meets. What they would refuse is not redirected. -#}
chain omr_proxy_fw_{{ proto }} {
}

chain v2r_rules_forward_{{ proto }} {
	jump omr_proxy_fw_{{ proto }};
{%	for (let r in extra_rules()): %}
	meta l4proto udp {{ o_nft_udp_extra }} {{ r.match }} meta mark set 1 tproxy ip to :{{ r.port }} accept;
{%	endfor %}
	meta l4proto udp {{ o_nft_udp_extra }} meta mark set 1 tproxy to :{{ redir_port }};
}
{%   endif %}
{% endif %}
