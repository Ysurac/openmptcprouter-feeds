'use strict';
'require form';
'require view';
'require uci';

return view.extend({
	load: function() {
		return uci.load('omr-events');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('omr-events', _('Interface Event History — Settings'),
			_('Configure how long the interface UP/DOWN/latency/loss event history is kept.'));

		s = m.section(form.NamedSection, 'settings', 'settings');
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable event history'),
			_('Log a timestamped event every time an interface tracked by omr-tracker changes state.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'max_age', _('Maximum age'),
			_('Events older than this are discarded, in seconds. Default: 172800 (2 days).'));
		o.datatype = 'uinteger';
		o.placeholder = '172800';
		o.depends('enabled', '1');

		o = s.option(form.Value, 'max_size', _('Maximum log size'),
			_('Oldest events are discarded once the log exceeds this size, in bytes. Default: 10485760 (10 MB).'));
		o.datatype = 'uinteger';
		o.placeholder = '10485760';
		o.depends('enabled', '1');

		return m.render();
	}
});
