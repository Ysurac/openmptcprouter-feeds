'use strict';
'require view';
'require form';
'require fs';
'require validation';

/* One element of the host list, checked here instead of with the datatype
 * list(neg(or(ipmask4,ipmask6,iprange,uciname))): in luci-base, or() lets an
 * alternative see the value a previous one rewrote (ip4addr leaves "33"
 * behind for "198.51.100.0/33", which uciname then takes) and the validate
 * function is handed that rewritten value too, so a prefix out of range
 * went through. */
function cmpAddr(a, b) {
	for (var i = 0; i < a.length; i++)
		if (a[i] != b[i])
			return a[i] < b[i] ? -1 : 1;
	return 0;
}

function validHostElement(v) {
	var m, a, b;

	v = v.replace(/^[ \t]*![ \t]*/, '');

	if ((m = v.match(/^(\d{1,3}(?:\.\d{1,3}){3})(?:\/(\d{1,2}|\d{1,3}(?:\.\d{1,3}){3}))?$/)) &&
	    validation.parseIPv4(m[1]) &&
	    (m[2] == null || (m[2].indexOf('.') >= 0 ? !!validation.parseIPv4(m[2]) : +m[2] <= 32)))
		return true;

	if ((m = v.match(/^([0-9a-fA-F:.]+)(?:\/(\d{1,3}|[0-9a-fA-F:.]+))?$/)) &&
	    validation.parseIPv6(m[1]) &&
	    (m[2] == null || (/^\d+$/.test(m[2]) ? +m[2] <= 128 : !!validation.parseIPv6(m[2]))))
		return true;

	if ((m = v.split('-')).length == 2) {
		a = validation.parseIPv4(m[0]); b = validation.parseIPv4(m[1]);
		if (a && b && cmpAddr(a, b) <= 0)
			return true;
		a = validation.parseIPv6(m[0]); b = validation.parseIPv6(m[1]);
		if (a && b && cmpAddr(a, b) <= 0)
			return true;
	}

	return /^[a-zA-Z0-9_]+$/.test(v);
}

function validateHosts(section_id, value) {
	var items = (value || '').split(/[ \t]+/).filter(function(e) { return e != ''; });

	for (var i = 0; i < items.length; i++)
		if (!validHostElement(items[i]))
			return _('Expecting: %s').format(_('an address, a network (prefix 0-32 or 0-128), an address range or an interface name, "!" to negate'));

	return true;
}

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
	srch.validate = validateHosts;
	srch.rmempty = true;
	srch.value('', _('all'));

	sports = s.option(form.Value, 'src_port', _('Source ports'));
	sports.rmempty = true;
	sports.value('', _('all'));
	sports.depends('proto', 'tcp');
	sports.depends('proto', 'udp');

	dsth = s.option(form.Value, 'dest_ip', _('Destination host'));
	dsth.validate = validateHosts;
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