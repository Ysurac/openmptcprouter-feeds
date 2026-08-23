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

/* get_user_info/get_forecast/get_decision each make their own outbound
 * VPS round-trip on the router side (curl --max-time 10) and can each take
 * up to ~10s — longer when the VPS metrics API is slow, unreachable, or the
 * account isn't authorized. rpc.js batches every call fired in the same
 * tick into one HTTP request; without `nobatch` these three would ride
 * along with the fast, purely-local get_all in that single batch, and
 * uhttpd resolves a batch's entries one at a time -- three ~10s calls
 * serialize into ~30s, which blows past LuCI's default 20s client-side RPC
 * timeout ("XHR request timed out") and fails the *entire* batch,
 * including get_all's already-available data. `nobatch: true` gives each
 * of these its own request so a slow/broken VPS can never block the
 * always-local get_all, and each still gets the full 20s on its own. */
var callMetricsGetUserInfo = rpc.declare({
	object: 'metrics',
	method: 'get_user_info',
	expect: { '': {} },
	nobatch: true
});

var callMetricsGetForecast = rpc.declare({
	object: 'metrics',
	method: 'get_forecast',
	expect: { '': {} },
	nobatch: true
});

var callMetricsGetDecision = rpc.declare({
	object: 'metrics',
	method: 'get_decision',
	expect: { '': {} },
	nobatch: true
});

/* Belt-and-suspenders companion to `nobatch` above: even isolated in its
 * own request, get_user_info/get_forecast/get_decision can still reject
 * (VPS truly down, a slow DNS lookup pushing past 20s, a 5xx, ...). Without
 * this, that single rejection would fail the shared Promise.all() below and
 * blank the whole page -- these three are optional VPS enhancements, not
 * prerequisites for showing the (already local and available) interface
 * metrics, so any failure here just degrades to "no data" for that one
 * section instead of taking down the page. */
function optional(promise) {
	return promise.catch(function() { return {}; });
}

