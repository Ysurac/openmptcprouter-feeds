'use strict';
'require form';
'require uci';
'require v2ray as v2';

var conf = 'v2ray';

var protocols = ['dokodemo-door', 'http', 'mtproto', 'shadowsocks', 'socks', 'vmess', 'vless', 'trojan'];

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('V2Ray - Inbounds'),
			_('Listeners that accept connections. Only inbounds marked "Active" below are fed into the running v2ray config (see General.enabled to turn v2ray itself on/off).'));

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

		v2.addActiveFlag(s, 'main', 'inbounds', _('Active'), _('Fed into the running v2ray config'), 'general');

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

		v2.addInboundProtocolFields(s);
		v2.addStreamSettings(s, 'tproxy');

		return m.render();
	}
});
