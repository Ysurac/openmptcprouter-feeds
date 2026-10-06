'use strict';
'require dom';
'require form';
'require rpc';
'require ui';
'require view';

/* The page goes through the metrics rpcd backend, not the omr-metrics UCI
 * config: the ACL no longer grants that config, which holds the custom
 * server's password and Bearer token. get_settings leaves both out, the
 * password is only ever sent (left empty, the stored one is kept) and the
 * token is the daemons' business. */
var FIELDS = [ 'send_to_vps', 'interval', 'enable_weight_sync',
	'enable_decision_weights', 'decision_predict', 'decision_horizon',
	'use_custom_server', 'server', 'serverport', 'username',
	'custom_server_pin', 'password' ];

var callGetSettings = rpc.declare({
	object: 'metrics',
	method: 'get_settings'
});

var callSetSettings = rpc.declare({
	object: 'metrics',
	method: 'set_settings',
	params: FIELDS
});

var formData = { settings: {} };

return view.extend({
	load: function() {
		return L.resolveDefault(callGetSettings(), {});
	},

	render: function(settings) {
		var m, s, o;

		/* get_settings always says whether a password is set: without it
		 * the settings were not read, and saving an empty form would
		 * remove them all */
		if (!settings || !('password_set' in settings))
			return E('div', { 'class': 'alert-message warning' },
				_('The metrics settings could not be read.'));

		this.passwordSet = !!settings.password_set;
		formData.settings = Object.assign({}, settings);
		delete formData.settings.password_set;

		m = new form.JSONMap(formData, _('WAN Metrics — Settings'),
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

		o = s.option(form.Value, 'password', _('Password'),
			_('Leave empty to keep the current password.'));
		o.password = true;
		o.placeholder = this.passwordSet ? _('Unchanged') : '';
		o.depends('use_custom_server', '1');
		o.rmempty = true;

		/* omr-metrics-curl.sh only sends the credentials over a connection
		 * whose certificate carries this public key. Same check as
		 * omr-vps-curl.sh's _omr_vps_pin_valid: a pin it refuses stops every
		 * call to the server. */
		o = s.option(form.Value, 'custom_server_pin', _('Server API certificate pin'),
			_('SHA-256 of the public key of the custom server API certificate. Left empty, the key seen at the first connection is trusted from then on. Empty it after reinstalling the server.'));
		o.placeholder = _('Learned at the first connection');
		o.depends('use_custom_server', '1');
		o.rmempty = true;
		o.retain = true;
		o.validate = function(sid, val) {
			var pin = (val || '').trim();
			if (pin === '')
				return true;
			pin = pin.replace(/^sha256\/\//, '');
			if (/^[A-Za-z0-9+\/]{43}=$/.test(pin) && pin !== '47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=')
				return true;
			return _('Expecting a base64 SHA-256 (44 characters ending with "="), optionally prefixed by sha256//');
		};

		return m.render();
	},

	/* Saving commits and applies at once (set_settings), there are no
	 * staged UCI changes left to apply. */
	handleSave: function() {
		var map = document.querySelector('.cbi-map');

		if (!map)
			return Promise.resolve();

		return dom.callClassMethod(map, 'save').then(L.bind(function() {
			var data = formData.settings;

			/* An option the form dropped (emptied) goes as '' so the
			 * backend removes it, an empty password goes as nothing so the
			 * stored one is kept. */
			return callSetSettings.apply(null, FIELDS.map(function(f) {
				if (f == 'password')
					return data.password || undefined;
				return (data[f] != null) ? String(data[f]) : '';
			})).then(function(res) {
				if (res && res.result) {
					ui.addNotification(null, E('p', _('The settings have been saved.')), 'info');
					return true;
				}
				ui.addNotification(null, E('p', [ _('The settings were not saved: %s').format(res && res.error ? res.error : _('unknown error')) ]), 'danger');
			}).catch(function(e) {
				ui.addNotification(null, E('p', [ _('The settings were not saved: %s').format(e.message) ]), 'danger');
			}).then(L.bind(function(saved) {
				/* Show what was stored, without the password just typed */
				if (saved)
					return L.resolveDefault(callGetSettings(), {})
						.then(L.bind(this.render, this))
						.then(function(node) { map.parentNode.replaceChild(node, map); });
			}, this));
		}, this));
	},

	handleSaveApply: null,
	handleReset: null
});
