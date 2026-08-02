'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require fs';
'require ui';

var callSettingsAdd = rpc.declare({
	object: 'openmptcprouter', method: 'settingsadd',
	params: [
		'redirect_ports',
		'tcp_keepalive_time', 'tcp_fin_timeout', 'tcp_syn_retries', 'tcp_fastopen',
		'tcp_retries1', 'tcp_retries2', 'ip_default_ttl',
		'disable_ipv6', 'disable_6in4', 'disable_modemmanager', 'banudpip',
		'externalcheck', 'openvpnlb', 'restricttolan', 'debug', 'savevnstat',
		'disablegwping', 'status_vps_timeout', 'status_getip_timeout', 'status_whois_timeout',
		'disableloopdetection', 'disableserverhttptest', 'disableintfrename',
		'disabledefaultgw', 'disabletracebox', 'disableserverping', 'disablemultipathtest',
		'shadowsocksudp', 'v2rayudp', 'ndpi', 'disablefastopen', 'enablenodelay',
		'obfs', 'obfs_plugin', 'obfs_type',
		'scaling_min_freq', 'scaling_max_freq', 'scaling_governor',
		'sfe_enabled', 'sfe_bridge', 'sipalg', 'vxlan', 'vxlan_mode'
	],
	expect: { '': {} }
});

var callUpdateVPS = rpc.declare({
	object: 'openmptcprouter', method: 'updateVPS',
	params: ['server'],
	expect: { '': {} }
});

