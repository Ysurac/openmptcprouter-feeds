'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

var callMetricsGetAll = rpc.declare({
	object: 'metrics',
	method: 'get_all',
	expect: { '': {} }
});

var callMetricsGetUserInfo = rpc.declare({
	object: 'metrics',
	method: 'get_user_info',
	expect: { '': {} }
});

var callMetricsGetForecast = rpc.declare({
	object: 'metrics',
	method: 'get_forecast',
	expect: { '': {} }
});

var callMetricsGetDecision = rpc.declare({
	object: 'metrics',
	method: 'get_decision',
	expect: { '': {} }
});

return view.extend({
	/* Auto-refresh interval in seconds */
	POLL_INTERVAL: 5,

	load: function() {
		return Promise.all([
			callMetricsGetAll(),
			callMetricsGetUserInfo(),
			callMetricsGetForecast(),
			callMetricsGetDecision()
		]);
	},

	/* ------------------------------------------------------------------ *
	 *  Helpers                                                             *
	 * ------------------------------------------------------------------ */

	_fmt: function(val, unit, decimals) {
		if (val === null || val === undefined) return '—';
		return (decimals != null ? Number(val).toFixed(decimals) : val) + (unit ? ' ' + unit : '');
	},

	_fmtBytes: function(val) {
		if (val === null || val === undefined) return '—';
		if (val >= 1073741824) return (val / 1073741824).toFixed(2) + ' GB';
		if (val >= 1048576)    return (val / 1048576).toFixed(2) + ' MB';
		if (val >= 1024)       return (val / 1024).toFixed(1) + ' KB';
		return val + ' B';
	},

	_fmtBps: function(val) {
		if (val === null || val === undefined) return '—';
		if (val >= 1e9) return (val / 1e9).toFixed(2) + ' Gbps';
		if (val >= 1e6) return (val / 1e6).toFixed(2) + ' Mbps';
		if (val >= 1e3) return (val / 1e3).toFixed(1) + ' Kbps';
		return val + ' bps';
	},

	_fmtBytesPerSec: function(val) {
		if (val === null || val === undefined) return '—';
		if (val >= 1073741824) return (val / 1073741824).toFixed(2) + ' GB/s';
		if (val >= 1048576)    return (val / 1048576).toFixed(2) + ' MB/s';
		if (val >= 1024)       return (val / 1024).toFixed(1) + ' KB/s';
		return val + ' B/s';
	},

	/* Render val as plain string; colour it if > 0 (orange warn, red error) */
	_warnVal: function(val, severity) {
		if (val === null || val === undefined) return '—';
		if (val > 0) {
			var color = (severity === 'error') ? '#f44336' : '#ff9800';
			return E('span', { style: 'color:' + color + ';font-weight:bold' }, [ String(val) ]);
		}
		return String(val);
	},

	_congestionBar: function(score, level) {
		if (score === null || score === undefined) return E('span', {}, ['—']);
		var colors = {
			'none':     '#4caf50',
			'low':      '#8bc34a',
			'moderate': '#ff9800',
			'high':     '#f44336',
			'severe':   '#b71c1c'
		};
		var labels = {
			'none':     _('None'),
			'low':      _('Low'),
			'moderate': _('Moderate'),
			'high':     _('High'),
			'severe':   _('Severe')
		};
		var color = colors[level] || '#aaa';
		var label = labels[level] || (level || '—');
		var w     = Math.max(0, Math.min(100, score));
		return E('span', { style: 'display:inline-flex;align-items:center;gap:6px' }, [
			E('span', {
				style: 'display:inline-block;width:80px;height:10px;background:#ddd;border-radius:5px;overflow:hidden'
			}, [
				E('span', {
					style: 'display:block;height:100%;width:' + w + '%;background:' + color +
					       ';border-radius:5px;transition:width 0.3s'
				})
			]),
			E('span', {
				style: 'display:inline-block;padding:1px 6px;border-radius:4px;background:' + color +
				       ';color:#fff;font-size:0.8em;font-weight:bold'
			}, [ label ]),
			E('span', { style: 'font-size:0.82em;color:#777' }, [ '(' + score + ')' ])
		]);
	},

	_statusBadge: function(status) {
		var color = '#aaa', label = status || '—';
		if (status === 'up')      { color = '#4caf50'; label = _('Up'); }
		else if (status === 'down') { color = '#f44336'; label = _('Down'); }
		var span = E('span', {
			style: 'display:inline-block;padding:2px 8px;border-radius:4px;' +
			       'background:' + color + ';color:#fff;font-size:0.85em;font-weight:bold'
		}, [ label ]);
		return span;
	},

	_signalBar: function(pct) {
		if (pct === null || pct === undefined) return E('span', {}, ['—']);
		var w = Math.max(0, Math.min(100, pct));
		return E('span', { style: 'display:inline-flex;align-items:center;gap:6px' }, [
			E('span', {
				style: 'display:inline-block;width:80px;height:10px;background:#ddd;border-radius:5px;overflow:hidden'
			}, [
				E('span', {
					style: 'display:block;height:100%;width:' + w + '%;' +
					       'background:' + (w > 60 ? '#4caf50' : w > 30 ? '#ff9800' : '#f44336') +
					       ';border-radius:5px;transition:width 0.3s'
				})
			]),
			E('span', { style: 'font-size:0.85em;color:#555' }, [ pct + '%' ])
		]);
	},

	/* Render a label with a hover tooltip (ⓘ icon using native title attribute) */
	_help: function(label, tip) {
		return E('span', { style: 'white-space:nowrap' }, [
			label, ' ',
			E('abbr', {
				title: tip,
				style: 'cursor:help;color:#888;font-size:0.8em;text-decoration:none;font-style:normal'
			}, [ 'ⓘ' ])
		]);
	},

	/* Build a two-column key/value table */
	_kvTable: function(rows) {
		var tbody = E('tbody');
		rows.forEach(function(r) {
			if (!r) return;
			tbody.appendChild(E('tr', {}, [
				E('td', { style: 'padding:3px 8px 3px 0;color:#666;white-space:nowrap;font-size:0.9em;width:1%' }, [ r[0] ]),
				E('td', { style: 'padding:3px 0;font-weight:500;max-width:0;overflow-wrap:anywhere' }, [ r[1] ])
			]));
		});
		return E('table', { style: 'border-collapse:collapse;width:100%' }, [ tbody ]);
	},

	/* ------------------------------------------------------------------ *
	 *  User info panel (VPS metrics DB stats)                             *
	 * ------------------------------------------------------------------ */

	_renderUserInfo: function(info) {
		if (!info || !info.username) return null;

		var fmtTs = function(ts) {
			if (ts == null) return '—';
			return new Date(ts * 1000).toLocaleString();
		};

		var rows = [
			[ _('Username'),    info.username ],
			[ _('VPS entries'), info.entry_count != null ? String(info.entry_count) : '—' ],
			[ _('First seen'),  fmtTs(info.first_seen) ],
			[ _('Last seen'),   fmtTs(info.last_seen) ],
			[ _('Interfaces'),  (info.interfaces || []).join(', ') || '—' ],
		];

		var tbody = E('tbody');
		rows.forEach(function(r) {
			tbody.appendChild(E('tr', {}, [
				E('td', { style: 'padding:3px 12px 3px 0;color:#666;white-space:nowrap;font-size:0.9em' }, [ r[0] ]),
				E('td', { style: 'padding:3px 0;font-weight:500;font-size:0.9em' }, [ r[1] ])
			]));
		});

		return E('div', {
			style: 'border:1px solid #c5d8f0;border-radius:6px;padding:10px 14px;' +
			       'margin-bottom:16px;background:#f0f6ff'
		}, [
			E('strong', { style: 'font-size:0.9em;color:#345' }, [ _('VPS Metrics — User Info') ]),
			E('table', { style: 'border-collapse:collapse;margin-top:6px' }, [ tbody ])
		]);
	},

	/* ------------------------------------------------------------------ *
	 *  Forecast section (per interface)                                    *
	 * ------------------------------------------------------------------ */

	_levelColor: function(level) {
		var m = { 'none': '#4caf50', 'low': '#8bc34a', 'moderate': '#ff9800',
		          'high': '#f44336', 'severe': '#b71c1c' };
		return m[level] || '#aaa';
	},

	_fmtEta: function(seconds) {
		if (seconds == null) return null;
		if (seconds === 0)   return _('now');
		if (seconds < 60)    return seconds + 's';
		return Math.round(seconds / 60) + 'min';
	},

	_renderForecastSection: function(fc) {
		if (!fc) return null;
		var self = this;

		var metrics = [
			{
				key: 'congestion', label: _('Congestion'),
				fmtVal: function(v) { return v != null ? v.toFixed(0) : '—'; }
			},
			{
				key: 'loss', label: _('Loss'),
				fmtVal: function(v) { return v != null ? v.toFixed(1) + '%' : '—'; }
			},
			{
				key: 'jitter', label: _('Jitter'),
				fmtVal: function(v) { return v != null ? v.toFixed(1) + ' ms' : '—'; }
			},
		];

		var trendInfo = {
			'rising':  { sym: '⬆', color: '#f44336' },
			'falling': { sym: '⬇', color: '#4caf50' },
			'stable':  { sym: '→', color: '#888' }
		};

		var confColors = { 'high': '#4caf50', 'medium': '#ff9800', 'low': '#f44336', 'none': '#999' };

		var tbody = E('tbody');

		tbody.appendChild(E('tr', {}, [
			E('td', { style: 'font-size:0.75em;color:#888;padding:0 8px 4px 0' }, [ _('Metric') ]),
			E('td', { style: 'font-size:0.75em;color:#888;padding:0 4px 4px;text-align:center' }, [ _('Now') ]),
			E('td'),
			E('td', { style: 'font-size:0.75em;color:#888;padding:0 4px 4px;text-align:center' }, [ _('5 min') ]),
			E('td', { style: 'font-size:0.75em;color:#888;padding:0 4px 4px' }, [ _('ETA') ]),
			E('td', { style: 'font-size:0.75em;color:#888;padding:0 0 4px 4px' }, [ _('Conf') ]),
		]));

		var hasData = false;
		metrics.forEach(function(m) {
			var d = fc[m.key];
			if (!d) return;
			hasData = true;

			var curColor  = self._levelColor(d.current_level);
			var predColor = self._levelColor(d.predicted_level);
			var ti        = trendInfo[d.trend] || trendInfo['stable'];
			var confColor = confColors[d.confidence] || '#999';

			var eta = self._fmtEta(d.eta_severe_s) ||
			          self._fmtEta(d.eta_high_s)   ||
			          self._fmtEta(d.eta_moderate_s);

			tbody.appendChild(E('tr', {}, [
				E('td', { style: 'padding:3px 8px 3px 0;color:#555;white-space:nowrap;font-size:0.85em' }, [ m.label ]),
				E('td', { style: 'padding:3px 4px;white-space:nowrap' }, [
					E('span', {
						style: 'padding:1px 5px;border-radius:3px;background:' + curColor +
						       ';color:#fff;font-size:0.8em;font-weight:bold'
					}, [ m.fmtVal(d.current) ])
				]),
				E('td', { style: 'padding:3px 2px;color:' + ti.color + ';text-align:center' }, [ ti.sym ]),
				E('td', { style: 'padding:3px 4px;white-space:nowrap' }, [
					E('span', {
						style: 'padding:1px 5px;border-radius:3px;background:' + predColor +
						       ';color:#fff;font-size:0.8em;font-weight:bold'
					}, [ m.fmtVal(d.predicted) ])
				]),
				E('td', { style: 'padding:3px 4px;font-size:0.8em;color:#888;white-space:nowrap' }, [ eta || '—' ]),
				E('td', { style: 'padding:3px 0 3px 4px' }, [
					E('span', {
						style: 'padding:1px 4px;border-radius:3px;border:1px solid ' + confColor +
						       ';color:' + confColor + ';font-size:0.75em'
					}, [ d.confidence || '—' ])
				])
			]));
		});

		if (!hasData) return null;

		return E('div', { style: 'display:inline-block;padding:8px 12px;background:#f9f9f9;border-radius:4px' }, [
			E('h4', { style: 'margin:0 0 4px;font-size:0.95em;color:#333' }, [ _('Forecast') ]),
			E('table', { style: 'border-collapse:collapse' }, [ tbody ])
		]);
	},

	/* ------------------------------------------------------------------ *
	 *  Decision section (model-assigned routing weights)                  *
	 * ------------------------------------------------------------------ */

	_renderDecisionSection: function(decision, ifaceName) {
		var self = this;
		if (!decision || !decision.weights) return null;
		var w = decision.weights[ifaceName];
		var s = decision.scores ? decision.scores[ifaceName] : null;
		if (w == null && s == null) return null;

		var totalW = 0;
		Object.keys(decision.weights).forEach(function(k) {
			totalW += (decision.weights[k] || 0);
		});
		var share = (totalW > 0 && w != null) ? Math.round(w / totalW * 100) : null;

		var rows = [];
		if (w != null)
			rows.push([ self._help(_('Weight'), _('Routing weight assigned by the decision model — higher means this interface is preferred')),
				E('span', {}, [ String(w) + (share != null ? '  (' + share + '%)' : '') ]) ]);
		if (s != null)
			rows.push([ self._help(_('Score'), _('Model quality score (0–100) — higher means this interface is preferred')),
				self._signalBar(Math.round(s)) ]);

		return E('div', { style: 'display:inline-block;padding:8px 12px;background:#f9f9f9;border-radius:4px' }, [
			E('h4', { style: 'margin:0 0 4px;font-size:0.95em;color:#333' }, [ _('Decision') ]),
			self._kvTable(rows)
		]);
	},

	/* ------------------------------------------------------------------ *
	 *  Render one interface card                                           *
	 * ------------------------------------------------------------------ */

	_renderCard: function(iface, forecast, decision) {
		var self   = this;
		var name   = iface.interface || '?';
		var sig    = iface.signal      || {};
		var wifi   = iface.wifi        || {};
		var tc     = iface.tc          || {};
		var bbr    = iface.bbr         || {};
		var cong   = iface.congestion  || {};
		var bw     = iface.bandwidth   || {};
		var isWifi = sig.type === 'wifi';

		/* ---- connectivity rows ---- */
		var connRows = [
			[ self._help(_('Interface'), _('Logical UCI interface name')),  name ],
			[ self._help(_('Device'),    _('Physical network device (e.g. eth0, ppp0)')), iface.device || '—' ],
			[ self._help(_('Status'),    _('Link state as detected by omr-tracker')), self._statusBadge(iface.status) ],
			iface.status_msg ? [ self._help(_('Message'), _('Status detail from the last probe check')), iface.status_msg ] : null,
			[ self._help(_('IPv4'),      _('IPv4 address assigned to this interface')),    iface.device_ip  || '—' ],
			[ self._help(_('IPv6'),      _('IPv6 address assigned to this interface')),    iface.device_ip6 || '—' ],
			[ self._help(_('Gateway'),   _('IPv4 default gateway for this interface')),   iface.gateway    || '—' ],
			[ self._help(_('Gateway6'),  _('IPv6 default gateway for this interface')),   iface.gateway6   || '—' ],
		];

		/* ---- quality rows ---- */
		var qualRows = [
			[ self._help(_('Latency'),    _('Average round-trip time to the probe target in the last measurement')), self._fmt(iface.latency, 'ms', 1) ],
			[ self._help(_('RTT min'),    _('Lowest round-trip time ever seen — baseline for bufferbloat detection')), self._fmt(iface.rtt_min, 'ms', 1) ],
			[ self._help(_('RTT max'),    _('Highest round-trip time seen in the last measurement')), self._fmt(iface.rtt_max, 'ms', 1) ],
			[ self._help(_('Jitter'),     _('Variation in round-trip time — high values indicate an unstable link')), self._fmt(iface.jitter, 'ms', 1) ],
			[ self._help(_('Loss'),       _('Percentage of probe packets lost in the last measurement')), self._fmt(iface.loss, '%', 1) ],
			[ self._help(_('Congestion'), _('Composite score (0–100) computed from latency, loss, jitter, queue depth and signal quality')), self._congestionBar(cong.score, cong.level) ],
		];

		/* ---- signal rows ---- */
		var sigRows = [];
		if (isWifi) {
			sigRows = [
				[ self._help(_('Type'),     _('Signal source type (WiFi or cellular)')), 'WiFi' ],
				[ self._help(_('SSID'),     _('Wi-Fi network name')), wifi.ssid  || '—' ],
				[ self._help(_('BSSID'),    _('Access point MAC address')), wifi.bssid || '—' ],
				[ self._help(_('Channel'),  _('Wi-Fi channel in use')), self._fmt(wifi.channel, null) ],
				[ self._help(_('Mode'),     _('Wi-Fi operating mode (e.g. Master, Client)')), wifi.mode || '—' ],
				[ self._help(_('Signal'),   _('Received signal strength in dBm — less negative is better')), self._fmt(wifi.signal, 'dBm') ],
				[ self._help(_('Noise'),    _('Background noise floor in dBm')), self._fmt(wifi.noise, 'dBm') ],
				[ self._help(_('Bit rate'), _('Current negotiated radio transmission rate')), wifi.bitrate || '—' ],
				[ self._help(_('Quality'),  _('Link quality as a percentage of the maximum')), self._signalBar(
					wifi.quality != null && wifi.quality_max
						? Math.round(wifi.quality * 100 / wifi.quality_max)
						: null
				) ],
			];
		} else if (sig.type) {
			sigRows = [
				[ self._help(_('Type'),     _('Signal source type (WiFi or cellular)')), String(sig.type).toUpperCase() ],
				[ self._help(_('Operator'), _('Mobile network operator name')), sig.operator || '—' ],
				[ self._help(_('State'),    _('Connection state reported by the modem')), sig.state || '—' ],
				[ self._help(_('Quality'),  _('Signal quality percentage reported by the modem')), self._signalBar(sig.quality) ],
				[ self._help(_('RSSI'),     _('Received Signal Strength Indicator (dBm) — less negative is better')), self._fmt(sig.rssi, 'dBm') ],
				[ self._help(_('RSRP'),     _('Reference Signal Received Power (dBm, LTE) — less negative is better')), self._fmt(sig.rsrp, 'dBm') ],
				[ self._help(_('RSRQ'),     _('Reference Signal Received Quality (dB, LTE) — less negative is better')), self._fmt(sig.rsrq, 'dB') ],
				[ self._help(_('SINR'),     _('Signal to Interference and Noise Ratio (dB) — higher is better')), self._fmt(sig.sinr, 'dB') ],
			];
		}

		/* ---- BBR rows (only when BBR congestion control is active) ---- */
		var bbrRows = [];
		if (bbr.bw != null || bbr.pacing_rate != null || bbr.delivery_rate != null) {
			if (bbr.bw != null)
				bbrRows.push([ self._help(_('Bandwidth'),     _("BBR's estimated bottleneck bandwidth (filtered maximum delivery rate from active TCP connections)")), self._fmtBps(bbr.bw) ]);
			if (bbr.pacing_rate != null)
				bbrRows.push([ self._help(_('Pacing rate'),   _('Rate at which BBR paces packets — set to bandwidth × pacing gain during probing')), self._fmtBps(bbr.pacing_rate) ]);
			if (bbr.delivery_rate != null)
				bbrRows.push([ self._help(_('Delivery rate'), _('Actual measured data delivery rate to the receiver across active TCP connections')), self._fmtBps(bbr.delivery_rate) ]);
			if (bbr.cwnd != null)
				bbrRows.push([ self._help(_('Cwnd'),          _('Average TCP congestion window in segments across active connections')), self._fmt(bbr.cwnd, _('segs')) ]);
			if (bbr.min_rtt != null)
				bbrRows.push([ self._help(_('Min RTT'),       _('Minimum round-trip time observed by BBR — used as the propagation delay baseline')), self._fmt(bbr.min_rtt, 'ms', 3) ]);
			if (bbr.retrans != null)
				bbrRows.push([ self._help(_('Retrans'),       _('Total retransmissions across active TCP connections — any non-zero value indicates packet loss')), self._warnVal(bbr.retrans, 'error') ]);
		}

		/* ---- bandwidth rows ---- */
		var bwRows = [];
		if (bw.rx_bps != null || bw.tx_bps != null) {
			bwRows.push([ self._help(_('↓ RX'), _('Current receive rate measured over the last tracker interval')),  self._fmtBytesPerSec(bw.rx_bps) ]);
			bwRows.push([ self._help(_('↑ TX'), _('Current transmit rate measured over the last tracker interval')), self._fmtBytesPerSec(bw.tx_bps) ]);
			if (bw.rx_bytes != null)
				bwRows.push([ self._help(_('RX total'), _('Cumulative bytes received since boot')),    self._fmtBytes(bw.rx_bytes) ]);
			if (bw.tx_bytes != null)
				bwRows.push([ self._help(_('TX total'), _('Cumulative bytes transmitted since boot')), self._fmtBytes(bw.tx_bytes) ]);
		}

		/* ---- tc rows ---- */
		var tcRows = [];
		if (tc.qdisc != null) {
			tcRows.push([ self._help(_('Qdisc'),         _('Active queuing discipline (e.g. fq, cake, fq_codel)')), tc.qdisc ]);
			if (tc.sent_bytes != null)
				tcRows.push([ self._help(_('Sent'),       _('Total bytes and packets sent since the qdisc was created')), self._fmtBytes(tc.sent_bytes) + ' (' + (tc.sent_pkts || 0) + ' pkts)' ]);
			if (tc.dropped != null)
				tcRows.push([ self._help(_('Dropped'),    _('Packets discarded by the qdisc — high values indicate congestion')), self._warnVal(tc.dropped, 'error') ]);
			if (tc.overlimits != null)
				tcRows.push([ self._help(_('Overlimits'), _('Times the interface rate limit was exceeded')), String(tc.overlimits) ]);
			if (tc.backlog_bytes != null)
				tcRows.push([ self._help(_('Backlog'),    _('Bytes and packets currently waiting in the queue to be sent')), E('span', {}, [ self._warnVal(tc.backlog_bytes), ' B / ' + (tc.backlog_pkts || 0) + ' pkts' ]) ]);
			if (tc.ecn_mark != null)
				tcRows.push([ self._help(_('ECN mark'),   _('Packets marked for Explicit Congestion Notification instead of being dropped')), String(tc.ecn_mark) ]);
			if (tc.drop_overlimit != null)
				tcRows.push([ self._help(_('Drop overlimit'), _('Packets dropped because the queue length limit was exceeded')), self._warnVal(tc.drop_overlimit) ]);
			if (tc.flows != null)
				tcRows.push([ self._help(_('Flows'),      _('Number of active fair-queue flows')), String(tc.flows) ]);
			if (tc.throttled != null)
				tcRows.push([ self._help(_('Throttled'),  _('Flows currently paused by the scheduler')), self._warnVal(tc.throttled) ]);
			if (tc.flows_plimit != null)
				tcRows.push([ self._help(_('Flows plimit'), _('Flows dropped because the per-flow packet limit was reached')), self._warnVal(tc.flows_plimit) ]);
			if (tc.new_flow_count != null)
				tcRows.push([ self._help(_('New flows'),  _('New flows opened since the last measurement')), String(tc.new_flow_count) ]);
		}

		/* ---- timestamp ---- */
		var tsStr = '—';
		if (iface.timestamp) {
			var d = new Date(iface.timestamp * 1000);
			tsStr = d.toLocaleTimeString();
		}

		/* ---- assemble card ---- */
		var colStyle = 'flex:1;min-width:180px;padding:8px 12px;background:#f9f9f9;border-radius:4px';

		var cols = [
			E('div', { style: colStyle }, [
				E('h4', { style: 'margin:0 0 6px;font-size:0.95em;color:#333' }, [ _('Connectivity') ]),
				self._kvTable(connRows)
			]),
			E('div', { style: colStyle }, [
				E('h4', { style: 'margin:0 0 6px;font-size:0.95em;color:#333' }, [ _('Quality') ]),
				self._kvTable(qualRows)
			]),
		];

		if (bwRows.length) {
			cols.push(E('div', { style: colStyle }, [
				E('h4', { style: 'margin:0 0 6px;font-size:0.95em;color:#333' }, [ _('Bandwidth') ]),
				self._kvTable(bwRows)
			]));
		}

		if (sigRows.length) {
			cols.push(E('div', { style: colStyle }, [
				E('h4', { style: 'margin:0 0 6px;font-size:0.95em;color:#333' }, [ _('Signal') ]),
				self._kvTable(sigRows)
			]));
		}

		if (tcRows.length) {
			cols.push(E('div', { style: colStyle }, [
				E('h4', { style: 'margin:0 0 6px;font-size:0.95em;color:#333' }, [ _('Traffic Control') ]),
				self._kvTable(tcRows)
			]));
		}

		if (bbrRows.length) {
			cols.push(E('div', { style: colStyle }, [
				E('h4', { style: 'margin:0 0 6px;font-size:0.95em;color:#333' }, [ _('BBR') ]),
				self._kvTable(bbrRows)
			]));
		}

		var fcSection = self._renderForecastSection(forecast || null);
		var dcSection = self._renderDecisionSection(decision || null, name);

		var cardChildren = [
			E('div', { style: 'display:flex;justify-content:space-between;align-items:center;margin-bottom:10px' }, [
				E('strong', { style: 'font-size:1.05em' }, [ name ]),
				E('span',   { style: 'font-size:0.8em;color:#888' }, [ _('Updated: ') + tsStr ])
			]),
			E('div', { style: 'display:flex;flex-wrap:wrap;gap:10px' }, cols)
		];

		var extraSections = [];
		if (fcSection) extraSections.push(fcSection);
		if (dcSection) extraSections.push(dcSection);
		if (extraSections.length)
			cardChildren.push(E('div', { style: 'display:flex;flex-wrap:wrap;gap:10px;margin-top:10px' }, extraSections));

		return E('div', {
			style: 'border:1px solid #ddd;border-radius:6px;padding:12px;margin-bottom:16px;background:#fff'
		}, cardChildren);
	},

	/* ------------------------------------------------------------------ *
	 *  Build / update the full page                                        *
	 * ------------------------------------------------------------------ */

	_buildPage: function(data, userInfo, forecast, decision) {
		var self       = this;
		var ifaces     = (data && data.interfaces) ? data.interfaces : [];
		var container  = document.getElementById('omr-metrics-container');
		if (!container) return;

		/* Remove existing content */
		while (container.firstChild) container.removeChild(container.firstChild);

		/* User info panel */
		var userPanel = self._renderUserInfo(userInfo || {});
		if (userPanel) container.appendChild(userPanel);

		if (!ifaces.length) {
			container.appendChild(
				E('p', { style: 'color:#888;font-style:italic' },
				  [ _('No metrics available yet. Waiting for omr-tracker to run…') ])
			);
			return;
		}

		ifaces.forEach(function(iface) {
			var n = (iface.interface || '').toLowerCase();
			if (n === 'omrvpn' || n === 'owvpn') return;
			var ifaceFc = (forecast && forecast[iface.interface]) || null;
			container.appendChild(self._renderCard(iface, ifaceFc, decision || null));
		});
	},

	render: function(results) {
		var self     = this;
		var data     = results[0] || {};
		var userInfo = results[1] || {};
		var forecast = results[2] || {};
		var decision = results[3] || {};

		var view = E('div', {}, [
			E('h2', {}, [ _('WAN Metrics') ]),
			E('p', { style: 'color:#555;margin-bottom:16px' }, [
				_('Live per-interface metrics collected by omr-tracker. Refreshes every %d seconds.').format(self.POLL_INTERVAL)
			]),
			E('div', { id: 'omr-metrics-container' })
		]);

		self._buildPage(data, userInfo, forecast, decision);

		poll.add(function() {
			return Promise.all([
				callMetricsGetAll(),
				callMetricsGetUserInfo(),
				callMetricsGetForecast(),
				callMetricsGetDecision()
			]).then(function(r) {
				self._buildPage(r[0] || {}, r[1] || {}, r[2] || {}, r[3] || {});
			});
		}, self.POLL_INTERVAL);

		return view;
	},

	handleSaveApply: null,
	handleSave:      null,
	handleReset:     null
});
