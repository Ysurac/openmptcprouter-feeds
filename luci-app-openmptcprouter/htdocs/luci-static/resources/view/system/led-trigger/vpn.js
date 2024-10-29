'use strict';
'require baseclass';
'require form';

return baseclass.extend({
	trigger: _('VPN status (service: vpn)'),
	kernel: false,
	addFormOptions: function(s){
		var o;

		o = s.option(form.ListValue, 'vpn_status', _('VPN Status'));
		o.rmempty = true;
		o.modalonly = true;
		o.value('up', _('Up'));
		o.value('down', _('Down'));
		o.depends('trigger','vpn');
	}
});
