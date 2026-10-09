'use strict';
'require form';
'require uci';
'require v2ray as v2';

var conf = 'v2ray';

return L.view.extend({
	load: function() {
		return uci.load(conf);
	},

	render: function() {
		var m, s, o;

		m = new form.Map(conf, _('V2Ray - DNS'),
			_('Built-in v2ray DNS resolver. Leave disabled to use the system resolver instead.'));

		s = m.section(form.NamedSection, 'main_dns', 'dns', _('DNS'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;

		o = s.option(form.Value, 'tag', _('Tag'));
		o = s.option(form.Value, 'client_ip', _('Client IP'));
		o.datatype = 'ipaddr';
		o.description = _('IP to report to upstream DNS servers for geo-aware answers');

		o = s.option(form.DynamicList, 'hosts', _('Static hosts'));
		o.placeholder = 'example.com|127.0.0.1';
		o.description = _('One "domain|ip" pair per entry');

		s = m.section(form.TypedSection, 'dns_server', _('DNS servers'));
		s.addremove = true;
		s.anonymous = true;
		s.sectiontitle = function(section_id) {
			return uci.get(conf, section_id, 'address') || section_id;
		};

		v2.addActiveFlag(s, 'main_dns', 'servers', _('Active'), _('Included in the DNS resolver above'));

		o = s.option(form.Value, 'address', _('Address'));
		o.rmempty = false;
		o = s.option(form.Value, 'port', _('Port'));
		o.datatype = 'port';
		o.placeholder = '53';
		o = s.option(form.DynamicList, 'domains', _('Domains'));
		o.description = _('Only use this server for these domains; empty applies to all');
		o = s.option(form.DynamicList, 'expect_ips', _('Expected IPs'));
		o.description = _('CIDRs the returned IP must fall inside of to be accepted');

		return m.render();
	}
});
