'use strict';
'require form';
'require uci';
'require xray as xr';

var conf = 'xray';

var protocols = ['dokodemo-door', 'http', 'mtproto', 'shadowsocks', 'socks', 'vmess', 'vless', 'trojan'];

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('XRay - Inbounds'),
			_('Listeners that accept connections. Only inbounds marked "Active" below are fed into the running xray config (see General.enabled to turn xray itself on/off).'));

		s = m.section(form.TypedSection, 'inbound', _('Inbounds'));
		s.addremove = true;
		s.anonymous = true;
		s.sectiontitle = function(section_id) {
			var t = uci.get(conf, section_id, 'tag');
			return (t ? t + ' ' : '') + '(' + section_id + ')';
		};

		s.tab('general', _('General'));
		s.tab('protocol', _('Protocol'));
		s.tab('transport', _('Transport'));
		s.tab('tls', _('TLS'));
		s.tab('sockopt', _('Sockopt / sniffing'));

		xr.addActiveFlag(s, 'main', 'inbounds', _('Active'), _('Fed into the running xray config'), 'general');

		o = s.taboption('general', form.Value, 'tag', _('Tag'));
		o.rmempty = false;
		o = s.taboption('general', form.Value, 'listen', _('Listen address'));
		o.datatype = 'ipaddr';
		o.placeholder = '0.0.0.0';
		o = s.taboption('general', form.Value, 'port', _('Port'));
		o.datatype = 'or(port, portrange)';
		o.rmempty = false;
		o = s.taboption('general', form.ListValue, 'protocol', _('Protocol'));
		protocols.forEach(function(p) { o.value(p, p); });
		o.rmempty = false;

		xr.addInboundProtocolFields(s);
		xr.addStreamSettings(s, 'tproxy', false);

		return m.render();
	}
});