return view.extend({
	/* Auto-refresh interval in seconds */
	POLL_INTERVAL: 5,

	/* Number of samples kept per interface for the quality trend graph */
	HISTORY_LEN: 60,

	load: function() {
		return Promise.all([
			callMetricsGetAll(),
			optional(callMetricsGetUserInfo()),
			optional(callMetricsGetForecast()),
			optional(callMetricsGetDecision())
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

		return E('div', { style: 'flex:0 0 auto;min-width:260px;padding:8px 12px;background:#f9f9f9;border-radius:4px' }, [
			E('h4', { style: 'margin:0 0 4px;font-size:0.95em;color:#333' }, [ _('Forecast') ]),
			E('table', { style: 'border-collapse:collapse' }, [ tbody ])
		]);
	},

	/* ------------------------------------------------------------------ *
	 *  Quality trend graph (client-side rolling buffer, per interface)    *
	 * ------------------------------------------------------------------ */

	/* Append the current sample of each interface to its rolling history. There
	 * is no history endpoint on the router (get_all only reflects the current
	 * /tmp/metrics/<iface>.json snapshot), so the browser accumulates its own
	 * buffer across polls for as long as the view stays open. */
	_pushHistory: function(ifaces) {
		var self = this;
		if (!self._history) self._history = {};
		var now = Date.now();
		(ifaces || []).forEach(function(iface) {
			var name = iface.interface;
			if (!name) return;
			var cong = iface.congestion || {};
			var h = self._history[name] || (self._history[name] = []);
			h.push({
				ts:      now,
				latency: iface.latency != null ? Number(iface.latency) : null,
				loss:    iface.loss    != null ? Number(iface.loss)    : null,
				score:   cong.score    != null ? Number(cong.score)   : null
			});
			if (h.length > self.HISTORY_LEN)
				h.splice(0, h.length - self.HISTORY_LEN);
		});
	},

	/* Map a series of values (nulls allowed) to an SVG polyline "points" string
	 * against an explicit [min,max] range, so the caller controls the scale
	 * (e.g. a fixed 0-100 range for a score) instead of it floating per-frame. */
	_pathFromRange: function(values, w, h, pad, min, max) {
		var defined = values.filter(function(v) { return v != null; });
		if (defined.length < 2) return null;

		var span = (max - min) || 1;
		var innerH = h - pad * 2;
		var n = values.length;

		var pts = [];
		values.forEach(function(v, i) {
			if (v == null) return;
			var x = (n > 1) ? (i / (n - 1) * w) : 0;
			var y = pad + innerH - ((v - min) / span) * innerH;
			pts.push(x.toFixed(1) + ',' + y.toFixed(1));
		});
		return pts.join(' ');
	},

	/* One labelled sparkline row: color dot + name, chart, current value (with
	 * unit) and the visible min-max range so the scale is never ambiguous.
	 * Hovering the chart shows the exact value + time under the cursor. */
	_renderQualitySparkline: function(m, history) {
		var self   = this;
		var values = history.map(function(s) { return s[m.key]; });
		var defined = values.filter(function(v) { return v != null; });
		if (defined.length < 2) return null;

		var NS = 'http://www.w3.org/2000/svg';
		var W = 600, H = 40, PAD = 4;
		var n = values.length;

		var min, max;
		if (m.fixedMin != null && m.fixedMax != null) {
			min = m.fixedMin;
			max = m.fixedMax;
		} else {
			min = Math.min.apply(null, defined);
			max = Math.max.apply(null, defined);
			var rangePad = (max - min) * 0.15 || 1;
			min -= rangePad;
			max += rangePad;
		}

		var points = self._pathFromRange(values, W, H, PAD, min, max);
		var last   = defined[defined.length - 1];

		var svg = document.createElementNS(NS, 'svg');
		svg.setAttribute('width', '100%');
		svg.setAttribute('height', String(H));
		svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
		svg.setAttribute('preserveAspectRatio', 'none');
		svg.style.cssText = 'display:block;background:#fff;border:1px solid #eee;border-radius:3px;cursor:crosshair';

		/* Faint vertical guides at start/middle/end, so the timeline row below
		 * (which shares this exact width) lines up with something on the chart */
		[0, W / 2, W].forEach(function(x) {
			var gl = document.createElementNS(NS, 'line');
			gl.setAttribute('x1', String(x)); gl.setAttribute('x2', String(x));
			gl.setAttribute('y1', '0');       gl.setAttribute('y2', String(H));
			gl.setAttribute('stroke', '#eee');
			gl.setAttribute('stroke-width', '1');
			gl.setAttribute('vector-effect', 'non-scaling-stroke');
			svg.appendChild(gl);
		});

		if (points) {
			var poly = document.createElementNS(NS, 'polyline');
			poly.setAttribute('points', points);
			poly.setAttribute('fill', 'none');
			poly.setAttribute('stroke', m.color);
			poly.setAttribute('stroke-width', '1.75');
			poly.setAttribute('vector-effect', 'non-scaling-stroke');
			svg.appendChild(poly);
		}

		/* Hover crosshair (hidden until the pointer enters the chart) */
		var hoverLine = document.createElementNS(NS, 'line');
		hoverLine.setAttribute('y1', '0');
		hoverLine.setAttribute('y2', String(H));
		hoverLine.setAttribute('stroke', '#666');
		hoverLine.setAttribute('stroke-width', '1');
		hoverLine.setAttribute('vector-effect', 'non-scaling-stroke');
		hoverLine.style.display = 'none';
		svg.appendChild(hoverLine);

		var hoverDot = document.createElementNS(NS, 'circle');
		hoverDot.setAttribute('r', '3');
		hoverDot.setAttribute('fill', m.color);
		hoverDot.setAttribute('stroke', '#fff');
		hoverDot.setAttribute('stroke-width', '1');
		hoverDot.style.display = 'none';
		svg.appendChild(hoverDot);

		var tooltip = E('div', {
			style: 'position:absolute;top:-4px;transform:translate(-50%,-100%);' +
			       'background:#333;color:#fff;font-size:0.72em;padding:2px 6px;' +
			       'border-radius:3px;white-space:nowrap;pointer-events:none;display:none;z-index:1'
		});

		var updateHover = function(clientX) {
			var rect = svg.getBoundingClientRect();
			if (!rect.width) return;
			var relX = Math.max(0, Math.min(rect.width, clientX - rect.left));
			var idx  = Math.round(relX / rect.width * (n - 1));
			var v    = values[idx];

			var svgX = (n > 1) ? (idx / (n - 1) * W) : 0;
			hoverLine.setAttribute('x1', String(svgX));
			hoverLine.setAttribute('x2', String(svgX));
			hoverLine.style.display = 'block';

			if (v != null) {
				var innerH = H - PAD * 2;
				var y = PAD + innerH - ((v - min) / ((max - min) || 1)) * innerH;
				hoverDot.setAttribute('cx', String(svgX));
				hoverDot.setAttribute('cy', String(y));
				hoverDot.style.display = 'block';
			} else {
				hoverDot.style.display = 'none';
			}

			tooltip.style.left = relX + 'px';
			tooltip.style.display = 'block';
			tooltip.textContent = self._fmtClock(history[idx].ts) + '  ' +
				(v != null ? Number(v).toFixed(m.decimals) + (m.unit ? ' ' + m.unit : '') : '—');
		};

		var hideHover = function() {
			hoverLine.style.display = 'none';
			hoverDot.style.display  = 'none';
			tooltip.style.display   = 'none';
		};

		svg.addEventListener('mousemove', function(ev) { updateHover(ev.clientX); });
		svg.addEventListener('mouseleave', hideHover);
		svg.addEventListener('touchmove', function(ev) {
			if (ev.touches && ev.touches[0]) updateHover(ev.touches[0].clientX);
		});
		svg.addEventListener('touchend', hideHover);

		return E('div', { style: 'display:flex;align-items:center;gap:10px;margin-bottom:8px' }, [
			E('span', {
				style: 'flex:0 0 auto;width:90px;font-size:0.82em;color:#555;display:flex;align-items:center;gap:5px'
			}, [
				E('span', { style: 'display:inline-block;width:8px;height:8px;flex:0 0 auto;border-radius:50%;background:' + m.color }),
				m.label
			]),
			E('span', { style: 'flex:1;min-width:120px;position:relative;display:block' }, [ svg, tooltip ]),
			E('span', { style: 'flex:0 0 auto;width:72px;text-align:right;font-size:0.88em;font-weight:600;color:#333' }, [
				Number(last).toFixed(m.decimals) + (m.unit ? ' ' + m.unit : '')
			]),
			E('span', { style: 'flex:0 0 auto;width:88px;text-align:right;font-size:0.72em;color:#999' }, [
				Math.round(min) + '–' + Math.round(max) + (m.unit ? ' ' + m.unit : '')
			])
		]);
	},

	_fmtClock: function(ts) {
		var d = new Date(ts);
		var pad2 = function(n) { return ('0' + n).slice(-2); };
		return pad2(d.getHours()) + ':' + pad2(d.getMinutes()) + ':' + pad2(d.getSeconds());
	},

	/* Timeline row shown once under all sparklines. It reuses the exact same
	 * label/chart/value/range column widths as each sparkline row so its three
	 * clock ticks land under the start/middle/end of every chart above it. */
	_renderQualityTimeline: function(history) {
		var self = this;
		var n = history.length;
		var mid = Math.floor((n - 1) / 2);

		return E('div', { style: 'display:flex;align-items:center;gap:10px;margin-top:-2px' }, [
			E('span', { style: 'flex:0 0 auto;width:90px' }),
			E('span', {
				style: 'flex:1;min-width:120px;display:flex;justify-content:space-between;' +
				       'font-size:0.68em;color:#999'
			}, [
				E('span', {}, [ self._fmtClock(history[0].ts) ]),
				E('span', {}, [ self._fmtClock(history[mid].ts) ]),
				E('span', {}, [ self._fmtClock(history[n - 1].ts) ])
			]),
			E('span', { style: 'flex:0 0 auto;width:72px' }),
			E('span', { style: 'flex:0 0 auto;width:88px' })
		]);
	},

	_renderQualityGraph: function(history) {
		var self = this;
		if (!history || history.length < 2) return null;

		var metrics = [
			{ key: 'score',   color: '#2196f3', label: _('Congestion'), unit: '/100', decimals: 0, fixedMin: 0, fixedMax: 100 },
			{ key: 'latency', color: '#ff9800', label: _('Latency'),    unit: 'ms',    decimals: 1 },
			{ key: 'loss',    color: '#f44336', label: _('Loss'),       unit: '%',     decimals: 1 }
		];

		var rows = metrics
			.map(function(m) { return self._renderQualitySparkline(m, history); })
			.filter(Boolean);

		if (!rows.length) return null;

		var windowSec   = history.length * self.POLL_INTERVAL;
		var windowLabel = windowSec >= 60 ? Math.round(windowSec / 60) + 'min' : windowSec + 's';

		return E('div', { style: 'width:100%;margin-top:10px;padding:10px 12px;background:#f9f9f9;border-radius:4px' }, [
			E('h4', { style: 'margin:0 0 8px;font-size:0.95em;color:#333' }, [
				_('Quality trend'),
				E('span', { style: 'font-weight:normal;color:#999;font-size:0.8em' }, [ ' (' + _('last') + ' ' + windowLabel + ')' ])
			]),
			E('div', {}, rows),
			self._renderQualityTimeline(history)
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

		return E('div', { style: 'flex:0 0 auto;min-width:220px;padding:8px 12px;background:#f9f9f9;border-radius:4px' }, [
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

		var history   = (self._history && self._history[name]) || [];
		var qgSection = self._renderQualityGraph(history);
		var fcSection = self._renderForecastSection(forecast || null);
		var dcSection = self._renderDecisionSection(decision || null, name);

		var cardChildren = [
			E('div', { style: 'display:flex;justify-content:space-between;align-items:center;margin-bottom:10px' }, [
				E('strong', { style: 'font-size:1.05em' }, [ name ]),
				E('span',   { style: 'font-size:0.8em;color:#888' }, [ _('Updated: ') + tsStr ])
			]),
			E('div', { style: 'display:flex;flex-wrap:wrap;gap:10px' }, cols)
		];

		/* Full-width so the sparklines get enough horizontal room to be readable */
		if (qgSection) cardChildren.push(qgSection);

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

		self._pushHistory(ifaces);

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
				optional(callMetricsGetUserInfo()),
				optional(callMetricsGetForecast()),
				optional(callMetricsGetDecision())
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
