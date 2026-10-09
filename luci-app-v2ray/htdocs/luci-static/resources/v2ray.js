'use strict';
'require baseclass';
'require uci';
'require form';
'require fs';

var conf = 'v2ray';

/* uci.get() on a `list` option returns a bare string (not a 1-element
 * array) when the list currently holds exactly one value -- e.g. right
 * after a fresh install, main.inbounds == 'omr' rather than ['omr']. Every
 * reader of a list option has to normalize for that. */
function toArray(v) {
	return v == null ? [] : (Array.isArray(v) ? v : [v]);
}

/* The TLS pins of the running configuration by outbound tag, or null when
 * the service has written none. An empty pin field means the init script pins
 * the VPS certificate when it starts: the result is only in the generated
 * config, never in uci. */
function loadActivePins() {
	var dir = '/var/etc/' + conf;
	return L.resolveDefault(fs.list(dir), []).then(function(entries) {
		var files = entries.filter(function(e) { return /\.json$/.test(e.name); });
		if (!files.length)
			return null;
		return Promise.all(files.map(function(e) {
			return L.resolveDefault(fs.read(dir + '/' + e.name), '');
		})).then(function(contents) {
			var pins = {};
			contents.forEach(function(text) {
				var cfg;
				try { cfg = JSON.parse(text); } catch (e) { return; }
				toArray(cfg && cfg.outbounds).forEach(function(ob) {
					var tls = ob && ob.tag && ob.streamSettings && ob.streamSettings.tlsSettings;
					if (tls)
						pins[ob.tag] = {
							pin: toArray(tls.pinnedPeerCertSha256 || tls.pinnedPeerCertificateChainSha256).join(',').split(/\s*,\s*/).filter(Boolean).join(', '),
							insecure: !!tls.allowInsecure
						};
				});
			});
			return pins;
		});
	});
}

/*
 * Shared field builders for the luci-app-v2ray views. Keeps inbounds.js and
 * outbounds.js (which share ~80% of their fields: stream settings, TLS,
 * sockopt, ...) from duplicating the same option definitions twice.
 */
