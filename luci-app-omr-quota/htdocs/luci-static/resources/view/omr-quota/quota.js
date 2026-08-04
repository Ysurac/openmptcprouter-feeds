'use strict';
'require view';
'require form';
'require uci';
'require network';

// Shared by both quota kinds: per-interface (section identity = the interface
// itself) and global (section identity = a stable UCI name, 'interfaces'
// option lists what it combines). Everything below "which interfaces this
// quota covers" is common.
function addQuotaFields(s, downInterfacesHint) {
	var o;

	o = s.option(form.Value, 'txquota', _('TX quota (KiB)'));
	o.datatype = 'uinteger';
	o.placeholder = '0';

	o = s.option(form.Value, 'rxquota', _('RX quota (KiB)'));
	o.datatype = 'uinteger';
	o.placeholder = '0';

	o = s.option(form.Value, 'ttquota', _('TX+RX quota (KiB)'));
	o.datatype = 'uinteger';
	o.placeholder = '0';

	o = s.option(form.Value, 'begindate', _('Begin date'));
	o.datatype = 'date';
	o.placeholder = 'YYYY-MM-DD';
	o.rmempty = true;

	o = s.option(form.Value, 'enddate', _('End date'));
	o.datatype = 'date';
	o.placeholder = 'YYYY-MM-DD';
	o.rmempty = true;
	o.depends('method', '1');
	o.depends('method', '2');

	o = s.option(form.Value, 'interval', _('Interval between checks (s)'));
	o.datatype = 'uinteger';
	o.placeholder = '60';

	o = s.option(form.ListValue, 'method', _('Daily budget method'));
	o.value('0', _('Disabled'));
	o.value('1', _('Block when the interval budget is exceeded'));
	o.value('2', _('Limit speed using remaining daily volume'));
	o.default = '0';
	o.rmempty = false;

	o = s.option(form.Value, 'percent', _('Budget threshold (%)'));
	o.datatype = 'range(1,100)';
	o.placeholder = '80';
	o.depends('method', '1');
	o.depends('method', '2');

	o = s.option(form.Value, 'calculation_interval', _('Budget calculation interval (s)'));
	o.datatype = 'uinteger';
	o.placeholder = '120';
	o.depends('method', '1');

	o = s.option(form.Value, 'down_interfaces', _('Downstream limit interfaces'), downInterfacesHint);
	o.placeholder = 'lan';
	o.rmempty = true;
	o.depends('method', '2');

	o = s.option(form.ListValue, 'exceedance_action', _('Action when quota is reached'));
	o.value('cut',      _('Cut — bring interface(s) down for the rest of the month'));
	o.value('throttle', _('Throttle — limit interface(s) bandwidth'));
	o.default = 'cut';
	o.rmempty = false;

	o = s.option(form.Flag, 'block_lan', _('Block LAN and proxy when cut'),
		_('Set firewall LAN input to DROP and stop shadowsocks-rust while the quota is exceeded.'));
	o.default = '0';
	o.rmempty = false;
	o.depends('exceedance_action', 'cut');

	o = s.option(form.Value, 'throttle_dl', _('Download limit (Mbps)'),
		_('Maximum download speed applied to the interface(s) when quota is exceeded'));
	o.datatype = 'uinteger';
	o.placeholder = '1';
	o.depends('exceedance_action', 'throttle');

	o = s.option(form.Value, 'throttle_ul', _('Upload limit (Mbps)'),
		_('Maximum upload speed applied to the interface(s) when quota is exceeded'));
	o.datatype = 'uinteger';
	o.placeholder = '1';
	o.depends('exceedance_action', 'throttle');

	o = s.option(form.ListValue, 'exceedance_scope', _('Enforcement scope'));
	o.value('month_only', _('This month only — auto-recover when the month resets'));
	o.value('persistent', _('All future months — keep cut/throttled until manually reset'));
	o.default = 'month_only';
	o.rmempty = false;

	o = s.option(form.Flag, 'reset_exceeded', _('Reset exceeded state'),
		_('Tick and save to clear the persistent exceeded flag — the interface(s) recover on the next check interval'));
	o.depends('exceedance_scope', 'persistent');
	o.rmempty = true;
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('omr-quota'),
			network.getNetworks()
		]);
	},

	render: function(data) {
		var networks = (data[1] || []).filter(function(n) {
			return n.getName() !== 'loopback';
		});

		var m, s, o;

		m = new form.Map('omr-quota', _('Monthly Quota'),
			_('Set a quota per interface based only on its own traffic, or a global quota combining several interfaces. When a quota is reached, every interface it covers is cut or throttled together for the remainder of the month.'));

		// ── Per-interface quota ────────────────────────────────────────────

		s = m.section(form.TypedSection, 'interface', _('Interfaces'));
		s.addremove = true;
		s.anonymous = false;
		s.addbtntitle = _('Add interface…');

		s.handleAdd = function(ev) {
			this.sectiontype = 'interface';
			var promise = form.TypedSection.prototype.handleAdd.apply(this, arguments);
			this.sectiontype = undefined;
			return promise;
		};

		s.sectiontitle = function(section_id) {
			return section_id;
		};

		s.renderSectionAdd = function(extra_class) {
			if (!this.addremove)
				return E([]);

			var section = this;
			var createEl = E('div', { 'class': 'cbi-section-create' });
			if (extra_class != null)
				createEl.classList.add(extra_class);

			var select = E('select', {
				'class': 'cbi-section-create-name',
				'disabled': this.map.readonly || null
			});
			select.appendChild(E('option', { 'value': '' }, _('-- select interface --')));
			networks.forEach(function(n) {
				select.appendChild(E('option', { 'value': n.getName() }, n.getName()));
			});

			var btn = E('button', {
				'class': 'cbi-button cbi-button-add',
				'title': this.addbtntitle || _('Add'),
				'click': function(ev) {
					if (!select.value)
						return;
					return section.handleAdd(ev, select.value);
				},
				'disabled': this.map.readonly || true
			}, [ this.addbtntitle || _('Add') ]);

			select.addEventListener('change', function() {
				btn.disabled = select.value ? (section.map.readonly || null) : true;
			});

			createEl.appendChild(E('div', {}, select));
			createEl.appendChild(btn);
			return createEl;
		};

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;

		addQuotaFields(s, _('Space-separated interfaces shaped by the daily budget speed-limit method. Leave empty to use this section interface.'));

		// ── Global quota ───────────────────────────────────────────────────

		s = m.section(form.TypedSection, 'global', _('Global quota'),
			_('A quota combining the traffic of several interfaces. When it is reached, every interface listed below is cut or throttled together.'));
		s.addremove = true;
		s.anonymous = false;
		s.addbtntitle = _('Add global quota…');

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;

		o = s.option(form.Value, 'interfaces', _('Interfaces'),
			_('Space-separated interfaces whose combined traffic counts towards this quota. All of them are cut or throttled together when the quota is reached.'));
		o.placeholder = 'wan1 wan2';
		o.rmempty = false;

		addQuotaFields(s, _('Space-separated interfaces shaped by the daily budget speed-limit method. Leave empty to shape all interfaces listed above.'));

		return m.render();
	}
});
