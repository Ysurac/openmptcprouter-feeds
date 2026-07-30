'use strict';
'require form';
'require uci';

return L.view.extend({
	load: function() {
		return uci.load('mqvpn');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('mqvpn', _('MQVPN'), _('QUIC-based VPN tunnel'));

		s = m.section(form.NamedSection, 'settings', 'settings', _('General'));
		s.addremove = false;

		o = s.option(form.Flag, 'enable', _('Enabled'));
		o.default = o.disabled;

		s = m.section(form.NamedSection, 'server', 'server', _('Server'));
		s.addremove = false;

		o = s.option(form.Value, 'ip', _('Server address'));
		o.description = _('IP address or hostname of the MQVPN server');
		o.datatype = 'host';
		o.rmempty = false;

		o = s.option(form.Value, 'port', _('Server port'));
		o.datatype = 'port';
		o.placeholder = '443';
		o.rmempty = false;

		o = s.option(form.Value, 'server_name', _('Server name (SNI)'));
		o.description = _('TLS SNI/verification name, if different from the server address');
		o.rmempty = true;

		o = s.option(form.Flag, 'insecure', _('Insecure TLS'));
		o.description = _('Skip TLS certificate verification');
		o.default = o.enabled;

		s = m.section(form.NamedSection, 'tls', 'tls', _('TLS'));
		s.addremove = false;

		o = s.option(form.Value, 'cipher', _('Cipher suites'));
		o.description = _('Colon-separated list of TLS cipher suites (leave empty for defaults)');
		o.placeholder = 'TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256';
		o.rmempty = true;

		s = m.section(form.NamedSection, 'auth', 'auth', _('Authentication'));
		s.addremove = false;

		o = s.option(form.Value, 'user', _('User'));
		o.description = _('Optional: identifies this client on the server (shown in status/logs)');
		o.rmempty = true;

		o = s.option(form.Value, 'key', _('Key'));
		o.rmempty = false;
		o.password = true;

		s = m.section(form.NamedSection, 'interface', 'interface', _('Interface'));
		s.addremove = false;

		o = s.option(form.Value, 'tun_name', _('Tunnel name'));
		o.default = 'mqvpn0';
		o.rmempty = true;

		o = s.option(form.ListValue, 'log_level', _('Log level'));
		o.value('debug', _('Debug'));
		o.value('info',  _('Info'));
		o.value('warn',  _('Warning'));
		o.value('error', _('Error'));
		o.default = 'info';

		o = s.option(form.Value, 'mtu', _('MTU'));
		o.description = _('TUN MTU cap in bytes (1280–9000, leave empty for auto)');
		o.datatype = 'range(1280, 9000)';
		o.placeholder = 'auto';
		o.rmempty = true;

		o = s.option(form.Flag, 'kill_switch', _('Kill switch'));
		o.description = _('Block all traffic if the VPN tunnel goes down');
		o.default = o.disabled;

		o = s.option(form.Flag, 'reconnect', _('Reconnect'));
		o.description = _('Automatically reconnect on failure');
		o.default = o.enabled;

		o = s.option(form.Value, 'reconnect_interval', _('Reconnect interval'));
		o.description = _('Seconds between reconnection attempts');
		o.datatype = 'uinteger';
		o.default = '5';
		o.depends('reconnect', '1');

		o = s.option(form.Flag, 'route_via_server', _('Route via server'));
		o.description = _('Add a host route to the server IP before setting the default route');
		o.default = o.disabled;

		o = s.option(form.Flag, 'no_routes', _('No automatic routes'));
		o.description = _('Skip all automatic route setup and manage routes manually');
		o.default = o.disabled;

		o = s.option(form.DynamicList, 'dns', _('DNS servers'));
		o.datatype = 'ipaddr';
		o.rmempty = true;

		s = m.section(form.NamedSection, 'control', 'control', _('Control API'));
		s.addremove = false;

		o = s.option(form.Value, 'control_port', _('Port'));
		o.description = _('TCP port for the JSON control API (leave empty to disable)');
		o.datatype = 'port';
		o.placeholder = '9091';
		o.rmempty = true;

		o = s.option(form.Value, 'control_addr', _('Bind address'));
		o.description = _('Address to bind the control API (default: 127.0.0.1)');
		o.datatype = 'ipaddr';
		o.placeholder = '127.0.0.1';
		o.rmempty = true;

		s = m.section(form.NamedSection, 'multipath', 'multipath', _('Multipath'));
		s.addremove = false;

		o = s.option(form.ListValue, 'scheduler', _('Scheduler'));
		o.value('wlb',         _('Weighted Load Balancing'));
		o.value('wlb_udp_pin', _('WLB with UDP pinning'));
		o.value('minrtt',      _('Minimum RTT'));
		o.value('wrtt',        _('Weighted RTT'));
		o.value('wrr',         _('Weighted Round Robin'));
		o.value('backup',      _('Backup'));
		o.value('backup_fec',  _('Backup with FEC'));
		o.value('rap',         _('RAP'));
		o.value('redundant',   _('Redundant'));
		o.default = 'wlb';
		o.description = _('With "Weighted RTT" or "Weighted Round Robin", each path\'s weight is taken from its interface\'s "Weight" setting (Network page, same value used by the MPTCP weight schedulers and settable via the API) and pushed to mqvpn automatically. "Weighted RTT" favors the highest-weight path until it\'s congestion-window-limited, while "Weighted Round Robin" interleaves traffic across paths in proportion to their weight. "Redundant" broadcasts every packet on every usable path; use only for loss-critical, low-bitrate traffic.');

		o = s.option(form.ListValue, 'cc', _('Congestion control'));
		o.value('bbr2',      _('BBR2'));
		o.value('bbr',       _('BBR'));
		o.value('cubic',     _('CUBIC'));
		o.value('new_reno',  _('New Reno'));
		o.value('copa',      _('Copa'));
		o.value('unlimited', _('Unlimited'));
		o.value('none',      _('None'));
		o.default = 'bbr2';
		o.rmempty = true;

		o = s.option(form.Flag, 'auto_wan', _('Auto WAN'));
		o.description = _('Automatically add WAN interfaces as multipath paths. If disabled, use the paths defined below.');
		o.default = o.enabled;

		o = s.option(form.Flag, 'reinjection_control', _('Reinjection control'));
		o.description = _('Enable reinjection control');
		o.default = o.disabled;

		o = s.option(form.ListValue, 'reinjection_mode', _('Reinjection mode'));
		o.value('', _('Default'));
		o.value('default', _('Default'));
		o.value('deadline', _('Deadline'));
		o.value('dgram', _('Datagram'));
		o.rmempty = true;
		o.depends('reinjection_control', '1');

		o = s.option(form.Flag, 'fec_enable', _('FEC'));
		o.description = _('Enable Forward Error Correction');
		o.default = o.disabled;

		o = s.option(form.ListValue, 'fec_scheme', _('FEC scheme'));
		o.value('galois_calculation', _('Galois Calculation'));
		o.value('packet_mask',        _('Packet Mask'));
		o.value('reed_solomon',       _('Reed-Solomon'));
		o.value('xor',                _('XOR'));
		o.default = 'reed_solomon';
		o.rmempty = true;
		o.depends('fec_enable', '1');

		o = s.option(form.Value, 'init_max_path_id', _('Initial max path ID'));
		o.description = _('draft-21 initial_max_path_id transport parameter. Lower it (e.g. 2) to force PATHS_BLOCKED for testing; leave empty for the default');
		o.datatype = 'uinteger';
		o.rmempty = true;

		o = s.option(form.DynamicList, 'path', _('Paths'));
		o.description = _('Network interfaces to use as multipath paths');
		o.rmempty = true;
		o.depends('auto_wan', '0');

		o = s.option(form.DynamicList, 'backup_path', _('Backup paths'));
		o.description = _('Network interfaces to use as backup multipath paths');
		o.rmempty = true;
		o.depends('auto_wan', '0');

		s = m.section(form.NamedSection, 'reorder', 'reorder', _('Reorder'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable reorder buffer'));
		o.description = _('Enable reorder buffer for inner UDP (off by default)');
		o.default = o.disabled;

		o = s.option(form.Value, 'max_wait_ms', _('Max wait (ms)'));
		o.description = _('Max hold time before releasing a gap (ms)');
		o.datatype = 'uinteger';
		o.placeholder = '30';
		o.rmempty = true;
		o.depends('enabled', '1');

		o = s.option(form.Value, 'cap_packets', _('Cap packets'));
		o.description = _('Max buffered datagrams per flow (power of two)');
		o.datatype = 'uinteger';
		o.placeholder = '1024';
		o.rmempty = true;
		o.depends('enabled', '1');

		s = m.section(form.TypedSection, 'reorder_rule', _('Reorder rules'));
		s.addremove = true;
		s.anonymous = true;

		o = s.option(form.ListValue, 'proto', _('Protocol'));
		o.value('udp', _('UDP'));
		o.value('tcp', _('TCP'));
		o.rmempty = false;

		o = s.option(form.Value, 'port', _('Port'));
		o.datatype = 'port';
		o.rmempty = false;

		o = s.option(form.ListValue, 'profile', _('Profile'));
		o.value('cellular_bond', _('Cellular Bond'));
		o.value('fiber_lte',     _('Fiber + LTE'));
		o.value('quic_bulk',     _('QUIC Bulk'));
		o.value('low_latency',   _('Low Latency'));
		o.value('default_udp',   _('Default UDP (pass-through)'));
		o.rmempty = false;

		s = m.section(form.NamedSection, 'advanced', 'advanced', _('Advanced'));
		s.addremove = false;

		o = s.option(form.Value, 'recv_rate_limit', _('Receive rate limit'));
		o.description = _('Client-only: cap QUIC receive window to N bytes/sec (0 = no cap)');
		o.datatype = 'uinteger';
		o.placeholder = '0';
		o.rmempty = true;

		return m.render();
	}
});
