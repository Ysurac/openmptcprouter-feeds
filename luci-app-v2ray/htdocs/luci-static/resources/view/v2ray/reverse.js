'use strict';
'require form';
'require uci';

var conf = 'v2ray';

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('V2Ray - Reverse'),
			_('V2Ray reverse proxy (bridge/portal).'));

		s = m.section(form.NamedSection, 'main_reverse', 'reverse', _('Reverse'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;

		o = s.option(form.DynamicList, 'bridges', _('Bridges'));
		o.placeholder = 'tag|domain';
		o.description = _('One "tag|domain" pair per entry');

		o = s.option(form.DynamicList, 'portals', _('Portals'));
		o.placeholder = 'tag|domain';
		o.description = _('One "tag|domain" pair per entry');

		return m.render();
	}
});
