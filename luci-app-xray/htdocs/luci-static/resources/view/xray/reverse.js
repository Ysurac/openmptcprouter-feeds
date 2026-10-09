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
			_('Legacy xray "reverse" proxy (bridge/portal). Only used by xray < 24; on newer xray this section is skipped in favour of a VLESS Reverse Proxy outbound/inbound pair, configured on the Outbounds/Inbounds pages instead.'));

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
