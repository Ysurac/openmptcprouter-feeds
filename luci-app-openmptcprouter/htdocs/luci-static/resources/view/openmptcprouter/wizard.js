'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require network';
'require fs';
'require ui';
'require dom';

var callFileExec = rpc.declare({
	object: 'file', method: 'exec',
	params: ['command', 'params'], expect: { stdout: '' }
});
var callFileStat = rpc.declare({
	object: 'file', method: 'stat',
	params: ['path'], expect: { '': {} }
});
var callOMRWizardAdd = rpc.declare({
	object: 'openmptcprouter', method: 'wizardadd',
	params: [
		'interfaces', 'servers',
		'delete_intfs', 'delete_servers',
		'add_interface', 'add_interface_ifname',
		'add_server_name',
		'disableipv6', 'ula',
		'default_vpn', 'default_proxy',
		'encryption',
		'shadowsocks_key', 'shadowsocks2022_key',
		'glorytun_key', 'dsvpn_key',
		'mqvpn_key', 'mqvpn_scheduler', 'mqvpn_port',
		'mlvpn_password', 'softethervpn_password', 'ubond_password',
		'v2ray_user', 'xray_user', 'xray_transport',
		'v2rayudp', 'forceretrieve',
		'mptcpovervpn_vpn', 'country', 'dns64',
		'vxlan', 'vxlan_mode', 'vxlan_bridge_if',
		'master'
	],
	expect: { '': {} }
});

function callOMRWizardAddCompat(payload) {
	return callOMRWizardAdd(
		payload.interfaces,
		payload.servers,
		payload.delete_intfs,
		payload.delete_servers,
		payload.add_interface,
		payload.add_interface_ifname,
		payload.add_server_name,
		payload.disableipv6,
		payload.ula,
		payload.default_vpn,
		payload.default_proxy,
		payload.encryption,
		payload.shadowsocks_key,
		payload.shadowsocks2022_key,
		payload.glorytun_key,
		payload.dsvpn_key,
		payload.mqvpn_key,
		payload.mqvpn_scheduler,
		payload.mqvpn_port,
		payload.mlvpn_password,
		payload.softethervpn_password,
		payload.ubond_password,
		payload.v2ray_user,
		payload.xray_user,
		payload.xray_transport,
		payload.v2rayudp,
		payload.forceretrieve,
		payload.mptcpovervpn_vpn,
		payload.country,
		payload.dns64,
		payload.vxlan,
		payload.vxlan_mode,
		payload.vxlan_bridge_if,
		payload.master
	).catch(function(err) {
		var msg = (err && (err.message || err.toString())) || '';
		if (msg.indexOf('Object not found') === -1)
			throw err;

		/* Fallback for session ACL/object lookup edge-cases: invoke ubus through file.exec */
		return callFileExec('/bin/ubus', [
			'call',
			'openmptcprouter',
			'wizardadd',
			JSON.stringify({
				interfaces: payload.interfaces,
				servers: payload.servers,
				delete_intfs: payload.delete_intfs,
				delete_servers: payload.delete_servers,
				add_interface: payload.add_interface,
				add_interface_ifname: payload.add_interface_ifname,
				add_server_name: payload.add_server_name,
				disableipv6: payload.disableipv6,
				ula: payload.ula,
				default_vpn: payload.default_vpn,
				default_proxy: payload.default_proxy,
				encryption: payload.encryption,
				shadowsocks_key: payload.shadowsocks_key,
				shadowsocks2022_key: payload.shadowsocks2022_key,
				glorytun_key: payload.glorytun_key,
				dsvpn_key: payload.dsvpn_key,
				mqvpn_key: payload.mqvpn_key,
				mqvpn_scheduler: payload.mqvpn_scheduler,
				mqvpn_port: payload.mqvpn_port,
				mlvpn_password: payload.mlvpn_password,
				softethervpn_password: payload.softethervpn_password,
				ubond_password: payload.ubond_password,
				v2ray_user: payload.v2ray_user,
				xray_user: payload.xray_user,
				xray_transport: payload.xray_transport,
				v2rayudp: payload.v2rayudp,
				forceretrieve: payload.forceretrieve,
				mptcpovervpn_vpn: payload.mptcpovervpn_vpn,
				country: payload.country,
				dns64: payload.dns64,
				vxlan: payload.vxlan,
				vxlan_mode: payload.vxlan_mode,
				vxlan_bridge_if: payload.vxlan_bridge_if,
				master: payload.master
			})
		]).then(function(res) {
			var out = (res && res.stdout) ? res.stdout.trim() : '';
			if (!out)
				return { status: 'ok' };
			try {
				return JSON.parse(out);
			} catch (e) {
				return { status: 'ok' };
			}
		});
	});
}

function fileExists(path) {
	return callFileStat(path).then(function(s) {
		return s && s.type === 'file';
	}).catch(function() { return false; });
}

function splitDeviceAndVlan(device) {
	var d = device || '';
	if (!d || d.indexOf('/') !== -1)
		return { ifname: d, vlan: '' };

	var idx = d.lastIndexOf('.');
	if (idx <= 0)
		return { ifname: d, vlan: '' };

	return {
		ifname: d.substring(0, idx),
		vlan: d.substring(idx + 1)
	};
}

function uniqueValues(list) {
	var seen = {};
	return L.toArray(list).filter(function(v) {
		var s = String(v == null ? '' : v).trim();
		if (!s || seen[s])
			return false;
		seen[s] = true;
		return true;
	});
}

var excludeRe = /^(lo|6in4-omr6in4|mlvpn0|ifb|sit|gre|ip6|teql|erspan|tun|bond|vxlan|omrvxlan)/;