return L.Class.extend({
	conf: conf,
	toArray: toArray,

	/* -- generic "is this section referenced from config.main.<list>" toggle --
	 * v2ray only feeds an inbound/outbound/dns_server/policy_level/routing_rule/
	 * routing_balancer into the running config if its name is listed in the
	 * owning section's list option (main.inbounds, main.outbounds, main_dns.servers,
	 * main_policy.levels, main_routing.rules, main_routing.balancers). Rather than
	 * make the user hand-edit that list of names, expose it as a per-row toggle.
	 */
	addActiveFlag: function(s, ownerSection, listName, title, description, tab) {
		var o = tab
			? s.taboption(tab, form.Flag, '_active_' + listName, title || _('Active'),
				description || _('Included in %s of %s.%s').format(listName, conf, ownerSection))
			: s.option(form.Flag, '_active_' + listName, title || _('Active'),
				description || _('Included in %s of %s.%s').format(listName, conf, ownerSection));
		o.rmempty = false;
		o.editable = true;
		o.cfgvalue = function(section_id) {
			var list = toArray(uci.get(conf, ownerSection, listName));
			return (list.indexOf(section_id) !== -1) ? '1' : '0';
		};
		o.write = function(section_id, value) {
			var list = toArray(uci.get(conf, ownerSection, listName)).slice();
			var idx = list.indexOf(section_id);
			if (value === '1') {
				if (idx === -1) list.push(section_id);
			} else if (idx !== -1) {
				list.splice(idx, 1);
			}
			uci.set(conf, ownerSection, listName, list);
		};
		o.remove = function(section_id) {
			var list = toArray(uci.get(conf, ownerSection, listName)).slice();
			var idx = list.indexOf(section_id);
			if (idx !== -1) {
				list.splice(idx, 1);
				uci.set(conf, ownerSection, listName, list);
			}
		};
		return o;
	},

	/* stream transport + TLS + sockopt, shared by inbound & outbound sections.
	 * sockopt: 'tproxy' (inbound: redirect/tproxy/off) or 'mark' (outbound: uinteger)
	 */
	addStreamSettings: function(s, sockopt) {
		var o;

		o = s.taboption('transport', form.ListValue, 'ss_network', _('Transport (network)'));
		o.value('tcp', _('TCP'));
		o.value('kcp', _('mKCP'));
		o.value('ws', _('WebSocket'));
		o.value('http', _('HTTP/2'));
		o.value('domainsocket', _('Domain socket'));
		o.value('quic', _('QUIC'));
		o.default = 'tcp';

		/* tcp header */
		o = s.taboption('transport', form.ListValue, 'ss_tcp_header_type', _('TCP header obfuscation'));
		o.value('none', _('None'));
		o.value('http', _('HTTP')); o.depends('ss_network', 'tcp');
		o = s.taboption('transport', form.Value, 'ss_tcp_header_request_version', _('HTTP request version'));
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });
		o = s.taboption('transport', form.Value, 'ss_tcp_header_request_method', _('HTTP request method'));
		o.default = 'GET';
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });
		o = s.taboption('transport', form.Value, 'ss_tcp_header_request_path', _('HTTP request path'));
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });
		o = s.taboption('transport', form.DynamicList, 'ss_tcp_header_request_headers', _('HTTP request headers'));
		o.placeholder = 'Name=Value';
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });
		o = s.taboption('transport', form.Value, 'ss_tcp_header_response_version', _('HTTP response version'));
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });
		o = s.taboption('transport', form.Value, 'ss_tcp_header_response_status', _('HTTP response status'));
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });
		o = s.taboption('transport', form.Value, 'ss_tcp_header_response_reason', _('HTTP response reason'));
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });
		o = s.taboption('transport', form.DynamicList, 'ss_tcp_header_response_headers', _('HTTP response headers'));
		o.placeholder = 'Name=Value';
		o.depends({ ss_network: 'tcp', ss_tcp_header_type: 'http' });

		/* kcp */
		o = s.taboption('transport', form.Value, 'ss_kcp_mtu', _('mKCP MTU'));
		o.datatype = 'range(576,1460)'; o.placeholder = '1350'; o.depends('ss_network', 'kcp');
		o = s.taboption('transport', form.Value, 'ss_kcp_tti', _('mKCP TTI'));
		o.datatype = 'range(10,100)'; o.placeholder = '50'; o.depends('ss_network', 'kcp');
		o = s.taboption('transport', form.Value, 'ss_kcp_uplink_capacity', _('mKCP uplink capacity (MB/s)'));
		o.datatype = 'uinteger'; o.depends('ss_network', 'kcp');
		o = s.taboption('transport', form.Value, 'ss_kcp_downlink_capacity', _('mKCP downlink capacity (MB/s)'));
		o.datatype = 'uinteger'; o.depends('ss_network', 'kcp');
		o = s.taboption('transport', form.Flag, 'ss_kcp_congestion', _('mKCP congestion control'));
		o.depends('ss_network', 'kcp');
		o = s.taboption('transport', form.Value, 'ss_kcp_read_buffer_size', _('mKCP read buffer size (MB)'));
		o.datatype = 'uinteger'; o.depends('ss_network', 'kcp');
		o = s.taboption('transport', form.Value, 'ss_kcp_write_buffer_size', _('mKCP write buffer size (MB)'));
		o.datatype = 'uinteger'; o.depends('ss_network', 'kcp');
		o = s.taboption('transport', form.ListValue, 'ss_kcp_header_type', _('mKCP header obfuscation'));
		o.value('none', _('None'));
		o.value('srtp', 'SRTP'); o.value('utp', 'uTP'); o.value('wechat-video', _('WeChat video'));
		o.value('dtls', 'DTLS'); o.value('wireguard', 'WireGuard');
		o.depends('ss_network', 'kcp');

		/* websocket */
		o = s.taboption('transport', form.Value, 'ss_websocket_path', _('WebSocket path'));
		o.depends('ss_network', 'ws');
		o = s.taboption('transport', form.DynamicList, 'ss_websocket_headers', _('WebSocket headers'));
		o.placeholder = 'Name=Value'; o.depends('ss_network', 'ws');

		/* http/2 */
		o = s.taboption('transport', form.DynamicList, 'ss_http_host', _('HTTP/2 host(s)'));
		o.datatype = 'host'; o.depends('ss_network', 'http');
		o = s.taboption('transport', form.Value, 'ss_http_path', _('HTTP/2 path'));
		o.depends('ss_network', 'http');

		/* domain socket */
		o = s.taboption('transport', form.Value, 'ss_domainsocket_path', _('Domain socket path'));
		o.depends('ss_network', 'domainsocket');

		/* quic */
		o = s.taboption('transport', form.ListValue, 'ss_quic_security', _('QUIC encryption'));
		o.value('none', _('None')); o.value('aes-128-gcm', 'AES-128-GCM'); o.value('chacha20-poly1305', 'ChaCha20-Poly1305');
		o.depends('ss_network', 'quic');
		o = s.taboption('transport', form.Value, 'ss_quic_key', _('QUIC key'));
		o.password = true; o.depends('ss_network', 'quic');
		o = s.taboption('transport', form.ListValue, 'ss_quic_header_type', _('QUIC header obfuscation'));
		o.value('none', _('None'));
		o.value('srtp', 'SRTP'); o.value('utp', 'uTP'); o.value('wechat-video', _('WeChat video'));
		o.value('dtls', 'DTLS'); o.value('wireguard', 'WireGuard');
		o.depends('ss_network', 'quic');

		/* security / TLS */
		o = s.taboption('tls', form.ListValue, 'ss_security', _('Security'));
		o.value('none', _('None'));
		o.value('tls', 'TLS');
		o.default = 'none';

		o = s.taboption('tls', form.Value, 'ss_tls_server_name', _('TLS server name (SNI)'));
		o.datatype = 'host'; o.depends('ss_security', 'tls');
		o = s.taboption('tls', form.Value, 'ss_tls_alpn', _('TLS ALPN'));
		o.placeholder = 'h2,http/1.1'; o.depends('ss_security', 'tls');
		o = s.taboption('tls', form.Flag, 'ss_tls_allow_insecure', _('Allow insecure'));
		o.description = _('Skip certificate verification'); o.depends('ss_security', 'tls');
		o = s.taboption('tls', form.Flag, 'ss_tls_allow_insecure_ciphers', _('Allow insecure ciphers'));
		o.depends('ss_security', 'tls');
		o = s.taboption('tls', form.Flag, 'ss_tls_disable_system_root', _('Disable system root CAs'));
		o.depends('ss_security', 'tls');
		o = s.taboption('tls', form.ListValue, 'ss_tls_cert_usage', _('Certificate usage'));
		o.value('encipherment', _('Encipherment')); o.value('verify', _('Verify')); o.value('issue', _('Issue'));
		o.depends('ss_security', 'tls');
		o = s.taboption('tls', form.Value, 'ss_tls_cert_file', _('Certificate file'));
		o.depends('ss_security', 'tls');
		o = s.taboption('tls', form.Value, 'ss_tls_key_file', _('Certificate key file'));
		o.depends('ss_security', 'tls');
		if (sockopt === 'mark') {
			o = s.taboption('tls', form.Value, 'ss_tls_pinned_sha256', _('Pinned peer certificate SHA-256'));
			o.description = _('SHA-256 of the server certificate, in hex or base64; several are separated by commas. Accepted instead of the CA and name checks. Leave empty to auto-pin the VPS certificate when Allow insecure is set.');
			o.validate = function(section_id, value) {
				var pins = (value || '').split(/[\s,]+/).filter(function(p) { return p; });
				for (var i = 0; i < pins.length; i++)
					if (!/^[0-9a-fA-F]{64}$/.test(pins[i]) && !/^[A-Za-z0-9+\/]{43}=$/.test(pins[i]))
						return _('Expecting SHA-256 digests, 64 hex or 44 base64 characters each, separated by commas');
				return true;
			};
			o.placeholder = _('Automatic: VPS certificate');
			o.depends('ss_security', 'tls');

			o = s.taboption('tls', form.DummyValue, '_tls_pinned_active', _('Pinned certificate in use'));
			o.cfgvalue = function(section_id) {
				var tag = uci.get(conf, section_id, 'tag');
				return loadActivePins().then(function(pins) {
					if (pins == null)
						return _('%s is not running').format('V2Ray');
					var p = pins[tag];
					if (p && p.pin)
						return p.pin;
					return (p && p.insecure) ? _('None, any certificate is accepted') : _('None, the certificate is checked against the CA');
				});
			};
			o.depends('ss_security', 'tls');
		}

		/* sockopt */
		o = s.taboption('sockopt', form.ListValue, 'ss_sockopt_tcp_fast_open', _('TCP fast open'));
		o.value('', _('Default')); o.value('1', _('Enable')); o.value('0', _('Disable'));
		o = s.taboption('sockopt', form.ListValue, 'ss_sockopt_mptcp', _('MPTCP'));
		o.value('', _('Default')); o.value('1', _('Enable')); o.value('0', _('Disable'));
		if (sockopt === 'tproxy') {
			o = s.taboption('sockopt', form.ListValue, 'ss_sockopt_tproxy', _('TPROXY mode'));
			o.value('redirect', _('Redirect')); o.value('tproxy', 'TPROXY'); o.value('off', _('Off'));
			o.default = 'redirect';
		} else {
			o = s.taboption('sockopt', form.Value, 'ss_sockopt_mark', _('Firewall mark'));
			o.datatype = 'uinteger';
		}

		/* sniffing (inbound only in practice, harmless if present on outbound) */
		o = s.taboption('sockopt', form.Flag, 'sniffing_enabled', _('Sniffing'));
		o.description = _('Sniff the real destination (SNI/Host) out of the first packets, inbound only');
		o = s.taboption('sockopt', form.MultiValue, 'sniffing_dest_override', _('Sniffing destination override'));
		o.value('http', 'HTTP'); o.value('tls', 'TLS');
		o.depends('sniffing_enabled', '1');
		o = s.taboption('sockopt', form.ListValue, 'allocate_strategy', _('Port allocate strategy'));
		o.value('', _('Default')); o.value('always', _('Always')); o.value('random', _('Random'));
		o = s.taboption('sockopt', form.Value, 'allocate_refresh', _('Allocate refresh (minutes)'));
		o.datatype = 'uinteger'; o.depends('allocate_strategy', 'random');
		o = s.taboption('sockopt', form.Value, 'allocate_concurrency', _('Allocate concurrency'));
		o.datatype = 'uinteger'; o.depends('allocate_strategy', 'random');
	},

	/* per-protocol fields for an `inbound` section */
	addInboundProtocolFields: function(s) {
		var o;

		o = s.taboption('protocol', form.Value, 's_dokodemo_door_address', _('Address'));
		o.datatype = 'host'; o.depends('protocol', 'dokodemo-door');
		o = s.taboption('protocol', form.Value, 's_dokodemo_door_port', _('Port'));
		o.datatype = 'port'; o.depends('protocol', 'dokodemo-door');
		o = s.taboption('protocol', form.MultiValue, 's_dokodemo_door_network', _('Network'));
		o.value('tcp', 'TCP'); o.value('udp', 'UDP'); o.depends('protocol', 'dokodemo-door');
		o = s.taboption('protocol', form.Value, 's_dokodemo_door_timeout', _('Timeout'));
		o.datatype = 'uinteger'; o.depends('protocol', 'dokodemo-door');
		o = s.taboption('protocol', form.Flag, 's_dokodemo_door_follow_redirect', _('Follow redirect'));
		o.default = o.enabled; o.depends('protocol', 'dokodemo-door');
		o = s.taboption('protocol', form.Value, 's_dokodemo_door_user_level', _('User level'));
		o.datatype = 'uinteger'; o.depends('protocol', 'dokodemo-door');

		o = s.taboption('protocol', form.Value, 's_http_account_user', _('Username'));
		o.depends('protocol', 'http');
		o = s.taboption('protocol', form.Value, 's_http_account_pass', _('Password'));
		o.password = true; o.depends('protocol', 'http');
		o = s.taboption('protocol', form.Flag, 's_http_allow_transparent', _('Allow transparent'));
		o.depends('protocol', 'http');
		o = s.taboption('protocol', form.Value, 's_http_timeout', _('Timeout'));
		o.datatype = 'uinteger'; o.depends('protocol', 'http');
		o = s.taboption('protocol', form.Value, 's_http_user_level', _('User level'));
		o.datatype = 'uinteger'; o.depends('protocol', 'http');

		o = s.taboption('protocol', form.Value, 's_mtproto_user_email', _('User email'));
		o.depends('protocol', 'mtproto');
		o = s.taboption('protocol', form.Value, 's_mtproto_user_secret', _('User secret'));
		o.password = true; o.depends('protocol', 'mtproto');
		o = s.taboption('protocol', form.Value, 's_mtproto_user_level', _('User level'));
		o.datatype = 'uinteger'; o.depends('protocol', 'mtproto');

		o = s.taboption('protocol', form.Value, 's_shadowsocks_email', _('Email'));
		o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_method', _('Method'));
		o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_password', _('Password'));
		o.password = true; o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_level', _('Level'));
		o.datatype = 'uinteger'; o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Flag, 's_shadowsocks_ota', _('OTA'));
		o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.MultiValue, 's_shadowsocks_network', _('Network'));
		o.value('tcp', 'TCP'); o.value('udp', 'UDP'); o.default = 'tcp'; o.depends('protocol', 'shadowsocks');

		o = s.taboption('protocol', form.ListValue, 's_socks_auth', _('Auth'));
		o.value('noauth', _('No auth')); o.value('password', _('Password')); o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Value, 's_socks_account_user', _('Username'));
		o.depends({ protocol: 'socks', s_socks_auth: 'password' });
		o = s.taboption('protocol', form.Value, 's_socks_account_pass', _('Password'));
		o.password = true; o.depends({ protocol: 'socks', s_socks_auth: 'password' });
		o = s.taboption('protocol', form.Value, 's_socks_client_id', _('Client token'));
		o.description = _('Adds an extra accounts entry keyed on "Client email" below'); o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Value, 's_socks_client_email', _('Client email'));
		o.default = 'openmptcprouter'; o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Flag, 's_socks_udp', _('UDP'));
		o.default = o.enabled; o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Value, 's_socks_ip', _('IP'));
		o.datatype = 'host'; o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Value, 's_socks_user_level', _('User level'));
		o.datatype = 'uinteger'; o.depends('protocol', 'socks');

		['vmess', 'vless', 'trojan'].forEach(function(p) {
			o = s.taboption('protocol', form.Value, 's_' + p + '_client_id', p === 'trojan' ? _('Client password') : _('Client id (UUID)'));
			o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_client_alter_id', _('Client alter id'));
			o.datatype = 'range(0,65535)'; o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_client_email', _('Client email'));
			o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_client_user_level', _('Client user level'));
			o.datatype = 'uinteger'; o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_default_alter_id', _('Default alter id'));
			o.datatype = 'range(0,65535)'; o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_default_user_level', _('Default user level'));
			o.datatype = 'uinteger'; o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_detour_to', _('Detour to'));
			o.depends('protocol', p);
			o = s.taboption('protocol', form.Flag, 's_' + p + '_disable_insecure_encryption', _('Disable insecure encryption'));
			o.depends('protocol', p);
		});
	},

	/* per-protocol fields for an `outbound` section. */
	addOutboundProtocolFields: function(s) {
		var o;

		o = s.taboption('protocol', form.ListValue, 's_blackhole_reponse_type', _('Response type'));
		o.value('none', _('None')); o.value('http', 'HTTP'); o.depends('protocol', 'blackhole');

		o = s.taboption('protocol', form.ListValue, 's_dns_network', _('Network'));
		o.value('tcp', 'TCP'); o.value('udp', 'UDP'); o.depends('protocol', 'dns');
		o = s.taboption('protocol', form.Value, 's_dns_address', _('DNS server address'));
		o.depends('protocol', 'dns');
		o = s.taboption('protocol', form.Value, 's_dns_port', _('DNS server port'));
		o.datatype = 'port'; o.depends('protocol', 'dns');

		o = s.taboption('protocol', form.ListValue, 's_freedom_domain_strategy', _('Domain strategy'));
		o.value('AsIs', 'AsIs'); o.value('UseIP', 'UseIP'); o.value('UseIPv4', 'UseIPv4'); o.value('UseIPv6', 'UseIPv6');
		o.depends('protocol', 'freedom');
		o = s.taboption('protocol', form.Value, 's_freedom_redirect', _('Redirect to'));
		o.depends('protocol', 'freedom');
		o = s.taboption('protocol', form.Value, 's_freedom_user_level', _('User level'));
		o.datatype = 'uinteger'; o.depends('protocol', 'freedom');

		o = s.taboption('protocol', form.Value, 's_http_server_address', _('Server address'));
		o.datatype = 'host'; o.depends('protocol', 'http');
		o = s.taboption('protocol', form.Value, 's_http_server_port', _('Server port'));
		o.datatype = 'port'; o.depends('protocol', 'http');
		o = s.taboption('protocol', form.Value, 's_http_account_user', _('Username'));
		o.depends('protocol', 'http');
		o = s.taboption('protocol', form.Value, 's_http_account_pass', _('Password'));
		o.password = true; o.depends('protocol', 'http');

		o = s.taboption('protocol', form.Value, 's_shadowsocks_email', _('Email'));
		o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_address', _('Server address'));
		o.datatype = 'host'; o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_port', _('Server port'));
		o.datatype = 'port'; o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_method', _('Method'));
		o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_password', _('Password'));
		o.password = true; o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Value, 's_shadowsocks_level', _('Level'));
		o.datatype = 'uinteger'; o.depends('protocol', 'shadowsocks');
		o = s.taboption('protocol', form.Flag, 's_shadowsocks_ota', _('OTA'));
		o.depends('protocol', 'shadowsocks');

		o = s.taboption('protocol', form.Value, 's_socks_address', _('Server address'));
		o.datatype = 'host'; o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Value, 's_socks_port', _('Server port'));
		o.datatype = 'port'; o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Value, 's_socks_user_id', _('Password'));
		o.password = true; o.depends('protocol', 'socks');
		o = s.taboption('protocol', form.Value, 's_socks_email', _('User'));
		o.default = 'openmptcprouter'; o.depends('protocol', 'socks');

		['vmess', 'vless'].forEach(function(p) {
			o = s.taboption('protocol', form.Value, 's_' + p + '_address', _('Server address'));
			o.datatype = 'host'; o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_port', _('Server port'));
			o.datatype = 'port'; o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_user_id', _('User id (UUID)'));
			o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_user_alter_id', _('User alter id'));
			o.datatype = 'range(0,65535)'; o.depends('protocol', p);
			o = s.taboption('protocol', form.ListValue, 's_' + p + '_user_security', _('User security'));
			o.value('auto', _('Auto')); o.value('aes-128-gcm', 'AES-128-GCM'); o.value('chacha20-poly1305', 'ChaCha20-Poly1305'); o.value('none', _('None'));
			o.depends('protocol', p);
			o = s.taboption('protocol', form.Value, 's_' + p + '_user_level', _('User level'));
			o.datatype = 'uinteger'; o.depends('protocol', p);
		});
		o = s.taboption('protocol', form.ListValue, 's_vless_user_encryption', _('Encryption'));
		o.value('auto', _('Auto')); o.value('none', _('None')); o.depends('protocol', 'vless');

		o = s.taboption('protocol', form.Value, 's_trojan_address', _('Server address'));
		o.datatype = 'host'; o.depends('protocol', 'trojan');
		o = s.taboption('protocol', form.Value, 's_trojan_port', _('Server port'));
		o.datatype = 'port'; o.depends('protocol', 'trojan');
		o = s.taboption('protocol', form.Value, 's_trojan_user_id', _('Password'));
		o.password = true; o.depends('protocol', 'trojan');
	}
});
