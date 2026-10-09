'use strict';
'require form';
'require uci';
'require v2ray as v2';

var conf = 'v2ray';

var protocols = ['blackhole', 'dns', 'freedom', 'http', 'shadowsocks', 'socks', 'vmess', 'vless', 'trojan'];

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('V2Ray - Outbounds'),
			_('Where matched traffic is sent out. Only outbounds marked "Active" below are fed into the running v2ray config.'));

		s = m.section(form.TypedSection, 'outbound', _('Outbounds'));
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
		s.tab('sockopt', _('Sockopt'));

		v2.addActiveFlag(s, 'main', 'outbounds', _('Active'), _('Fed into the running v2ray config'), 'general');

		o = s.taboption('general', form.Value, 'tag', _('Tag'));
		o.rmempty = false;
		o = s.taboption('general', form.ListValue, 'protocol', _('Protocol'));
		protocols.forEach(function(p) { o.value(p, p); });
		o.rmempty = false;
		o = s.taboption('general', form.Value, 'send_through', _('Send through'));
		o.datatype = 'ipaddr';
		o.description = _('Local IP to originate connections from');
		o = s.taboption('general', form.Value, 'proxy_settings_tag', _('Chain through outbound tag'));
		o.description = _('Tag of another outbound to proxy through (v2ray "proxySettings")');
		o = s.taboption('general', form.Flag, 'mux_enabled', _('Mux'));
		o = s.taboption('general', form.Value, 'mux_concurrency', _('Mux concurrency'));
		o.datatype = 'uinteger'; o.placeholder = '8'; o.depends('mux_enabled', '1');
		o = s.taboption('transport', form.Value, 'stream_settings', _('Raw stream settings override'));
		o.rows = 8;
		o.description = _('Raw JSON, replaces the whole "streamSettings" object built from the fields below when set');

		v2.addOutboundProtocolFields(s);
		v2.addStreamSettings(s, 'mark');

		return m.render();
	}
});
