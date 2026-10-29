'use strict';
'require form';
'require uci';
'require rpc';

var conf = 'xray';

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

		m = new form.Map(conf, _('XRay'),
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
		o.placeholder = '0';
		o.description = _('Caps the virtual memory of xray at this percentage of total RAM: its allocations above it fail and procd starts it again. xray maps more memory than it uses, so a low value can keep it from starting. Empty or 0: no limit.');

		o = s.option(form.Value, 'asset_location', _('Asset location'));
		o.description = _('Directory holding geoip.dat / geosite.dat, if not the xray default');

		o = s.option(form.Value, 'config_file', _('Config file'));
		o.description = _('Raw xray JSON config file. When set, xray runs this file instead of the configuration built from these pages.');

		o = s.option(form.Flag, 'stats_enabled', _('Stats API'));
		o = s.option(form.Flag, 'transport_enabled', _('Custom transport'));
		o.description = _('Merge /etc/xray/transport.txt (raw JSON) as the top-level "transport" object');

		s = m.section(form.NamedSection, 'main_transparent_proxy', 'transparent_proxy', _('Transparent proxy'));
		s.addremove = false;

		/* proxy_mode, redirect_dns, only_privileged_ports, lan_ifaces,
		 * direct_list_dns, proxy_list_dns and the list mirrors are not
		 * shown: the nftables rules the init renders use none of them.
		 * The redirected interfaces are the shadowsocks ss_rules ones. */
		o = s.option(form.Value, 'redirect_port', _('Redirect port'));
		o.datatype = 'port';
		o.description = _('Must match the dokodemo-door inbound(s) handling redirected traffic');

		o = s.option(form.Flag, 'redirect_udp', _('Redirect UDP'));
		/* uci-defaults, the wizard and the Settings page all store it, '0'
		 * included: left to rmempty, a no-op save deleted that '0' */
		o.rmempty = false;
		o = s.option(form.Flag, 'use_tproxy', _('Use TPROXY'));
		o.description = _('Use TPROXY instead of REDIRECT for transparent proxying');

		return m.render().then(function(node) {
			L.Poll.add(function() {
				return L.resolveDefault(callServiceList(conf), {}).then(function(res) {
					/* the value only: the id is the whole row's, label included */
					var row = document.getElementById('cbi-' + conf + '-main-_running');
					var el = row ? (row.querySelector('output') || row.querySelector('.cbi-value-field')) : null;
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
