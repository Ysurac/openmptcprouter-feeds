'use strict';
'require view';
'require poll';
'require rpc';
'require ui';

var callMetrics = rpc.declare({
	object: 'mqvpn',
	method: 'metrics',
	expect: { '': {} }
});

var POLL_INTERVAL = 10;

return view.extend({
	load: function() {
		return callMetrics().catch(function() { return null; });
	},

	pollData: function(container) {
		poll.add(L.bind(function() {
			return callMetrics().then(L.bind(function(data) {
				this.renderAll(container, data);
			}, this)).catch(function() {
				/* Ignore transient poll errors -- keep showing the last good snapshot */
			});
		}, this), POLL_INTERVAL);
	},

	render: function(initialData) {
		var container = E('div', { 'id': 'mqvpn-metrics-container' }, [
			E('img', { 'src': L.resource('spinner.gif') })
		]);

		var page = E('div', {}, [
			E('h2', {}, [ _('MQVPN Metrics') ]),
			E('div', { 'class': 'cbi-map-descr' }, [
				_('Refreshes automatically ' +
				  'every %d seconds.').format(POLL_INTERVAL)
			]),
			container
		]);

		this.renderAll(container, initialData);
		this.pollData(container);

		return page;
	},

	/* ------------------------------------------------------------------ *
	 *  Helpers                                                             *
	 * ------------------------------------------------------------------ */

	_fmtBytes: function(val) {
		if (val === null || val === undefined) return '—';
		val = Number(val);
		if (val >= 1073741824) return (val / 1073741824).toFixed(2) + ' GB';
		if (val >= 1048576)    return (val / 1048576).toFixed(2) + ' MB';
		if (val >= 1024)       return (val / 1024).toFixed(1) + ' KB';
		return val + ' B';
	},

	_fmtDuration: function(sec) {
		if (sec === null || sec === undefined) return '—';
		sec = Number(sec);
		var d = Math.floor(sec / 86400); sec -= d * 86400;
		var h = Math.floor(sec / 3600);  sec -= h * 3600;
		var m = Math.floor(sec / 60);    sec -= m * 60;
		var out = [];
		if (d) out.push(d + 'd');
		if (h) out.push(h + 'h');
		if (m) out.push(m + 'm');
		if (!d && !h) out.push(Math.round(sec) + 's');
		return out.join(' ');
	},

	_kvTable: function(rows) {
		var table = E('table', { 'class': 'table' });
		rows.forEach(function(r) {
			if (r == null || r[1] === undefined || r[1] === null || r[1] === '') return;
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td', style: 'width:1%;white-space:nowrap;color:#666' }, [ r[0] ]),
				E('td', { 'class': 'td' }, [ r[1] ])
			]));
		});
		return table;
	},

	_badge: function(text, ok) {
		return E('span', { 'class': 'label ' + (ok ? 'success' : 'important') }, [ text ]);
	},

	/* ------------------------------------------------------------------ *
	 *  Sections                                                            *
	 * ------------------------------------------------------------------ */

	_renderStatus: function(d) {
		var rows = [];
		if (!d.enabled) {
			return E('div', { 'class': 'alert-message warning' }, [ _('MQVPN is disabled.') ]);
		}
		if (!d.reachable) {
			return E('div', { 'class': 'alert-message warning' }, [
				(d.error || _('Control API unreachable.')) + ' ',
				d.control && d.control.addr ?
					_('(endpoint: %s%s)').format(d.control.addr, d.control.port ? ':' + d.control.port : '') : ''
			]);
		}
		return E('div', { style: 'margin-bottom:10px' }, [
			this._badge(_('Reachable'), true), ' ',
			E('span', { style: 'color:#888;font-size:0.9em' }, [
				_('control API at %s:%s').format(d.control.addr, d.control.port)
			])
		]);
	},

	_renderBuildInfo: function(bi) {
		if (!bi || !bi.ok) return null;
		return E('div', {}, [
			E('h3', {}, [ _('Build info') ]),
			this._kvTable([
				[ _('Version'), bi.version ],
				[ _('Active scheduler'), bi.scheduler ],
				[ _('FEC support'), this._badge(bi.fec_enabled ? _('enabled') : _('not built'), !!bi.fec_enabled) ]
			])
		]);
	},

	_renderStats: function(st) {
		if (!st || !st.ok) return null;
		var self = this;
		var rows = [
			[ _('Clients connected'), String(st.n_clients) ],
			[ _('Uptime'), self._fmtDuration(st.uptime_sec) ],
			[ _('TUN bytes TX'), self._fmtBytes(st.bytes_tx) ],
			[ _('TUN bytes RX'), self._fmtBytes(st.bytes_rx) ],
			[ _('Datagrams sent'), st.dgram_sent ],
			[ _('Datagrams received'), st.dgram_recv ],
			[ _('Datagrams lost'), st.dgram_lost ],
			[ _('Datagrams acked'), st.dgram_acked ],
			[ _('UDP TX sends / datagrams'), st.udp_tx_sends + ' / ' + st.udp_tx_datagrams ],
			[ _('UDP RX receives / datagrams'), st.udp_rx_receives + ' / ' + st.udp_rx_datagrams ],
			[ _('Hybrid: TCP-lane packets'), st.pkts_lane_tcp ],
			[ _('Hybrid: datagram-lane packets'), st.pkts_lane_dgram ],
			[ _('Hybrid: raw-lane packets'), st.pkts_lane_raw ],
			[ _('Hybrid: TCP-lane packets dropped'), st.pkts_lane_tcp_dropped ],
			[ _('Hybrid: TCP flows active'), st.tcp_flows_active ],
			[ _('Hybrid: TCP flows opened (total)'), st.tcp_flows_total ],
			[ _('Hybrid: TCP flows rejected'), st.tcp_flows_rejected ],
			[ _('Hybrid: sticky-RAW markers active'), st.raw_markers_active ]
		];
		return E('div', {}, [
			E('h3', {}, [ _('Server / tunnel counters') ]),
			this._kvTable(rows)
		]);
	},

	_renderPaths: function(paths) {
		if (!paths) return null;
		if (!paths.ok) {
			/* Expected when mqvpn runs in server mode -- list_paths is client-only */
			return null;
		}
		return E('div', {}, [
			E('h3', {}, [ _('Configured local paths') ]),
			E('p', {}, [ (paths.paths || []).join(', ') || _('none') ])
		]);
	},

	_renderClientPaths: function(paths) {
		if (!paths || !paths.length) {
			return E('p', { 'class': 'cbi-value-description' }, [ _('No active paths.') ]);
		}
		var self = this;
		var table = E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, [ _('Path') ]),
				E('th', { 'class': 'th' }, [ _('State') ]),
				E('th', { 'class': 'th' }, [ _('sRTT') ]),
				E('th', { 'class': 'th' }, [ _('min RTT') ]),
				E('th', { 'class': 'th' }, [ _('cwnd') ]),
				E('th', { 'class': 'th' }, [ _('in flight') ]),
				E('th', { 'class': 'th' }, [ _('bytes TX/RX') ]),
				E('th', { 'class': 'th' }, [ _('pkts sent/recv/lost') ]),
				E('th', { 'class': 'th' }, [ _('reinject TX') ])
			])
		]);

		cbi_update_table(table, paths.map(function(p) {
			return [
				String(p.path_id),
				p.state_label || String(p.state),
				p.srtt_ms != null ? p.srtt_ms + ' ms' : '—',
				p.min_rtt_ms != null ? p.min_rtt_ms + ' ms' : '—',
				self._fmtBytes(p.cwnd),
				self._fmtBytes(p.in_flight),
				self._fmtBytes(p.bytes_tx) + ' / ' + self._fmtBytes(p.bytes_rx),
				(p.pkt_sent || 0) + ' / ' + (p.pkt_recv || 0) + ' / ' + (p.pkt_lost || 0),
				p.reinject_tx_bytes != null ? self._fmtBytes(p.reinject_tx_bytes) : '—'
			];
		}));

		return table;
	},

	_renderClients: function(status) {
		if (!status || !status.ok) return null;
		var self = this;
		var wrap = E('div', {}, [ E('h3', {}, [ _('Clients (%d)').format(status.n_clients || 0) ]) ]);
		if (!status.n_clients) {
			wrap.appendChild(E('p', { 'class': 'cbi-value-description' }, [ _('No active client sessions.') ]));
			return wrap;
		}
		(status.clients || []).forEach(function(c) {
			var paths = c.paths || [];
			var active = paths.filter(function(p) { return p.state_label === 'active'; }).length;
			wrap.appendChild(E('div', {
				style: 'border:1px solid #ddd;border-radius:6px;padding:10px 14px;margin-bottom:12px'
			}, [
				E('div', { style: 'display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px' }, [
					E('strong', {}, [ c.user || '(global)' ]),
					E('span', { style: 'color:#888;font-size:0.9em' }, [
						(c.endpoint || '') + ' — ' + _('connected') + ' ' + self._fmtDuration(c.connected_sec)
					])
				]),
				E('div', { style: 'color:#666;font-size:0.9em;margin:4px 0 8px' }, [
					_('TUN bytes TX/RX: %s / %s').format(self._fmtBytes(c.bytes_tx), self._fmtBytes(c.bytes_rx)) +
					'  •  ' + _('paths: %d active / %d total').format(active, paths.length)
				]),
				self._renderClientPaths(paths)
			]));
		});
		return wrap;
	},

	_renderFec: function(fec) {
		if (!fec) return null;
		var wrap = E('div', {}, [ E('h3', {}, [ _('FEC / multipath (per client)') ]) ]);
		if (!fec.ok) {
			wrap.appendChild(E('p', { 'class': 'cbi-value-description' }, [
				fec.error === 'fec not built' ?
					_('This mqvpn build does not include FEC support.') :
					(fec.error || _('No FEC data available.'))
			]));
			return wrap;
		}

		var self = this;
		var table = E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, [ _('User') ]),
				E('th', { 'class': 'th' }, [ _('FEC') ]),
				E('th', { 'class': 'th' }, [ _('Multipath state') ]),
				E('th', { 'class': 'th' }, [ _('FEC sent/recovered') ]),
				E('th', { 'class': 'th' }, [ _('Datagrams lost') ]),
				E('th', { 'class': 'th' }, [ _('App bytes (total/standby)') ])
			])
		]);

		cbi_update_table(table, (fec.clients || []).map(function(c) {
			return [
				c.user || '',
				self._badge(c.enable_fec ? _('on') : _('off'), !!c.enable_fec),
				c.mp_state_label || String(c.mp_state),
				(c.fec_send_cnt || 0) + ' / ' + (c.fec_recover_cnt || 0),
				String(c.lost_dgram_cnt || 0),
				self._fmtBytes(c.total_app_bytes) + ' / ' + self._fmtBytes(c.standby_app_bytes)
			];
		}), E('em', {}, [ _('No active sessions.') ]));

		wrap.appendChild(table);
		return wrap;
	},

	_renderReorder: function(reorder) {
		if (!reorder) return null;
		var ro = reorder.reorder;
		if (!ro) {
			// Live-observed: mqvpn's get_reorder_stats can return
			// {"ok":false,"error":"internal error"} while running in client
			// mode (confirmed on bench 192.168.100.1, mqvpn 0.16.0) --
			// surface that instead of silently hiding the whole section, so
			// it doesn't look like reorder buffering just has no data yet.
			return E('div', {}, [
				E('h3', {}, [ _('Reorder buffer counters') ]),
				E('p', { 'class': 'cbi-value-description' }, [
					_('Unavailable: %s').format(reorder.error || _('unknown error'))
				])
			]);
		}
		return E('div', {}, [
			E('h3', {}, [ _('Reorder buffer counters') ]),
			this._kvTable([
				[ _('Gaps seen / filled'), ro.gap_count + ' / ' + ro.gap_filled_count ],
				[ _('Gap timeouts'), ro.gap_timeout_count ],
				[ _('Gap overflow'), ro.gap_overflow_count ],
				[ _('Gap demotions'), ro.gap_demote_count ],
				[ _('Gap resets'), ro.gap_reset_count ],
				[ _('Ack demotions'), ro.ack_demote_count ],
				[ _('Dropped: too late'), ro.too_late_drop_count ],
				[ _('Dropped: too far ahead'), ro.too_far_ahead_drop_count ],
				[ _('Dropped: duplicate'), ro.duplicate_drop_count ],
				[ _('Dropped: pool exhausted'), ro.pool_drop_count ],
				[ _('Dropped: per-flow limit'), ro.per_flow_limit_drop_count ],
				[ _('Dropped: reset discard'), ro.reset_discard_count ],
				[ _('Delivered'), ro.delivered_count ],
				[ _('Added latency p99 / max'), ro.added_latency_p99_ms + ' ms / ' + ro.added_latency_max_ms + ' ms' ],
				[ _('Added latency buffered p99'), ro.added_latency_buffered_p99_ms + ' ms' ]
			])
		]);
	},

	renderAll: function(container, data) {
		if (!container) return;
		var d = data || {};

		container.textContent = '';
		container.appendChild(E('div', { style: 'color:#888;font-size:0.85em;margin-bottom:8px' },
			[ _('Last updated:') + ' ' + (new Date()).toLocaleTimeString() ]));

		container.appendChild(this._renderStatus(d));

		if (d.reachable) {
			[
				this._renderBuildInfo(d.build_info),
				this._renderStats(d.stats),
				this._renderPaths(d.paths),
				this._renderClients(d.status),
				this._renderFec(d.fec),
				this._renderReorder(d.reorder)
			].forEach(function(section) {
				if (section) container.appendChild(section);
			});
		}
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
