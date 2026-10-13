'use strict';
'require form';
'require uci';

return L.view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('bpftune', _('bpftune'),
			_('BPF-based auto-tuning of Linux system parameters (TCP buffers, congestion control, neighbour tables, etc.).'));

		s = m.section(form.TypedSection, 'config', _('General Settings'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.option(form.Flag, 'rollback', _('Rollback on stop'),
			_('Revert all tuning changes when bpftune stops.'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.option(form.Flag, 'legacy', _('Force legacy BPF mode'),
			_('Use BPF legacy mode even if modern BPF is available.'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.option(form.Flag, 'logging_stdout', _('Log to stdout'),
			_('Send log output to stdout (captured by procd).'));
		o.default = o.disabled;
		o.rmempty = false;

		o = s.option(form.ListValue, 'learning_rate', _('Learning rate'),
			_('Controls the frequency of adjustments. Lower values mean less frequent changes.'));
		o.value('0', _('0 (~1%) — very slow'));
		o.value('1', _('1 (~6%)'));
		o.value('2', _('2 (~12%) — default'));
		o.value('3', _('3 (~18%)'));
		o.value('4', _('4 (~25%) — fast'));
		o.default = '2';
		o.rmempty = false;

		o = s.option(form.Value, 'cgroup', _('cgroup directory'),
			_('Path to the cgroup directory. Leave empty to use the system default.'));
		o.rmempty = true;
		o.placeholder = _('default');

		o = s.option(form.Value, 'libdir', _('Tuner library directory'),
			_('Path to the bpftune tuner shared libraries.'));
		o.rmempty = true;
		o.placeholder = '/usr/lib/bpftune';

		s = m.section(form.TypedSection, 'config', _('Tuner Selection'),
			_('Available tuners: tcp_buffer, tcp_conn, ip_frag, neigh_table, sysctl, net_buffer, netns, route_table, udp_buffer.'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'tuners_disabled', _('Disabled tuners'),
			_('Space-separated list of tuners to disable. Leave empty to enable all.'));
		o.rmempty = true;
		o.placeholder = 'e.g. netns tcp_conn';

		o = s.option(form.Value, 'tuners_allowed', _('Allowed tuners (allowlist)'),
			_('Space-separated list. When set, only these tuners are active and all others are disabled.'));
		o.rmempty = true;
		o.placeholder = 'e.g. tcp_buffer udp_buffer';

		s = m.section(form.TypedSection, 'config', _('Respawn Settings'),
			_('procd respawn parameters controlling automatic restart behaviour.'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'respawn_threshold', _('Threshold (seconds)'),
			_('Time window in which crash counts are evaluated.'));
		o.datatype = 'uinteger';
		o.default = '3600';
		o.rmempty = false;

		o = s.option(form.Value, 'respawn_timeout', _('Timeout (seconds)'),
			_('Delay before restarting after a crash.'));
		o.datatype = 'uinteger';
		o.default = '5';
		o.rmempty = false;

		o = s.option(form.Value, 'respawn_retry', _('Max retries'),
			_('Maximum number of respawn attempts within the threshold window. 0 means unlimited.'));
		o.datatype = 'uinteger';
		o.default = '5';
		o.rmempty = false;

		return m.render();
	}
});
