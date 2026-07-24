'use strict';
'require view';
'require form';
'require uci';
'require network';

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
			_('Set monthly quota per interface. When the quota is reached the interface can be cut or throttled for the remainder of the month.'));

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

		o = s.option(form.Value, 'txquota', _('TX quota (KiB)'));
		o.datatype = 'uinteger';
		o.placeholder = '0';

		o = s.option(form.Value, 'rxquota', _('RX quota (KiB)'));
		o.datatype = 'uinteger';
		o.placeholder = '0';

		o = s.option(form.Value, 'ttquota', _('TX+RX quota (KiB)'));
		o.datatype = 'uinteger';
		o.placeholder = '0';

		o = s.option(form.Value, 'interval', _('Interval between checks (s)'));
		o.datatype = 'uinteger';
		o.placeholder = '60';

		o = s.option(form.ListValue, 'exceedance_action', _('Action when quota is reached'));
		o.value('cut',      _('Cut — bring interface down for the rest of the month'));
		o.value('throttle', _('Throttle — limit interface bandwidth'));
		o.default = 'cut';
		o.rmempty = false;

		o = s.option(form.Value, 'throttle_dl', _('Download limit (Mbps)'),
			_('Maximum download speed applied to the interface when quota is exceeded'));
		o.datatype = 'uinteger';
		o.placeholder = '1';
		o.depends('exceedance_action', 'throttle');

		o = s.option(form.Value, 'throttle_ul', _('Upload limit (Mbps)'),
			_('Maximum upload speed applied to the interface when quota is exceeded'));
		o.datatype = 'uinteger';
		o.placeholder = '1';
		o.depends('exceedance_action', 'throttle');

		o = s.option(form.ListValue, 'exceedance_scope', _('Enforcement scope'));
		o.value('month_only', _('This month only — auto-recover when the month resets'));
		o.value('persistent', _('All future months — keep cut/throttled until manually reset'));
		o.default = 'month_only';
		o.rmempty = false;

		o = s.option(form.Flag, 'reset_exceeded', _('Reset exceeded state'),
			_('Tick and save to clear the persistent exceeded flag — the interface recovers on the next check interval'));
		o.depends('exceedance_scope', 'persistent');
		o.rmempty = true;

		return m.render();
	}
});
