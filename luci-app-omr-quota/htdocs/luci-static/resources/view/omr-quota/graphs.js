'use strict';
'require view';
'require rpc';
'require poll';

var callQuotaGetStatus = rpc.declare({
	object: 'quota',
	method: 'get_status',
	expect: { '': { interfaces: [] } }
});

return view.extend({
	POLL_INTERVAL: 15,

	load: function() {
		return callQuotaGetStatus();
	},

	_fmtKib: function(kib) {
		if (kib == null) return '—';
		var bytes = kib * 1024;
		if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(2) + ' GB';
		if (bytes >= 1048576)    return (bytes / 1048576).toFixed(2) + ' MB';
		if (bytes >= 1024)       return (bytes / 1024).toFixed(1) + ' KB';
		return bytes + ' B';
	},

	_badge: function(label, color) {
		return E('span', {
			style: 'display:inline-block;padding:2px 8px;border-radius:4px;margin-left:6px;' +
			       'background:' + color + ';color:#fff;font-size:0.75em;font-weight:bold'
		}, [ label ]);
	},

	_bar: function(label, used, quota, pct, exceeded) {
		var self = this;
		if (!quota) return null;

		pct = Math.max(Number(pct) || 0, quota > 0 ? (used * 100 / quota) : 0);
		var color = exceeded ? '#f44336' : (pct >= 85 ? '#ff9800' : '#4caf50');
		var remaining = Math.max(0, quota - used);
		var pctLabel = pct > 0 && pct < 1 ? '<1' : pct.toFixed(0);
		var width = Math.min(100, Math.max(pct > 0 ? 1 : 0, pct));

		return E('div', { style: 'margin-bottom:10px' }, [
			E('div', { style: 'display:flex;justify-content:space-between;font-size:0.85em;color:#555;margin-bottom:2px' }, [
				E('span', {}, [ label ]),
				E('span', {}, [ self._fmtKib(used) + ' / ' + self._fmtKib(quota) + ' (' + pctLabel + '%)' ])
			]),
			E('div', {
				'class': 'cbi-progressbar',
				title: pctLabel + '%'
			}, [
				E('div', { style: 'width:' + width + '%;background:' + color })
			]),
			E('div', { style: 'font-size:0.8em;color:#888;margin-top:2px' }, [
				_('Remaining: %s').format(self._fmtKib(remaining))
			])
		]);
	},

	_renderCard: function(iface) {
		var self = this;
		var name = iface.type === 'global'
			? _('Global — %s').format(iface.interfaces || '?')
			: (iface.name || '?');
		var enabled = iface.enabled === '1' || iface.enabled === 1;

		var bars = [
			self._bar(_('Total (RX+TX)'), iface.tt_kib, iface.ttquota, iface.tt_pct, iface.exceeded),
			self._bar(_('Download (RX)'), iface.rx_kib, iface.rxquota, iface.rx_pct, iface.exceeded),
			self._bar(_('Upload (TX)'),   iface.tx_kib, iface.txquota, iface.tx_pct, iface.exceeded)
		].filter(function(b) { return b != null; });

		var badges = [];
		if (!enabled) badges.push(self._badge(_('Disabled'), '#999'));
		if (enabled && iface.exceeded) badges.push(self._badge(_('Exceeded'), '#f44336'));
		if (enabled && iface.throttled) badges.push(self._badge(_('Throttled'), '#ff9800'));

		var meta = _('Action: %s · Scope: %s').format(iface.exceedance_action || '—', iface.exceedance_scope || '—');

		return E('div', {
			style: 'border:1px solid #ddd;border-radius:6px;padding:12px;margin-bottom:16px;background:#fff;' +
			       (enabled ? '' : 'opacity:0.6')
		}, [
			E('div', { style: 'display:flex;align-items:center;margin-bottom:10px' }, [
				E('strong', { style: 'font-size:1.05em' }, [ name ]),
				E('span', {}, badges)
			]),
			bars.length ? E('div', {}, bars) : E('p', { style: 'color:#888;font-style:italic;margin:0' }, [
				_('No quota configured.')
			]),
			E('div', { style: 'font-size:0.78em;color:#aaa;margin-top:4px' }, [ meta ])
		]);
	},

	_buildPage: function(data, container) {
		var self = this;
		var ifaces = (data && data.interfaces) ? data.interfaces : [];
		if (!container) return;

		while (container.firstChild) container.removeChild(container.firstChild);

		if (!ifaces.length) {
			container.appendChild(
				E('p', { style: 'color:#888;font-style:italic' }, [
					_('No interfaces configured. Add one under Network → Quota → Settings.')
				])
			);
			return;
		}

		ifaces.forEach(function(iface) {
			container.appendChild(self._renderCard(iface));
		});
	},

	render: function(data) {
		var self = this;

		var container = E('div', { id: 'omr-quota-graphs-container' });
		var view = E('div', {}, [
			E('h2', {}, [ _('Quota — Graphs') ]),
			E('p', { style: 'color:#555;margin-bottom:16px' }, [
				_('Current-month usage and remaining data per interface. Refreshes every %d seconds.').format(self.POLL_INTERVAL)
			]),
			container
		]);

		self._buildPage(data, container);

		poll.add(function() {
			return callQuotaGetStatus().then(function(r) {
				self._buildPage(r, container);
			});
		}, self.POLL_INTERVAL);

		return view;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
