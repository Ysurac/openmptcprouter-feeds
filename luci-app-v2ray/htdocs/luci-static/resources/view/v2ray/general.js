'use strict';
'require form';
'require uci';
'require rpc';

var conf = 'v2ray';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: ['name'],
	expect: { '': {} }
});

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('V2Ray'),
			_('General settings, transparent proxy behaviour and running status. Inbounds, outbounds, routing, DNS, policy and reverse proxy have their own pages.'));

		s = m.section(form.NamedSection, 'main', conf, _('General'));
		s.addremove = false;

		o = s.option(form.DummyValue, '_running', _('Status'));
		o.default = _('collecting data...');

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'loglevel', _('Log level'));
		o.value('debug', _('Debug'));
		o.value('info', _('Info'));
		o.value('warning', _('Warning'));
		o.value('error', _('Error'));
		o.value('none', _('None'));
		o.default = 'error';
		o.rmempty = false;

		o = s.option(form.Value, 'access_log', _('Access log'));
		o.placeholder = '/dev/null';
		o = s.option(form.Value, 'error_log', _('Error log'));
		o.placeholder = '/dev/null';

		o = s.option(form.Value, 'mem_percentage', _('Memory limit (%)'));
		o.datatype = 'range(0,100)';
		o.description = _('Restart v2ray if it exceeds this percentage of total RAM. 0 disables the check.');

		o = s.option(form.Value, 'asset_location', _('Asset location'));
		o.description = _('Directory holding geoip.dat / geosite.dat, if not the v2ray default');

		o = s.option(form.Value, 'config_file', _('Extra config file'));
		o.description = _('Optional additional raw v2ray JSON config file to merge in');

		o = s.option(form.Flag, 'stats_enabled', _('Stats API'));
		o = s.option(form.Flag, 'transport_enabled', _('Custom transport'));
		o.description = _('Merge /etc/v2ray/transport.txt (raw JSON) as the top-level "transport" object');

		s = m.section(form.NamedSection, 'main_transparent_proxy', 'transparent_proxy', _('Transparent proxy'));
		s.addremove = false;

		o = s.option(form.ListValue, 'proxy_mode', _('Proxy mode'));
		o.value('default', _('Default'));
		o.value('gfwlist', _('GFWList'));
		o.value('bypass_mainland_china', _('Bypass mainland China'));

		o = s.option(form.Value, 'redirect_port', _('Redirect port'));
		o.datatype = 'port';
		o.description = _('Must match the dokodemo-door inbound(s) handling redirected traffic');

		o = s.option(form.Flag, 'redirect_udp', _('Redirect UDP'));
		o = s.option(form.Flag, 'redirect_dns', _('Redirect DNS'));
		o = s.option(form.Flag, 'use_tproxy', _('Use TPROXY'));
		o.description = _('Use TPROXY instead of REDIRECT for transparent proxying');

		o = s.option(form.Flag, 'only_privileged_ports', _('Only privileged ports'));
		o.description = _('Only redirect traffic to ports below 1024');

		o = s.option(form.DynamicList, 'lan_ifaces', _('LAN interfaces'));
		o.description = _('Interfaces whose traffic is transparently proxied; empty applies to all LAN');

		o = s.option(form.Value, 'direct_list_dns', _('Direct list DNS'));
		o.description = _('DNS server used to resolve domains from /etc/v2ray/directlist.txt');
		o = s.option(form.Value, 'proxy_list_dns', _('Proxy list DNS'));
		o.description = _('DNS server used to resolve domains from /etc/v2ray/proxylist.txt');

		o = s.option(form.Value, 'apnic_delegated_mirror', _('APNIC delegated mirror'));
		o = s.option(form.Value, 'gfwlist_mirror', _('GFWList mirror'));

		return m.render().then(function(node) {
			L.Poll.add(function() {
				return L.resolveDefault(callServiceList(conf), {}).then(function(res) {
					var el = document.getElementById('cbi-' + conf + '-main-_running');
					if (!el) return;
					var instances = (res && res[conf]) ? res[conf].instances : null;
					var running = instances ? Object.keys(instances).some(function(k) { return instances[k].running; }) : false;
					el.textContent = running ? _('running') : _('not running');
					el.style.color = running ? 'var(--color-success, #2d862d)' : 'var(--color-danger, #c0392b)';
				});
			});
			return node;
		});
	}
});
