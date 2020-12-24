'use strict';
'require rpc';
'require form';
'require fs';
'require uci';
'require tools.widgets as widgets';

var callHostHints;

return L.view.extend({
	callHostHints: rpc.declare({
		object: 'luci-rpc',
		method: 'getHostHints',
		expect: { '': {} }
	}),

	load: function() {
		return  this.callHostHints();
	},

	render: function(hosts) {
		var m, s, o;

		m = new form.Map('omr-bypass', _('OMR-Bypass'),_('OpenMPTCProuter IP must be used as DNS.'));

		s = m.section(form.GridSection, 'domains', _('Domains'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'name', _('Domain'));
		o.rmempty = false;

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used.'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'ips', _('IPs and Networks'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'ip', _('IP'));
		o.rmempty = false;

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used.'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'dest_port', _('Ports destination'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'dport', _('port'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'proto', _('protocol'));
		o.default = 'tcp';
		o.rmempty = false;
		o.value('tcp');
		o.value('udp');
		o.value('icmp');

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used.'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'src_port', _('Ports source'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'sport', _('port'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'proto', _('protocol'));
		o.default = 'tcp';
		o.rmempty = false;
		o.value('tcp');
		o.value('udp');
		o.value('icmp');

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used.'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'macs', _('MAC-Address'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'mac', _('source MAC-Address'));
		o.datatype = 'list(unique(macaddr))';
		o.rmempty = false;
		Object.keys(hosts).forEach(function(mac) {
			var hint = hosts[mac].name || hosts[mac].ipv4;
			o.value(mac, hint ? '%s (%s)'.format(mac, hint) : mac);
		});

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used.'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'lan_ip', _('Source lan IP address or network'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'ip', _('IP Address'));
		o.datatype = 'or(ip4addr,ip6addr)';
		o.rmempty = false;
		Object.keys(hosts).forEach(function(mac) {
			if (hosts[mac].ipv4) {
				var hint = hosts[mac].name;
				o.value(hosts[mac].ipv4, hint ? '%s (%s)'.format(hosts[mac].ipv4, hint) : hosts[mac].ipv4);
			}
		});

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used.'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'asns', _('ASN'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'asn', _('ASN'));
		o.rmempty = false;

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used.'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		s = m.section(form.GridSection, 'dpis', _('Protocols and services'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;

		o = s.option(form.Value, 'proto', _('Protocol/Service'));
		o.rmempty = false;
		o.load = function(section_id) {
			return Promise.all([
				fs.read_direct('/proc/net/xt_ndpi/proto'),
				fs.read_direct('/proc/net/xt_ndpi/host_proto')
			]).then(L.bind(function(filesi) {
				var proto = filesi[0].split(/\n/),
				    host = filesi[1].split(/\n/),
				    name = [];
				for (var i = 0; i < proto.length; i++) {
					var m = proto[i].split(/\s+/);
					if (m && m[0] != "#id" && m[1] != "disabled")
					    name.push(m[2]);
				}
				for (var i = 0; i < host.length; i++) {
					var m = host[i].split(/:/);
					if (m && m[0] != "#Proto")
					  name.push(m[0].toLowerCase());
				}
				name = Array.from(new Set(name)).sort(function (a, b) { return a.toLowerCase().localeCompare(b.toLowerCase())}).reduce(function(a, b){ if (a.slice(-1)[0] !== b) a.push(b);return a;},[]);
				for (var i = 0; i < name.length; i++) {
					this.value(name[i]);
				}
				return this.super('load', [section_id]);
			},this));
		};

		o = s.option(widgets.DeviceSelect, 'interface', _('Interface'),_('When none selected, MPTCP master interface is used (or an other interface if master is down).'));
		o.noaliases = true;
		o.noinactive = true;
		o.nocreate    = true;

		o = s.option(form.Value, 'note', _('Note'));
		o.rmempty = true;

		return m.render();
	}
});
