'use strict';
'require view';
'require rpc';
'require poll';
'require dom';
'require ui';

/* rpc.declare() binds "params" positionally, not by object key: callers
 * below must pass arguments in this exact order (empty string / 0 to skip
 * a filter), not a { interface: ... } options object. */
var callEventsGetEvents = rpc.declare({
	object: 'events',
	method: 'get_events',
	params: [ 'interface', 'event', 'reason', 'since', 'limit' ],
	expect: { '': {} }
});

var callEventsGetSummary = rpc.declare({
	object: 'events',
	method: 'get_summary',
	expect: { '': {} }
});

var callEventsClear = rpc.declare({
	object: 'events',
	method: 'clear',
	expect: { '': {} }
});

var REASON_LABELS = {
	'link_down':    _('Link down'),
	'gateway_down': _('Gateway down'),
	'high_latency': _('High latency'),
	'packet_loss':  _('Packet loss'),
	'no_answer':    _('No answer from server'),
	'no_ip':        _('No IP / gateway'),
	'vpn_path':     _('VPN path'),
	'recovered':    _('Recovered'),
	'unknown':      _('Unknown'),
	'other':        _('Other')
};

var REASON_COLORS = {
	'link_down':    '#f44336',
	'gateway_down': '#f44336',
	'high_latency': '#ff9800',
	'packet_loss':  '#ff9800',
	'no_answer':    '#f44336',
	'no_ip':        '#f44336',
	'vpn_path':     '#9c27b0',
	'recovered':    '#4caf50',
	'unknown':      '#aaa',
	'other':        '#aaa'
};

