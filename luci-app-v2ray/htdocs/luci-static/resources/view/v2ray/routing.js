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

		m = new form.Map(conf, _('V2Ray - Routing'),
			_('Routes traffic between inbounds and outbounds by rule. OMR\'s own omrbridge/omrout rules already live here (do not remove them); add further rules below them.'));

		s = m.section(form.NamedSection, 'main_routing', 'routing', _('Routing'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;
		o = s.option(form.ListValue, 'domain_strategy', _('Domain strategy'));
		o.value('AsIs', 'AsIs'); o.value('IPIfNonMatch', 'IPIfNonMatch'); o.value('IPOnDemand', 'IPOnDemand');

		s = m.section(form.TypedSection, 'routing_rule', _('Routing rules'));
		s.addremove = true;
		s.anonymous = true;
		s.sectiontitle = function(section_id) {
			return uci.get(conf, section_id, 'outbound_tag') || uci.get(conf, section_id, 'balancer_tag') || section_id;
		};

		v2.addActiveFlag(s, 'main_routing', 'rules', _('Active'), _('Included in the routing table above, in list order'));

		o = s.option(form.ListValue, 'type', _('Type'));
		o.value('field', 'field');
		o.default = 'field';
		o.rmempty = false;

		o = s.option(form.DynamicList, 'domain', _('Domain'));
		o = s.option(form.DynamicList, 'ip', _('IP'));
		o = s.option(form.Value, 'port', _('Port'));
		o.datatype = 'or(port, portrange)';
		o = s.option(form.MultiValue, 'network', _('Network'));
		o.value('tcp', 'TCP'); o.value('udp', 'UDP');
		o = s.option(form.DynamicList, 'source', _('Source'));
		o = s.option(form.DynamicList, 'user', _('User (email)'));
		o = s.option(form.DynamicList, 'inbound_tag', _('Inbound tag'));
		o = s.option(form.MultiValue, 'protocol', _('Sniffed protocol'));
		o.value('http', 'HTTP'); o.value('tls', 'TLS'); o.value('bittorrent', 'BitTorrent');
		o = s.option(form.Value, 'attrs', _('Attributes'));
		o = s.option(form.Value, 'outbound_tag', _('Outbound tag'));
		o.description = _('Mutually exclusive with balancer tag');
		o = s.option(form.Value, 'balancer_tag', _('Balancer tag'));

		s = m.section(form.TypedSection, 'routing_balancer', _('Balancers'));
		s.addremove = true;
		s.anonymous = true;
		s.sectiontitle = function(section_id) {
			return uci.get(conf, section_id, 'tag') || section_id;
		};

		v2.addActiveFlag(s, 'main_routing', 'balancers', _('Active'), _('Included in the routing table above'));

		o = s.option(form.Value, 'tag', _('Tag'));
		o.rmempty = false;
		o = s.option(form.DynamicList, 'selector', _('Selector'));
		o.description = _('Outbound tag prefixes eligible for this balancer');

		return m.render();
	}
});
