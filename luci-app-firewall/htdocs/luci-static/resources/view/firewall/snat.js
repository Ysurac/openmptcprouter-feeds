'use strict';
'require ui';
'require rpc';
'require uci';
'require form';
'require tools.firewall as fwtool';
'require tools.widgets as widgets';

function fmt(fmt /*, ...*/) {
	var repl = [], wrap = false;

	for (var i = 1; i < arguments.length; i++) {
		if (L.dom.elem(arguments[i])) {
			switch (arguments[i].nodeType) {
			case 1:
				repl.push(arguments[i].outerHTML);
				wrap = true;
				break;

			case 3:
				repl.push(arguments[i].data);
				break;

			case 11:
				var span = E('span');
				span.appendChild(arguments[i]);
				repl.push(span.innerHTML);
				wrap = true;
				break;

			default:
				repl.push('');
			}
		}
		else {
			repl.push(arguments[i]);
		}
	}

	var rv = fmt.format.apply(fmt, repl);
	return wrap ? E('span', rv) : rv;
}

function snat_proto_txt(s) {
	return fmt('%s-%s',
		fwtool.fmt_family(uci.get('firewall', s, 'family')),
		fwtool.fmt_proto(uci.get('firewall', s, 'proto'),
		                 uci.get('firewall', s, 'icmp_type')) || 'TCP+UDP');
}

function snat_src_txt(s) {
	var z = fwtool.fmt_zone(uci.get('firewall', s, 'src'), _('any zone')),
	    a = fwtool.fmt_ip(uci.get('firewall', s, 'src_ip'), _('any host')),
	    p = fwtool.fmt_port(uci.get('firewall', s, 'src_port')),
	    m = fwtool.fmt_mac(uci.get('firewall', s, 'src_mac'));

	if (p && m)
		return fmt(_('From %s in %s with source %s and %s'), a, z, p, m);
	else if (p || m)
		return fmt(_('From %s in %s with source %s'), a, z, p || m);
	else
		return fmt(_('From %s in %s'), a, z);
}

function snat_via_txt(s) {
	var a = fwtool.fmt_ip(uci.get('firewall', s, 'src_dip'), _('any router IP')),
	    p = fwtool.fmt_port(uci.get('firewall', s, 'src_dport'));

	if (p)
		return fmt(_('Via %s at %s'), a, p);
	else
		return fmt(_('Via %s'), a);
}

