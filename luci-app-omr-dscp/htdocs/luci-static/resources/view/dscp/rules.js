'use strict';
'require view';
'require form';
'require fs';

return view.extend({
    render: function(extra_protocols) {
	var m, s, direction, proto, srch, sports, dsth, dports, t, comment;

	m = new form.Map('dscp', _('Differentiated services'),
	    _('Traffic may be classified by many different parameters, such as source address, destination address or traffic type and assigned to a specific traffic class.'));

	s = m.section(form.TableSection, 'classify', _('Classification Rules'));
	s.anonymous = true;
	s.addremove = true;

	direction = s.option(form.ListValue, 'direction', _('Direction'));
	direction.default = 'upload';
	direction.rmempty = false;
	direction.value('upload', _('upload'));
	direction.value('download', _('download'));
	direction.value('both', _('both'));

	proto = s.option(form.Value, 'proto', _('Protocol'));
	proto.default = 'all';
	proto.rmempty = false;
	proto.value('tcp');
	proto.value('udp');
	proto.value('all');
	proto.value('ip');
	proto.value('icmp');
	proto.value('esp');

	/* an address, a network (prefix or netmask), a range or a network
	 * interface name, "!" to negate: a prefix out of range went into the
	 * firewall rule as is and nft refused the whole ruleset */
	srch = s.option(form.Value, 'src_ip', _('Source host'));
	srch.datatype = 'list(neg(or(ipmask4,ipmask6,iprange,uciname)))';
	srch.rmempty = true;
	srch.value('', _('all'));

	sports = s.option(form.Value, 'src_port', _('Source ports'));
	sports.rmempty = true;
	sports.value('', _('all'));
	sports.depends('proto', 'tcp');
	sports.depends('proto', 'udp');

	dsth = s.option(form.Value, 'dest_ip', _('Destination host'));
	dsth.datatype = 'list(neg(or(ipmask4,ipmask6,iprange,uciname)))';
	dsth.rmempty = true;
	dsth.value('', _('all'));
	dsth.depends('direction', 'upload');
	dsth.depends('direction', 'both');

	dports = s.option(form.Value, 'dest_port', _('Destination ports'));
	dports.rmempty = true;
	dports.value('', _('all'));
	dports.depends('proto', 'tcp');
	dports.depends('proto', 'udp');

	t = s.option(form.ListValue, 'class', _('Class'));
	t.value('cs0', _('CS0 - Normal/Best Effort'));
	t.value('cs1', _('CS1 - Low priority'));
	t.value('cs2', _('CS2 - High priority'));
	t.value('cs3', _('CS3 - SIP'));
	t.value('cs4', _('CS4 - Real-Time Interactive'));
	t.value('cs5', _('CS5 - Broadcast Video'));
	t.value('cs6', _('CS6 - Network routing'));
	t.value('cs7', _('CS7 - Latency sensitive'));
	t.value('ef',  _('EF - Voice'));

	comment = s.option(form.Value, 'comment', _('Comment'));
	comment.rmempty = true;

	return m.render();
    }
});