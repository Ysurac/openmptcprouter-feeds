'use strict';
'require view';
'require poll';
'require rpc';
'require uci';

var callGetInterfaces = rpc.declare({
	object: 'network.interface',
	method: 'dump',
	expect: { interface: [] }
});

var callMultipathBandwidth = rpc.declare({
	object: 'luci.mptcp',
	method: 'multipath_bandwidth',
	expect: { '': {} }
});

var callIfaceBandwidth = rpc.declare({
	object: 'luci.mptcp',
	method: 'interface_bandwidth',
	params: ['iface'],
	expect: { data: [] }
});

return view.extend({
	STEP:   5,
	HEIGHT: 300,
	WIDTH:  760,

	/* runtime state – reset on every tab switch */
	_state:    null,
	_smaState: {},

	load: function() {
		return Promise.all([
			uci.load('network'),
			callGetInterfaces()
		]);
	},

	/* ------------------------------------------------------------------ *
	 *  Helpers                                                            *
	 * ------------------------------------------------------------------ */

	/* The same colours as the status page (stringToColour() in
	 * openmptcprouter/wanstatus.js), so that a WAN has one colour on both
	 * pages; "total" is this page's own line. They are written in hex
	 * because the WAN card's badge appends an alpha byte to them, which
	 * turns a colour name into an invalid value. */
	_ifaceColor: function(name) {
		var fixed = {
			total: '#ff4500',   /* OrangeRed */
			wan1: '#8a2be2',    /* BlueViolet */
			wan2: '#00bfff',    /* DeepSkyBlue */
			wan3: '#90ee90',    /* LightGreen */
			wan4: '#b0e0e6',    /* PowderBlue */
			wan5: '#98fb98',    /* PaleGreen */
			wan6: '#9acd32',    /* YellowGreen */
			wan7: '#2e8b57',    /* SeaGreen */
			wan8: '#4682b4'     /* SteelBlue */
		};
		if (fixed[name]) return fixed[name];
		var h = 0;
		for (var i = 0; i < (name || '').length; i++)
			h = ((h << 5) - h) + name.charCodeAt(i);
		var color = '#';
		for (var j = 0; j < 3; j++) {
			var v = (h >> (j * 8)) & 0xFF;
			color += ('00' + v.toString(16)).slice(-2);
		}
		return color;
	},

	_bwLabel: function(bytes, br) {
		if (bytes < 0) bytes = 0;
		var kby = bytes / 1024, uby = _('kB/s');
		if (kby >= 1024) { uby = _('MB/s'); kby /= 1024; }
		var kbi = bytes * 8 / 1024, ubi = _('kbit/s');
		if (kbi >= 1024) { ubi = _('Mbit/s'); kbi /= 1024; }
		return kbi.toFixed(2) + '\u202f' + ubi +
		       (br ? '<br />' : ' ') +
		       '(' + kby.toFixed(2) + '\u202f' + uby + ')';
	},

	_sma: function(key, period, val) {
		if (!this._smaState[key]) this._smaState[key] = [];
		var buf = this._smaState[key];
		buf.push(val);
		if (buf.length > period) buf.shift();
		var s = 0;
		for (var i = 0; i < buf.length; i++) s += buf[i];
		return s / buf.length;
	},

	_domSafeId: function(s) {
		return String(s == null ? '' : s).replace(/[^A-Za-z0-9_-]/g, '_');
	},

	/* Returns [{name, label, device}] for multipath-enabled interfaces */
	_getMultipathIfaces: function(ifaceDump) {
		var devByName = {};
		(ifaceDump || []).forEach(function(ifc) {
			if (ifc['interface'] && ifc['l3_device'])
				devByName[ifc['interface']] = ifc['l3_device'];
		});
		var ifaces = [];
		uci.sections('network', 'interface', function(s) {
			var name = s['.name'];
			if (!name || name === 'loopback') return;
			var mp = s.multipath || '';
			if (mp !== 'on' && mp !== 'master' && mp !== 'backup' && mp !== 'handover') return;
			var dev = devByName[name] || s.device || s.ifname || name;
			ifaces.push({ name: name, label: s.label || name, device: dev });
		});
		return ifaces;
	},

	/* ------------------------------------------------------------------ *
	 *  SVG construction                                                   *
	 * ------------------------------------------------------------------ */

	_createSVG: function(id, height) {
		var NS = 'http://www.w3.org/2000/svg';
		var svg = document.createElementNS(NS, 'svg');
		svg.id = id;
		svg.setAttribute('width',  '100%');
		svg.setAttribute('height', String(height));
		svg.setAttribute('viewBox', '0 0 ' + this.WIDTH + ' ' + height);
		svg.setAttribute('preserveAspectRatio', 'none');
		svg.style.cssText = 'display:block;border:1px solid #d6e2ee;border-radius:14px;background:linear-gradient(180deg,#fdfefe 0%,#eef5fb 100%);box-shadow:inset 0 1px 0 rgba(255,255,255,.9);box-sizing:border-box;';

		var g = document.createElementNS(NS, 'g');
		g.id = id + '_g';
		svg.appendChild(g);

		/* Scale labels at 25 / 50 / 75 % */
		[25, 50, 75].forEach(function(pct) {
			var t = document.createElementNS(NS, 'text');
			t.id = id + '_lbl' + pct;
			t.setAttribute('x', '4');
			t.setAttribute('y', String(height - Math.round(height * pct / 100) - 3));
			t.setAttribute('style', 'fill:#888;font-size:9px;');
			t.appendChild(document.createTextNode(''));
			svg.appendChild(t);
		});

		return svg;
	},

	_addTimeLines: function(id, width, height, step) {
		var NS = 'http://www.w3.org/2000/svg';
		var g = document.getElementById(id + '_g');
		if (!g) return;
		[25, 50, 75].forEach(function(pct) {
			var y = height - Math.round(height * pct / 100);
			var hline = document.createElementNS(NS, 'line');
			hline.setAttribute('x1', 0);
			hline.setAttribute('y1', y);
			hline.setAttribute('x2', width);
			hline.setAttribute('y2', y);
			hline.setAttribute('style', 'stroke:#d9e5ef;stroke-width:0.8');
			g.insertBefore(hline, g.firstChild);
		});
		for (var x = width % (step * 60); x < width; x += step * 60) {
			var line = document.createElementNS(NS, 'line');
			line.setAttribute('x1', x); line.setAttribute('y1', 0);
			line.setAttribute('x2', x); line.setAttribute('y2', height);
			line.setAttribute('style', 'stroke:#d9e5ef;stroke-width:0.8');
			g.insertBefore(line, g.firstChild);
			var txt = document.createElementNS(NS, 'text');
			txt.setAttribute('x', x + 3);
			txt.setAttribute('y', 12);
			txt.setAttribute('style', 'fill:#8ca0b4;font-size:8px;');
			txt.appendChild(document.createTextNode(Math.round((width - x) / step / 60) + 'm'));
			g.insertBefore(txt, g.firstChild);
		}
	},

	_scaleLbl: function(id, pct, maxBytes) {
		var el = document.getElementById(id + '_lbl' + pct);
		if (el) el.textContent = this._bwLabel(maxBytes * pct / 100);
	},

	_injectStyles: function() {
		if (document.getElementById('mptcp-bw-styles'))
			return;

		var style = document.createElement('style');
		style.id = 'mptcp-bw-styles';
		style.textContent = [
			'.mptcp-summary-card{margin-bottom:18px;padding:18px;}',
			'.mptcp-summary-card__header{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:12px;}',
			'.mptcp-summary-card__title{font-size:17px;font-weight:700;color:#17324e;line-height:1.2;}',
			'.mptcp-summary-card__meta{margin-top:4px;font-size:11px;color:#688198;}',
			'.mptcp-summary-card__legend{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end;}',
			'.mptcp-legend-pill{display:inline-flex;align-items:center;gap:6px;padding:5px 10px;border-radius:999px;background:#fff;border:1px solid #dde7f1;font-size:11px;font-weight:700;color:#29445f;}',
			'.mptcp-legend-pill__swatch{width:10px;height:10px;border-radius:999px;display:inline-block;}',
			'.mptcp-summary-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:8px;margin-top:12px;}',
			'.mptcp-all-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:18px;align-items:start;}',
			'.mptcp-wan-card{padding:16px;}',
			'.mptcp-wan-card__header{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:12px;}',
			'.mptcp-wan-card__title{font-size:15px;font-weight:700;color:#16324f;line-height:1.2;}',
			'.mptcp-wan-card__meta{margin-top:3px;font-size:11px;color:#5b728a;}',
			'.mptcp-wan-card__badge{display:inline-flex;align-items:center;padding:4px 10px;border-radius:999px;border:1px solid currentColor;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;white-space:nowrap;}',
			'.mptcp-chart-block + .mptcp-chart-block{margin-top:14px;padding-top:14px;border-top:1px solid #dde7f1;}',
			'.mptcp-chart-block__title{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;font-size:12px;font-weight:700;color:#29445f;text-transform:uppercase;letter-spacing:.04em;}',
			'.mptcp-chart-block__stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:10px;}',
			'.mptcp-stat{background:#fff;border:1px solid #e2ebf3;border-radius:12px;padding:8px 10px;min-width:0;}',
			'.mptcp-stat__label{display:block;font-size:10px;font-weight:700;color:#6b8298;text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px;}',
			'.mptcp-stat__value{display:block;font-size:12px;color:#18344f;line-height:1.35;}',
			'.mptcp-chart-block__meta{margin-top:8px;font-size:11px;color:#6b8298;text-align:right;}',
			'.mptcp-empty-state{padding:28px;border:1px dashed #c9d7e5;border-radius:14px;background:#f8fbfd;color:#56708a;text-align:center;}',
			'#mptcp-tooltip{position:fixed;z-index:9999;pointer-events:none;background:rgba(15,23,42,.88);color:#e8f0f8;border-radius:8px;padding:8px 12px;font-size:12px;line-height:1.7;box-shadow:0 4px 16px rgba(0,0,0,.3);white-space:nowrap;display:none;}'
		].join('');
		document.head.appendChild(style);
	},

	_getTooltip: function() {
		var tip = document.getElementById('mptcp-tooltip');
		if (!tip) {
			tip = document.createElement('div');
			tip.id = 'mptcp-tooltip';
			document.body.appendChild(tip);
		}
		return tip;
	},

	_xToIndex: function(svgX, seriesLen) {
		if (!seriesLen) return -1;
		var startX = this.WIDTH - (seriesLen - 1) * this.STEP;
		var i = Math.round((svgX - startX) / this.STEP);
		return Math.max(0, Math.min(seriesLen - 1, i));
	},

	_addSVGHover: function(svgId, height, getContent) {
		var self = this;
		var svg = document.getElementById(svgId);
		if (!svg) return;
		var NS = 'http://www.w3.org/2000/svg';
		var g = document.getElementById(svgId + '_g');
		var xh = document.createElementNS(NS, 'line');
		xh.setAttribute('y1', '0');
		xh.setAttribute('y2', String(height));
		xh.setAttribute('style', 'stroke:#8ca0b4;stroke-width:1;stroke-dasharray:3,2;visibility:hidden');
		if (g) g.appendChild(xh);
		svg.style.cursor = 'crosshair';
		svg.addEventListener('mousemove', function(ev) {
			var rect = svg.getBoundingClientRect();
			if (!rect.width) return;
			var svgX = (ev.clientX - rect.left) * self.WIDTH / rect.width;
			svgX = Math.max(0, Math.min(self.WIDTH, svgX));
			xh.setAttribute('x1', String(svgX));
			xh.setAttribute('x2', String(svgX));
			xh.style.visibility = 'visible';
			var html = getContent(svgX);
			var tip = self._getTooltip();
			if (html) {
				tip.innerHTML = html;
				var tx = ev.clientX + 14;
				var ty = ev.clientY - 10;
				if (tx + 200 > window.innerWidth) tx = ev.clientX - 214;
				tip.style.left = tx + 'px';
				tip.style.top  = ty + 'px';
				tip.style.display = 'block';
			} else {
				tip.style.display = 'none';
			}
		});
		svg.addEventListener('mouseleave', function() {
			xh.style.visibility = 'hidden';
			var tip = document.getElementById('mptcp-tooltip');
			if (tip) tip.style.display = 'none';
		});
	},

	_linePoints: function(series, width, height, step, scale) {
		if (!series.length) return '';
		var startX = width - (series.length - 1) * step;
		var points = '';
		for (var i = 0; i < series.length; i++) {
			var x = startX + i * step;
			var y = height - Math.floor((series[i] || 0) * scale);
			points += (i ? ' ' : '') + x + ',' + y;
		}
		var lastY = height - Math.floor((series[series.length - 1] || 0) * scale);
		points += ' ' + width + ',' + lastY;
		return points;
	},

	_areaPoints: function(series, width, height, step, scale) {
		if (!series.length) return '';
		var startX = width - (series.length - 1) * step;
		var points = startX + ',' + height;
		for (var i = 0; i < series.length; i++) {
			var x = startX + i * step;
			var y = height - Math.floor((series[i] || 0) * scale);
			points += ' ' + x + ',' + y;
		}
		var lastY = height - Math.floor((series[series.length - 1] || 0) * scale);
		points += ' ' + width + ',' + lastY;
		points += ' ' + width + ',' + height + ' ' + startX + ',' + height;
		return points;
	},

	_seriesStats: function(series) {
		var current = 0, peak = 0, sum = 0;
		for (var i = 0; i < series.length; i++) {
			var val = series[i] || 0;
			sum += val;
			peak = Math.max(peak, val);
		}
		if (series.length)
			current = series[series.length - 1] || 0;
		return {
			current: current,
			average: series.length ? (sum / series.length) : 0,
			peak: peak
		};
	},

	/* ------------------------------------------------------------------ *
	 *  Render                                                             *
	 * ------------------------------------------------------------------ */

	render: function(data) {
		var self    = this;
		var ifaces  = this._getMultipathIfaces(data[1]);
		var allTabs = [{ name: 'all', label: _('All interfaces'), device: 'all' }].concat(ifaces);
		this._allIfaces = ifaces;
		this._injectStyles();

		var root = E('div', { 'id': 'bw-root' }, [
			E('ul', { 'class': 'cbi-tabmenu', 'id': 'bw-tabmenu' }),
			E('div', { 'id': 'bw-area' })
		]);

		var tabmenu = root.querySelector('#bw-tabmenu');
		allTabs.forEach(function(tab) {
			var li = E('li', { 'class': tab.name === 'all' ? 'cbi-tab' : 'cbi-tab-disabled' },
				E('a', { 'href': '#', 'click': function(ev) {
					ev.preventDefault();
					self._switchTab(tab, allTabs);
				}}, [ tab.label ])
			);
			li.id = 'bwtab-' + tab.name;
			tabmenu.appendChild(li);
		});

		/* Register the single recurring poll; data arrives after SVG is sized */
		poll.add(L.bind(this._tick, this), 1);

		/* Build initial chart after first layout pass */
		requestAnimationFrame(function() {
			self._switchTab(allTabs[0], allTabs);
		});

		return root;
	},

	/* ------------------------------------------------------------------ *
	 *  Tab switching                                                      *
	 * ------------------------------------------------------------------ */

	_switchTab: function(tab, allTabs) {
		var self = this;

		allTabs.forEach(function(t) {
			var li = document.getElementById('bwtab-' + t.name);
			if (li) li.className = (t.name === tab.name) ? 'cbi-tab' : 'cbi-tab-disabled';
		});

		/* Nulling _state makes _tick a no-op until the new state is ready */
		this._state    = null;
		this._smaState = {};

		var area = document.getElementById('bw-area');
		if (!area) return;
		area.innerHTML = '';

		if (tab.name === 'all')
			this._buildAllCharts(area, this._allIfaces || []);
		else
			this._buildIfaceChart(area, tab);
	},

	/* ------------------------------------------------------------------ *
	 *  "All interfaces" chart construction                               *
	 * ------------------------------------------------------------------ */

	_buildAllCharts: function(area, ifaces) {
		var self = this;
		ifaces = ifaces || [];

		if (!ifaces.length) {
			area.appendChild(E('div', { 'class': 'mptcp-empty-state' },
				_('No multipath WAN interface is currently available.')));
			return;
		}

		var totalInColor  = '#2f7df6';
		var totalOutColor = '#0f9d7a';

		var legendPills = [
			E('span', { 'class': 'mptcp-legend-pill' }, [
				E('span', { 'class': 'mptcp-legend-pill__swatch', 'style': 'background:' + totalInColor }),
				_('Total in')
			]),
			E('span', { 'class': 'mptcp-legend-pill' }, [
				E('span', { 'class': 'mptcp-legend-pill__swatch', 'style': 'background:' + totalOutColor }),
				_('Total out')
			])
		];
		ifaces.forEach(function(iface) {
			var c = self._ifaceColor(iface.name);
			legendPills.push(E('span', { 'class': 'mptcp-legend-pill' }, [
				E('span', { 'class': 'mptcp-legend-pill__swatch', 'style': 'background:' + c }),
				iface.label
			]));
		});

		var makeSummaryStats = function(prefix) {
			var cells = [];
			/* header row */
			['', _('Current'), _('Average'), _('Peak')].forEach(function(h) {
				cells.push(E('div', { 'class': 'mptcp-stat', 'style': 'background:#eef3f8;' }, [
					E('span', { 'class': 'mptcp-stat__label', 'style': 'display:block;text-align:center;' }, h)
				]));
			});
			/* one row per WAN interface */
			ifaces.forEach(function(iface) {
				var sid = self._domSafeId(iface.name);
				var c   = self._ifaceColor(iface.name);
				cells.push(E('div', { 'class': 'mptcp-stat' }, [
					E('span', { 'class': 'mptcp-stat__value', 'style': 'color:' + c + ';font-weight:700;font-size:11px;' }, [ iface.label ])
				]));
				['_cur', '_avg', '_peak'].forEach(function(suf) {
					cells.push(E('div', { 'class': 'mptcp-stat' }, [
						E('span', { 'id': prefix + '_' + sid + suf, 'class': 'mptcp-stat__value' }, '0\u202f' + _('kbit/s'))
					]));
				});
			});
			/* total row */
			cells.push(E('div', { 'class': 'mptcp-stat', 'style': 'background:#eef3f8;' }, [
				E('span', { 'class': 'mptcp-stat__value', 'style': 'font-weight:700;font-size:11px;' }, _('Total'))
			]));
			['_cur', '_avg', '_peak'].forEach(function(suf) {
				cells.push(E('div', { 'class': 'mptcp-stat', 'style': 'background:#eef3f8;' }, [
					E('span', { 'id': prefix + suf, 'class': 'mptcp-stat__value' }, '0\u202f' + _('kbit/s'))
				]));
			});
			return E('div', { 'style': 'display:grid;grid-template-columns:minmax(80px,auto) repeat(3,minmax(0,1fr));gap:6px;margin-top:10px;' }, cells);
		};

		var combinedHeight = Math.max(190, Math.round(this.HEIGHT * 0.72));
		var totalCard = E('div', { 'class': 'mptcp-summary-card' }, [
			E('div', { 'class': 'mptcp-summary-card__header' }, [
				E('div', {}, [
					E('div', { 'class': 'mptcp-summary-card__title' }, _('All interfaces – combined view')),
					E('div', { 'class': 'mptcp-summary-card__meta' }, _('All interfaces overlaid, inbound and outbound separately'))
				]),
				E('div', { 'class': 'mptcp-summary-card__legend' }, legendPills)
			]),
			E('div', { 'class': 'mptcp-chart-block' }, [
				E('div', { 'class': 'mptcp-chart-block__title' }, _('Inbound – all interfaces')),
				self._createSVG('total_dn_svg', combinedHeight),
				makeSummaryStats('total_dn'),
				E('div', { 'id': 'total_dn_scale', 'class': 'mptcp-chart-block__meta' }, '-')
			]),
			E('div', { 'class': 'mptcp-chart-block' }, [
				E('div', { 'class': 'mptcp-chart-block__title' }, _('Outbound – all interfaces')),
				self._createSVG('total_up_svg', combinedHeight),
				makeSummaryStats('total_up'),
				E('div', { 'id': 'total_up_scale', 'class': 'mptcp-chart-block__meta' }, '-')
			])
		]);
		area.appendChild(totalCard);

		var cards = {};
		ifaces.forEach(function(iface) {
			cards[iface.name] = { color: self._ifaceColor(iface.name), label: iface.label };
		});

		requestAnimationFrame(function() {
			var totalWidth  = self.WIDTH;
			var totalHeight = Math.max(190, Math.round(self.HEIGHT * 0.72));
			var step   = self.STEP;
			var wanted = Math.ceil(totalWidth / step);
			var NS     = 'http://www.w3.org/2000/svg';
			var minWin = Math.round(wanted / 60);

			self._addTimeLines('total_dn_svg', totalWidth, totalHeight, step);
			self._addTimeLines('total_up_svg', totalWidth, totalHeight, step);

			var totalDnG = document.getElementById('total_dn_svg_g');
			var totalUpG = document.getElementById('total_up_svg_g');

			var combinedDn = { width: totalWidth, height: totalHeight, id: 'total_dn_svg', ifaceLines: {} };
			var combinedUp = { width: totalWidth, height: totalHeight, id: 'total_up_svg', ifaceLines: {} };

			/* Per-interface lines (behind total) */
			ifaces.forEach(function(iface) {
				var color = self._ifaceColor(iface.name);

				var dnFill = document.createElementNS(NS, 'polyline');
				dnFill.setAttribute('style', 'fill:' + color + ';fill-opacity:0.10;stroke:none');
				if (totalDnG) totalDnG.appendChild(dnFill);
				var dnLine = document.createElementNS(NS, 'polyline');
				dnLine.setAttribute('style', 'fill:none;stroke:' + color + ';stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;opacity:0.85');
				if (totalDnG) totalDnG.appendChild(dnLine);
				combinedDn.ifaceLines[iface.name] = { fill: dnFill, line: dnLine };

				var upFill = document.createElementNS(NS, 'polyline');
				upFill.setAttribute('style', 'fill:' + color + ';fill-opacity:0.10;stroke:none');
				if (totalUpG) totalUpG.appendChild(upFill);
				var upLine = document.createElementNS(NS, 'polyline');
				upLine.setAttribute('style', 'fill:none;stroke:' + color + ';stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;opacity:0.85');
				if (totalUpG) totalUpG.appendChild(upLine);
				combinedUp.ifaceLines[iface.name] = { fill: upFill, line: upLine };
			});

			/* Total lines on top */
			var totalDnFill = document.createElementNS(NS, 'polyline');
			totalDnFill.setAttribute('style', 'fill:' + totalInColor + ';fill-opacity:0.18;stroke:none');
			if (totalDnG) totalDnG.appendChild(totalDnFill);
			var totalDnLine = document.createElementNS(NS, 'polyline');
			totalDnLine.setAttribute('style', 'fill:none;stroke:' + totalInColor + ';stroke-width:2.6;stroke-linecap:round;stroke-linejoin:round');
			if (totalDnG) totalDnG.appendChild(totalDnLine);
			combinedDn.totalFill = totalDnFill;
			combinedDn.totalLine = totalDnLine;

			var totalUpFill = document.createElementNS(NS, 'polyline');
			totalUpFill.setAttribute('style', 'fill:' + totalOutColor + ';fill-opacity:0.18;stroke:none');
			if (totalUpG) totalUpG.appendChild(totalUpFill);
			var totalUpLine = document.createElementNS(NS, 'polyline');
			totalUpLine.setAttribute('style', 'fill:none;stroke:' + totalOutColor + ';stroke-width:2.6;stroke-linecap:round;stroke-linejoin:round');
			if (totalUpG) totalUpG.appendChild(totalUpLine);
			combinedUp.totalFill = totalUpFill;
			combinedUp.totalLine = totalUpLine;

			var dnScaleEl = document.getElementById('total_dn_scale');
			var upScaleEl = document.getElementById('total_up_scale');
			if (dnScaleEl) dnScaleEl.textContent = '(' + minWin + ' ' + _('minutes window, 1 second interval') + ')';
			if (upScaleEl) upScaleEl.textContent = '(' + minWin + ' ' + _('minutes window, 1 second interval') + ')';

			self._state = {
				mode:        'all',
				step:        step,
				wanted:      wanted,
				stamp:       0,
				stampIface:  {},
				cards:       cards,
				ifaces:      ifaces.map(function(iface) { return iface.name; }),
				combinedDn:  combinedDn,
				combinedUp:  combinedUp,
				dndata:      {},
				updata:      {},
				totalDn:     [],
				totalUp:     []
			};
			ifaces.forEach(function(iface) {
				self._state.dndata[iface.name] = [];
				self._state.updata[iface.name] = [];
				self._state.stampIface[iface.name] = 0;
			});

			/* Hover tooltips */
			self._addSVGHover('total_dn_svg', totalHeight, function(svgX) {
				var st = self._state;
				if (!st || st.mode !== 'all') return null;
				var lines = [];
				var ti = self._xToIndex(svgX, st.totalDn.length);
				if (ti >= 0) lines.push('<span style="color:#5aabff">\u25bc\u00a0' + _('Total') + ':</span> ' + self._bwLabel(st.totalDn[ti] || 0, false));
				st.ifaces.forEach(function(itf) {
					var series = (st.dndata && st.dndata[itf]) || [];
					var j = self._xToIndex(svgX, series.length);
					if (j < 0) return;
					var c = st.cards[itf];
					lines.push('<span style="color:' + (c ? c.color : '#aaa') + '">' + '%h'.format(c ? c.label : itf) + ':</span> ' + self._bwLabel(series[j] || 0, false));
				});
				return lines.length ? lines.join('<br>') : null;
			});
			self._addSVGHover('total_up_svg', totalHeight, function(svgX) {
				var st = self._state;
				if (!st || st.mode !== 'all') return null;
				var lines = [];
				var ti = self._xToIndex(svgX, st.totalUp.length);
				if (ti >= 0) lines.push('<span style="color:#3ecfa8">\u25b2\u00a0' + _('Total') + ':</span> ' + self._bwLabel(st.totalUp[ti] || 0, false));
				st.ifaces.forEach(function(itf) {
					var series = (st.updata && st.updata[itf]) || [];
					var j = self._xToIndex(svgX, series.length);
					if (j < 0) return;
					var c = st.cards[itf];
					lines.push('<span style="color:' + (c ? c.color : '#aaa') + '">' + '%h'.format(c ? c.label : itf) + ':</span> ' + self._bwLabel(series[j] || 0, false));
				});
				return lines.length ? lines.join('<br>') : null;
			});
		});
	},

	/* ------------------------------------------------------------------ *
	 *  Single-interface chart construction                               *
	 * ------------------------------------------------------------------ */

	_buildIfaceChart: function(area, tab) {
		var self  = this;
		var color = this._ifaceColor(tab.name);
		var badgeStyle  = 'background:' + color + '18;color:' + color + ';border-color:' + color + '55;';
		var chartHeight = Math.max(160, Math.round(this.HEIGHT * 0.58));

		var makeStats = function(prefix) {
			return E('div', { 'class': 'mptcp-chart-block__stats' }, [
				E('div', { 'class': 'mptcp-stat' }, [
					E('span', { 'class': 'mptcp-stat__label' }, _('Current')),
					E('span', { 'id': prefix + '_cur', 'class': 'mptcp-stat__value' }, '0 ' + _('kbit/s'))
				]),
				E('div', { 'class': 'mptcp-stat' }, [
					E('span', { 'class': 'mptcp-stat__label' }, _('Average')),
					E('span', { 'id': prefix + '_avg', 'class': 'mptcp-stat__value' }, '0 ' + _('kbit/s'))
				]),
				E('div', { 'class': 'mptcp-stat' }, [
					E('span', { 'class': 'mptcp-stat__label' }, _('Peak')),
					E('span', { 'id': prefix + '_peak', 'class': 'mptcp-stat__value' }, '0 ' + _('kbit/s'))
				])
			]);
		};

		var card = E('div', { 'class': 'mptcp-wan-card' }, [
			E('div', { 'class': 'mptcp-wan-card__header' }, [
				E('div', {}, [
					E('div', { 'class': 'mptcp-wan-card__title' }, [ tab.label ]),
					E('div', { 'class': 'mptcp-wan-card__meta' }, [ tab.device || '' ])
				]),
				E('span', { 'class': 'mptcp-wan-card__badge', 'style': badgeStyle }, [ tab.name ])
			]),
			E('div', { 'class': 'mptcp-chart-block' }, [
				E('div', { 'class': 'mptcp-chart-block__title' }, _('Inbound traffic')),
				self._createSVG('bwsvg_dn', chartHeight),
				makeStats('rx_bw'),
				E('div', { 'id': 'bwscale_dn', 'class': 'mptcp-chart-block__meta' }, '-')
			]),
			E('div', { 'class': 'mptcp-chart-block' }, [
				E('div', { 'class': 'mptcp-chart-block__title' }, _('Outbound traffic')),
				self._createSVG('bwsvg_up', chartHeight),
				makeStats('tx_bw'),
				E('div', { 'id': 'bwscale_up', 'class': 'mptcp-chart-block__meta' }, '-')
			])
		]);
		area.appendChild(card);

		var NS = 'http://www.w3.org/2000/svg';
		['dn', 'up'].forEach(function(dir) {
			var g = document.getElementById('bwsvg_' + dir + '_g');
			var fill = document.createElementNS(NS, 'polyline');
			fill.id = 'bwsvg_' + dir + '_fill';
			fill.setAttribute('style', 'fill:' + color + ';fill-opacity:0.18;stroke:none');
			if (g) g.appendChild(fill);
			var line = document.createElementNS(NS, 'polyline');
			line.id = 'bwsvg_' + dir + '_line';
			line.setAttribute('style', 'fill:none;stroke:' + color + ';stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round');
			if (g) g.appendChild(line);
		});

		requestAnimationFrame(function() {
			var width  = self.WIDTH;
			var height = chartHeight;
			var step   = self.STEP;
			var wanted = Math.ceil(width / step);
			var minWin = Math.round(wanted / 60);

			self._addTimeLines('bwsvg_dn', width, height, step);
			self._addTimeLines('bwsvg_up', width, height, step);

			var scDn = document.getElementById('bwscale_dn');
			var scUp = document.getElementById('bwscale_up');
			if (scDn) scDn.textContent = '(' + minWin + ' ' + _('minutes window, 1 second interval') + ')';
			if (scUp) scUp.textContent = '(' + minWin + ' ' + _('minutes window, 1 second interval') + ')';

			self._state = {
				mode:   'iface',
				device: tab.device,
				width:  width,
				height: height,
				step:   step,
				wanted: wanted,
				stamp:  0,
				dataRx: [],
				dataTx: []
			};

			self._addSVGHover('bwsvg_dn', height, function(svgX) {
				var st = self._state;
				if (!st || st.mode !== 'iface') return null;
				var i = self._xToIndex(svgX, st.dataRx.length);
				if (i < 0) return null;
				return '<span style="color:#6699ff">\u25bc\u00a0' + _('In') + ':</span> ' + self._bwLabel(st.dataRx[i] || 0, false);
			});
			self._addSVGHover('bwsvg_up', height, function(svgX) {
				var st = self._state;
				if (!st || st.mode !== 'iface') return null;
				var i = self._xToIndex(svgX, st.dataTx.length);
				if (i < 0) return null;
				return '<span style="color:#44cc88">\u25b2\u00a0' + _('Out') + ':</span> ' + self._bwLabel(st.dataTx[i] || 0, false);
			});
		});
	},

	/* ------------------------------------------------------------------ *
	 *  Poll dispatcher                                                    *
	 * ------------------------------------------------------------------ */

	_tick: function() {
		if (!this._state) return Promise.resolve();
		if (this._state.mode === 'all')   return this._pollAll();
		if (this._state.mode === 'iface') return this._pollIface();
		return Promise.resolve();
	},

	/* ------------------------------------------------------------------ *
	 *  "All interfaces" poll & render                                    *
	 * ------------------------------------------------------------------ */

	_pollAll: function() {
		var self = this;
		var st   = this._state;

		return callMultipathBandwidth().then(function(raw) {
			if (!st || st.mode !== 'all') return;
			if (!raw || typeof raw !== 'object') return;

			/* Accept both direct payload and wrapped { data: ... } payloads */
			var payload = (raw.data && typeof raw.data === 'object') ? raw.data : raw;

			/* Interface data can arrive as arrays, strings or wrapped arrays */
			var parsed = {};
			var keys = Object.keys(payload);
			var nextStamp = st.stamp;

			keys.forEach(function(itf) {
				var v = payload[itf];
				if (Array.isArray(v)) {
					parsed[itf] = v;
				}
				else if (v && Array.isArray(v.data)) {
					parsed[itf] = v.data;
				}
				else if (typeof v === 'string' && v !== '') {
					try {
						var j = JSON.parse(v);
						if (Array.isArray(j))
							parsed[itf] = j;
					} catch (e) {}
				}
			});

			/* Append new data points using per-interface stamps so a slow/short
			   interface is not permanently frozen by a faster one's stamp. */
			st.ifaces.forEach(function(itf) {
				var d = parsed[itf];
				if (!d) return;
				var prev = st.stampIface[itf] || 0;
				for (var i = (prev ? 0 : 1); i < d.length; i++) {
					if (d[i][0] <= prev) continue;
					if (i > 0) {
						var dt = d[i][0] - d[i-1][0];
						if (dt) {
							st.dndata[itf].push(self._sma('dn_'+itf, 15, Math.max(0, (d[i][1]-d[i-1][1])/dt)));
							st.updata[itf].push(self._sma('up_'+itf, 15, Math.max(0, (d[i][3]-d[i-1][3])/dt)));
						}
					}
				}
				st.dndata[itf] = st.dndata[itf].slice(-st.wanted);
				st.updata[itf] = st.updata[itf].slice(-st.wanted);
				if (d.length) {
					st.stampIface[itf] = d[d.length-1][0];
					nextStamp = Math.max(nextStamp, st.stampIface[itf]);
				}
			});

			var totalSeries = parsed.total;
			if (totalSeries) {
				var prevTotal = st.stamp;
				for (var ti = (prevTotal ? 0 : 1); ti < totalSeries.length; ti++) {
					if (totalSeries[ti][0] <= prevTotal) continue;
					if (ti > 0) {
						var tdt = totalSeries[ti][0] - totalSeries[ti - 1][0];
						if (tdt) {
							st.totalDn.push(self._sma('dn_total', 15, Math.max(0, (totalSeries[ti][1] - totalSeries[ti - 1][1]) / tdt)));
							st.totalUp.push(self._sma('up_total', 15, Math.max(0, (totalSeries[ti][3] - totalSeries[ti - 1][3]) / tdt)));
						}
					}
				}
				st.totalDn = st.totalDn.slice(-st.wanted);
				st.totalUp = st.totalUp.slice(-st.wanted);
				nextStamp = Math.max(nextStamp, totalSeries[totalSeries.length - 1][0]);
			}

			st.stamp = nextStamp;

			if (st.combinedDn && st.combinedUp) {
				var scDnAll, scUpAll;
				var cDn = st.combinedDn, cUp = st.combinedUp;

				/* Align all series to globalStamp:
				   1. Right-pad lagging interfaces with their last known value.
				   2. Left-pad shorter histories with 0 so all start at the same x. */
				var globalStamp = st.stamp;
				function alignSeries(s, itfStamp) {
					var lag = (itfStamp > 0) ? Math.max(0, Math.round(globalStamp - itfStamp)) : 0;
					if (lag === 0) return s;
					var lastVal = s.length > 0 ? s[s.length - 1] : 0;
					var out = s.slice();
					for (var _p = 0; _p < Math.min(lag, st.wanted); _p++) out.push(lastVal);
					return out;
				}
				var alignedDn = {}, alignedUp = {};
				var refLen = 0;
				st.ifaces.forEach(function(itf) {
					var aDn = alignSeries(st.dndata[itf] || [], st.stampIface[itf] || 0);
					var aUp = alignSeries(st.updata[itf] || [], st.stampIface[itf] || 0);
					alignedDn[itf] = aDn;
					alignedUp[itf] = aUp;
					refLen = Math.max(refLen, aDn.length, aUp.length);
				});
				function padLeft(s) {
					if (s.length >= refLen) return s;
					var z = new Array(refLen - s.length); for (var _i = 0; _i < z.length; _i++) z[_i] = 0;
					return z.concat(s);
				}

				/* Compute total as element-wise sum of per-interface rate series.
				   This avoids the cumulative-counter alignment bug where timestamps
				   from different interfaces interleave, causing negative/zero rates. */
				var totalDnP = new Array(refLen);
				var totalUpP = new Array(refLen);
				for (var _k = 0; _k < refLen; _k++) { totalDnP[_k] = 0; totalUpP[_k] = 0; }
				st.ifaces.forEach(function(itf) {
					var aDn = padLeft(alignedDn[itf] || []);
					var aUp = padLeft(alignedUp[itf] || []);
					for (var _k = 0; _k < refLen; _k++) {
						totalDnP[_k] += (aDn[_k] || 0);
						totalUpP[_k] += (aUp[_k] || 0);
					}
				});

				var totalDnStats = self._seriesStats(totalDnP);
				var totalUpStats = self._seriesStats(totalUpP);
				var maxDnAll = Math.max(totalDnStats.peak, 1);
				var maxUpAll = Math.max(totalUpStats.peak, 1);
				scDnAll  = st.combinedDn.height / (maxDnAll * 1.15);
				scUpAll  = st.combinedUp.height / (maxUpAll * 1.15);
				if (cDn.totalFill) cDn.totalFill.setAttribute('points', self._areaPoints(totalDnP, cDn.width, cDn.height, st.step, scDnAll));
				if (cDn.totalLine) cDn.totalLine.setAttribute('points', self._linePoints(totalDnP, cDn.width, cDn.height, st.step, scDnAll));
				if (cUp.totalFill) cUp.totalFill.setAttribute('points', self._areaPoints(totalUpP, cUp.width, cUp.height, st.step, scUpAll));
				if (cUp.totalLine) cUp.totalLine.setAttribute('points', self._linePoints(totalUpP, cUp.width, cUp.height, st.step, scUpAll));

				st.ifaces.forEach(function(itf) {
					var dnSeries = padLeft(alignedDn[itf] || []);
					var upSeries = padLeft(alignedUp[itf] || []);
					var il = cDn.ifaceLines[itf];
					var ul = cUp.ifaceLines[itf];
					if (il) {
						if (il.fill) il.fill.setAttribute('points', self._areaPoints(dnSeries, cDn.width, cDn.height, st.step, scDnAll));
						if (il.line) il.line.setAttribute('points', self._linePoints(dnSeries, cDn.width, cDn.height, st.step, scDnAll));
					}
					if (ul) {
						if (ul.fill) ul.fill.setAttribute('points', self._areaPoints(upSeries, cUp.width, cUp.height, st.step, scUpAll));
						if (ul.line) ul.line.setAttribute('points', self._linePoints(upSeries, cUp.width, cUp.height, st.step, scUpAll));
					}
				});

				/* per-interface stats update */
				st.ifaces.forEach(function(itf) {
					var sid    = self._domSafeId(itf);
					var dnSer  = padLeft(alignedDn[itf] || []);
					var upSer  = padLeft(alignedUp[itf] || []);
					var dnSt   = self._seriesStats(dnSer);
					var upSt   = self._seriesStats(upSer);
					[
						{ id: 'total_dn_' + sid + '_cur',  v: dnSt.current },
						{ id: 'total_dn_' + sid + '_avg',  v: dnSt.average },
						{ id: 'total_dn_' + sid + '_peak', v: dnSt.peak },
						{ id: 'total_up_' + sid + '_cur',  v: upSt.current },
						{ id: 'total_up_' + sid + '_avg',  v: upSt.average },
						{ id: 'total_up_' + sid + '_peak', v: upSt.peak }
					].forEach(function(entry) {
						var el = document.getElementById(entry.id);
						if (el) el.innerHTML = self._bwLabel(entry.v, true);
					});
				});

				[25, 50, 75].forEach(function(pct) {
					self._scaleLbl(cDn.id, pct, maxDnAll * 1.15);
					self._scaleLbl(cUp.id, pct, maxUpAll * 1.15);
				});

				[
					{ id: 'total_dn_cur',  v: totalDnStats.current },
					{ id: 'total_dn_avg',  v: totalDnStats.average },
					{ id: 'total_dn_peak', v: totalDnStats.peak },
					{ id: 'total_up_cur',  v: totalUpStats.current },
					{ id: 'total_up_avg',  v: totalUpStats.average },
					{ id: 'total_up_peak', v: totalUpStats.peak }
				].forEach(function(entry) {
					var el = document.getElementById(entry.id);
					if (el) el.innerHTML = self._bwLabel(entry.v, true);
				});
			}
		}).catch(function() {});
	},

	/* ------------------------------------------------------------------ *
	 *  Single-interface poll & render                                    *
	 * ------------------------------------------------------------------ */

	_pollIface: function() {
		var self = this;
		var st   = this._state;

		return callIfaceBandwidth(st.device).then(function(data) {
			if (!st || st.mode !== 'iface') return;
			if (!Array.isArray(data) || !data.length) return;

			for (var i = (st.stamp ? 0 : 1); i < data.length; i++) {
				if (data[i][0] <= st.stamp) continue;
				if (i > 0) {
					var dt = data[i][0] - data[i-1][0];
					if (dt) {
						st.dataRx.push((data[i][1] - data[i-1][1]) / dt);
						st.dataTx.push((data[i][3] - data[i-1][3]) / dt);
					}
				}
			}
			st.dataRx = st.dataRx.slice(-st.wanted);
			st.dataTx = st.dataTx.slice(-st.wanted);
			st.stamp  = data[data.length-1][0];

			var rxStats = self._seriesStats(st.dataRx);
			var txStats = self._seriesStats(st.dataTx);
			var maxRx = Math.max(rxStats.peak, 1);
			var maxTx = Math.max(txStats.peak, 1);
			var scRx  = st.height / (maxRx * 1.15);
			var scTx  = st.height / (maxTx * 1.15);

			var dnFill = document.getElementById('bwsvg_dn_fill');
			var dnLine = document.getElementById('bwsvg_dn_line');
			var upFill = document.getElementById('bwsvg_up_fill');
			var upLine = document.getElementById('bwsvg_up_line');
			if (dnFill) dnFill.setAttribute('points', self._areaPoints(st.dataRx, st.width, st.height, st.step, scRx));
			if (dnLine) dnLine.setAttribute('points', self._linePoints(st.dataRx, st.width, st.height, st.step, scRx));
			if (upFill) upFill.setAttribute('points', self._areaPoints(st.dataTx, st.width, st.height, st.step, scTx));
			if (upLine) upLine.setAttribute('points', self._linePoints(st.dataTx, st.width, st.height, st.step, scTx));

			[25, 50, 75].forEach(function(pct) {
				self._scaleLbl('bwsvg_dn', pct, maxRx * 1.15);
				self._scaleLbl('bwsvg_up', pct, maxTx * 1.15);
			});

			[
				{ id: 'rx_bw_cur',  v: rxStats.current },
				{ id: 'rx_bw_avg',  v: rxStats.average },
				{ id: 'rx_bw_peak', v: rxStats.peak },
				{ id: 'tx_bw_cur',  v: txStats.current },
				{ id: 'tx_bw_avg',  v: txStats.average },
				{ id: 'tx_bw_peak', v: txStats.peak }
			].forEach(function(c) {
				var el = document.getElementById(c.id);
				if (el) el.innerHTML = self._bwLabel(c.v, true);
			});
		}).catch(function() {});
	},

	handleSaveApply: null,
	handleSave:      null,
	handleReset:     null
});
