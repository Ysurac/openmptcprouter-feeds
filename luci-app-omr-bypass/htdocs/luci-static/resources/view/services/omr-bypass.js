'use strict';
'require rpc';
'require form';
'require fs';
'require uci';
'require tools.widgets as widgets';

var callHostHints;

var callUciCommit = rpc.declare({
	object: 'uci',
	method: 'commit',
	params: ['config']
});

return L.view.extend({
	callHostHints: rpc.declare({
		object: 'luci-rpc',
		method: 'getHostHints',
		expect: { '': {} }
	}),

	load: function() {
		return Promise.all([
			L.resolveDefault(fs.stat('/proc/net/xt_ndpi/proto'), null),
			this.callHostHints(),
			L.resolveDefault(fs.read_direct('/proc/net/xt_ndpi/proto'), ''),
			L.resolveDefault(fs.read_direct('/proc/net/xt_ndpi/host_proto'), ''),
			fs.read_direct('/usr/share/omr-bypass/omr-bypass-proto.json'),
			L.resolveDefault(fs.stat('/usr/sbin/ndpisrvd'), null),
			uci.load('network'),
			L.resolveDefault(fs.read_direct('/var/run/omr-bypass-failover/status'), ''),
			L.resolveDefault(fs.read_direct('/var/run/omr-bypass-failover/groups'), '')
		]);
	},

	render: function(testhosts) {
		var m, s, o, hosts;
		hosts = testhosts[1];
		var ifaces = uci.sections('network', 'interface').map(function(s) { return s['.name']; }).filter(function(name) { return name !== 'loopback'; });

		var protodata = [];
		try { protodata = JSON.parse(testhosts[4]); } catch(e) {}
		var protoMap = {};
		protodata.forEach(function(p) {
			if (!p || !p.proto)
				return;
			protoMap[p.proto] = p;
			protoMap[String(p.proto).toLowerCase()] = p;
		});
		function getProtoMeta(name) {
			if (!name)
				return null;
			return protoMap[name] || protoMap[String(name).toLowerCase()] || null;
		}

		var groupStatus = {};
		String(testhosts[8] || '').split('\n').forEach(function(line) {
			var f = line.trim().split(/\s+/);
			if (f.length >= 3)
				groupStatus[f[2]] = f[1];
		});

		/* Output interface as an ordered list: the first usable entry is
		 * used, the next ones are its failover order (OMR-Tracker decides
		 * what is up). An empty list means no routing change (DSCP only).
		 * New rows start with "default", set when the row is created rather
		 * than through o.default: a default-valued option is dropped on
		 * save, and an absent interface means "DSCP only" to the backend. */
		function addOutputInterfaces(s, vpn) {
			var o = s.option(form.DynamicList, 'interface', _('Output interfaces'),
				_('Ordered list: the first interface that is up is used, the next ones take over when it goes down, and the first one is used again once it is back. "Default" is the MPTCP master interface; when no listed interface is up, traffic is blocked unless "Default" is in the list. Leave empty for no routing change (DSCP marking only).'));
			o.value('default', _('Default (MPTCP master interface)'));
			o.value('none', _('None (block traffic)'));
			ifaces.forEach(function(name) { o.value(name); });
			o.textvalue = function(section_id) {
				var v = L.toArray(this.cfgvalue(section_id)).map(function(x) { return x === 'all' ? 'default' : x; });
				var fb = uci.get('omr-bypass', section_id, 'failback');
				if (fb && v.length && v[0] !== 'none' && v.indexOf(fb) < 0)
					v.push(fb === 'all' ? 'default' : fb);
				if (!v.length)
					return _('No routing change');
				var text = v.join(' → ');
				var active = v.length > 1 ? groupStatus[v.join(',')] : null;
				if (active)
					text += ' (' + _('now: %s').format(active) + ')';
				return text;
			};
			if (vpn)
				o.depends('vpn', '0');

			var handleAdd = s.handleAdd;
			s.handleAdd = function(ev, name) {
				var data = this.map.data,
				    config = this.uciconfig || this.map.config,
				    type = this.sectiontype,
				    add = data.add;
				data.add = function(c, t) {
					var sid = add.apply(this, arguments);
					if (c === config && t === type)
						this.set(c, sid, 'interface', [ 'default' ]);
					return sid;
				};
				try {
					return handleAdd.apply(this, arguments);
				} finally {
					data.add = add;
				}
			};
			return o;
		}

		m = new form.Map('omr-bypass', _('OMR-Bypass'),_('OpenMPTCProuter IP must be used as DNS.'));

		s = m.section(form.TypedSection, 'global', _('Global settings'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.ListValue, 'reload_rules_hour', _('Bypassed domains IP refresh'),
			_('When domain-based bypass rules are used, OpenMPTCProuter periodically refreshes the resolved IPs, which can force a firewall/DNS restart and briefly interrupt existing connections if any IP actually changed. By default this refresh runs once a day at 02:00; pick a different hour, or "Every hour", if needed.'));
		for (var hourIdx = 0; hourIdx < 24; hourIdx++) {
			var hourLabel = (hourIdx < 10 ? '0' : '') + hourIdx + ':00';
			o.value(String(hourIdx), hourLabel);
		}
		o.value('hourly', _('Every hour'));
		o.default = '2';
		/* Written explicitly, never dropped for matching the default: form.js
		 * removes an option whose value equals its default when the option is
		 * optional (or rmempty), so every save of this page queued the removal
		 * of a schedule the user had chosen. It happens to be harmless while
		 * this default and 010-services' fallback are both "2" -- the whole
		 * point of #4348/#4352 is that such an agreement is not something to
		 * rely on, and an option that is simply absent tells the next reader
		 * nothing about what was intended. */
		o.optional = false;
		o.rmempty = false;

		/*
		o = s.option(form.Flag, 'noipv6', _('Disable IPv6 AAAA DNS results for bypassed domains'));
		o.default = o.disabled;
		o.optional = true;
		*/

		s = m.section(form.GridSection, 'domains', _('Domains'),
			_('Create rules that match destination domain names. Domain-based bypass requires OpenMPTCProuter DNS to be used by clients.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.Value, 'name', _('Domain'),
			_('Enter a domain name to route through the selected interface or the server VPN.'));
		o.rmempty = false;

		o = s.option(form.Flag, 'vpn', _('VPN on server'),_('Bypass using VPN configured on server.'));
		o.modalonly = true

		addOutputInterfaces(s, true);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		o = s.option(form.ListValue, 'family', _('Restrict to address family'),
			_('Limit the rule to IPv4 results, IPv6 results, or allow both.'));
		o.value('ipv4ipv6', _('IPv4 and IPv6'));
		o.value('ipv4', _('IPv4 only'));
		o.value('ipv6', _('IPv6 only'));
		o.default = 'ipv4ipv6';
		o.modalonly = true

		o = s.option(form.ListValue, 'proto', _('protocol'),
			_('Restrict the matched traffic to a specific transport protocol.'));
		o.default = 'all';
		o.rmempty = false;
		o.value('all');
		o.value('tcp');
		o.value('udp');
		o.modalonly = true

		o = s.option(form.Flag, 'noipv6', _('Disable AAAA IPv6 DNS'),
			_('Ignore IPv6 AAAA DNS answers for this rule and only use IPv4 results.'));
		o.default = o.enabled;
		o.modalonly = true

		s = m.section(form.GridSection, 'ips', _('IPs and Networks'),
			_('Create rules that match destination IP addresses or networks directly.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.Value, 'ip', _('IP'),
			_('Enter a destination IP address or network in CIDR notation.'));
		o.rmempty = false;

		o = s.option(form.Flag, 'vpn', _('VPN on server'),_('Bypass using VPN configured on server.'));
		o.modalonly = true

		o = s.option(form.ListValue, 'proto', _('protocol'),
			_('Restrict the matched traffic to a specific transport protocol.'));
		o.default = 'all';
		o.rmempty = false;
		o.value('all');
		o.value('tcp');
		o.value('udp');
		o.modalonly = true

		addOutputInterfaces(s, true);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'dest_port', _('Ports destination'),
			_('Create rules that match destination ports, for example to steer selected services.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.Value, 'dport', _('port'),
			_('Destination port number to match.'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'proto', _('protocol'),
			_('Protocol to match for this destination port rule.'));
		o.default = 'tcp';
		o.rmempty = false;
		o.value('tcp');
		o.value('udp');
		o.value('icmp');

		addOutputInterfaces(s, false);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'src_port', _('Ports source'),
			_('Create rules that match source ports generated by local applications or devices.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.Value, 'sport', _('port'),
			_('Source port number to match.'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'proto', _('protocol'),
			_('Protocol to match for this source port rule.'));
		o.default = 'tcp';
		o.rmempty = false;
		o.value('tcp');
		o.value('udp');
		o.value('icmp');

		addOutputInterfaces(s, false);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'macs', _('MAC-Address'),
			_('Create rules that match traffic from specific client devices by MAC address.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.Value, 'mac', _('source MAC-Address'),
			_('Match traffic coming from this client MAC address.'));
		o.datatype = 'list(unique(macaddr))';
		o.rmempty = false;
		Object.keys(hosts).forEach(function(mac) {
			var hint = hosts[mac].name || hosts[mac].ipv4;
			o.value(mac, hint ? '%s (%s)'.format(mac, hint) : mac);
		});

		addOutputInterfaces(s, false);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'lan_ip', _('Source lan IP address or network'),
			_('Create rules that match traffic from a local source IP address or subnet.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.Value, 'ip', _('IP Address'),
			_('Enter a source LAN IP address to match.'));
		o.datatype = 'or(ip4addr,ip6addr)';
		o.rmempty = false;
		Object.keys(hosts).forEach(function(mac) {
			if (hosts[mac].ipv4) {
				var hint = hosts[mac].name;
				o.value(hosts[mac].ipv4, hint ? '%s (%s)'.format(hosts[mac].ipv4, hint) : hosts[mac].ipv4);
			}
		});

		addOutputInterfaces(s, false);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		var srcifStatus = {};
		String(testhosts[7] || '').split('\n').forEach(function(line) {
			var f = line.trim().split(/\s+/);
			if (f.length >= 2)
				srcifStatus[f[0]] = f[1];
		});

		s = m.section(form.GridSection, 'src_intf', _('Source interface policies'),
			_('Send everything that enters the router on a local interface out through a chosen WAN, directly, instead of the aggregated connection. The first WAN of the list that is up is used; when it goes down (as detected by OMR-Tracker) the next one takes over, and the preferred one is used again once it is back. Rules above that match a destination (domain, IP, port...) still take precedence.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this policy without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.MultiValue, 'source', _('Source interface'),
			_('Local interface(s) whose traffic this policy applies to.'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = false;

		o = s.option(form.DynamicList, 'wan', _('Output WANs'),
			_('Ordered list: the first WAN that is up is used, the following ones are the failover order.'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = false;

		o = s.option(form.ListValue, 'fallback', _('When all WANs are down'),
			_('Default: traffic follows the normal OpenMPTCProuter path (aggregation through the server). Block: traffic from this interface is dropped.'));
		o.value('default', _('Default OpenMPTCProuter path'));
		o.value('block', _('Block traffic'));
		o.default = 'default';
		o.optional = false;
		o.rmempty = false;

		o = s.option(form.ListValue, 'ipv6', _('IPv6'),
			_('Policy routes IPv6 through the same WAN too: only use it when that WAN gives the interface routable IPv6 addresses. Default leaves IPv6 on the normal OpenMPTCProuter path.'));
		o.value('default', _('Default OpenMPTCProuter path'));
		o.value('policy', _('Same WAN as IPv4'));
		o.value('block', _('Block IPv6'));
		o.default = 'default';
		o.optional = false;
		o.rmempty = false;
		o.modalonly = true;

		o = s.option(form.DummyValue, '_active', _('Current output'));
		o.modalonly = false;
		o.textvalue = function(section_id) {
			var st = srcifStatus[section_id];
			if (!st)
				return _('Not applied yet');
			if (st === 'disabled')
				return _('Disabled');
			if (st === 'nosource')
				return _('Source interface not up');
			if (st === 'fallback:default')
				return _('All WANs down: default path');
			if (st === 'fallback:block')
				return _('All WANs down: blocked');
			return st;
		};

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this policy.'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'asns', _('ASN'),
			_('Create rules that match destinations announced by a specific autonomous system number.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.Value, 'asn', _('ASN'),
			_('Enter the autonomous system number to match.'));
		o.rmempty = false;

		o = s.option(form.Flag, 'vpn', _('VPN on server'),_('Bypass using VPN configured on server.'));
		o.modalonly = true

		addOutputInterfaces(s, true);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'dpis', _('Protocols and services'),
			_('Create rules that match application protocols or services detected by nDPI.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		// Full list of DPI protocol names, populated by o.load below.
		var allDpiNames = [];

		// Rebuild protoSel options from allDpiNames filtered by catVal / typVal.
		function applyDpiFilter(protoSel, catVal, typVal) {
			if (!protoSel || !allDpiNames.length) return;
			var curVal = protoSel.value;
			while (protoSel.options.length) protoSel.remove(0);
			var first = null, found = false;
			allDpiNames.forEach(function(n) {
				var meta = getProtoMeta(n) || {};
				if ((!catVal || catVal === meta.category) &&
				    (!typVal || typVal === meta.type)) {
					protoSel.add(new Option(n, n));
					if (!first) first = n;
					if (n === curVal) found = true;
				}
			});
			protoSel.value = found ? curVal : (first || '');
		}
/*
		o = s.option(form.ListValue, 'category', _('Category'),
			_('Filter the protocol list by category.'));
		o.rmempty = true;
		o.modalonly = true;
		o.default = '';
		o.value('', _('All'));
		Array.from(new Set(protodata.map(function(p) { return p.category; }).filter(Boolean))).sort().forEach(function(cat) { o.value(cat); });

		o = s.option(form.ListValue, 'ndpitype', _('Type'),
			_('Filter the protocol list by type.'));
		o.rmempty = true;
		o.modalonly = true;
		o.default = '';
		o.value('', _('All'));
		o.value('application', _('Application'));
		o.value('protocol', _('Protocol'));
*/
		o = s.option(form.ListValue, 'proto', _('Protocol/Service'),
			_('Select the application protocol or service name to match.'));
		o.rmempty = false;
		o.load = function(section_id) {
			var proto = testhosts[2].split(/\n/),
			    host = testhosts[3].split(/\n/),
			    name = [];
			if (proto.length > 2) {
				for (var i = 0; i < proto.length; i++) {
					var m = proto[i].split(/\s+/);
					if (m && m[0] != "#id" && m[1] != "disabled")
					    name.push(m[2]);
				}
			}
			if (host.length > 2) {
				for (var i = 0; i < host.length; i++) {
					var m = host[i].split(/:/);
					if (m && m[0] != "#Proto")
					  name.push(m[0].toLowerCase());
				}
			}
			if (proto.length == 1 && host.length == 1) {
				for (var i = 0; i < protodata.length; i++) {
					if (protodata[i] && protodata[i].proto)
						name.push(protodata[i].proto);
				}
			}
			if (host.length > 2) {
				name = Array.from(new Set(name)).sort(function (a, b) { return a.toLowerCase().localeCompare(b.toLowerCase())}).reduce(function(a, b){ if (a.slice(-1)[0] !== b) a.push(b);return a;},[]);
			}
			allDpiNames = name;
			for (var i = 0; i < name.length; i++) {
				this.value(name[i], name[i]);
			}
			return this.super('load', [section_id]);
		};
		o.renderWidget = function(section_id, option_index, cfgvalue) {
			var node = this.super('renderWidget', [section_id, option_index, cfgvalue]);
			var protoSel = node.querySelector('select');
			if (!protoSel || !allDpiNames.length) return node;

			// Apply initial filter based on saved UCI values (editing existing row).
			var mapCfg = this.map.config;
			var initCat = uci.get(mapCfg, section_id, 'category') || '';
			var initTyp = uci.get(mapCfg, section_id, 'ndpitype') || '';
			if (initCat || initTyp)
				applyDpiFilter(protoSel, initCat, initTyp);

			// Attach native change listeners to category/ndpitype selects.
			// Use setTimeout so the modal is fully in the DOM before we query it.
			setTimeout(function() {
				function findSel(field) {
					var w = document.getElementById('cbid.' + mapCfg + '.' + section_id + '.' + field);
					if (w) return w.querySelector('select') || (w.tagName === 'SELECT' ? w : null);
					w = document.querySelector('[id$=".' + field + '"] select, select[id$=".' + field + '"]');
					return w || null;
				}
				var catSel = findSel('category');
				var typSel = findSel('ndpitype');
				function onChange() {
					applyDpiFilter(protoSel,
						catSel ? catSel.value : '',
						typSel ? typSel.value : '');
				}
				if (catSel) catSel.addEventListener('change', onChange);
				if (typSel) typSel.addEventListener('change', onChange);
			}, 0);

			return node;
		};

		o = s.option(form.Flag, 'vpn', _('VPN on server'),_('Bypass using VPN configured on server.'));
		o.modalonly = true

		addOutputInterfaces(s, true);

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		o = s.option(form.ListValue, 'family', _('Restrict to address family'),
			_('Limit the rule to IPv4 results, IPv6 results, or allow both.'));
		o.value('ipv4ipv6', _('IPv4 and IPv6'));
		o.value('ipv4', _('IPv4 only'));
		o.value('ipv6', _('IPv6 only'));
		o.default = 'ipv4ipv6';
		o.modalonly = true

		o = s.option(form.ListValue, 'tcpudp', _('Transport protocol'),
			_('Restrict the matched traffic to a specific transport protocol.'));
		o.default = 'all';
		o.rmempty = false;
		o.value('all');
		o.value('tcp');
		o.value('udp');
		o.modalonly = true

		o = s.option(form.Flag, 'noipv6', _('Disable AAAA IPv6 DNS'),
			_('Ignore IPv6 AAAA DNS answers for this rule and only use IPv4 results.'));
		o.default = true;
		o.modalonly = true

		if (testhosts[0] || testhosts[5]) {
			o = s.option(form.Flag, 'ndpi', _('Enable ndpi'),
				_('Enable deep packet inspection for this rule when nDPI support is available.'));
			o.default = o.enabled;
			o.modalonly = true
			o.depends('vpn', '0');
		}

		s = m.section(form.GridSection, 'categories', _('Protocol categories'),
			_('Create rules that bypass all protocols belonging to a selected category.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable or disable this bypass rule without deleting it.'));
		o.default = o.enabled;

		o = s.option(form.ListValue, 'category', _('Category'),
			_('Select the protocol category to bypass.'));
		o.rmempty = false;
		Array.from(new Set(protodata.map(function(p) { return p.category; }).filter(Boolean))).sort().forEach(function(cat) { o.value(cat); });

		o = s.option(form.Flag, 'vpn', _('VPN on server'), _('Bypass using VPN configured on server.'));
		o.modalonly = true;

		addOutputInterfaces(s, true);

		o = s.option(form.ListValue, 'tcpudp', _('Protocol'),
			_('Restrict the matched traffic to a specific transport protocol.'));
		o.default = 'all';
		o.rmempty = false;
		o.value('all');
		o.value('tcp');
		o.value('udp');
		o.modalonly = true;

		o = s.option(form.ListValue, 'family', _('Restrict to address family'),
			_('Limit the rule to IPv4 results, IPv6 results, or allow both.'));
		o.value('ipv4ipv6', _('IPv4 and IPv6'));
		o.value('ipv4', _('IPv4 only'));
		o.value('ipv6', _('IPv6 only'));
		o.default = 'ipv4ipv6';
		o.modalonly = true;

		o = s.option(form.Flag, 'noipv6', _('Disable AAAA IPv6 DNS'),
			_('Ignore IPv6 AAAA DNS answers for bypassed domain names in this category.'));
		o.default = true;
		o.modalonly = true;

		if (testhosts[0] || testhosts[5]) {
			o = s.option(form.Flag, 'ndpi', _('Enable ndpi'),
				_('Enable deep packet inspection for this rule when nDPI support is available.'));
			o.default = o.enabled;
			o.modalonly = true;
			o.depends('vpn', '0');
		}

		o = s.option(form.ListValue, 'dscp', _('DSCP marking'),
			_('Optional DSCP value to mark matched traffic. Can be set without an output interface.'));
		o.value('', _('None'));
		o.value('cs0', 'CS0 (0) - Best Effort');
		o.value('cs1', 'CS1 (8)');
		o.value('cs2', 'CS2 (16)');
		o.value('cs3', 'CS3 (24)');
		o.value('cs4', 'CS4 (32)');
		o.value('cs5', 'CS5 (40)');
		o.value('cs6', 'CS6 (48)');
		o.value('cs7', 'CS7 (56)');
		o.value('af11', 'AF11 (10)');
		o.value('af12', 'AF12 (12)');
		o.value('af13', 'AF13 (14)');
		o.value('af21', 'AF21 (18)');
		o.value('af22', 'AF22 (20)');
		o.value('af23', 'AF23 (22)');
		o.value('af31', 'AF31 (26)');
		o.value('af32', 'AF32 (28)');
		o.value('af33', 'AF33 (30)');
		o.value('af41', 'AF41 (34)');
		o.value('af42', 'AF42 (36)');
		o.value('af43', 'AF43 (38)');
		o.value('ef', 'EF (46) - Expedited Forwarding');
		o.value('le', 'LE (1) - Lower Effort');
		o.rmempty = true;
		o.modalonly = true;

		o = s.option(form.Value, 'note', _('Note'),
			_('Optional comment to help identify the purpose of this rule.'));
		o.rmempty = true;

		return m.render();
	}
});
