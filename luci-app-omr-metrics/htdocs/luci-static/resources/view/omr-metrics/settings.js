'use strict';
'require form';
'require view';
'require uci';

return view.extend({
	load: function() {
		return uci.load('omr-metrics');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('omr-metrics', _('WAN Metrics — Settings'),
			_('Configure how per-interface metrics are collected and sent to the VPS.'));

		s = m.section(form.NamedSection, 'settings', 'settings');
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'send_to_vps', _('Send metrics to VPS'),
			_('POST per-interface metrics to every configured VPS server at the interval below.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'interval', _('Send interval'),
			_('How often metrics are sent to the VPS, in seconds.'));
		o.datatype = 'uinteger';
		o.placeholder = '30';
		o.retain = true;
		o.depends('send_to_vps', '1');

		/* Every option on this page is written explicitly (rmempty = false) or
		 * kept when its dependency is off (retain = true). form.js otherwise
		 * drops an option whose value equals the widget default, and removes
		 * outright any option whose depends() are unsatisfied: saving this page
		 * without editing anything queued the removal of the weight sync flag,
		 * the model-assigned weights flag and the custom server port. The
		 * readers happen to default a missing value the same way today
		 * (`${v:-1}` in omr-weight-sync and the init), which makes it silent
		 * rather than harmless -- the same agreement between two files that
		 * #4348, #4349 and #4352 each broke. */
		o = s.option(form.Flag, 'enable_weight_sync', _('Enable weight sync'),
			_('Synchronise <code>multipath_weight</code> values into the BPF scheduler map and ip route weights.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'enable_decision_weights', _('Enable model-assigned weights'),
			_('Poll <code>GET /metrics/decision</code> on the VPS and apply the returned per-interface weights before the BPF sync.'));
		o.default = '1';
		o.rmempty = false;
		o.retain = true;
		o.depends('enable_weight_sync', '1');

		o = s.option(form.Flag, 'decision_predict', _('Enable prediction'),
			_('Ask the VPS model to extrapolate metrics forward in time before scoring interfaces.'));
		o.default = '0';
		o.rmempty = false;
		o.retain = true;
		o.depends('enable_decision_weights', '1');

		o = s.option(form.Value, 'decision_horizon', _('Prediction horizon'),
			_('How far ahead (in seconds) to extrapolate metrics when prediction is enabled. Range: 1 – 86400.'));
		o.datatype = 'range(1, 86400)';
		o.placeholder = '300';
		o.retain = true;
		o.depends('decision_predict', '1');

		o = s.option(form.Flag, 'use_custom_server', _('Use custom metrics server'),
			_('Send metrics to a dedicated server instead of the VPS.'));
		o.default = '0';
		o.rmempty = false;

		o = s.option(form.Value, 'server', _('Server address'),
			_('Hostname or IP address of the custom metrics server.'));
		o.depends('use_custom_server', '1');
		o.rmempty = true;
		o.retain = true;

		o = s.option(form.Value, 'serverport', _('Server port'));
		o.datatype = 'port';
		o.placeholder = '65500';
		o.depends('use_custom_server', '1');
		o.rmempty = true;
		o.retain = true;

		o = s.option(form.Value, 'username', _('Username'));
		o.depends('use_custom_server', '1');
		o.rmempty = true;
		o.retain = true;

		o = s.option(form.Value, 'password', _('Password'));
		o.password = true;
		o.depends('use_custom_server', '1');
		o.rmempty = true;
		o.retain = true;

		o = s.option(form.Value, 'token', _('Token'),
			_('Bearer token — filled in automatically after the first successful login.'));
		o.depends('use_custom_server', '1');
		o.rmempty = true;
		o.retain = true;

		return m.render();
	}
});
