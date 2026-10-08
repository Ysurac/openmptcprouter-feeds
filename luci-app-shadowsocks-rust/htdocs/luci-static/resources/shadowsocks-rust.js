'use strict';
'require baseclass';
'require uci';
'require form';
'require network';

var names_options_server = [
	'server',
	'server_port',
	'method',
	'password',
	'plugin',
	'plugin_opts',
];

var names_options_client = [
	'server',
	'local_address',
	'local_port',
];

var names_options_common = [
	'verbose',
	'ipv6_first',
	'fast_open',
	'no_delay',
	'reuse_port',
	'mode',
	'mtu',
	'timeout',
	'keep_alive',
	'user',
	'mptcp',
];

var modes = [
	'tcp_only',
	'tcp_and_udp',
	'udp_only',
];

var methods = [
	'none',
	// aead
	'aes-128-gcm',
	'aes-256-gcm',
	'chacha20-ietf-poly1305',
	'2022-blake3-aes-128-gcm',
	'2022-blake3-aes-256-gcm',
	'2022-blake3-chacha8-poly1305',
	'2022-blake3-chacha20-poly1305',
];

function ucival_to_bool(val) {
	return val === 'true' || val === '1' || val === 'yes' || val === 'on';
}

return L.Class.extend({
	values_actions: function(o) {
		o.value('bypass');
		o.value('forward');
		if (o.option !== 'dst_default') {
			o.value('checkdst');
		}
	},
	values_redir: function(o, xmode) {
		uci.sections('shadowsocks-rust', 'ss_redir', function(sdata) {
			var disabled = ucival_to_bool(sdata['disabled']),
				sname = sdata['.name'],
				mode = sdata['mode'] || 'tcp_only';
			if (!disabled && mode.indexOf(xmode) !== -1) {
				o.value(sname, sname + ' - ' + mode);
			}
		});
		o.value('', '<unset>');
		o.value('all', 'all');
		o.default = '';
	},
	values_serverlist: function(o) {
		uci.sections('shadowsocks-rust', 'server', function(sdata) {
			var sname = sdata['.name'],
				server = sdata['server'],
				server_port = sdata['server_port'];
			if (server && server_port) {
				var disabled = ucival_to_bool(sdata['disabled']) ? ' - disabled' : '',
					desc = '%s - %s:%s%s'.format(sname, server, server_port, disabled);
				o.value(sname, desc);
			}
		});
	},
	values_ipaddr: function(o, netDevs) {
		netDevs.forEach(function(v) {
			v.getIPAddrs().forEach(function(a) {
				var host = a.split('/')[0];
				o.value(host, '%s (%s)'.format(host, v.getShortName()));
			});
		});
	},
	options_client: function(s, tab, netDevs) {
		var o = s.taboption(tab, form.ListValue, 'server', _('Remote server'));
		this.values_serverlist(o);
		o = s.taboption(tab, form.Value, 'local_address', _('Local address'));
		o.datatype = 'ipaddr';
		o.placeholder = '0.0.0.0';
		this.values_ipaddr(o, netDevs);
		o = s.taboption(tab, form.Value, 'local_port', _('Local port'));
		o.datatype = 'port';
	},
	options_server: function(s, opts) {
		var o, optfunc,
			tab = opts && opts.tab || null;

		if (!tab) {
			optfunc = function(/* ... */) {
				var o = s.option.apply(s, arguments);
				o.editable = true;
				return o;
			};
		} else {
			optfunc = function(/* ... */) {
				var o = s.taboption.apply(s, L.varargs(arguments, 0, tab));
				o.editable = true;
				return o;
			};
		}

		o = optfunc(form.Value, 'label', _('Label'));

		o = optfunc(form.Value, 'server', _('Server'));
		o.datatype = 'host';
		o.size = 16;

		o = optfunc(form.Value, 'server_port', _('Server port'));
		o.datatype = 'port';
		o.size = 5;

		o = optfunc(form.ListValue, 'method', _('Method'));
		methods.forEach(function(m) {
			o.value(m);
		});
		o.default = '2022-blake3-aes-256-gcm';

		o = optfunc(form.Value, 'password', _('Password (Base64)'));
		o.password = true;
		o.size = 12;
		o.validate = function(section_id, value) {
			var opt = this.map.lookupOption('method', section_id),
				method = opt ? opt[0].formvalue(opt[1]) : uci.get('shadowsocks-rust', section_id, 'method');
			// 2022 ciphers take a Base64 key, the older ones a plain password
			if (value && method && method.indexOf('2022-') === 0 &&
			    !/^[A-Za-z0-9+\/]+={0,2}$/.test(value))
				return _('2022 ciphers need a Base64 encoded key');
			return true;
		};

		optfunc(form.Value, 'plugin', _('Plugin')).modalonly = true;

		optfunc(form.Value, 'plugin_opts', _('Plugin Options')).modalonly = true;
	},
	options_common: function(s, tab) {
		var o = s.taboption(tab, form.ListValue, 'mode', _('Mode of operation'));
		modes.forEach(function(m) {
			o.value(m);
		});
		o.default = 'tcp_and_udp';
		o = s.taboption(tab, form.Value, 'mtu', _('MTU'));
		o.datatype = 'uinteger';
		o = s.taboption(tab, form.Value, 'timeout', _('Timeout (sec)'));
		o.datatype = 'uinteger';
		o = s.taboption(tab, form.Value, 'keep_alive', _('Keep Alive (sec)'));
		o.datatype = 'uinteger';
		s.taboption(tab, form.Value, 'user', _('Run as'));

		s.taboption(tab, form.Flag, 'verbose', _('Verbose'));
		s.taboption(tab, form.Flag, 'ipv6_first', _('IPv6 First'), _('Prefer IPv6 addresses when resolving names'));
		s.taboption(tab, form.Flag, 'fast_open', _('Enable TCP Fast Open'));
		s.taboption(tab, form.Flag, 'no_delay', _('Enable TCP_NODELAY'));
		s.taboption(tab, form.Flag, 'reuse_port', _('Enable SO_REUSEPORT'));
		s.taboption(tab, form.Flag, 'mptcp', _('Enable MPTCP'));
	},
	ucival_to_bool: function(val) {
		return ucival_to_bool(val);
	},
	cfgvalue_overview: function(sdata) {
		var stype = sdata['.type'],
			lines = [];

		if (stype === 'ss_server') {
			this.cfgvalue_overview_(sdata, lines, names_options_server);
			this.cfgvalue_overview_(sdata, lines, names_options_common);
			this.cfgvalue_overview_(sdata, lines, ['bind_address']);
		} else if (stype === 'ss_local' || stype === 'ss_redir' || stype === 'ss_tunnel') {
			this.cfgvalue_overview_(sdata, lines, names_options_client);
			if (stype === 'ss_tunnel') {
				this.cfgvalue_overview_(sdata, lines, ['forward_address']);
				this.cfgvalue_overview_(sdata, lines, ['forward_port']);
			}
			this.cfgvalue_overview_(sdata, lines, names_options_common);
		} else {
			return [];
		}

		return lines;
	},
	cfgvalue_overview_: function(sdata, lines, names) {
		names.forEach(function(n) {
			var v = sdata[n];
			if (v) {
				if (n === 'password') {
					v = _('<hidden>');
				}
				var fv = E('var', [v]);
				if (sdata['.type'] !== 'ss_server' && n === 'server') {
					fv = E('a', {
						class: 'label',
						href: L.url('admin/proxy/shadowsocks-rust/servers') + '#edit=' + v,
						target: '_blank',
						rel: 'noopener'
					}, fv);
				}
				lines.push(n + ': ', fv, E('br'));
			}
		});
	},
	/*
	option_install_package: function(s, tab) {
		var bin = s.sectiontype.replace('_', '-'),
			opkg_package = 'shadowsocks-rust-' + bin, o;
		if (tab) {
			o = s.taboption(tab, form.Button, '_install');
		} else {
			o = s.option(form.Button, '_install');
		}
		o.title      = _('Package is not installed');
		o.inputtitle = _('Install package ' + opkg_package);
		o.inputstyle = 'apply';
		o.onclick = function() {
			window.open(L.url('admin/system/opkg') +
				'?query=' + opkg_package, '_blank', 'noopener');
		};
	},
	*/
	parse_uri: function(uri) {
		var scheme = 'ss://';
		if (!uri || uri.indexOf(scheme) !== 0)
			return null;

		var body = uri.slice(scheme.length), tag, config,
			hashPos = body.lastIndexOf('#');
		if (hashPos !== -1) {
			tag = body.slice(hashPos + 1);
			try { tag = decodeURIComponent(tag); } catch (e) {}
			body = body.slice(0, hashPos);
		}

		try {
			var atPos = body.lastIndexOf('@');
			if (atPos !== -1) { // SIP002 format https://shadowsocks.org/doc/sip002.html
				var userinfo = decodeURIComponent(body.slice(0, atPos)),
					hostport = body.slice(atPos + 1),
					query = '',
					qPos = hostport.indexOf('?');
				if (qPos !== -1) {
					query = hostport.slice(qPos + 1);
					hostport = hostport.slice(0, qPos);
				}
				hostport = hostport.replace(/\/$/, '');
				var hp = hostport.match(/^\[([0-9a-fA-F:.]+)\]:(\d+)$/) ||
					hostport.match(/^([^:\[\]]+):(\d+)$/);
				if (!hp) return null;

				// AEAD-2022 userinfo is percent-encoded, older ciphers
				// base64url-encode it (and base64 never contains ':')
				if (userinfo.indexOf(':') === -1)
					userinfo = atob(userinfo.replace(/-/g, '+').replace(/_/g, '/'));
				var i = userinfo.indexOf(':');
				if (i === -1) return null;

				config = {
					server: hp[1],
					server_port: hp[2],
					password: userinfo.slice(i + 1),
					method: userinfo.slice(0, i)
				};

				query.split('&').forEach(function(s) {
					var j = s.indexOf('=');
					if (j === -1 || s.slice(0, j) !== 'plugin') return;
					var v = decodeURIComponent(s.slice(j + 1)),
						k = v.indexOf(';');
					config['plugin'] = (k === -1) ? v : v.slice(0, k);
					if (k !== -1)
						config['plugin_opts'] = v.slice(k + 1);
				});
			} else { // Legacy format https://shadowsocks.org/doc/configs.html#uri-and-qr-code
				var plain = atob(body.replace(/-/g, '+').replace(/_/g, '/')),
					firstColonPos = plain.indexOf(':'),
					lastColonPos = plain.lastIndexOf(':'),
					atPos = plain.lastIndexOf('@', lastColonPos);
				if (firstColonPos === -1 ||
					lastColonPos === -1 ||
					atPos === -1) return null;

				config = {
					server: plain.slice(atPos + 1, lastColonPos).replace(/^\[(.*)\]$/, '$1'),
					server_port: plain.slice(lastColonPos + 1),
					password: plain.slice(firstColonPos + 1, atPos),
					method: plain.slice(0, firstColonPos)
				};
			}
		} catch (e) {
			// malformed base64 or percent-encoding
			return null;
		}
		// the Method list would show anything else as 'none' and save it
		if (methods.indexOf(config.method) === -1)
			return null;
		return [config, tag];
	}
});
