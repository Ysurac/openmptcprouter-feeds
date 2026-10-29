'use strict';
'require form';
'require uci';

var conf = 'xray';

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('XRay - Reverse'),
			_('Legacy xray "reverse" proxy (bridge/portal). The bridges and portals are only used by xray < 24. On newer xray, "Enabled" turns on the VLESS reverse bridge to the VPS instead, which carries the port forwards from the VPS to the LAN: unticked, they stop.'));

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
