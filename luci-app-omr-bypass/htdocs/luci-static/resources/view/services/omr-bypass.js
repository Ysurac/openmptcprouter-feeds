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
			uci.load('network')
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
		o.optional = true;

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });
		o.depends('vpn', '0');

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;
		o.depends('vpn', '0');

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });
		o.depends('vpn', '0');

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;
		o.depends('vpn', '0');

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });
		o.depends('vpn', '0');

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;
		o.depends('vpn', '0');

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

		o = s.option(form.ListValue, 'interface', _('Output interface'),_('When none selected, MPTCP master interface is used (or an other interface if master is down).'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });
		o.depends('vpn', '0');

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;
		o.depends('vpn', '0');

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

		o = s.option(form.ListValue, 'interface', _('Output interface'), _('When none selected, MPTCP master interface is used.'));
		o.value('default', _('Default (MPTCP master interface)'));
		o.value('', _('No routing change (DSCP marking only)'));
		o.value('none', _('None (block traffic)'));
		ifaces.forEach(function(name) { o.value(name); });
		o.depends('vpn', '0');

		o = s.option(form.ListValue, 'failback', _('Failback'),
			_('Failback interface when the selected interface is down.'));
		o.value('', _('None (no failback)'));
		o.value('default', _('Default MPTCP interface'));
		ifaces.forEach(function(name) { o.value(name); });
		o.rmempty = true;
		o.modalonly = true;
		o.depends('vpn', '0');

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
