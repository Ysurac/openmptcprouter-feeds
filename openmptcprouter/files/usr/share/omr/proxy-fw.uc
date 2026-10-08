{%
// Fills the omr_proxy_fw_<proto> chains of table inet fw4 that the
// transparent proxies (shadowsocks-libev/-rust, xray, v2ray) jump to before
// they redirect a LAN connection. Run by /bin/blocklanfw from the firewall
// include, i.e. after every fw4 start or reload.
//
// The redirect is in prerouting, before the forward hook: a redirected
// connection is local input for the firewall and never meets its forward
// rules, so a traffic rule that rejects or drops a LAN host did not stop that
// host's proxied traffic. These chains replay the forward rules on the
// connection before it is redirected, in fw4's order: "return" when the
// forward chain would accept it (the proxy takes it), "accept" when it would
// reject or drop it (no redirect: the connection is forwarded and the forward
// chain refuses it). Falling off the end is "return".
//
// The output device that a dest zone matches does not exist yet in
// prerouting, so the connection is dispatched on the zone of the device that
// the routing lookup picks for it (fib daddr . mark oifname), and only the
// rules for that dest zone or for any dest are replayed. The rules are
// rendered with fw4's own rule template, in fw4's table, so named sets work.
// A rule that matches an output device (option device + direction out) can't
// be evaluated before routing and is left out.

let fw4 = require("fw4");
fw4.load(false);

const templates = "/usr/share/firewall4/templates";
const protos = filter(split(getenv("OMR_PROXY_FW_PROTOS") || "", " "), p => p in ["tcp", "udp"]);

function relevant(chain, proto, egress) {
	let res = filter(fw4.rules(chain) || [], r =>
		(r.target in ["accept", "reject", "drop"]) && !r.oifnames &&
		(!r.proto || r.proto.any || r.proto.name == proto) &&
		(!r.dest || r.dest.any || (egress && r.dest.zone?.name == egress.name)));

	// Accepting rules after the last refusing one change nothing
	let last = -1;
	for (let i = 0; i < length(res); i++)
		if (res[i].target != "accept")
			last = i;

	return slice(res, 0, last + 1);
}

function verdict(rule) {
	return {
		...rule,
		target: (rule.target == "accept") ? "return" : "accept",
		jump_chain: null,
		counter: false,
		log: null,
		name: `omr proxy check: ${rule.name}`
	};
}

function egress_match(mr) {
	let m = [];

	if (mr.family)
		push(m, `meta nfproto ${fw4.nfproto(mr.family)}`);
	if (mr.devices_pos)
		push(m, `fib daddr . mark oifname ${fw4.set(mr.devices_pos)}`);
	if (mr.devices_neg)
		push(m, `fib daddr . mark oifname != ${fw4.set(mr.devices_neg)}`);
	for (let d in mr.devices_neg_wildcard)
		push(m, `fib daddr . mark oifname != ${fw4.quote(d)}`);
	if (mr.subnets_pos)
		push(m, `${fw4.ipproto(mr.family)} daddr ${fw4.set(mr.subnets_pos)}`);
	if (mr.subnets_neg)
		push(m, `${fw4.ipproto(mr.family)} daddr != ${fw4.set(mr.subnets_neg)}`);
	for (let s in mr.subnets_masked)
		push(m, `${fw4.ipproto(mr.family)} daddr & ${s.mask} ${s.invert ? '!=' : '=='} ${s.addr}`);

	return length(m) ? join(" ", m) : null;
}

// One chain per (dest zone or none, source zone or global)
let plan = {};
for (let proto in protos) {
	let egresses = [ ...map(fw4.zones() || [], z => ({ zone: z, name: `omr_proxy_fw_${proto}_to_${z.name}` })),
	                 { zone: null, name: `omr_proxy_fw_${proto}_nozone` } ];

	for (let e in egresses) {
		e.global = relevant("forward", proto, e.zone);
		e.sources = [];
		for (let z in fw4.zones() || []) {
			let rules = relevant(`forward_${z.name}`, proto, e.zone);
			if (length(rules))
				push(e.sources, { zone: z, rules, name: `${e.name}_from_${z.name}` });
		}
		e.used = !!(length(e.global) || length(e.sources));
	}

	plan[proto] = egresses;
}
-%}
{% for (let proto in protos): %}
{%  for (let e in plan[proto]): if (!e.used) continue; %}
{%   for (let s in e.sources): %}
add chain inet fw4 {{ s.name }}
flush chain inet fw4 {{ s.name }}
{%   endfor %}
add chain inet fw4 {{ e.name }}
flush chain inet fw4 {{ e.name }}
{%  endfor %}
add chain inet fw4 omr_proxy_fw_{{ proto }}
flush chain inet fw4 omr_proxy_fw_{{ proto }}
{% endfor %}

table inet fw4 {
{% for (let proto in protos): %}
{%  for (let e in plan[proto]): if (!e.used) continue; %}
{%   for (let s in e.sources): %}
	chain {{ s.name }} {
{%    for (let rule in s.rules): %}
		{%+ include(`${templates}/rule.uc`, { fw4, zone: null, rule: verdict(rule) }) %}
{%    endfor %}
	}

{%   endfor %}
	chain {{ e.name }} {
{%   for (let rule in e.global): %}
		{%+ include(`${templates}/rule.uc`, { fw4, zone: null, rule: verdict(rule) }) %}
{%   endfor %}
{%   for (let s in e.sources): for (let mr in s.zone.match_rules): %}
		{%+ include(`${templates}/zone-match.uc`, { fw4, egress: false, rule: mr }) -%}
		goto {{ s.name }}
{%   endfor; endfor %}
	}

{%  endfor %}
	chain omr_proxy_fw_{{ proto }} {
		ct state established,related return
{%  for (let e in plan[proto]): if (!e.zone) continue; %}
{%   for (let mr in e.zone.match_rules): let m = egress_match(mr); if (!m) continue; %}
		{{ m }} {{ e.used ? `goto ${e.name}` : "return" }}
{%   endfor %}
{%  endfor %}
{%  let nozone = plan[proto][length(plan[proto]) - 1]; if (nozone.used): %}
		goto {{ nozone.name }}
{%  endif %}
	}

{% endfor %}
}
