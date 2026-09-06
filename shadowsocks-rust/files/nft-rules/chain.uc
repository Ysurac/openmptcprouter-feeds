{%
function get_local_verdict() {
	let v = o_local_default;
	if (v == "checkdst") {
		return "goto ss_rules_dst_" + proto;
	} else if (v == "forward") {
		return "goto ss_rules_forward_" + proto;
	} else {
		return null;
	}
}

function get_src_default_verdict() {
	let v = o_src_default;
	if (v == "checkdst") {
		return "goto ss_rules_dst_" + proto;
	} else if (v == "forward") {
		return "goto ss_rules_forward_" + proto;
	} else {
		return "accept";
	}
}

function get_dst_default_verdict() {
	let v = o_dst_default;
	if (v == "forward") {
		return "goto ss_rules_forward_" + proto;
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

// Port expression for the TCP redirect/tproxy statement. One port is used as
// is; several (space or comma separated, every enabled ss_redir instance when
// ss_rules.redir_tcp is "all") become a round-robin over the list: the kernel
// would hand a plain "1100-1101" DNAT range to its first free port every time,
// so no connection ever reached the other instances. NAT rules run once per
// new connection, so "numgen inc" spreads connections, not packets.
function redir_target(ports) {
	let list = [];
	for (let p in split(ports, /[ \t\n,]+/)) {
		p = trim(p);
		if (p) push(list, p);
	}
	if (length(list) <= 1)
		return trim(ports);
	let entries = [];
	for (let i = 0; i < length(list); i++)
		push(entries, sprintf("%d : %s", i, list[i]));
	return sprintf("numgen inc mod %d map { %s }", length(list), join(", ", entries));
}

let type, hook, priority, redir_port;
if (o_tun == "tcp_only") {
	if (proto == "tcp") {
		type = "nat";
		hook = "prerouting";
		priority = 1;
		redir_port = o_redir_tcp_port;
		if (system("
			set -o errexit
			iprr() {
				while ip $1 rule del fwmark 9988 lookup 9988 2>/dev/null; do true; done
				ip $1 rule add fwmark 0x9988 lookup 9988
				ip $1 route flush table 9988 2>/dev/null || true
				ip $1 route add local default dev tunprox table 9988
			}
			iprr -4
			iprr -6
		") != 0) {
			return ;
		}
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

} else if (o_tproxy == "1") {
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
chain ss_rules_pre_{{ proto }} {
	type {{ type }} hook {{ hook }} priority {{ priority }};
	ip daddr @ss_rules_remote_servers accept;
	ip6 daddr @ss_rules6_remote_servers accept;
	meta l4proto {{ proto }}{%- let ifnames=get_ifnames(); if (length(ifnames)): %} iifname { {{join(", ", ifnames)}} }{% endif %} goto ss_rules_pre_src_{{ proto }};
}

chain ss_rules_pre_src_{{ proto }} {
	ip daddr @ss_rules_dst_bypass_ accept;
	ip6 daddr @ss_rules6_dst_bypass_ accept;
	goto ss_rules_src_{{ proto }};
}

chain ss_rules_src_{{ proto }} {
	ip saddr @ss_rules_src_bypass accept;
	ip saddr @ss_rules_src_forward goto ss_rules_forward_{{ proto }};
	ip saddr @ss_rules_src_checkdst goto ss_rules_dst_{{ proto }};
	ip6 saddr @ss_rules6_src_bypass accept;
	ip6 saddr @ss_rules6_src_forward goto ss_rules_forward_{{ proto }};
	ip6 saddr @ss_rules6_src_checkdst goto ss_rules_dst_{{ proto }};
	{{ get_src_default_verdict() }};
}

chain ss_rules_dst_{{ proto }} {
	ip daddr @ss_rules_dst_bypass accept;
	ip daddr @ss_rules_remote_servers accept;
	ip daddr @ss_rules_dst_forward goto ss_rules_forward_{{ proto }};
	ip6 daddr @ss_rules6_dst_bypass accept;
	ip6 daddr @ss_rules6_remote_servers accept;
	ip6 daddr @ss_rules6_dst_forward goto ss_rules_forward_{{ proto }};
	{{ get_dst_default_verdict() }};
}

{%   if (proto == "tcp"): %}
chain ss_rules_forward_{{ proto }} {
{%	if (o_tun == "tcp_only"): %}
	meta l4proto tcp {{ o_nft_tcp_extra }} meta mark set 0x00009988;
{% 	elif (o_tproxy == "1"): %}
	meta l4proto tcp {{ o_nft_tcp_extra }} meta mark set 1 tproxy to :{{ redir_target(redir_port) }};
{% 	else %}
	meta l4proto tcp {{ o_nft_tcp_extra }} redirect to :{{ redir_target(redir_port) }};
{%	endif %}
}
{%   let local_verdict = get_local_verdict(); if (local_verdict): %}
chain ss_rules_local_out {
	type {{ type }} hook output priority -1;
	meta l4proto != tcp accept;
	ip daddr @ss_rules_remote_servers accept;
	ip daddr @ss_rules_dst_bypass_ accept;
	ip daddr @ss_rules_dst_bypass accept;
	ip6 daddr @ss_rules6_remote_servers accept;
	ip6 daddr @ss_rules6_dst_bypass_ accept;
	ip6 daddr @ss_rules6_dst_bypass accept;
{%	if (o_tproxy != "1"): %}
	{{ local_verdict }};
{%	endif %}
}
{%     endif %}
{%   elif (proto == "udp"): %}
chain ss_rules_forward_{{ proto }} {
	meta l4proto udp {{ o_nft_udp_extra }} meta mark set 1 tproxy to :{{ redir_port }};
}
{%   endif %}
{% endif %}
