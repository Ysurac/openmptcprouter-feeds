'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require ui';
'require poll';
'require dom';

/*
 * OpenMPTCProuter keepalived HA easy setup.
 *
 * Copyright 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org>
 * Licensed to the public under the GNU General Public License v3.
 */

const callStatus = rpc.declare({
	object: 'luci.keepalived-ha',
	method: 'status',
	expect: { }
});

const callApplyLocal = rpc.declare({
	object: 'luci.keepalived-ha',
	method: 'apply_local',
	expect: { }
});

const callPushPeer = rpc.declare({
	object: 'luci.keepalived-ha',
	method: 'push_peer',
	params: [ 'ip', 'username', 'password' ],
	expect: { }
});

const callCheckPeer = rpc.declare({
	object: 'luci.keepalived-ha',
	method: 'check_peer',
	params: [ 'ip', 'username', 'password' ],
	expect: { }
});

const callGenkey = rpc.declare({
	object: 'luci.keepalived-ha',
	method: 'genkey',
	expect: { }
});

/*
 * rpcd stages session-authenticated uci changes in a per-session savedir,
 * invisible to the root CLI used by the setup engine. The staged settings
 * must therefore be committed through this same session before apply_local
 * reads them.
 */
const callUciCommit = rpc.declare({
	object: 'uci',
	method: 'commit',
	params: [ 'config' ]
});

const callKeepalivedDump = rpc.declare({
	object: 'keepalived',
	method: 'dump',
	expect: { }
});

const VRRP_STATES = {
	0: 'INIT',
	1: 'BACKUP',
	2: 'MASTER',
	3: 'FAULT',
	4: 'STOP',
	98: 'DELETED'
};

function vrrpState(dump) {
	const list = (dump && Array.isArray(dump.status)) ? dump.status : [];

	for (const entry of list) {
		const data = entry ? entry.data : null;

		if (data && data.iname === 'OMR_HA')
			return VRRP_STATES[data.state] || String(data.state);
	}

	return null;
}

