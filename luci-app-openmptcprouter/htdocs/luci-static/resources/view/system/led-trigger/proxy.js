'use strict';
'require baseclass';
'require form';

return baseclass.extend({
	trigger: _('Proxy status (service: proxy)'),
	kernel: false,
	addFormOptions: function(s){
		var o;

		o = s.option(form.ListValue, 'proxy_status', _('Proxy Status'));
		o.rmempty = true;
		o.modalonly = true;
		o.value('up', _('Up'));
		o.value('down', _('Down'));
		o.depends('trigger','proxy');
	}
});
