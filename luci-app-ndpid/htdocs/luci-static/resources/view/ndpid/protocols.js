'use strict';
'require view';
'require rpc';
'require dom';

var callGetProtocols = rpc.declare({
	object: 'luci.ndpid',
	method: 'get_supported_protocols',
	expect: { '': { protocols: [], categories: [] } }
});

return view.extend({
	_filterText: '',
	_filterCat:  '',
	_filterType: '',
	_groupBy:    false,
	_data:       null,

	load: function() {
		return callGetProtocols();
	},

	render: function(data) {
		this._data = data || { protocols: [], categories: [] };

		var protocols  = this._data.protocols  || [];
		var categories = this._data.categories || [];

		var stats = E('p', { 'style': 'color:#666;margin-bottom:12px;' }, [
			E('strong', {}, [ String(protocols.length) ]),
			' ' + _('protocols across') + ' ',
			E('strong', {}, [ String(categories.length) ]),
			' ' + _('categories')
		]);

		var catSelect = E('select', {
			'id': 'ndpid-cat-filter',
			'style': 'max-width:200px;',
			'change': L.bind(function(ev) {
				this._filterCat = ev.target.value;
				this._applyFilter();
			}, this)
		}, [ E('option', { 'value': '' }, [ _('All categories') ]) ]
		.concat(categories.map(function(c) {
			return E('option', { 'value': c }, [ c ]);
		})));

		var typeSelect = E('select', {
			'id': 'ndpid-type-filter',
			'style': 'max-width:160px;',
			'change': L.bind(function(ev) {
				this._filterType = ev.target.value;
				this._applyFilter();
			}, this)
		}, [
			E('option', { 'value': '' },            [ _('All types') ]),
			E('option', { 'value': 'protocol' },    [ _('Protocol') ]),
			E('option', { 'value': 'application' }, [ _('Application') ]),
		]);

		var searchInput = E('input', {
			'type':        'text',
			'id':          'ndpid-proto-search',
			'placeholder': _('Search protocols…'),
			'style':       'flex:1;max-width:280px;',
			'input': L.bind(function(ev) {
				this._filterText = ev.target.value.toLowerCase();
				this._applyFilter();
			}, this)
		});

		var groupBtn = E('button', {
			'class': 'btn',
			'id':    'ndpid-group-btn',
			'click': L.bind(function() {
				this._groupBy = !this._groupBy;
				document.getElementById('ndpid-group-btn').textContent =
					this._groupBy ? _('Sort by name') : _('Group by category');
				this._applyFilter();
			}, this)
		}, [ _('Group by category') ]);

		var countEl = E('span', { 'style': 'color:#666;' });

		var filterRow = E('div', {
			'style': 'display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:10px;'
		}, [ searchInput, catSelect, typeSelect, groupBtn, countEl ]);

		var tableWrap = E('div', {});

		var container = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, [ _('nDPId Detectable Protocols') ]),
			stats,
			filterRow,
			tableWrap
		]);

		this._wrap = tableWrap;
		this._countEl = countEl;
		this._applyFilter();
		return container;
	},

	_filtered: function() {
		var protocols = (this._data && this._data.protocols) || [];
		var text = this._filterText;
		var cat  = this._filterCat;
		var type = this._filterType;

		return protocols.filter(function(p) {
			if (text && p.name.toLowerCase().indexOf(text) === -1 &&
			    (p.category || '').toLowerCase().indexOf(text) === -1)
				return false;
			if (cat && p.category !== cat)
				return false;
			if (type === 'application' && !p.app)
				return false;
			if (type === 'protocol' && p.app)
				return false;
			return true;
		});
	},

	_makeTable: function(rows) {
		return E('table', {
			'class': 'table cbi-section-table',
			'style': 'width:100%;'
		}, [
			E('thead', {}, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th', 'style': 'width:40%' }, [ _('Protocol / Application') ]),
					E('th', { 'class': 'th', 'style': 'width:30%' }, [ _('Category') ]),
					E('th', { 'class': 'th', 'style': 'width:15%' }, [ _('Type') ]),
					E('th', { 'class': 'th', 'style': 'width:15%' }, [ _('Transport') ]),
				])
			]),
			E('tbody', {}, rows)
		]);
	},

	_makeRow: function(p, showCat) {
		var typeLabel = p.app
			? E('span', { 'style': 'color:#0a7ac9;' }, [ _('Application') ])
			: E('span', { 'style': 'color:#2d8a2d;' }, [ _('Protocol') ]);
		var xport = p.cleartext
			? E('span', { 'style': 'color:#888;font-size:0.9em;' }, [ _('Cleartext') ])
			: E('span', { 'style': 'color:#c96a00;font-size:0.9em;' }, [ _('Encrypted') ]);
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td' }, [ E('strong', {}, [ p.name ]) ]),
			E('td', { 'class': 'td' }, [ showCat ? (p.category || '') : '' ]),
			E('td', { 'class': 'td' }, [ typeLabel ]),
			E('td', { 'class': 'td' }, [ xport ]),
		]);
	},

	_applyFilter: function() {
		var wrap    = this._wrap;
		var countEl = this._countEl;
		if (!wrap) return;

		var filtered = this._filtered();

		if (countEl)
			countEl.textContent = filtered.length + ' / ' +
				((this._data && this._data.protocols) || []).length;

		var content;

		if (this._groupBy) {
			// Group protocols by category
			var byCategory = {};
			filtered.forEach(function(p) {
				var cat = p.category || _('Unspecified');
				if (!byCategory[cat]) byCategory[cat] = [];
				byCategory[cat].push(p);
			});

			var sortedCats = Object.keys(byCategory).sort();

			if (sortedCats.length === 0) {
				content = E('p', { 'style': 'color:#999;text-align:center;padding:16px;' },
					[ _('No protocols match the filter.') ]);
			} else {
				content = E('div', {}, sortedCats.map(L.bind(function(cat) {
					var rows = byCategory[cat].map(L.bind(function(p) {
						return this._makeRow(p, false);
					}, this));

					return E('div', { 'style': 'margin-bottom:20px;' }, [
						E('h4', {
							'style': 'margin:0 0 6px 0;padding:6px 10px;' +
							         'background:#f0f0f0;border-left:4px solid #0a7ac9;' +
							         'font-size:1em;'
						}, [
							cat,
							E('span', {
								'style': 'font-weight:normal;font-size:0.85em;color:#666;margin-left:8px;'
							}, [ '(' + byCategory[cat].length + ')' ])
						]),
						this._makeTable(rows)
					]);
				}, this)));
			}
		} else {
			// Flat alphabetical table
			var rows = filtered.map(L.bind(function(p) {
				return this._makeRow(p, true);
			}, this));

			if (rows.length === 0)
				rows = [ E('tr', { 'class': 'tr placeholder' }, [
					E('td', { 'class': 'td', 'colspan': '4',
					          'style': 'text-align:center;color:#999;' },
						[ _('No protocols match the filter.') ])
				]) ];

			content = this._makeTable(rows);
		}

		dom.content(wrap, content);
	},

	handleSaveApply: null,
	handleSave:      null,
	handleReset:     null
});
