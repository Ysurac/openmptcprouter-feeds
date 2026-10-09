'use strict';
'require form';
'require uci';
'require xray as xr';

var conf = 'xray';

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('XRay - Policy'),
			_('Connection handling policies applied per level, and system-wide stats collection.'));

		s = m.section(form.NamedSection, 'main_policy', 'policy', _('Policy'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;
		o = s.option(form.Flag, 'system_stats_inbound_uplink', _('System stats: inbound uplink'));
		o = s.option(form.Flag, 'system_stats_inbound_downlink', _('System stats: inbound downlink'));

		s = m.section(form.TypedSection, 'policy_level', _('Policy levels'));
		s.addremove = true;
		s.anonymous = true;
		s.sectiontitle = function(section_id) {
			var l = uci.get(conf, section_id, 'level');
			return _('Level') + ' ' + (l != null ? l : section_id);
		};

		xr.addActiveFlag(s, 'main_policy', 'levels', _('Active'), _('Included in the policy above'));

		o = s.option(form.Value, 'level', _('Level'));
		o.datatype = 'uinteger';
		o.rmempty = false;
		o.description = _('Numeric level id, referenced by inbound/outbound "user level" fields');

		o = s.option(form.Value, 'handshake', _('Handshake timeout (s)'));
		o.datatype = 'uinteger'; o.placeholder = '4';
		o = s.option(form.Value, 'conn_idle', _('Connection idle timeout (s)'));
		o.datatype = 'uinteger'; o.placeholder = '300';
		o = s.option(form.Value, 'uplink_only', _('Uplink-only timeout (s)'));
		o.datatype = 'uinteger'; o.placeholder = '2';
		o = s.option(form.Value, 'downlink_only', _('Downlink-only timeout (s)'));
		o.datatype = 'uinteger'; o.placeholder = '5';
		o = s.option(form.Value, 'buffer_size', _('Buffer size (KB)'));
		o.datatype = 'uinteger';
		o = s.option(form.Flag, 'stats_user_uplink', _('Stats: user uplink'));
		o = s.option(form.Flag, 'stats_user_downlink', _('Stats: user downlink'));

		return m.render();
	}
});
