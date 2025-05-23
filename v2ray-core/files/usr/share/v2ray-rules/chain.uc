{%
function get_local_verdict() {
	let v = o_local_default;
	if (v == "checkdst") {
		return "goto v2r_rules_dst_" + proto;
	} else if (v == "forward") {
		return "goto v2r_rules_forward_" + proto;
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
	if (system("
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
		if (system("
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
chain v2r_rules_forward_{{ proto }} {
{%	if (o_tproxy == "1"): %}
	meta l4proto tcp {{ o_nft_tcp_extra }} meta mark set 1 tproxy to :{{ redir_port }};
{%	else %}
	meta l4proto tcp {{ o_nft_tcp_extra }} redirect to :{{ redir_port }};
{%	endif %}
}
{%   let local_verdict = get_local_verdict(); if (local_verdict): %}
chain v2r_rules_local_out {
	type {{ type }} hook output priority -1;
	meta l4proto != tcp accept;
	ip daddr @v2r_rules_remote_servers accept;
	ip daddr @v2r_rules_dst_bypass_ accept;
	ip daddr @v2r_rules_dst_bypass accept;
	ip6 daddr @v2r_rules6_remote_servers accept;
	ip6 daddr @v2r_rules6_dst_bypass_ accept;
	ip6 daddr @v2r_rules6_dst_bypass accept;
{%	if (o_tproxy != "1"): %}
	{{ local_verdict }};
{% 	endif %}
}
{%     endif %}
{%   elif (proto == "udp"): %}
chain v2r_rules_forward_{{ proto }} {
	meta l4proto udp {{ o_nft_udp_extra }} meta mark set 1 tproxy to :{{ redir_port }};
}
{%   endif %}
{% endif %}