return view.extend({
	load: function() {
		return Promise.all([
			Promise.all([
				L.resolveDefault(uci.load('openmptcprouter'), null),
				L.resolveDefault(uci.load('shadowsocks-libev'), null),
				L.resolveDefault(uci.load('v2ray'), null),
				L.resolveDefault(uci.load('xray'), null),
				L.resolveDefault(uci.load('firewall'), null),
			]),
			L.resolveDefault(fs.stat('/usr/bin/obfs-local'),    null),
			L.resolveDefault(fs.stat('/usr/bin/v2ray-plugin'),  null),
			L.resolveDefault(fs.read('/proc/sys/net/ipv4/tcp_keepalive_time'), ''),
			L.resolveDefault(fs.read('/proc/sys/net/ipv4/tcp_fin_timeout'),    ''),
			L.resolveDefault(fs.read('/proc/sys/net/ipv4/tcp_syn_retries'),    ''),
			L.resolveDefault(fs.read('/proc/sys/net/ipv4/tcp_retries1'),       ''),
			L.resolveDefault(fs.read('/proc/sys/net/ipv4/tcp_retries2'),       ''),
			L.resolveDefault(fs.read('/proc/sys/net/ipv4/tcp_fastopen'),       ''),
			L.resolveDefault(fs.read('/proc/sys/net/ipv4/ip_default_ttl'),     ''),
			L.resolveDefault(fs.read('/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq'),          ''),
			L.resolveDefault(fs.read('/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq'),          ''),
			L.resolveDefault(fs.read('/sys/devices/system/cpu/cpufreq/policy0/scaling_governor'),          ''),
			L.resolveDefault(fs.read('/sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors'),''),
			L.resolveDefault(fs.read('/proc/sys/kernel/osrelease'), ''),
		]).then(function(res) {
			var kern = (res[14] || '').trim();
			return Promise.all([
				res,
				kern ? L.resolveDefault(fs.stat('/lib/modules/' + kern + '/shortcut-fe.ko'), null)
				     : Promise.resolve(null)
			]);
		});
	},

	render: function(data) {
		var res     = data[0];
		var sfeStat = data[1];
		var m, s, o;
		var self = this;

		var hasObfs  = !!(res[1] && res[1].type);
		var hasV2ray = !!(res[2] && res[2].type);
		var sysctl = {
			tcp_keepalive_time: (res[3]  || '').trim(),
			tcp_fin_timeout:    (res[4]  || '').trim(),
			tcp_syn_retries:    (res[5]  || '').trim(),
			tcp_retries1:       (res[6]  || '').trim(),
			tcp_retries2:       (res[7]  || '').trim(),
			tcp_fastopen:       (res[8]  || '').trim(),
			ip_default_ttl:     (res[9]  || '').trim(),
		};
		var cpuMin      = (res[10] || '').trim();
		var cpuMax      = (res[11] || '').trim();
		var cpuGov      = (res[12] || '').trim();
		var cpuGovAvail = (res[13] || '').trim().split(/\s+/).filter(Boolean);
		var hasCpuFreq  = !!cpuMin;
		var hasSfe      = !!(sfeStat && sfeStat.type);

		this._hasObfs    = hasObfs || hasV2ray;
		this._hasCpuFreq = hasCpuFreq;
		this._hasSfe     = hasSfe;

		/* Values sourced from configs other than openmptcprouter */
		var v2rayCfg = uci.get('v2ray', 'main_transparent_proxy', 'redirect_udp')
		           || uci.get('xray',  'main_transparent_proxy', 'redirect_udp') || '0';
		var fwBanudp = uci.get('firewall', 'omr_dst_udp_banip_rule_v4', 'enabled') || '0';
		var ss0Obfs     = uci.get('shadowsocks-libev', 'sss0',         'obfs')        || '0';
		var ss0Plugin   = uci.get('shadowsocks-libev', 'sss0',         'obfs_plugin') || 'v2ray';
		var trkObfsType = uci.get('shadowsocks-libev', 'tracker_sss0', 'obfs_type')   || 'http';

		/* Determine if any server needs a VPS update */
		var latestVpsVer = uci.get('openmptcprouter', 'latest_versions', 'vps') || '';
		var updateServer = null;
		(uci.sections('openmptcprouter', 'server') || []).forEach(function(srv) {
			var ver = srv.omr_version || '';
			if (ver && latestVpsVer && ver !== latestVpsVer)
				updateServer = srv['.name'];
		});
		this._updateServer = updateServer;

		m = new form.Map('openmptcprouter', _('Advanced Settings'));
		this._map = m;

		/* ── Update VPS (conditional) ──────────────────────────────── */
		if (updateServer) {
			s = m.section(form.NamedSection, updateServer, 'server', _('Update server'));
			s.description = _('Update remotely to latest version and reboot. (Beta)');
			s.addremove   = false;

			o = s.option(form.Button, '_update_vps', _('Trigger update'));
			o.inputtitle = _('Update server');
			o.inputstyle = 'apply';
			o.onclick    = function(ev, section_id) {
				return callUpdateVPS(section_id).then(function() {
					ui.addNotification(null, _('Update started.'), 'info');
				});
			};
		}

		/* ── Server settings ───────────────────────────────────────── */
		s = m.section(form.TypedSection, 'server', _('Server settings'));
		s.anonymous  = false;
		s.addremove  = false;

		o = s.option(form.Flag, 'redirect_ports',
			_('Redirects all ports from server to this router'),
			_("You shouldn't do that and you should redirect only needed ports"));

		o = s.option(form.Flag, 'nofwredirect',
			_('Disable ports redirection defined in firewall from server to this router'));

		/* ── Tabbed settings section ───────────────────────────────── */
		s = m.section(form.NamedSection, 'settings', 'settings', _('Settings'));
		s.addremove = false;
		s.tab('network', _('Network'));
		s.tab('other',   _('Other'));
		if (hasObfs || hasV2ray) s.tab('obfs', _('Obfuscation'));
		if (hasSfe)              s.tab('sfe',  _('Qualcomm SFE'));
		if (hasCpuFreq)          s.tab('cpu',  _('System'));

		/* ── Network tab ───────────────────────────────────────────── */
		o = s.taboption('network', form.Value, 'tcp_keepalive_time',
			_('IPv4 TCP Keepalive time'),
			_('How often TCP sends out keepalive messages when keepalive is enabled.'));
		o.datatype = 'uinteger';
		o.cfgvalue = function() { return sysctl.tcp_keepalive_time; };

		o = s.taboption('network', form.Value, 'tcp_fin_timeout',
			_('IPv4 TCP FIN timeout'),
			_('The length of time an orphaned connection will remain in the FIN_WAIT_2 state before it is aborted at the local end.'));
		o.datatype = 'uinteger';
		o.cfgvalue = function() { return sysctl.tcp_fin_timeout; };

		o = s.taboption('network', form.Value, 'tcp_syn_retries',
			_('IPv4 TCP SYN retries'),
			_('Number of times initial SYNs for an active TCP connection attempt will be retransmitted.'));
		o.datatype = 'uinteger';
		o.cfgvalue = function() { return sysctl.tcp_syn_retries; };

		o = s.taboption('network', form.Value, 'tcp_retries1',
			_('IPv4 TCP retries1'),
			_('This value influences the time, after which TCP decides, that something is wrong due to unacknowledged RTO retransmissions, and reports this suspicion to the network layer.'));
		o.datatype = 'uinteger';
		o.cfgvalue = function() { return sysctl.tcp_retries1; };

		o = s.taboption('network', form.Value, 'tcp_retries2',
			_('IPv4 TCP retries2'),
			_('This value influences the timeout of an alive TCP connection, when RTO retransmissions remain unacknowledged.'));
		o.datatype = 'uinteger';
		o.cfgvalue = function() { return sysctl.tcp_retries2; };

		o = s.taboption('network', form.Value, 'tcp_fastopen', _('IPv4 TCP Fast Open'));
		o.datatype = 'uinteger';
		o.cfgvalue = function() { return sysctl.tcp_fastopen; };

		o = s.taboption('network', form.Value, 'ip_default_ttl', _('IPv4 IP default TTL'));
		o.datatype = 'uinteger';
		o.cfgvalue = function() { return sysctl.ip_default_ttl; };

		/* Inverted flags: enabled='0' means the feature is active when checked */
		o = s.taboption('network', form.Flag, 'disable_ipv6', _('Enable IPv6'));
		o.enabled = '0'; o.disabled = '1';

		o = s.taboption('network', form.Flag, 'disable_6in4', _('Disable 6in4'));

		o = s.taboption('network', form.Flag, 'external_check',
			_('Disable external check'),
			_('When enabled, checks are done on external sites to get each WAN IP and the IP used to go outside.'));
		o.enabled = '0'; o.disabled = '1';

		o = s.taboption('network', form.Flag, 'disable_fastopen',
			_('Disable TCP Fast Open'),
			_('Disable TCP Fast Open on Linux and Shadowsocks configuration'));

		o = s.taboption('network', form.Flag, 'enable_nodelay',
			_('Enable TCP Low Latency'),
			_('Optimize for latency instead of bandwidth'));

		o = s.taboption('network', form.Flag, 'sipalg', _('Enable SIP ALG'));

		o = s.taboption('network', form.Flag, 'vxlan',
			_('VXLAN'),
			_('Set a VXLAN tunnel over the VPN, configured on the server via the API.'));

		o = s.taboption('network', form.ListValue, 'vxlan_mode', _('VXLAN mode'),
			_('Layer 3: a routed point-to-point link over the tunnel. Layer 2: the tunnel is bridged into the LAN, extending its broadcast domain.'));
		o.value('l3', _('Layer 3 (routed)'));
		o.value('l2', _('Layer 2 (bridged into LAN)'));
		o.default = 'l3';
		o.depends('vxlan', '1');

		/* ── Other tab ─────────────────────────────────────────────── */
		o = s.taboption('other', form.Flag, 'vnstat_backup',
			_('Save vnstats stats'),
			_('Save vnstats statistics on disk'));

		o = s.taboption('other', form.Flag, 'disablegwping',
			_('Disable gateway ping'),
			_('Disable gateway ping check in status page'));

		o = s.taboption('other', form.Flag, 'disableserverhttptest',
			_('Disable server http test'),
			_('Disable HTTP test on Server API'));

		o = s.taboption('other', form.Value, 'status_vps_timeout',
			_('VPS checks timeout'),
			_('Timeout for VPS checks on status pages'));
		o.datatype = 'uinteger';

		o = s.taboption('other', form.Value, 'status_getip_timeout',
			_('WAN IPs retrieve timeout'),
			_('Timeout for retrieving WANs IP on status pages'));
		o.datatype = 'uinteger';

		o = s.taboption('other', form.Value, 'status_whois_timeout',
			_('Whois WAN IPs retrieve timeout'),
			_('Timeout for retrieving Whois WANs IP on status pages'));
		o.datatype = 'uinteger';

		o = s.taboption('other', form.Flag, 'disableintfrename',
			_('Disable interfaces auto rename'),
			_('Disable renaming interfaces'));

		o = s.taboption('other', form.Flag, 'disable_modemmanager',
			_('Disable ModemManager'));

		o = s.taboption('other', form.Flag, 'shadowsocksudp',
			_('Shadowsocks UDP'),
			_('When proxy shadowsocks is used, use it for UDP if VPN down'));

		o = s.taboption('other', form.Flag, 'v2rayudp',
			_('V2Ray/XRay UDP'),
			_('When proxy V2Ray/XRay VLESS, VMESS or Trojan is used, use it for UDP'));
		o.cfgvalue = function() { return v2rayCfg; };

		o = s.taboption('other', form.Flag, 'defaultgw',
			_('Disable default gateway'),
			_('Disable default gateway, no internet if VPS are down'));
		o.enabled = '0'; o.disabled = '1';

		o = s.taboption('other', form.Flag, 'disableserverping',
			_('Disable server ping'),
			_('Disable server ping status check'));

		o = s.taboption('other', form.Flag, 'restrict_to_lan',
			_('Restrict proxy to LAN zone'),
			_('Authorize access to proxy only from LAN firewall zone'));

		o = s.taboption('other', form.Flag, 'disableloopdetection',
			_('Disable route loop detection'),
			_('Disable route loop detection'));

		o = s.taboption('other', form.Flag, 'openvpn_lb',
			_('Disable OpenVPN multi clients'),
			_('Disable OpenVPN multi clients to distribute connections and use more CPU cores'));
		o.enabled = '0'; o.disabled = '1';

		o = s.taboption('other', form.Flag, 'tracebox',
			_('Disable tracebox test'),
			_('Disable multipath test using tracebox'));
		o.enabled = '0'; o.disabled = '1';

		o = s.taboption('other', form.Flag, 'disablemultipathtest',
			_('Disable multipath test'),
			_('Disable multipath test display in status page'));

		o = s.taboption('other', form.Flag, 'banudpip',
			_('Force TCP failback in compatible applications'),
			_('Force TCP failback in Zoom, Microsoft Teams and Google Net'));
		o.cfgvalue = function() { return fwBanudp; };

		o = s.taboption('other', form.Flag, 'debug',
			_('Debug'),
			_('Enable debug logs'));

		/* ── Obfuscation tab ───────────────────────────────────────── */
		if (hasObfs || hasV2ray) {
			o = s.taboption('obfs', form.Flag, 'obfs',
				_('Enable ShadowSocks Obfuscating'),
				_('Obfuscating will be enabled on both side'));
			o.cfgvalue = function() { return ss0Obfs; };

			o = s.taboption('obfs', form.ListValue, 'obfs_plugin', _('Obfuscating plugin'));
			o.cfgvalue = function() { return ss0Plugin; };
			if (hasV2ray) o.value('v2ray', 'v2ray');
			if (hasObfs)  o.value('obfs',  'simple-obfs');

			o = s.taboption('obfs', form.ListValue, 'obfs_type', _('Obfuscating type'));
			o.cfgvalue = function() { return trkObfsType; };
			o.value('http', 'http');
			o.value('tls',  'tls');
		}

		/* ── SFE tab ───────────────────────────────────────────────── */
		if (hasSfe) {
			o = s.taboption('sfe', form.Flag, 'sfe_enabled',
				_('Enable Fast Path offloading for connections'));

			o = s.taboption('sfe', form.Flag, 'sfe_bridge',
				_('Enable Bridge Acceleration'));
		}

		/* ── CPU frequency tab ─────────────────────────────────────── */
		if (hasCpuFreq) {
			o = s.taboption('cpu', form.Value, 'scaling_min_freq',
				_('Minimum scaling CPU frequency'));
			o.datatype = 'uinteger';
			o.cfgvalue = function() { return cpuMin; };

			o = s.taboption('cpu', form.Value, 'scaling_max_freq',
				_('Maximum scaling CPU frequency'));
			o.datatype = 'uinteger';
			o.cfgvalue = function() { return cpuMax; };

			o = s.taboption('cpu', form.ListValue, 'scaling_governor', _('Scaling governor'));
			o.cfgvalue = function() { return cpuGov; };
			cpuGovAvail.forEach(function(g) { o.value(g, g); });
		}

		return m.render();
	},

	handleSave: function() {
		var m    = this._map;
		var self = this;

		/* Collect form values into in-memory UCI, then read back */
		return m.parse().then(function() {
			var get = function(opt) {
				return uci.get('openmptcprouter', 'settings', opt) || '';
			};

			/* Build per-server redirect_ports JSON */
			var redirectPorts = {};
			(uci.sections('openmptcprouter', 'server') || []).forEach(function(srv) {
				var sname = srv['.name'];
				redirectPorts[sname] = {
					redirect_ports: uci.get('openmptcprouter', sname, 'redirect_ports') || '0',
					nofwredirect:   uci.get('openmptcprouter', sname, 'nofwredirect')   || '0'
				};
			});

			var hasObfs    = self._hasObfs;
			var hasCpuFreq = self._hasCpuFreq;
			var hasSfe     = self._hasSfe;

			/*
			 * Positional mapping to rpcd settingsadd params.
			 * UCI option name → rpcd param name where they differ:
			 *   external_check  → externalcheck
			 *   openvpn_lb      → openvpnlb
			 *   restrict_to_lan → restricttolan
			 *   vnstat_backup   → savevnstat
			 *   defaultgw       → disabledefaultgw
			 *   tracebox        → disabletracebox
			 *   disable_fastopen→ disablefastopen
			 *   enable_nodelay  → enablenodelay
			 */
			return callSettingsAdd(
				JSON.stringify(redirectPorts),
				get('tcp_keepalive_time'),
				get('tcp_fin_timeout'),
				get('tcp_syn_retries'),
				get('tcp_fastopen'),
				get('tcp_retries1'),
				get('tcp_retries2'),
				get('ip_default_ttl'),
				get('disable_ipv6'),
				get('disable_6in4'),
				get('disable_modemmanager'),
				get('banudpip'),
				get('external_check'),
				get('openvpn_lb'),
				get('restrict_to_lan'),
				get('debug'),
				get('vnstat_backup'),
				get('disablegwping'),
				get('status_vps_timeout'),
				get('status_getip_timeout'),
				get('status_whois_timeout'),
				get('disableloopdetection'),
				get('disableserverhttptest'),
				get('disableintfrename'),
				get('defaultgw'),
				get('tracebox'),
				get('disableserverping'),
				get('disablemultipathtest'),
				get('shadowsocksudp'),
				get('v2rayudp'),
				'1',
				get('disable_fastopen'),
				get('enable_nodelay'),
				hasObfs    ? get('obfs')              : '0',
				hasObfs    ? get('obfs_plugin')       : '',
				hasObfs    ? get('obfs_type')         : '',
				hasCpuFreq ? get('scaling_min_freq')  : '',
				hasCpuFreq ? get('scaling_max_freq')  : '',
				hasCpuFreq ? get('scaling_governor')  : '',
				hasSfe     ? get('sfe_enabled')       : '0',
				hasSfe     ? get('sfe_bridge')        : '0',
				get('sipalg'),
				get('vxlan'),
				get('vxlan_mode')
			).then(function() {
				ui.addNotification(null, _('Settings saved and applied successfully.'), 'info');
			}).catch(function(err) {
				ui.addNotification(null, _('Failed to save settings: ') + String(err), 'error');
			});
		});
	},

	handleSaveApply: null,
	handleReset:     null
});