function statusRow(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'width': '33%' }, label),
		E('td', { 'class': 'td left' }, value)
	]);
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load() {
		return Promise.all([
			uci.load('keepalived'),
			callStatus().catch(() => ({})),
			callKeepalivedDump().catch(() => null)
		]);
	},

	renderStatus(st, dump) {
		const state = vrrpState(dump);
		const rows = [
			statusRow(_('Configured'), st.configured ? _('yes') : _('no')),
			statusRow(_('Role of this router'),
				st.role === 'primary' ? _('primary (preferred master)') :
				st.role === 'backup' ? _('backup') :
				_('unknown - none of the router IPs is assigned to this device')),
			statusRow(_('This router IP'), st.my_ip || '-'),
			statusRow(_('Virtual IP'), st.vip || '-'),
			statusRow(_('keepalived running'), st.running ? _('yes') : _('no')),
			statusRow(_('VRRP state'), state || _('n/a')),
			statusRow(_('Sync cron entry'), st.cron_installed ? _('installed') : _('not installed'))
		];

		for (const peer of (Array.isArray(st.peers) ? st.peers : [])) {
			let syncInfo = peer.last_sync_status || 'NA';

			if (peer.last_sync_time > 0)
				syncInfo += ' (%s)'.format(new Date(peer.last_sync_time * 1000).toLocaleString());

			rows.push(statusRow(_('Peer %s sync').format(peer.address), syncInfo));
		}

		if (st.pubkey)
			rows.push(statusRow(_('Sync public key'),
				E('code', { 'style': 'word-break:break-all' }, st.pubkey)));

		return E('table', { 'class': 'table' }, rows);
	},

	pollStatus() {
		return Promise.all([
			callStatus().catch(() => ({})),
			callKeepalivedDump().catch(() => null)
		]).then(([st, dump]) => {
			const container = document.getElementById('kaha-status');

			if (container)
				dom.content(container, this.renderStatus(st, dump));
		});
	},

	deployLog(node) {
		const log = document.getElementById('kaha-deploy-log');

		if (log)
			log.appendChild(E('div', {}, node));
	},

	handleDeploy(m, ev) {
		const user = document.getElementById('kaha-user').value || 'root';
		const pass = document.getElementById('kaha-pass').value || '';
		const log = document.getElementById('kaha-deploy-log');

		dom.content(log, E('div', {}, _('Saving settings…')));

		return m.save(null, true)
			.then(() => callUciCommit('keepalived'))
			.then(() => callApplyLocal())
			.then((res) => {
				if (!res.ok)
					throw new Error(res.error || _('local configuration failed'));

				this.deployLog(E('span', {}, [
					'✓ ',
					_('This router configured as %s (%s)').format(res.role, res.my_ip)
				]));

				const routers = L.toArray(uci.get('keepalived', 'ha', 'router'));
				const peers = routers.filter(r => r !== res.my_ip);

				if (!peers.length)
					return null;

				if (!pass)
					this.deployLog(E('em', {}, _('No password given, trying the peers with an empty password…')));

				return peers.reduce((chain, ip) => chain.then(() => {
					this.deployLog(E('span', {}, _('Configuring %s…').format(ip)));

					return callPushPeer(ip, user, pass).then((r) => {
						if (r.ok)
							this.deployLog(E('span', {}, '✓ ' + _('%s configured').format(ip)));
						else
							this.deployLog(E('span', { 'style': 'color:red' },
								'✗ ' + _('%s failed: %s').format(ip, r.error || '?')));
					}).catch((err) => {
						this.deployLog(E('span', { 'style': 'color:red' },
							'✗ ' + _('%s failed: %s').format(ip, err.message)));
					});
				}), Promise.resolve());
			})
			.then(() => {
				this.deployLog(E('strong', {}, _('Done.')));

				return this.pollStatus();
			})
			.catch((err) => {
				this.deployLog(E('span', { 'style': 'color:red' }, '✗ ' + err.message));
			});
	},

	handleTest(ev) {
		const user = document.getElementById('kaha-user').value || 'root';
		const pass = document.getElementById('kaha-pass').value || '';
		const log = document.getElementById('kaha-deploy-log');
		const routers = L.toArray(uci.get('keepalived', 'ha', 'router'));

		dom.content(log, E('div', {}, _('Testing peer connections…')));

		return callStatus().then((st) => {
			const peers = routers.filter(r => r !== st.my_ip);

			if (!peers.length) {
				this.deployLog(E('em', {}, _('No peers configured yet (save the router list first).')));
				return null;
			}

			return peers.reduce((chain, ip) => chain.then(() => {
				return callCheckPeer(ip, user, pass).then((r) => {
					if (r.ok)
						this.deployLog(E('span', {}, '✓ ' + _('%s reachable, app installed, current role: %s').format(ip, r.remote_role || '?')));
					else
						this.deployLog(E('span', { 'style': 'color:red' },
							'✗ ' + _('%s: %s').format(ip, r.error || '?')));
				}).catch((err) => {
					this.deployLog(E('span', { 'style': 'color:red' },
						'✗ ' + _('%s: %s').format(ip, err.message)));
				});
			}), Promise.resolve());
		});
	},

	handleGenkey(ev) {
		return callGenkey().then((res) => {
			if (res.ok)
				ui.addNotification(null, E('p', {}, _('Sync key generated: %s').format(res.pubkey)), 'info');
			else
				ui.addNotification(null, E('p', {}, _('Key generation failed: %s').format(res.error || '?')), 'error');

			return this.pollStatus();
		});
	},

	render([, st, dump]) {
		let m, s, o;

		if (uci.get('keepalived', 'ha') == null)
			uci.add('keepalived', 'ha', 'ha');

		m = new form.Map('keepalived');

		s = m.section(form.NamedSection, 'ha', 'ha', _('High Availability Setup'),
			_('Run two (or more) OpenMPTCProuter devices on the same LAN with a shared virtual IP. ' +
			  'List the LAN IP of every router in preferred-master order (first entry wins), set the ' +
			  'virtual IP the LAN clients use as gateway, then deploy. DHCP config and leases are ' +
			  'synchronized from the preferred master to the backups, dnsmasq only answers on the ' +
			  'current master, and each router must keep its own WAN and VPS configuration.') + '<br/>' +
			_('Requirement: luci-app-keepalived-ha must be installed on every router.'));

		o = s.option(form.Flag, 'enabled', _('Enable HA'),
			_('Disabling removes the generated keepalived and DHCP settings on deploy.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'vip', _('Virtual IP'),
			_('Shared LAN address the clients use as gateway and DNS. Must not be the address of any router. A prefix may be given, default is /24.'));
		o.datatype = 'ip4addr';
		o.rmempty = false;
		o.placeholder = '192.168.100.1';

		o = s.option(form.DynamicList, 'router', _('Router IPs'),
			_('Real LAN IP of every router, in order of preference: the first entry is the preferred master and the source of configuration sync. This router\'s LAN IP must be in the list.'));
		o.datatype = 'ip4addr("nomask")';
		o.rmempty = false;

		o = s.option(form.Value, 'interface', _('LAN interface'),
			_('Interface carrying the VRRP traffic and the virtual IP. A logical interface name like \'lan\' is resolved to the underlying device on each router (recommended for mixed hardware); a device name like \'br-lan\' or \'eth0\' is used as-is.'));
		o.placeholder = 'lan';

		o = s.option(form.Value, 'vrid', _('Virtual router ID'),
			_('Must be identical on all routers and unique on the LAN.'));
		o.datatype = 'range(1,255)';
		o.placeholder = '51';

		o = s.option(form.Value, 'advert_int', _('Advertisement interval (s)'),
			_('Failover takes roughly three times this interval.'));
		o.datatype = 'range(1,60)';
		o.placeholder = '1';

		o = s.option(form.Flag, 'track_omrvpn', _('Track VPN health'),
			_('Demote a router whose aggregation tunnel (omrvpn) is down so a healthy backup takes over even if the master is still powered.'));
		o.default = '1';

		o = s.option(form.Flag, 'track_proxy', _('Track proxy health'),
			_('Demote a router whose proxy (Shadowsocks, Shadowsocks-Rust, V2Ray or Xray) is not running or is reported down by omr-tracker.'));
		o.default = '1';

		o = s.option(form.Flag, 'track_wans', _('Track WAN health'),
			_('Demote a router by one rank when any multipath WAN has lost its address or is reported down by omr-tracker, so a router with all WANs healthy is preferred.'));
		o.default = '1';

		o = s.option(form.Flag, 'manage_dhcp', _('Advertise VIP via DHCP'),
			_('Set DHCP options 3 (gateway) and 6 (DNS) to the virtual IP on the lan pool.'));
		o.default = '1';

		return m.render().then((mapEl) => {
			const deploySection = E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Deploy')),
				E('div', { 'class': 'cbi-section-descr' },
					_('The credentials below are used once to configure the other routers through their LuCI RPC interface; they are never stored. The SSH key used by the config sync is generated and exchanged automatically.')),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('Peers LuCI username')),
					E('div', { 'class': 'cbi-value-field' },
						E('input', { 'id': 'kaha-user', 'type': 'text', 'class': 'cbi-input-text', 'value': 'root' }))
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, _('Peers LuCI password')),
					E('div', { 'class': 'cbi-value-field' },
						E('input', { 'id': 'kaha-pass', 'type': 'password', 'class': 'cbi-input-text' }))
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, ''),
					E('div', { 'class': 'cbi-value-field' }, [
						E('button', {
							'class': 'btn cbi-button cbi-button-apply',
							'click': ui.createHandlerFn(this, 'handleDeploy', m)
						}, _('Save & Deploy HA')),
						' ',
						E('button', {
							'class': 'btn cbi-button',
							'click': ui.createHandlerFn(this, 'handleTest')
						}, _('Test peer connections')),
						' ',
						E('button', {
							'class': 'btn cbi-button',
							'click': ui.createHandlerFn(this, 'handleGenkey')
						}, _('Generate sync key'))
					])
				]),
				E('div', { 'id': 'kaha-deploy-log', 'class': 'cbi-value', 'style': 'display:block' })
			]);

			const statusSection = E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Status')),
				E('div', { 'id': 'kaha-status' }, this.renderStatus(st || {}, dump))
			]);

			poll.add(L.bind(this.pollStatus, this), 5);

			return E('div', {}, [ statusSection, mapEl, deploySection ]);
		});
	}
});