return view.extend({
	/* Auto-refresh interval in seconds */
	POLL_INTERVAL: 10,

	load: function() {
		return Promise.all([
			callEventsGetEvents('', '', '', 0, 500),
			callEventsGetSummary()
		]);
	},

	_fmtTs: function(ts) {
		if (ts == null) return '—';
		return new Date(ts * 1000).toLocaleString();
	},

	_eventBadge: function(evt) {
		var color = (evt === 'up') ? '#4caf50' : (evt === 'down') ? '#f44336' : '#aaa';
		var label = (evt === 'up') ? _('Up') : (evt === 'down') ? _('Down') : (evt || '—');
		return E('span', {
			style: 'display:inline-block;padding:2px 8px;border-radius:4px;' +
			       'background:' + color + ';color:#fff;font-size:0.85em;font-weight:bold'
		}, [ label ]);
	},

	_reasonBadge: function(reason) {
		if (!reason) return E('span', {}, [ '—' ]);
		var color = REASON_COLORS[reason] || '#aaa';
		var label = REASON_LABELS[reason] || reason;
		return E('span', {
			style: 'display:inline-block;padding:1px 6px;border-radius:3px;border:1px solid ' + color +
			       ';color:' + color + ';font-size:0.82em'
		}, [ label ]);
	},

	_uniqueInterfaces: function(events) {
		var seen = {}, out = [];
		(events || []).forEach(function(e) {
			if (e.interface && !seen[e.interface]) { seen[e.interface] = true; out.push(e.interface); }
		});
		return out.sort();
	},

	_renderSummary: function(summary) {
		if (!summary) return null;

		var rows = [
			[ _('Total events kept'), String(summary.count || 0) ],
			[ _('Log size'), ((summary.size_bytes || 0) / 1024).toFixed(1) + ' KB' ],
			[ _('Oldest event'), this._fmtTs(summary.oldest) ],
			[ _('Newest event'), this._fmtTs(summary.newest) ],
			[ _('Retention'), _('%d days or %d MB, whichever comes first')
				.format(Math.round((summary.max_age || 0) / 86400), Math.round((summary.max_size || 0) / 1048576)) ]
		];

		var tbody = E('tbody');
		rows.forEach(function(r) {
			tbody.appendChild(E('tr', {}, [
				E('td', { style: 'padding:3px 12px 3px 0;color:#666;white-space:nowrap;font-size:0.9em' }, [ r[0] ]),
				E('td', { style: 'padding:3px 0;font-weight:500;font-size:0.9em' }, [ r[1] ])
			]));
		});

		var perIface = summary.per_interface || {};
		var ifaceRows = Object.keys(perIface).sort().map(function(name) {
			var c = perIface[name] || {};
			return E('div', { style: 'display:flex;justify-content:space-between;gap:16px;font-size:0.85em;padding:2px 0' }, [
				E('span', {}, [ name ]),
				E('span', { style: 'color:#888' }, [ (c.down || 0) + ' ' + _('down') + ' / ' + (c.total || 0) + ' ' + _('total') ])
			]);
		});

		return E('div', {
			style: 'display:flex;flex-wrap:wrap;gap:16px;border:1px solid #ddd;border-radius:6px;' +
			       'padding:10px 14px;margin-bottom:16px;background:#f9f9f9'
		}, [
			E('div', { style: 'flex:1;min-width:220px' }, [
				E('table', { style: 'border-collapse:collapse' }, [ tbody ])
			]),
			ifaceRows.length ? E('div', { style: 'flex:1;min-width:200px' }, [
				E('strong', { style: 'font-size:0.85em;color:#345' }, [ _('Per interface') ]),
				E('div', { style: 'margin-top:4px' }, ifaceRows)
			]) : E('div')
		]);
	},

	_renderTable: function(events) {
		var self = this;
		var table = E('table', { class: 'table', style: 'width:100%;border-collapse:collapse' }, [
			E('tr', { class: 'tr table-titles' }, [
				E('th', { class: 'th' }, [ _('Time') ]),
				E('th', { class: 'th' }, [ _('Interface') ]),
				E('th', { class: 'th' }, [ _('Device') ]),
				E('th', { class: 'th' }, [ _('Event') ]),
				E('th', { class: 'th' }, [ _('Reason') ]),
				E('th', { class: 'th' }, [ _('Message') ]),
				E('th', { class: 'th' }, [ _('Latency') ]),
				E('th', { class: 'th' }, [ _('Loss') ])
			])
		]);

		if (!events || !events.length) {
			table.appendChild(E('tr', { class: 'tr' }, [
				E('td', { class: 'td', colspan: 8, style: 'text-align:center;color:#888;font-style:italic' }, [
					_('No events recorded yet.')
				])
			]));
			return table;
		}

		/* Newest first */
		events.slice().sort(function(a, b) { return (b.ts || 0) - (a.ts || 0); }).forEach(function(e) {
			table.appendChild(E('tr', { class: 'tr' }, [
				E('td', { class: 'td', style: 'white-space:nowrap' }, [ self._fmtTs(e.ts) ]),
				E('td', { class: 'td' }, [ e.interface || '—' ]),
				E('td', { class: 'td' }, [ e.device || '—' ]),
				E('td', { class: 'td' }, [ self._eventBadge(e.event) ]),
				E('td', { class: 'td' }, [ self._reasonBadge(e.reason) ]),
				E('td', { class: 'td', style: 'max-width:320px;overflow-wrap:anywhere;color:#555;font-size:0.9em' }, [ e.message || '—' ]),
				E('td', { class: 'td' }, [ e.latency != null ? e.latency + ' ms' : '—' ]),
				E('td', { class: 'td' }, [ e.loss != null ? e.loss + ' %' : '—' ])
			]));
		});

		return table;
	},

	_buildFilters: function(events, onChange) {
		var self = this;
		var ifaceSelect = E('select', { class: 'cbi-input-select' }, [
			E('option', { value: '' }, [ _('All interfaces') ])
		]);
		self._uniqueInterfaces(events).forEach(function(name) {
			ifaceSelect.appendChild(E('option', { value: name }, [ name ]));
		});

		var eventSelect = E('select', { class: 'cbi-input-select' }, [
			E('option', { value: '' }, [ _('Up & Down') ]),
			E('option', { value: 'up' }, [ _('Up only') ]),
			E('option', { value: 'down' }, [ _('Down only') ])
		]);

		var reasonSelect = E('select', { class: 'cbi-input-select' }, [
			E('option', { value: '' }, [ _('All reasons') ])
		]);
		Object.keys(REASON_LABELS).forEach(function(key) {
			reasonSelect.appendChild(E('option', { value: key }, [ REASON_LABELS[key] ]));
		});

		[ifaceSelect, eventSelect, reasonSelect].forEach(function(sel) {
			sel.addEventListener('change', function() {
				onChange({
					interface: ifaceSelect.value || undefined,
					event: eventSelect.value || undefined,
					reason: reasonSelect.value || undefined
				});
			});
		});

		var clearBtn = E('button', { class: 'cbi-button cbi-button-negative' }, [ _('Clear history') ]);
		clearBtn.addEventListener('click', ui.createHandlerFn(this, function() {
			return ui.showModal(_('Clear event history'), [
				E('p', {}, [ _('This permanently deletes every recorded interface event. Continue?') ]),
				E('div', { class: 'right' }, [
					E('button', { class: 'btn', click: ui.hideModal }, [ _('Cancel') ]),
					E('button', {
						class: 'btn cbi-button-negative',
						click: ui.createHandlerFn(this, function() {
							return callEventsClear().then(function() {
								ui.hideModal();
								location.reload();
							});
						})
					}, [ _('Clear') ])
				])
			]);
		}));

		return E('div', { style: 'display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:12px' }, [
			ifaceSelect, eventSelect, reasonSelect,
			E('div', { style: 'flex:1' }),
			clearBtn
		]);
	},

	render: function(results) {
		var self = this;
		var events  = (results[0] && results[0].events) || [];
		var summary = results[1] || {};

		var tableContainer = E('div', { id: 'omr-events-table' }, [ self._renderTable(events) ]);
		var summaryContainer = E('div', { id: 'omr-events-summary' }, [ self._renderSummary(summary) ]);

		var currentFilter = {};

		var refresh = function(filter) {
			currentFilter = filter || currentFilter;
			return Promise.all([
				callEventsGetEvents(
					currentFilter.interface || '',
					currentFilter.event || '',
					currentFilter.reason || '',
					0,
					500
				),
				callEventsGetSummary()
			]).then(function(r) {
				var evts = (r[0] && r[0].events) || [];
				dom.content(tableContainer, self._renderTable(evts));
				dom.content(summaryContainer, self._renderSummary(r[1] || {}));
			});
		};

		var filterBar = self._buildFilters(events, function(filter) { refresh(filter); });

		var view = E('div', {}, [
			E('h2', {}, [ _('Interface Events') ]),
			E('p', { style: 'color:#555;margin-bottom:16px' }, [
				_('History of UP/DOWN transitions and their cause (high latency, packet loss, gateway or link loss, ...) as detected by omr-tracker. Refreshes every %d seconds.').format(self.POLL_INTERVAL)
			]),
			summaryContainer,
			filterBar,
			tableContainer
		]);

		poll.add(function() { return refresh(); }, self.POLL_INTERVAL);

		return view;
	},

	handleSaveApply: null,
	handleSave:      null,
	handleReset:     null
});