return L.view.extend({
	callHostHints: rpc.declare({
		object: 'luci-rpc',
		method: 'getHostHints',
		expect: { '': {} }
	}),

	load: function() {
		return Promise.all([
			this.callHostHints()
		]);
	},

	render: function(data) {
		var hosts = data[0],
		    m, s, o;

		m = new form.Map('firewall', _('Firewall - Source NAT'),
			_('Source NAT is a specific form of masquerading which allows fine grained control over the source IP used for outgoing traffic, for example to map multiple WAN addresses to internal subnets.'));

		s = m.section(form.GridSection, 'snat', _('Port SNAT'));
		s.addremove = true;
		s.anonymous = true;
		s.sortable  = true;

		s.tab('general', _('General Settings'));
		s.tab('advanced', _('Advanced Settings'));

		s.filter = function(section_id) {
			return (uci.get('firewall', section_id, 'target') != 'DNAT');
		};

		s.sectiontitle = function(section_id) {
			return uci.get('firewall', section_id, 'name') || _('Unnamed snat');
		};

		s.handleAdd = function(ev) {
			var config_name = this.uciconfig || this.map.config,
			    section_id = uci.add(config_name, this.sectiontype);

			uci.set(config_name, section_id, 'target', 'SNAT');

			this.addedSection = section_id;
			this.renderMoreOptionsModal(section_id);
		};

		o = s.taboption('general', form.Value, 'name', _('Name'));
		o.placeholder = _('Unnamed snat');
		o.modalonly = true;

		o = s.option(form.DummyValue, '_match', _('Match'));
		o.modalonly = false;
		o.textvalue = function(s) {
			return E('small', [
				snat_proto_txt(s), E('br'),
				snat_src_txt(s), E('br'),
				snat_via_txt(s)
			]);
		};

		o = s.option(form.ListValue, '_dest', _('snat to'));
		o.modalonly = false;
		o.textvalue = function(s) {
			var z = fwtool.fmt_zone(uci.get('firewall', s, 'dest'), _('any zone')),
			    a = fwtool.fmt_ip(uci.get('firewall', s, 'dest_ip'), _('any host')),
			    p = fwtool.fmt_port(uci.get('firewall', s, 'dest_port')) ||
			        fwtool.fmt_port(uci.get('firewall', s, 'src_dport'));

			if (p)
				return fmt(_('%s, %s in %s'), a, p, z);
			else
				return fmt(_('%s in %s'), a, z);
		};

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.modalonly = false;
		o.default = o.enabled;
		o.editable = true;

		o = s.taboption('general', form.Value, 'proto', _('Protocol'));
		o.modalonly = true;
		o.default = 'tcp udp';
		o.value('tcp udp', 'TCP+UDP');
		o.value('tcp', 'TCP');
		o.value('udp', 'UDP');
		o.value('icmp', 'ICMP');

		o.cfgvalue = function(/* ... */) {
			var v = this.super('cfgvalue', arguments);
			return (v == 'tcpudp') ? 'tcp udp' : v;
		};

		o = s.taboption('general', widgets.ZoneSelect, 'src', _('Source zone'));
		o.modalonly = true;
		o.rmempty = false;
		o.nocreate = true;
		o.default = 'wan';

		o = s.taboption('advanced', form.Value, 'src_ip', _('Source IP address'),
			_('Only match incoming traffic from this IP or range.'));
		o.modalonly = true;
		o.rmempty = true;
		o.datatype = 'neg(ipmask4)';
		o.placeholder = E('em', _('any'));
		L.sortedKeys(hosts, 'ipv4', 'addr').forEach(function(mac) {
			o.value(hosts[mac].ipv4, '%s (%s)'.format(
				hosts[mac].ipv4,
				hosts[mac].name || mac
			));
		});

		o = s.taboption('advanced', form.Value, 'src_port', _('Source port'),
			_('Only match incoming traffic originating from the given source port or port range on the client host'));
		o.modalonly = true;
		o.rmempty = true;
		o.datatype = 'neg(portrange)';
		o.placeholder = _('any');
		o.depends('proto', 'tcp');
		o.depends('proto', 'udp');
		o.depends('proto', 'tcp udp');
		o.depends('proto', 'tcpudp');

		o = s.taboption('general', widgets.ZoneSelect, 'dest', _('Destination zone'));
		o.modalonly = true;
		o.rmempty = true;
		o.nocreate = true;
		o.default = 'lan';

		o = s.taboption('general', form.Value, 'dest_ip', _('Destination IP address'));
		o.modalonly = true;
		o.rmempty = true;
		o.datatype = 'ipmask4';
		L.sortedKeys(hosts, 'ipv4', 'addr').forEach(function(mac) {
			o.value(hosts[mac].ipv4, '%s (%s)'.format(
				hosts[mac].ipv4,
				hosts[mac].name || mac
			));
		});

		o = s.taboption('general', form.Value, 'dest_port', _('Destination port'),
			_('Match forwarded traffic to the given destination or port range'));
		o.modalonly = true;
		o.rmempty = true;
		o.placeholder = _('any');
		o.datatype = 'portrange';
		o.depends('proto', 'tcp');
		o.depends('proto', 'udp');
		o.depends('proto', 'tcp udp');
		o.depends('proto', 'tcpudp');

		o = s.taboption('general', form.Value, 'src_dip', _('SNAT IP address'),
			_('Rewrite matched traffic to the given address'));
		o.modalonly = true;
		o.rmempty = true;
		o.datatype = 'ipmask4';
		L.sortedKeys(hosts, 'ipv4', 'addr').forEach(function(mac) {
			o.value(hosts[mac].ipv4, '%s (%s)'.format(
				hosts[mac].ipv4,
				hosts[mac].name || mac
			));
		});

		o = s.taboption('general', form.Value, 'src_dport', _('SNAT port'),
			_('Rewrite matched traffic to the given source port. May be left empty to only rewrite the IP address'));
		o.modalonly = true;
		o.rmempty = true;
		o.placeholder = _('Do not rewrite');
		o.datatype = 'portrange';
		o.depends('proto', 'tcp');
		o.depends('proto', 'udp');
		o.depends('proto', 'tcp udp');
		o.depends('proto', 'tcpudp');


		o = s.taboption('advanced', form.Value, 'extra', _('Extra arguments'),
			_('Passes additional arguments to iptables. Use with care!'));
		o.modalonly = true;
		o.rmempty = true;

		return m.render();
	}
});
