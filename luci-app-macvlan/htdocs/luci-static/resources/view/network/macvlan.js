'use strict';
'require rpc';
'require form';
'require tools.widgets as widgets';

return L.view.extend({
	callHostHints: rpc.declare({
		object: 'luci-rpc',
		method: 'getHostHints',
		expect: { '': {} }
	}),

	load: function() {
		return this.callHostHints();
	},

	render: function(hosts) {
		var m, s, o;

		m = new form.Map('macvlan', _('Macvlan'));

		s = m.section(form.GridSection, 'macvlan', _('Interfaces'));
		s.addremove = true;
		s.anonymous = true;

		o = s.option(form.Value, 'name', _('Name'));
		o.datatype = 'uciname';
		o.rmempty = false;

		o = s.option(widgets.DeviceSelect, 'ifname', _('Interface'));
		o.rmempty = false;

		return m.render();
	}
});
