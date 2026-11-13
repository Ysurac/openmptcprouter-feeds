'use strict';
'require baseclass';
'require rpc';

var callStatus = rpc.declare({
	object: 'omr-adblock',
	method: 'status',
	expect: { }
});

var labels = {
	active: _('Active'),
	paused: _('Paused'),
	processing: _('Downloading and processing the lists'),
	waiting: _('Waiting for the network'),
	error: _('Error'),
	stopped: _('Stopped'),
	disabled: _('Disabled')
};

return baseclass.extend({
	title: _('Ad blocking'),

	load: function() {
		return L.resolveDefault(callStatus(), {});
	},

	render: function(st) {
		var run = (st && st.run) || {};

		/* nothing to show on a router that never enabled it */
		if (!st || (!st.enabled && !run.status))
			return null;

		var rows = [
			[ _('Status'), labels[run.status] || run.status || '-' ],
			[ _('Blocked domains'), run.entries ? String(run.entries) : '-' ],
			[ _('Last update'), run.updated ? new Date(run.updated * 1000).toLocaleString() : '-' ]
		];

		return E('table', { 'class': 'table' }, rows.map(function(r) {
			return E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, r[0]),
				E('td', { 'class': 'td left' }, r[1])
			]);
		}));
	}
});