function ensureWizardCSSLoaded() {
	if (document.getElementById('omr-wizard-css'))
		return;

	document.head.appendChild(E('link', {
		id: 'omr-wizard-css',
		rel: 'stylesheet',
		type: 'text/css',
		href: L.resource('openmptcprouter/css/wizard.css')
	}));
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('openmptcprouter'), uci.load('network'), uci.load('firewall'),
			uci.load('shadowsocks-libev').catch(function(){}),
			uci.load('shadowsocks-rust').catch(function(){}),
			uci.load('v2ray').catch(function(){}),
			uci.load('xray').catch(function(){}),
			uci.load('glorytun').catch(function(){}),
			uci.load('dsvpn').catch(function(){}),
			uci.load('mlvpn').catch(function(){}),
			uci.load('ubond').catch(function(){}),
			uci.load('softethervpn').catch(function(){}),
			uci.load('sqm').catch(function(){}),
			uci.load('qos').catch(function(){}),
			network.getNetworks(),
			network.getDevices(),
			fileExists('/etc/init.d/shadowsocks-libev'),
			fileExists('/etc/init.d/shadowsocks-rust'),
			fileExists('/etc/init.d/v2ray'),
			fileExists('/etc/init.d/xray'),
			fileExists('/usr/sbin/glorytun'),
			fileExists('/usr/sbin/glorytun-udp'),
			fileExists('/usr/sbin/dsvpn'),
			fileExists('/usr/sbin/mlvpn'),
			fileExists('/usr/sbin/ubond'),
			fileExists('/etc/init.d/openvpn'),
			fileExists('/etc/init.d/openvpnbonding'),
			fileExists('/etc/init.d/softethervpnclient'),
			fileExists('/usr/bin/wg'),
			callFileExec('/bin/sh', ['/usr/share/openmptcprouter/detect-pkg.sh', 'luci-app-sqm']),
			callFileExec('/bin/sh', ['/usr/share/openmptcprouter/detect-pkg.sh', 'luci-app-qos']),
			callFileExec('/bin/sh', ['-c', 'grep -q aes /proc/cpuinfo && echo -n 1 || echo -n 0']),
			callFileExec('/bin/sh', ['/usr/share/openmptcprouter/list-serial.sh', 'ttyUSB']),
			callFileExec('/bin/sh', ['/usr/share/openmptcprouter/list-serial.sh', 'cdc-wdm']),
			callFileExec('/bin/sh', ['-c', 'timeout 1 /usr/bin/mmcli -L 2>/dev/null || true']),
		uci.load('mqvpn').catch(function(){}),
		fileExists('/usr/sbin/mqvpn')
		]);
	},

	render: function(data) {
		var nets = data[14], devs = data[15];
		var has = {
			ssLibev: data[16], ssRust: data[17], v2ray: data[18], xray: data[19],
			glorytun: data[20], glorytunUdp: data[21], dsvpn: data[22],
			mlvpn: data[23], ubond: data[24], openvpn: data[25],
			openvpnBond: data[26], softether: data[27], wg: data[28],
			sqm: (data[29]||'').trim() === '1',
			qos: (data[30]||'').trim() === '1',
			aes: (data[31]||'').trim() === '1',
			mqvpn: data[36]
		};
		var ttyUSB = (data[32]||'').trim().split('\n').filter(Boolean);
		var ttyCdc = (data[33]||'').trim().split('\n').filter(Boolean);
		var ttyAll = ttyUSB.concat(ttyCdc);
		var alltty = [];
		(data[34]||'').split('\n').forEach(function(l) {
			var mt = l.match(/\/(\d+)\s/);
			if (mt) alltty.push('/sys/devices/modem' + mt[1]);
		});

		var physDevs = [];
		(devs || []).forEach(function(d) {
			var n = d.getName();
			if (n && !excludeRe.test(n)) {
				var skip = nets.some(function(net) {
					return uci.get('network', net.getName(), 'device') === n &&
						(uci.get('network', net.getName(), 'type') === 'macvlan' ||
						 uci.get('network', net.getName(), 'proto') === '6in4');
				});
				if (!skip) physDevs.push(n);
			}
		});

		var zoneLan = L.toArray(uci.get('firewall', 'zone_lan', 'network'));
		var zoneWan = L.toArray(uci.get('firewall', 'zone_wan', 'network'));

		/* Candidate interfaces the VXLAN tunnel can be bridged into (L2 mode):
		 * any configured network interface, not just the LAN zone's, minus
		 * the tunnel's own interfaces and interfaces bridging into those
		 * would break (loopback, the VPN tunnel, the VXLAN itself) */
		var vxlanBridgeExcludeRe = /^(loopback|omrvpn|omrvxlan|omrvxlanip)$/;
		var vxlanBridgeIfs = [];
		uci.sections('network', 'interface', function(sec) {
			var name = sec['.name'];
			if (name && !vxlanBridgeExcludeRe.test(name) && vxlanBridgeIfs.indexOf(name) === -1)
				vxlanBridgeIfs.push(name);
		});

		/* Snapshot existing interfaces/servers so deletions done in the form
		 * can be sent to the backend (nothing is staged via ubus uci anymore,
		 * see #4316). */
		var origIntfNames = [];
		zoneLan.concat(zoneWan).forEach(function(i) {
			if (uci.get('network', i) && origIntfNames.indexOf(i) === -1)
				origIntfNames.push(i);
		});
		var origServerNames = [];
		uci.sections('openmptcprouter', 'server', function(srv) {
			origServerNames.push(srv['.name']);
		});

		function buildWizardPayload() {
			var allIntfs = {};
			zoneLan.forEach(function(i) { allIntfs[i] = true; });
			zoneWan.forEach(function(i) { allIntfs[i] = true; });

			var interfaces = [];
			Object.keys(allIntfs).forEach(function(intf) {
				if (!uci.get('network', intf))
					return;

				var proto = uci.get('network', intf, 'proto') || 'static';
				var typeintf = uci.get('network', intf, 'type') || '';
				var device = uci.get('network', intf, 'device') || '';
				var dev = splitDeviceAndVlan(device);

				interfaces.push({
					name: intf,
					label: uci.get('network', intf, 'label') || '',
					proto: proto,
					type: typeintf,
					masterintf: uci.get('network', intf, 'masterintf') || '',
					ifname: dev.ifname,
					vlan: dev.vlan,
					device_ncm: proto === 'ncm' ? device : '',
					device_qmi: proto === 'qmi' ? device : '',
					device_modemmanager: proto === 'modemmanager' ? device : '',
					ipaddr: uci.get('network', intf, 'ipaddr') || '',
					ip6addr: uci.get('network', intf, 'ip6addr') || '',
					netmask: uci.get('network', intf, 'netmask') || '',
					gateway: uci.get('network', intf, 'gateway') || '',
					ip6gw: uci.get('network', intf, 'ip6gw') || '',
					ipv6: uci.get('openmptcprouter', intf, 'ipv6') ||
						(proto === 'dhcp' ? '0' : (uci.get('network', intf, 'ipv6') || '0')),
					apn: uci.get('network', intf, 'apn') || '',
					pincode: uci.get('network', intf, 'pincode') || '',
					delay: uci.get('network', intf, 'delay') || '',
					username: uci.get('network', intf, 'username') || '',
					password: uci.get('network', intf, 'password') || '',
					auth: uci.get('network', intf, 'auth') || '',
					mode: uci.get('network', intf, 'mode') || '',
					sqmenabled: uci.get('sqm', intf, 'enabled') || '0',
					sqmautorate: uci.get('sqm', intf, 'autorate') || '0',
					qosenabled: uci.get('qos', intf, 'enabled') || '0',
					multipath: uci.get('network', intf, 'multipath') || 'on',
					lan: zoneLan.indexOf(intf) !== -1 ? '1' : '0',
					ttl: uci.get('network', intf + '_dev', 'ttl') || '',
					downloadspeed: uci.get('network', intf, 'downloadspeed') || '0',
					uploadspeed: uci.get('network', intf, 'uploadspeed') || '0',
					testspeed: uci.get('openmptcprouter', intf, 'testspeed') || '0',
					multipathvpn: uci.get('openmptcprouter', intf, 'multipathvpn') || '0'
				});
			});

			var servers = [];
			var master = '';
			uci.sections('openmptcprouter', 'server', function(srv) {
				var sid = srv['.name'];
				if (!master && (uci.get('openmptcprouter', sid, 'master') === '1'))
					master = sid;

				servers.push({
					name: sid,
					ips: uniqueValues(uci.get('openmptcprouter', sid, 'ip')),
					password: uci.get('openmptcprouter', sid, 'password') || '',
					username: uci.get('openmptcprouter', sid, 'username') || 'openmptcprouter',
					disabled: uci.get('openmptcprouter', sid, 'disabled') || '0'
				});
			});

			if (!master && servers.length)
				master = servers[0].name;

			var delIntfs = origIntfNames.filter(function(n) {
				return !uci.get('network', n);
			});
			var delServers = origServerNames.filter(function(n) {
				return !uci.get('openmptcprouter', n);
			});

			return {
				interfaces: JSON.stringify(interfaces),
				servers: JSON.stringify(servers),
				delete_intfs: JSON.stringify(delIntfs),
				delete_servers: JSON.stringify(delServers),
				add_interface: '',
				add_interface_ifname: '',
				add_server_name: '',
				disableipv6: uci.get('openmptcprouter', 'settings', 'disable_ipv6') || '1',
				ula: uci.get('network', 'globals', 'ula_prefix') || '',
				default_vpn: uci.get('openmptcprouter', 'settings', 'vpn') || 'mqvpn',
				default_proxy: uci.get('openmptcprouter', 'settings', 'proxy') || '',
				encryption: uci.get('openmptcprouter', 'settings', 'encryption') || (has.aes ? 'aes-256-gcm' : 'chacha20-ietf-poly1305'),
				shadowsocks_key: uci.get('shadowsocks-libev', 'sss0', 'key') || '',
				shadowsocks2022_key: uci.get('shadowsocks-rust', 'sss0', 'password') || '',
				glorytun_key: uci.get('glorytun', 'vpn', 'key') || '',
				dsvpn_key: uci.get('dsvpn', 'vpn', 'key') || '',
				mqvpn_key: uci.get('mqvpn', 'auth', 'key') || '',
				mqvpn_scheduler: uci.get('mqvpn', 'multipath', 'scheduler') || '',
				mqvpn_port: uci.get('mqvpn', 'server', 'port') || '',
				mlvpn_password: uci.get('mlvpn', 'general', 'password') || '',
				softethervpn_password: uci.get('softethervpn', 'openmptcprouter', 'password') || '',
				ubond_password: uci.get('ubond', 'general', 'password') || '',
				v2ray_user: uci.get('v2ray', 'omrout', 's_vmess_user_id') || '',
				xray_user: uci.get('xray', 'omrout', 's_vmess_user_id') || '',
				xray_transport: uci.get('xray', 'omrout', 'ss_network') || 'tcp',
				v2rayudp: (uci.get('v2ray', 'main_transparent_proxy', 'redirect_udp') === '1' ||
					uci.get('xray', 'main_transparent_proxy', 'redirect_udp') === '1') ? '1' : '0',
				forceretrieve: uci.get('openmptcprouter', 'settings', 'forceretrieve') === '1' ? '1' : '',
				mptcpovervpn_vpn: uci.get('openmptcprouter', 'settings', 'mptcpovervpn') || 'wireguard',
				country: uci.get('openmptcprouter', 'settings', 'country') || 'world',
				dns64: uci.get('openmptcprouter', 'settings', 'dns64') || '0',
				vxlan: uci.get('openmptcprouter', 'settings', 'vxlan') || '0',
				vxlan_mode: uci.get('openmptcprouter', 'settings', 'vxlan_mode') || 'l3',
				vxlan_bridge_if: uci.get('openmptcprouter', 'settings', 'vxlan_bridge_if') || 'lan',
				master: master
			};
		}

		var srvCount = 0;
		uci.sections('openmptcprouter', 'server', function() { srvCount++; });
		if (srvCount === 0) uci.add('openmptcprouter', 'server', 'vps');

		var m, s, o;
		m = new form.Map('openmptcprouter');
		m.chain('network');
		m.chain('firewall');
		if (has.ssLibev) m.chain('shadowsocks-libev');
		if (has.ssRust || has.xray) m.chain('shadowsocks-rust');
		if (has.v2ray)   m.chain('v2ray');
		if (has.xray)    m.chain('xray');
		if (has.glorytun || has.glorytunUdp) m.chain('glorytun');
		if (has.dsvpn)   m.chain('dsvpn');
		if (has.mqvpn)   m.chain('mqvpn');
		if (has.mlvpn)   m.chain('mlvpn');
		if (has.ubond)   m.chain('ubond');
		if (has.softether) m.chain('softethervpn');
		if (has.sqm) m.chain('sqm');
		if (has.qos) m.chain('qos');

		/* Never push form changes into the rpcd uci staging area: everything
		 * is applied atomically by the openmptcprouter.wizardadd ubus method.
		 * Staged-but-never-committed deltas were left behind by the stock
		 * Map.save()/TypedSection.handleAdd()/handleRemove() flow; applying
		 * (or auto-merging) them later corrupted the config (#4316).
		 * This local-only save keeps the stock add/remove buttons working. */
		m.save = function(cb, silent) {
			this.checkDepends();
			return this.parse()
				.then(cb)
				.catch(function(e) {
					if (!silent)
						ui.addNotification(null, E('p', _('Save error: ') + (e.message || e.toString())), 'error');
					return Promise.reject(e);
				})
				.finally(L.bind(this.renderContents, this));
		};

		/* ── Step 1: Servers ───────────────────────────── */
		s = m.section(form.TypedSection, 'server', _('Server settings'));
		s.addremove = true;
		s.anonymous = false;
		s.addbtntitle = _('Add a new server');

		o = s.option(form.DynamicList, 'ip', _('Server IP or hostname'));
		o.rmempty = true;
		o.datatype = 'host';
		o.description = _('Server IP will be set for proxy and VPN');
		o.write = function(sid, val) {
			var ips = uniqueValues(val);
			uci.unset('openmptcprouter', sid, 'ip');
			if (ips.length)
				uci.set('openmptcprouter', sid, 'ip', ips);
		};

		o = s.option(form.Value, 'username', _('Server username'));
		o.rmempty = true;
		o.description = _('API username to retrieve personnalized settings from the server.');

		o = s.option(form.Value, 'password', _('Server key'));
		o.rmempty = true;
		o.description = _('Key to configure and retrieve others keys from Server.');

		o = s.option(form.Flag, 'master', _('Set server as master'));
		o.rmempty = true;
		o.description = _('Only one server can be master.');
		o.write = function(sid, val) {
			uci.sections('openmptcprouter', 'server', function(sec) {
				if (sec['.name'] !== sid)
					uci.set('openmptcprouter', sec['.name'], 'master', '0');
			});
			uci.set('openmptcprouter', sid, 'master', val);
		};

		o = s.option(form.Flag, 'disabled', _('Disable server'));
		o.rmempty = true;

		/* ── Step 2: Settings (tabbed) ─────────────────── */
		s = m.section(form.NamedSection, 'settings', 'main', _('Settings'));
		s.tab('general',  _('General'));
		s.tab('ipv6',     _('IPv6'));
		s.tab('proxy',    _('Proxy'));
		s.tab('vpn',      _('VPN'));
		s.tab('mptcpvpn', _('MPTCP over VPN'));
		s.tab('country',  _('Country'));

		// ── General ──
		o = s.taboption('general', form.Flag, '_show_adv', _('Show advanced settings'));
		o.description = _('Reveal proxy, VPN, IPv6 and country settings.');
		o.default = '0';
		o.cfgvalue = function() { return '0'; };
		o.write = function() {};
		o.remove = function() {};

		o = s.taboption('general', form.ListValue, 'encryption', _('Encryption'));
		o.value('none', _('None'));
		o.value('aes-256-gcm', 'AES-256-GCM');
		o.value('chacha20-ietf-poly1305', 'chacha20');
		o.value('other', _('other'));
		o.default = has.aes ? 'aes-256-gcm' : 'chacha20-ietf-poly1305';
		o.description = (has.aes
			? _('AES instruction set detected.')
			: _('No AES instruction set, you should use chacha20.')) +
			' ' + _('Used for Shadowsocks, V2Ray/XRay, Glorytun and OpenVPN.');
		o.depends('_show_adv', '1');
		/* retain must stay true: LuCI's CBIAbstractValue.parse() removes the
		 * uci value of ANY inactive (dependency-unmet) option unless
		 * retain=true, regardless of rmempty. Since this option only shows
		 * when "Show advanced settings" is checked, saving the wizard with
		 * advanced settings collapsed (the default state) wiped it on every
		 * save -- not just when the Settings tab was touched (#4350, same
		 * class as the 'vpn' option below). */
		o.retain = true;

		o = s.taboption('general', form.Flag, '_force_retrieve', _('Force retrieve settings'));
		o.rmempty = true;
		o.description = _('Force retrieve all keys from server.');
		o.depends('_show_adv', '1');
		o.cfgvalue = function() { return '0'; };
		o.write = function(sid, val) {
			if (val === '1') uci.set('openmptcprouter', 'settings', 'forceretrieve', '1');
		};
		o.remove = function() {};

		// ── IPv6 ──
		o = s.taboption('ipv6', form.ListValue, 'disable_ipv6', _('Enable IPv6'));
		o.rmempty = true;
		o.value('1', _('Disabled'));
		o.value('0', _('Enabled'));
		o.description = _('Disable if server doesn\'t provide IPv6.');
		o.depends('_show_adv', '1');
		o.retain = true; /* see encryption's comment above (#4350) */

		o = s.taboption('ipv6', form.Value, '_ula_prefix', _('IPv6 Prefix'));
		o.rmempty = true;
		o.description = _('Public IPv6 prefix only with one server.');
		o.depends('_show_adv', '1');
		o.cfgvalue = function() { return uci.get('network', 'globals', 'ula_prefix'); };
		o.write = function(sid, val) { uci.set('network', 'globals', 'ula_prefix', val); };
		o.remove = function() {};

		o = s.taboption('ipv6', form.Flag, 'dns64', _('Enable DNS64'));
		o.rmempty = true;
		o.description = _('Enable if host supports NAT64.');
		o.depends('_show_adv', '1');
		o.retain = true; /* see encryption's comment above (#4350) */

		// ── Proxy ──
		o = s.taboption('proxy', form.ListValue, 'proxy', _('Default Proxy'));
		/* rmempty must stay false here: LuCI's CBIValue.parse() calls remove()
		 * instead of write() whenever the selected formvalue equals o.default
		 * and rmempty (or optional) is true. Since o.default below is set to
		 * 'shadowsocks-rust', picking "Shadowsocks-Rust 2022" used to unset
		 * openmptcprouter.settings.proxy client-side instead of writing it;
		 * wizardadd() then saw an empty default_proxy and silently kept the
		 * previously saved proxy, so the selection appeared to revert after
		 * Save & Apply (#4348). 'None' is already an explicit value below,
		 * so this option never needs "unset" semantics.
		 *
		 * retain must also stay true: independently of rmempty, LuCI removes
		 * the uci value of any option whose depends() aren't met unless
		 * retain=true. Since this option only shows with advanced settings
		 * expanded, saving the wizard with them collapsed silently wiped the
		 * chosen proxy back to buildWizardPayload()'s '' fallback (#4350). */
		o.rmempty = false;
		o.retain = true;
		o.description = _('Proxy for TCP (and UDP for V2Ray/XRay).');
		o.depends('_show_adv', '1');
		var availProxy = L.toArray(uci.get('openmptcprouter', 'vps', 'available_proxy'));
		var proxyDefs = {
			'shadowsocks':        ['Shadowsocks',           has.ssLibev],
			'v2ray':              ['V2Ray VLESS',            has.v2ray],
			'v2ray-vmess':        ['V2Ray VMESS',            has.v2ray],
			'v2ray-trojan':       ['V2Ray TROJAN',           has.v2ray],
			'v2ray-socks':        ['V2Ray SOCKS',            has.v2ray],
			'xray':               ['XRay VLESS',             has.xray],
			'xray-vless-reality': ['XRay VLESS Reality',     has.xray],
			'xray-vmess':         ['XRay VMESS',             has.xray],
			'xray-trojan':        ['XRay Trojan',            has.xray],
			'xray-socks':         ['XRay Socks',             has.xray],
			'xray-shadowsocks':   ['XRay Shadowsocks 2022',  has.xray],
			'shadowsocks-rust':   ['Shadowsocks-Rust 2022',  has.ssRust]
		};
		Object.keys(proxyDefs).forEach(function(p) {
			var d = proxyDefs[p];
			var serverHas = !availProxy.length || availProxy.indexOf(p) !== -1 ||
			                (p === 'shadowsocks-rust' && availProxy.indexOf('shadowsocks-go') !== -1);
			if (d && d[1] && serverHas) o.value(p, d[0]);
		});
		o.value('none', _('None'));
		o.default = 'shadowsocks-rust';

		if (has.ssLibev) {
			o = s.taboption('proxy', form.Value, '_ss_key', _('ShadowSocks key'));
			o.rmempty = true;
			o.depends('_show_adv', '1');
			o.cfgvalue = function() { return uci.get('shadowsocks-libev', 'sss0', 'key'); };
			o.write = function(sid, val) { uci.set('shadowsocks-libev', 'sss0', 'key', val); };
			o.remove = function() {};
		}
		if (has.xray || has.ssRust) {
			o = s.taboption('proxy', form.Value, '_ss2022_key', _('ShadowSocks 2022 key'));
			o.rmempty = true;
			o.depends('_show_adv', '1');
			o.cfgvalue = function() { return uci.get('shadowsocks-rust', 'sss0', 'password'); };
			o.write = function(sid, val) { uci.set('shadowsocks-rust', 'sss0', 'password', val); };
			o.remove = function() {};
		}
		if (has.v2ray) {
			o = s.taboption('proxy', form.Value, '_v2ray_user', _('V2Ray user id'));
			o.rmempty = true;
			o.depends('_show_adv', '1');
			o.cfgvalue = function() { return uci.get('v2ray', 'omrout', 's_vmess_user_id'); };
			o.write = function(sid, val) { uci.set('v2ray', 'omrout', 's_vmess_user_id', val); };
			o.remove = function() {};
		}
		if (has.xray) {
			o = s.taboption('proxy', form.Value, '_xray_user', _('XRay user id'));
			o.rmempty = true;
			o.depends('_show_adv', '1');
			o.cfgvalue = function() { return uci.get('xray', 'omrout', 's_vmess_user_id'); };
			o.write = function(sid, val) { uci.set('xray', 'omrout', 's_vmess_user_id', val); };
			o.remove = function() {};
		}
		if (has.xray || has.v2ray) {
			o = s.taboption('proxy', form.Flag, '_v2ray_udp', _('V2Ray/XRay UDP'));
			o.rmempty = true;
			o.description = _('Use V2Ray/XRay for UDP too');
			o.depends('_show_adv', '1');
			o.cfgvalue = function() {
				return (uci.get('v2ray', 'main_transparent_proxy', 'redirect_udp') === '1' ||
						uci.get('xray', 'main_transparent_proxy', 'redirect_udp') === '1') ? '1' : '0';
			};
			o.write = function(sid, val) {
				if (has.v2ray) uci.set('v2ray', 'main_transparent_proxy', 'redirect_udp', val);
				if (has.xray)  uci.set('xray', 'main_transparent_proxy', 'redirect_udp', val);
			};
			o.remove = function() {};

			o = s.taboption('proxy', form.ListValue, '_xray_transport', _('XRay Transport'));
			o.rmempty = true;
			o.value('tcp', 'TCP');
			o.value('grpc', 'gRPC');
			o.value('xhttp', 'XHTTP');
			o.depends('_show_adv', '1');
			o.cfgvalue = function() { return uci.get('xray', 'omrout', 'ss_network') || 'tcp'; };
			o.write = function(sid, val) { uci.set('xray', 'omrout', 'ss_network', val); };
			o.remove = function() {};
		}

		// ── VPN ──
		var vpnKeyOpts = [
			[has.glorytun||has.glorytunUdp, '_glorytun_key', _('Glorytun key'),          'glorytun',      'vpn',              'key'],
			[has.dsvpn,                     '_dsvpn_key',    _('A Dead Simple VPN key'), 'dsvpn',         'vpn',              'key'],
			[has.mqvpn,                     '_mqvpn_key',    _('MQVPN key'),             'mqvpn',         'auth',             'key'],
			[has.mlvpn,                     '_mlvpn_pw',     _('MLVPN password'),        'mlvpn',         'general',          'password'],
			[has.ubond,                     '_ubond_pw',     _('UBOND password'),        'ubond',         'general',          'password'],
			[has.softether,                 '_softether_pw', _('SoftEther VPN password'),'softethervpn',  'openmptcprouter',  'password']
		];
		vpnKeyOpts.forEach(function(def) {
			if (!def[0]) return;
			o = s.taboption('vpn', form.Value, def[1], def[2]);
			o.rmempty = true;
			o.description = _('Key is retrieved from server API by default.');
			o.depends('_show_adv', '1');
			o.cfgvalue = function() { return uci.get(def[3], def[4], def[5]); };
			o.write = function(sid, val) { uci.set(def[3], def[4], def[5], val); };
			o.remove = function() {};
		});

		o = s.taboption('vpn', form.ListValue, 'vpn', _('Default VPN'));
		o.rmempty = true;
		o.description = _('VPN for ICMP (and UDP with Shadowsocks proxy).');
		o.depends('_show_adv', '1');
		/* retain=true is required here regardless of rmempty: LuCI's
		 * CBIAbstractValue.parse() unconditionally calls remove() on any
		 * option whose depends() are unmet, unless retain=true (checked
		 * before rmempty is ever consulted). This option only shows with
		 * "Show advanced settings" checked, so leaving that box unchecked
		 * (the default) and saving from ANY step -- e.g. adding/removing a
		 * WAN interface, which calls map.save() -- wiped
		 * openmptcprouter.settings.vpn client-side even though the user
		 * never touched the VPN tab. buildWizardPayload() then fell back to
		 * 'openvpn' and pushed that to the backend, silently replacing the
		 * configured VPN (e.g. mqvpn) on save. See GH #4350. */
		o.retain = true;
		var vpnDefs = {
			'glorytun_tcp':    ['Glorytun TCP',      has.glorytun],
			'glorytun_udp':    ['Glorytun UDP',      has.glorytunUdp],
			'dsvpn':           ['A Dead Simple VPN',  has.dsvpn],
			'mqvpn':           ['MQVPN',             has.mqvpn],
			'mlvpn':           ['MLVPN',             has.mlvpn],
			'ubond':           ['UBOND',             has.ubond],
			'openvpn':         ['OpenVPN TCP',       has.openvpn],
			'openvpn_bonding': ['OpenVPN Bonding',   has.openvpnBond],
			'softether':       ['SoftEther VPN',     has.softether]
		};
		var availVpn = L.toArray(uci.get('openmptcprouter', 'vps', 'available_vpn'));
		(availVpn.length ? availVpn : Object.keys(vpnDefs)).forEach(function(v) {
			var d = vpnDefs[v];
			if (d && d[1]) o.value(v, d[0]);
		});
		o.value('none', _('None'));

		if (has.mqvpn) {
			o = s.taboption('vpn', form.ListValue, '_mqvpn_scheduler', _('MQVPN scheduler'));
			o.depends({ '_show_adv': '1', 'vpn': 'mqvpn' });
			o.value('wlb',    _('Weighted Load Balancing'));
			o.value('minrtt', _('Minimum RTT'));
			o.default = 'wlb';
			o.cfgvalue = function() { return uci.get('mqvpn', 'multipath', 'scheduler') || 'wlb'; };
			o.write = function(sid, val) { uci.set('mqvpn', 'multipath', 'scheduler', val); };
			o.remove = function() {};

			o = s.taboption('vpn', form.Value, '_mqvpn_port', _('MQVPN port'));
			o.description = _('UDP port of the MQVPN server (e.g. 443 when other UDP ports are blocked). The server port is changed via the server API.');
			o.depends({ '_show_adv': '1', 'vpn': 'mqvpn' });
			o.datatype = 'port';
			o.placeholder = '65443';
			o.cfgvalue = function() { return uci.get('mqvpn', 'server', 'port') || ''; };
			o.write = function(sid, val) { uci.set('mqvpn', 'server', 'port', val); };
			o.remove = function() {};
		}

		o = s.taboption('vpn', form.Flag, 'vxlan', _('VXLAN'));
		o.rmempty = true;
		o.description = _('Set a VXLAN tunnel over the VPN, configured on the server via the API.');
		o.depends('_show_adv', '1');
		o.default = '0';
		o.retain = true; /* see 'vpn' option's comment above (#4350) */

		o = s.taboption('vpn', form.ListValue, 'vxlan_mode', _('VXLAN mode'));
		o.description = _('Layer 3: a routed point-to-point link over the tunnel. Layer 2: the tunnel is bridged into the LAN, extending its broadcast domain.');
		o.value('l3', _('Layer 3 (routed)'));
		o.value('l2', _('Layer 2 (bridged into LAN)'));
		o.default = 'l3';
		o.depends({ '_show_adv': '1', 'vxlan': '1' });
		o.retain = true; /* see 'vpn' option's comment above (#4350) */

		o = s.taboption('vpn', form.ListValue, 'vxlan_bridge_if', _('VXLAN bridge interface'));
		o.description = _('Interface the VXLAN tunnel is bridged into.');
		(vxlanBridgeIfs.length ? vxlanBridgeIfs : ['lan']).forEach(function(i) {
			var label = uci.get('network', i, 'label') || i;
			if (zoneWan.indexOf(i) !== -1) label += ' (' + _('WAN') + ')';
			else if (zoneLan.indexOf(i) !== -1) label += ' (' + _('LAN') + ')';
			o.value(i, label);
		});
		o.default = 'lan';
		o.depends({ '_show_adv': '1', 'vxlan': '1', 'vxlan_mode': 'l2' });
		o.retain = true; /* see 'vpn' option's comment above (#4350) */

		// ── MPTCP over VPN ──
		o = s.taboption('mptcpvpn', form.ListValue, 'mptcpovervpn', _('MPTCP over VPN'));
		o.description = _('Use when MPTCP is blocked by your ISP.');
		o.depends('_show_adv', '1');
		if (has.openvpn) o.value('openvpn', 'OpenVPN');
		if (has.wg)      o.value('wireguard', 'WireGuard');
		o.default = 'wireguard';
		o.retain = true; /* see 'vpn' option's comment above (#4350) */

		// ── Country ──
		o = s.taboption('country', form.ListValue, 'country', _('Country'));
		o.description = _('For China: accessible DNS and disable DNSSEC.');
		o.depends('_show_adv', '1');
		o.value('world', _('World'));
		o.value('china', _('China'));
		o.value('europe', _('Europe'));
		o.value('usa', _('USA'));
		o.value('custom', _('Custom'));
		o.default = 'world';
		o.retain = true; /* see 'vpn' option's comment above (#4350) */

		/* ── Step 3: LAN ───────────────────────────────── */
		s = m.section(form.TypedSection, 'interface', _('LAN interfaces'));
		s.uciconfig = 'network';
		s.addremove = false;
		s.anonymous = false;
		s.filter = function(sid) { return zoneLan.indexOf(sid) !== -1; };

		o = s.option(form.Value, 'label', _('Label'));
		o.rmempty = true;
		o.optional = true;

		o = s.option(form.ListValue, 'proto', _('Protocol'));
		o.rmempty = true;
		o.value('static', _('Static address'));
		o.value('dhcp', _('DHCP'));

		o = s.option(form.ListValue, 'device', _('Physical interface'));
		o.rmempty = true;
		physDevs.forEach(function(d) { o.value(d); });

		o = s.option(form.Value, 'ipaddr', _('IPv4 address'));
		o.rmempty = true;
		o.datatype = 'ip4addr';
		o.depends('proto', 'static');

		o = s.option(form.Value, 'netmask', _('IPv4 netmask'));
		o.datatype = 'ip4addr';
		o.default = '255.255.255.0';
		o.depends('proto', 'static');

		/* ── Step 4: WAN ───────────────────────────────── */
		s = m.section(form.TypedSection, 'interface', _('WAN interfaces'));
		s.uciconfig = 'network';
		s.addremove = true;
		s.anonymous = false;
		s.addbtntitle = _('Add an interface');
		s.filter = function(sid) { return zoneWan.indexOf(sid) !== -1; };

		s.handleAdd = function(ev, name) {
			if (!name) {
				var n = 1;
				while (uci.get('network', 'wan' + n)) n++;
				name = 'wan' + n;
			}
			uci.add('network', 'interface', name);
			uci.set('network', name, 'proto', 'static');
			uci.set('network', name, 'multipath', 'on');
			var w = L.toArray(uci.get('firewall', 'zone_wan', 'network'));
			w.push(name);
			uci.set('firewall', 'zone_wan', 'network', w);
			zoneWan.push(name);
			return this.map.save(null, true);
		};

		s.handleRemove = function(sid, ev) {
			var w = L.toArray(uci.get('firewall', 'zone_wan', 'network'));
			var i = w.indexOf(sid);
			if (i !== -1) { w.splice(i, 1); uci.set('firewall', 'zone_wan', 'network', w); }
			i = zoneWan.indexOf(sid);
			if (i !== -1) zoneWan.splice(i, 1);
			uci.remove('network', sid);
			return this.map.save(null, true);
		};

		o = s.option(form.Value, 'label', _('Label'));
		o.rmempty = true;
		o.optional = true;

		// Type
		o = s.option(form.ListValue, '_type', _('Type'));
		o.rmempty = true;
		o.value('normal', _('Normal'));
		o.value('macvlan', _('MacVLAN'));
		o.value('bridge', _('Bridge'));
		o.cfgvalue = function(sid) { return uci.get('network', sid, 'type') || 'normal'; };
		o.write = function(sid, val) {
			if (val === 'normal') uci.unset('network', sid, 'type');
			else uci.set('network', sid, 'type', val);
		};

		// MacVLAN master — type=macvlan
		o = s.option(form.ListValue, 'masterintf', _('MacVLAN master'));
		o.rmempty = true;
		physDevs.forEach(function(d) { o.value(d); });
		o.depends('_type', 'macvlan');

		// Protocol — type=normal|bridge
		o = s.option(form.ListValue, 'proto', _('Protocol'));
		o.value('static', _('Static address'));
		o.value('dhcp', _('DHCP'));
		o.value('dhcpv6', _('DHCPv6'));
		o.value('modemmanager', _('ModemManager'));
		o.value('ncm', _('NCM'));
		o.value('pppoe', _('PPPoE'));
		o.value('qmi', _('QMI'));
		o.value('other', _('Other'));
		o.default = 'static';
		o.depends('_type', 'normal');
		o.depends('_type', 'bridge');

		// Physical interface — proto=static|dhcp|dhcpv6
		o = s.option(form.ListValue, '_intf', _('Physical interface'));
		o.rmempty = true;
		physDevs.forEach(function(d) { o.value(d); });
		o.depends('proto', 'static');
		o.depends('proto', 'dhcp');
		o.depends('proto', 'dhcpv6');
		o.cfgvalue = function(sid) {
			var d = uci.get('network', sid, 'device') || '';
			return d.indexOf('/') !== -1 ? d : d.split('.')[0];
		};
		o.write = function(sid, val) {
			var vl = this.section.formvalue(sid, '_vlan') || '';
			uci.set('network', sid, 'device', vl ? val + '.' + vl : val);
		};

		o = s.option(form.Value, '_vlan', _('VLAN'));
		o.rmempty = true;
		o.optional = true;
		o.datatype = 'uinteger';
		o.placeholder = _('Optional');
		o.depends('proto', 'static');
		o.depends('proto', 'dhcp');
		o.depends('proto', 'dhcpv6');
		o.cfgvalue = function(sid) {
			var d = uci.get('network', sid, 'device') || '';
			return d.indexOf('/') !== -1 ? '' : (d.split('.')[1] || '');
		};
		o.write = function() {};

		// IPv4 — proto=static OR type=macvlan
		o = s.option(form.Value, 'ipaddr', _('IPv4 address'));
		o.rmempty = true;
		o.datatype = 'ip4addr';
		o.depends('proto', 'static');
		o.depends('_type', 'macvlan');

		o = s.option(form.Value, 'netmask', _('IPv4 netmask'));
		o.datatype = 'ip4addr';
		o.default = '255.255.255.0';
		o.depends('proto', 'static');
		o.depends('_type', 'macvlan');

		o = s.option(form.Value, 'gateway', _('IPv4 gateway'));
		o.rmempty = true;
		o.datatype = 'ip4addr';
		o.depends('proto', 'static');
		o.depends('_type', 'macvlan');

		// IPv6 — proto=static OR type=macvlan
		o = s.option(form.Value, 'ip6addr', _('IPv6 address'));
		o.rmempty = true;
		o.datatype = 'ip6addr';
		o.optional = true;
		o.depends('proto', 'static');
		o.depends('_type', 'macvlan');

		o = s.option(form.Value, 'ip6gw', _('IPv6 gateway'));
		o.rmempty = true;
		o.datatype = 'ip6addr';
		o.optional = true;
		o.depends('proto', 'static');
		o.depends('_type', 'macvlan');

		// IPv6 — proto=dhcp; the backend manages a companion "<intf>_6"
		// DHCPv6 interface on the same device (SLAAC needs odhcp6c, the
		// kernel ignores RAs on a router). Stored in openmptcprouter.<intf>
		// because /etc/init.d/openmptcprouter rewrites network.<intf>.ipv6
		// from the global IPv6 setting.
		o = s.option(form.ListValue, '_ipv6', _('IPv6'));
		o.value('0', _('Disabled'));
		o.value('1', _('Enabled (SLAAC/DHCPv6)'));
		o.default = '0';
		o.depends('proto', 'dhcp');
		o.description = _('Acquire an IPv6 address on this WAN via router advertisements or DHCPv6. IPv6 must also be enabled in the advanced settings.');
		o.cfgvalue = function(sid) { return uci.get('openmptcprouter', sid, 'ipv6') || '0'; };
		o.write = function(sid, val) { uci.set('openmptcprouter', sid, 'ipv6', val); };
		o.remove = function(sid) { uci.unset('openmptcprouter', sid, 'ipv6'); };

		// Device NCM — proto=ncm
		o = s.option(form.ListValue, '_device_ncm', _('Device'));
		o.rmempty = true;
		ttyAll.forEach(function(d) { o.value(d); });
		o.depends('proto', 'ncm');
		o.cfgvalue = function(sid) { return uci.get('network', sid, 'device'); };
		o.write = function(sid, val) { uci.set('network', sid, 'device', val); };

		// Device QMI — proto=qmi
		o = s.option(form.ListValue, '_device_qmi', _('Device'));
		o.rmempty = true;
		ttyCdc.forEach(function(d) { o.value(d); });
		o.depends('proto', 'qmi');
		o.cfgvalue = function(sid) { return uci.get('network', sid, 'device'); };
		o.write = function(sid, val) { uci.set('network', sid, 'device', val); };

		// Device ModemManager — proto=modemmanager
		o = s.option(form.ListValue, '_device_mm', _('Device'));
		o.rmempty = true;
		alltty.forEach(function(d) { o.value(d); });
		o.depends('proto', 'modemmanager');
		o.cfgvalue = function(sid) { return uci.get('network', sid, 'device'); };
		o.write = function(sid, val) { uci.set('network', sid, 'device', val); };

		// APN — proto=ncm|qmi|modemmanager only
		o = s.option(form.Value, 'apn', _('APN'));
		o.rmempty = true;
		o.depends('proto', 'ncm');
		o.depends('proto', 'qmi');
		o.depends('proto', 'modemmanager');

		// PIN code — proto=ncm|qmi|modemmanager only
		o = s.option(form.Value, 'pincode', _('PIN code'));
		o.rmempty = true;
		o.depends('proto', 'ncm');
		o.depends('proto', 'qmi');
		o.depends('proto', 'modemmanager');

		// Service type — proto=ncm only
		o = s.option(form.ListValue, 'mode', _('Service Type'));
		o.rmempty = true;
		o.value('', _('Modem default'));
		o.value('preferlte', _('Prefer LTE'));
		o.value('preferumts', _('Prefer UMTS'));
		o.value('lte', _('LTE'));
		o.value('umts', _('UMTS/GPRS'));
		o.value('gsm', _('GPRS only'));
		o.value('auto', _('auto'));
		o.depends('proto', 'ncm');

		// Authentication — proto=qmi|pppoe only
		o = s.option(form.ListValue, 'auth', _('Authentication Type'));
		o.value('none', _('NONE'));
		o.value('pap', _('PAP'));
		o.value('chap', _('CHAP'));
		o.value('both', _('PAP/CHAP'));
		o.default = 'none';
		o.depends('proto', 'qmi');
		o.depends('proto', 'pppoe');

		// PAP/CHAP — proto=ncm|qmi|pppoe only
		o = s.option(form.Value, 'username', _('PAP/CHAP username'));
		o.rmempty = true;
		o.depends('proto', 'ncm');
		o.depends('proto', 'qmi');
		o.depends('proto', 'pppoe');

		o = s.option(form.Value, 'password', _('PAP/CHAP password'));
		o.rmempty = true;
		o.password = true;
		o.depends('proto', 'ncm');
		o.depends('proto', 'qmi');
		o.depends('proto', 'pppoe');

		// Modem init timeout — proto=ncm|qmi only
		o = s.option(form.Value, 'delay', _('Modem init timeout'));
		o.rmempty = true;
		o.datatype = 'uinteger';
		o.optional = true;
		o.depends('proto', 'ncm');
		o.depends('proto', 'qmi');

		// ── Always visible WAN fields ──

		o = s.option(form.ListValue, 'multipath', _('Multipath TCP'));
		o.value('on', _('Enabled'));
		o.value('off', _('Disabled'));
		o.value('master', _('Master'));
		o.value('backup', _('Backup'));
		o.default = 'on';

		o = s.option(form.Value, '_ttl', _('Force TTL'));
		o.rmempty = true;
		o.datatype = 'uinteger';
		o.optional = true;
		o.description = _('65 often solves LTE tethering detection.');
		o.cfgvalue = function(sid) { return uci.get('network', sid + '_dev', 'ttl'); };
		o.write = function(sid, val) {
			if (val) uci.set('network', sid + '_dev', 'ttl', val);
			else uci.unset('network', sid + '_dev', 'ttl');
		};
		o.remove = function(sid) { uci.unset('network', sid + '_dev', 'ttl'); };

		o = s.option(form.Flag, '_multipathvpn', _('MPTCP over VPN'));
		o.rmempty = true;
		o.cfgvalue = function(sid) { return uci.get('openmptcprouter', sid, 'multipathvpn'); };
		o.write = function(sid, val) { uci.set('openmptcprouter', sid, 'multipathvpn', val); };
		o.remove = function(sid) { uci.set('openmptcprouter', sid, 'multipathvpn', '0'); };

		if (has.sqm) {
			o = s.option(form.Flag, '_sqm_enabled', _('Enable SQM'));
			o.default = '0';
			o.cfgvalue = function(sid) { return uci.get('sqm', sid, 'enabled') || '0'; };
			o.write = function(sid, val) { uci.set('sqm', sid, 'enabled', val); };
			o.remove = function(sid) { uci.set('sqm', sid, 'enabled', '0'); };
		}

		if (has.qos) {
			o = s.option(form.Flag, '_qos_enabled', _('Enable QoS'));
			o.rmempty = true;
			o.cfgvalue = function(sid) { return uci.get('qos', sid, 'enabled'); };
			o.write = function(sid, val) { uci.set('qos', sid, 'enabled', val); };
			o.remove = function(sid) { uci.set('qos', sid, 'enabled', '0'); };
		}

		o = s.option(form.Flag, '_testspeed', _('Calculate speed'));
		o.rmempty = true;
		o.description = _('Run an automatic speedtest.');
		o.cfgvalue = function(sid) { return uci.get('openmptcprouter', sid, 'testspeed'); };
		o.write = function(sid, val) { uci.set('openmptcprouter', sid, 'testspeed', val); };
		o.remove = function(sid) { uci.set('openmptcprouter', sid, 'testspeed', '0'); };

		o = s.option(form.Value, 'downloadspeed', _('Download speed (Kb/s)'));
		o.datatype = 'uinteger';
		o.default = '0';

		o = s.option(form.Value, 'uploadspeed', _('Upload speed (Kb/s)'));
		o.datatype = 'uinteger';
		o.default = '0';

		/* ═══════════════════════════════════════════════════
		 *  SAVE FLOW
		 *
		 *  The form is only parsed into the local (client-side) uci cache;
		 *  the full state is then sent to the openmptcprouter.wizardadd
		 *  ubus method which validates, writes and commits everything
		 *  atomically on the router. No change is ever staged through the
		 *  ubus uci add/set/delete methods, so no "unapplied changes"
		 *  are left behind after an apply (#4316).
		 * ═══════════════════════════════════════════════════ */
		this.map = m;

		function doSave() {
			if (document.querySelector('.cbi-input-invalid')) {
				ui.addNotification(null,
					E('p', _('Validation errors exist in the form. Please check all fields.')),
					'error');
				return Promise.reject(new Error(_('Validation errors exist in the form. Please check all fields.')));
			}

			m.checkDepends();
			return m.parse()
				.then(function() {
					return callOMRWizardAddCompat(buildWizardPayload());
				})
				.then(function(res) {
					var status = (res && res.status) ? res.status : 'ok';
					if (status !== 'ok' && status !== 'reload')
						throw new Error(_('API returned unexpected status: %s').format(status));
					ui.addNotification(null, E('p', _('Saved through openmptcprouter ubus API (%s). Reloading...').format(status)), 'info');
					setTimeout(function() { window.location.reload(); }, 3000);
				})
				.catch(function(e) {
					ui.addNotification(null,
						E('p', [
							_('Save error: '),
							E('em', {}, e.message || e.toString())
						]),
						'error');
					throw e;
				});
		}
		this._doSave = doSave;

		/* ═══════════════════════════════════════════════════
		 *  STEP WIZARD WRAPPER
		 *  Re-applied after every Map.renderContents() so the step UI
		 *  survives section add/remove re-renders.
		 * ═══════════════════════════════════════════════════ */
		var currentStep = 0;

		function decorateWizard(mapEl) {
			if (!mapEl || mapEl.querySelector('.omr-steps'))
				return;

			ensureWizardCSSLoaded();

			var sections = mapEl.querySelectorAll(':scope > .cbi-section');
			if (sections.length < 4)
				sections = mapEl.querySelectorAll('.cbi-section');

			var stepLabels = [_('Server'), _('Settings'), _('LAN'), _('WAN')];
			var panels = [], i;

			for (i = 0; i < Math.min(sections.length, 4); i++) {
				var panel = E('div', { 'class': 'omr-panel' });
				sections[i].parentNode.insertBefore(panel, sections[i]);
				panel.appendChild(sections[i]);
				panels.push(panel);
			}

			if (!panels.length)
				return;

			// Remove LuCI default page actions (using wizard's custom buttons instead)
			mapEl.querySelectorAll('.cbi-page-actions').forEach(function(el) {
				el.remove();
			});

			if (currentStep >= panels.length) currentStep = panels.length - 1;
			if (currentStep < 0) currentStep = 0;

			panels[currentStep].classList.add('active');

			// Step bar
			var stepsUl = E('ul', { 'class': 'omr-steps' });

			function goTo(idx) {
				if (idx < 0 || idx >= panels.length) return;
				for (var j = 0; j < idx; j++)
					stepsUl.children[j].classList.add('done');
				panels[currentStep].classList.remove('active');
				stepsUl.children[currentStep].classList.remove('active');
				currentStep = idx;
				panels[currentStep].classList.add('active');
				stepsUl.children[currentStep].classList.add('active');
				updateNav();
				window.scrollTo({ top: 0, behavior: 'smooth' });
			}

			stepLabels.forEach(function(label, idx) {
				stepsUl.appendChild(E('li', {
					'class': idx === currentStep ? 'active' : (idx < currentStep ? 'done' : ''),
					'click': function() { goTo(idx); }
				}, [
					E('span', { 'class': 'step-num' }, '' + (idx + 1)),
					E('span', { 'class': 'step-label' }, ' ' + label)
				]));
			});

			// Nav buttons
			var btnPrev = E('button', { 'type': 'button', 'class': 'cbi-button' }, '← ' + _('Previous'));
			var btnNext = E('button', { 'type': 'button', 'class': 'cbi-button cbi-button-apply' }, _('Next') + ' →');
			var btnSave = E('button', { 'type': 'button', 'class': 'cbi-button cbi-button-apply' }, _('Save & Apply'));

			btnPrev.addEventListener('click', function() { goTo(currentStep - 1); });
			btnNext.addEventListener('click', function() { goTo(currentStep + 1); });
			btnSave.addEventListener('click', function() {
				btnSave.disabled = true;
				doSave().catch(function() {}).finally(function() {
					btnSave.disabled = false;
				});
			});

			var navDiv = E('div', { 'class': 'cbi-page-actions omr-nav' }, [
				E('div', { 'style': 'display:flex;gap:.5em' }, [btnPrev, btnNext, btnSave])
			]);

			function updateNav() {
				btnPrev.style.display = currentStep === 0 ? 'none' : '';
				btnNext.style.display = currentStep === panels.length - 1 ? 'none' : '';
			}
			updateNav();

			// Assemble
			var wrapper = E('div', {}, [
				E('h2', {}, _('OpenMPTCProuter Wizard')),
				stepsUl
			]);

			panels.forEach(function(p) { wrapper.appendChild(p); });
			wrapper.appendChild(navDiv);

			// Remove ALL page action elements and buttons outside wrapper
			mapEl.querySelectorAll('.cbi-page-actions:not(.omr-nav), .cbi-section-actions').forEach(function(el) {
				el.remove();
			});
			mapEl.querySelectorAll('button').forEach(function(btn) {
				if (!wrapper.contains(btn)) {
					btn.remove();
				}
			});

			while (mapEl.firstChild) mapEl.removeChild(mapEl.firstChild);
			mapEl.appendChild(wrapper);

			// Remove LuCI default buttons that appear after render (with delay to ensure they're added)
			setTimeout(function() {
				document.querySelectorAll('.cbi-page-actions:not(.omr-nav), .cbi-section-actions').forEach(function(el) {
					el.remove();
				});
			}, 100);
		}

		var origRenderContents = m.renderContents;
		m.renderContents = function() {
			var self = this;
			return origRenderContents.apply(this, arguments).then(function(node) {
				decorateWizard(node || self.root);
				return node;
			});
		};

		return m.render();
	},

	handleSaveApply: function(ev) {
		return this.handleSave(ev);
	},

	handleSave: function(ev) {
		return this._doSave ? this._doSave() :
			Promise.reject(new Error('wizard is not initialized'));
	},

	handleReset: function(ev) {
		return this.map ? this.map.reset() : Promise.resolve();
	}
});
