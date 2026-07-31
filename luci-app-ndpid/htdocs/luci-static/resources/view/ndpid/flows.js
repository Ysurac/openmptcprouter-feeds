'use strict';
'require view';
'require poll';
'require rpc';
'require dom';

var callGetFlows = rpc.declare({
	object: 'luci.ndpid',
	method: 'get_flows',
	expect: { '': { flows: [], total: 0 } }
});

var callGetStatus = rpc.declare({
	object: 'luci.ndpid',
	method: 'get_status',
	expect: { '': { ndpid_running: false, tracker_running: false, flow_count: 0 } }
});

return view.extend({
	POLL_INTERVAL: 5,

	_filterText: '',

	load: function() {
		return Promise.all([ callGetStatus(), callGetFlows() ]);
	},

	render: function(data) {
		var status = data[0] || {};
		var flowsData = data[1] || {};

		var statusDiv = E('div', { 'class': 'cbi-section', 'id': 'ndpid-status' });
		var filterRow = E('div', { 'style': 'margin-bottom:8px;display:flex;align-items:center;gap:8px;' }, [
			E('label', {}, [ _('Filter:') ]),
			E('input', {
				'type': 'text',
				'id': 'ndpid-filter',
				'placeholder': _('Application, protocol, IP…'),
				'style': 'flex:1;max-width:320px;',
				'input': L.bind(function(ev) {
					this._filterText = ev.target.value.toLowerCase();
					this._applyFilter();
				}, this)
			}),
			E('span', { 'id': 'ndpid-count', 'style': 'margin-left:8px;color:#666;' })
		]);

		var table = E('table', {
			'class': 'table cbi-section-table',
			'id': 'ndpid-flows-table',
			'style': 'width:100%;table-layout:fixed;'
		}, [
			E('thead', {}, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th', 'style': 'width:18%' }, [ _('Application') ]),
					E('th', { 'class': 'th', 'style': 'width:10%' }, [ _('Carrier') ]),
					E('th', { 'class': 'th', 'style': 'width:12%' }, [ _('Category') ]),
					E('th', { 'class': 'th', 'style': 'width:10%' }, [ _('L4') ]),
					E('th', { 'class': 'th', 'style': 'width:18%' }, [ _('Source') ]),
					E('th', { 'class': 'th', 'style': 'width:18%' }, [ _('Destination') ]),
					E('th', { 'class': 'th', 'style': 'width:8%', 'style': 'text-align:right' }, [ _('Packets') ]),
					E('th', { 'class': 'th', 'style': 'width:6%' }, [ _('State') ]),
				])
			]),
			E('tbody', { 'id': 'ndpid-flows-body' })
		]);

		var summaryDiv = E('div', { 'id': 'ndpid-summary', 'style': 'display:flex;gap:24px;margin-bottom:12px;flex-wrap:wrap;' });

		var container = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, [ _('nDPId Active Flows') ]),
			statusDiv,
			summaryDiv,
			filterRow,
			table
		]);

		this._updateStatus(statusDiv, status);
		this._updateSummary(summaryDiv, flowsData.flows || []);
		this._updateTable(flowsData.flows || []);

		poll.add(L.bind(function() {
			return Promise.all([ callGetStatus(), callGetFlows() ]).then(L.bind(function(res) {
				var flows = (res[1] || {}).flows || [];
				this._updateStatus(statusDiv, res[0] || {});
				this._updateSummary(summaryDiv, flows);
				this._updateTable(flows);
			}, this));
		}, this), this.POLL_INTERVAL);

		return container;
	},

	_updateStatus: function(div, s) {
		var ndpidState  = s.ndpid_running   ? E('span', { 'style': 'color:green' }, [ _('running') ])
		                                     : E('span', { 'style': 'color:red'  }, [ _('stopped') ]);
		var trackerState = s.tracker_running  ? E('span', { 'style': 'color:green' }, [ _('running') ])
		                                      : E('span', { 'style': 'color:red'  }, [ _('stopped') ]);

		dom.content(div, [
			E('p', {}, [
				_('nDPId:'), ' ', ndpidState,
				' | ',
				_('Flow tracker:'), ' ', trackerState,
				' | ',
				_('Tracked flows:'), ' ', E('strong', {}, [ String(s.flow_count || 0) ])
			])
		]);
	},

	_updateSummary: function(div, flows) {
		var apps   = {};
		var protos = {};
		var cats   = {};
		var srcs   = {};
		var dsts   = {};

		flows.forEach(function(f) {
			if (f.app)      apps[f.app]        = (apps[f.app]        || 0) + 1;
			if (f.l4_proto) protos[f.l4_proto] = (protos[f.l4_proto] || 0) + 1;
			if (f.category) cats[f.category]   = (cats[f.category]   || 0) + 1;
			if (f.src_ip)   srcs[f.src_ip]     = (srcs[f.src_ip]     || 0) + 1;
			if (f.dst_ip)   dsts[f.dst_ip]     = (dsts[f.dst_ip]     || 0) + 1;
		});

		function buildTable(title, counts, maxRows) {
			var sorted = Object.keys(counts).sort(function(a, b) {
				return counts[b] - counts[a];
			});
			if (sorted.length === 0) return E('div', {});
			var visible = (maxRows && sorted.length > maxRows) ? sorted.slice(0, maxRows) : sorted;
			var extra   = sorted.length - visible.length;
			var rows = visible.map(function(k) {
				return E('tr', {}, [
					E('td', { 'style': 'padding:1px 8px 1px 0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:160px;' }, [ k ]),
					E('td', { 'style': 'padding:1px 0;text-align:right;font-weight:bold;white-space:nowrap;' }, [ String(counts[k]) ])
				]);
			});
			if (extra > 0)
				rows.push(E('tr', {}, [
					E('td', { 'colspan': '2', 'style': 'padding:2px 0;color:#999;font-size:0.85em;' },
						[ '…' + _('and %d more').format(extra) ])
				]));
			return E('div', { 'style': 'min-width:160px;max-width:220px;' }, [
				E('strong', {}, [ title ]),
				E('table', { 'style': 'width:100%;font-size:0.9em;margin-top:4px;table-layout:fixed;' }, rows)
			]);
		}

		dom.content(div, [
			buildTable(_('Applications'), apps),
			buildTable(_('Protocols'), protos),
			buildTable(_('Categories'), cats),
			buildTable(_('Source IPs'), srcs, 10),
			buildTable(_('Destination IPs'), dsts, 10)
		]);
	},

	_updateTable: function(flows) {
		this._flows = flows;
		this._applyFilter();
	},

	_applyFilter: function() {
		var flows   = this._flows || [];
		var filter  = this._filterText || '';
		var tbody   = document.getElementById('ndpid-flows-body');
		var countEl = document.getElementById('ndpid-count');
		if (!tbody) return;

		var filtered = filter ? flows.filter(function(f) {
			return (f.app      || '').toLowerCase().indexOf(filter) !== -1 ||
			       (f.category || '').toLowerCase().indexOf(filter) !== -1 ||
			       (f.src_ip   || '').toLowerCase().indexOf(filter) !== -1 ||
			       (f.dst_ip   || '').toLowerCase().indexOf(filter) !== -1 ||
			       (f.l4_proto || '').toLowerCase().indexOf(filter) !== -1;
		}) : flows;

		if (countEl)
			countEl.textContent = _('Showing %d of %d flows').format(filtered.length, flows.length);

		var rows = filtered.map(function(f) {
			var src = f.src_ip || '';
			if (f.src_port) src += ':' + f.src_port;
			var dst = f.dst_ip || '';
			if (f.dst_port) dst += ':' + f.dst_port;

			var stateColor = '';
			if      (f.event === 'detected')          stateColor = 'color:green';
			else if (f.event === 'guessed')           stateColor = 'color:orange';
			else if (f.event === 'detection-update')  stateColor = 'color:#0a0';
			else if (f.event === 'new')               stateColor = 'color:#999';

			return E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td', 'style': 'overflow:hidden;text-overflow:ellipsis;white-space:nowrap' },
					[ f.app ? E('strong', {}, [ f.app ]) : E('em', { 'style': 'color:#999' }, [ _('unknown') ]) ]),
				E('td', { 'class': 'td', 'style': 'overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, [ f.base || '' ]),
				E('td', { 'class': 'td', 'style': 'overflow:hidden;text-overflow:ellipsis;white-space:nowrap' }, [ f.category || '' ]),
				E('td', { 'class': 'td' }, [ f.l4_proto || '' ]),
				E('td', { 'class': 'td', 'style': 'overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-family:monospace' }, [ src ]),
				E('td', { 'class': 'td', 'style': 'overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-family:monospace' }, [ dst ]),
				E('td', { 'class': 'td', 'style': 'text-align:right' }, [ String(f.packets || 0) ]),
				E('td', { 'class': 'td', 'style': stateColor }, [ f.event || '' ]),
			]);
		});

		if (rows.length === 0)
			rows = [ E('tr', { 'class': 'tr placeholder' }, [
				E('td', { 'class': 'td', 'colspan': '8', 'style': 'text-align:center;color:#999' },
					[ filter ? _('No flows match the filter.') : _('No flows tracked yet. Make sure nDPId and the flow tracker are running.') ])
			]) ];

		dom.content(tbody, rows);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
