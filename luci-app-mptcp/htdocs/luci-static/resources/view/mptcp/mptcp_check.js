'use strict';
'require view';
'require uci';
'require rpc';

var callMptcpCheckTrace = rpc.declare({
	object: 'luci.mptcp',
	method: 'mptcp_check_trace',
	params: ['iface'],
	expect: { output: '' }
});

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('network'),
			// only for the old copy of the mode below: the ACL doesn't
			// give this config (VPS passwords and tokens) to non-root users
			L.resolveDefault(uci.load('openmptcprouter'), null)
		]);
	},

	render: function() {
		var ifaces = [];
		uci.sections('network', 'interface', function(s) {
			var name = s['.name'];
			if (name === 'loopback') return;
			var multipath = s.multipath ||
				uci.get('openmptcprouter', name, 'multipath') || 'off';
			if (multipath !== 'off')
				ifaces.push(name);
		});

		var select = E('select', { 'class': 'cbi-input-select', 'id': 'mptcp-check-iface' },
			ifaces.map(function(n) { return E('option', { 'value': n }, [ n ]); })
		);

		var pre = E('pre', { 'style': 'white-space:pre-wrap' });

		var btn = E('input', {
			'type': 'button',
			'value': _('Test'),
			'class': 'cbi-button cbi-button-apply',
			'click': L.bind(this._runCheck, this, select, pre)
		});

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, [ _('MPTCP Support Check') ]),
			E('div', { 'class': 'cbi-map-descr' },
				[ _('Check if MPTCP between interface and server is working.') ]),
			E('fieldset', { 'class': 'cbi-section' }, [
				E('legend', {}, [ _('Settings') ]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, [ _('Interface') ]),
					E('div', { 'class': 'cbi-value-field' }, [ select ])
				]),
				btn
			]),
			E('div', { 'class': 'cbi-section' }, [
				pre,
				E('br'),
				E('i', {}, [ _('If you get "TCPOptionMPTCPCapable [...] Sender\'s Key" at the end, then MPTCP is supported. If there is a "-TCPOptionMPTCPCapable", then it\'s blocked.') ])
			])
		]);
	},

	_runCheck: function(select, pre) {
		var iface = select.value;
		if (!iface) return;

		pre.textContent = _('Waiting for command to complete…');

		return callMptcpCheckTrace(iface).then(function(text) {
			pre.textContent = (text || '').trim() || _('Error');
		}).catch(function() {
			pre.textContent = _('Error');
		});
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
