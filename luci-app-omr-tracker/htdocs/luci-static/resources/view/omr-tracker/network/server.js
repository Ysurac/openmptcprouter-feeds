'use strict';
'require form';
'require fs';
'require view';
'require uci';

var cfgtypes = ['server'];

return view.extend({
	load: function() {
		return Promise.all([
			L.resolveDefault(fs.stat('/usr/bin/httping'), {}),
			L.resolveDefault(fs.stat('/usr/bin/dig'), {}),
//			L.resolveDefault(fs.stat('/usr/bin/nping'), {}),
//			L.resolveDefault(fs.stat('/usr/bin/arping'), {}),
			uci.load('network')
		]);
	},

	render: function (stats) {
		var m, s, o;

		m = new form.Map('omr-tracker', _('OMR-Tracker - Server'),
			_('Detect if server is down and use defined backup server in this case.'));

		//s = m.section(form.GridSection, 'defaults');
		s = m.section(form.GridSection);
		//s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.cfgsections = function() {
			return this.map.data.sections(this.map.config)
				.filter(function(s) { return cfgtypes.indexOf(s['.type']) !== -1; })
				.map(function(s) { return s['.name']; });
		};

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = false;

		o = s.option(form.ListValue, 'initial_state', _('Initial state'),
			_('Expect interface state on up event'));
		o.default = 'online';
		o.value('online', _('Online'));
		o.value('offline', _('Offline'));
		o.modalonly = true;

		o = s.option(form.ListValue, 'type', _('Tracking method'),_('Check if VPS api answer or/and ping server IPs.'));
		o.default = 'apiping';
		o.value('apiping',_('API & Ping'));
		o.value('api',_('API'));
		o.value('ping',_('Ping'));
		o.value('none',_('None'));

		o = s.option(form.Flag, 'mail_alert', _('Mail alert'),
			_('Send a mail when connection status change. You need to configure e-mail settings here.'));
		o.rmempty = false;
		o.modalonly = true;
/*
		o = s.option(form.Value, 'reliability', _('Tracking reliability'),
			_('Acceptable values: 1-100. This many Tracking IP addresses must respond for the link to be deemed up'));
		o.datatype = 'range(1, 100)';
		o.default = '1';
*/
		o = s.option(form.ListValue, 'tries', _('Test count'));
		o.default = '1';
		o.value('1');
		o.value('2');
		o.value('3');
		o.value('4');
		o.value('5');
		o.modalonly = true;

/*
		o = s.option(form.Flag, 'check_quality', _('Check link quality'));
		o.depends('track_method', 'ping');
		o.default = false;
		o.modalonly = true;
*/
		o = s.option(form.ListValue, "timeout", _("Test timeout"));
		o.default = '4';
		o.value('1', _('%d second').format('1'));
		for (var i = 2; i <= 10; i++)
			o.value(String(i), _('%d seconds').format(i));
		o.modalonly = true;

		o = s.option(form.ListValue, 'interval', _('Test interval'));
		o.default = '10';
		o.value('1', _('%d second').format('1'));
		o.value('3', _('%d seconds').format('3'));
		o.value('5', _('%d seconds').format('5'));
		o.value('10', _('%d seconds').format('10'));
		o.value('20', _('%d seconds').format('20'));
		o.value('30', _('%d seconds').format('30'));
		o.value('60', _('%d minute').format('1'));
		o.value('300', _('%d minutes').format('5'));
		o.value('600', _('%d minutes').format('10'));
		o.value('900', _('%d minutes').format('15'));
		o.value('1800', _('%d minutes').format('30'));
		o.value('3600', _('%d hour').format('1'));
/*
		o = s.option(form.Value, 'failure_interval', _('Failure interval'),
			_('Ping interval during failure detection'));
		o.default = '5';
		o.value('1', _('%d second').format('1'));
		o.value('3', _('%d seconds').format('3'));
		o.value('5', _('%d seconds').format('5'));
		o.value('10', _('%d seconds').format('10'));
		o.value('20', _('%d seconds').format('20'));
		o.value('30', _('%d seconds').format('30'));
		o.value('60', _('%d minute').format('1'));
		o.value('300', _('%d minutes').format('5'));
		o.value('600', _('%d minutes').format('10'));
		o.value('900', _('%d minutes').format('15'));
		o.value('1800', _('%d minutes').format('30'));
		o.value('3600', _('%d hour').format('1'));
		o.modalonly = true;

		o = s.option(form.Flag, 'keep_failure_interval', _('Keep failure interval'),
			_('Keep ping failure interval during failure state'));
		o.default = false;
		o.modalonly = true;

		o = s.option(form.Value, 'recovery_interval', _('Recovery interval'),
			_('Ping interval during failure recovering'));
		o.default = '5';
		o.value('1', _('%d second').format('1'));
		o.value('3', _('%d seconds').format('3'));
		o.value('5', _('%d seconds').format('5'));
		o.value('10', _('%d seconds').format('10'));
		o.value('20', _('%d seconds').format('20'));
		o.value('30', _('%d seconds').format('30'));
		o.value('60', _('%d minute').format('1'));
		o.value('300', _('%d minutes').format('5'));
		o.value('600', _('%d minutes').format('10'));
		o.value('900', _('%d minutes').format('15'));
		o.value('1800', _('%d minutes').format('30'));
		o.value('3600', _('%d hour').format('1'));
		o.modalonly = true;

		o = s.option(form.ListValue, 'down', _('Interface down'),
			_('Interface will be deemed down after this many failed ping tests'));
		o.default = '5';
		o.value('1');
		o.value('2');
		o.value('3');
		o.value('4');
		o.value('5');
		o.value('6');
		o.value('7');
		o.value('8');
		o.value('9');
		o.value('10');

		o = s.option(form.ListValue, 'up', _('Interface up'),
			_('Downed interface will be deemed up after this many successful ping tests'));
		o.default = "5";
		o.value('1');
		o.value('2');
		o.value('3');
		o.value('4');
		o.value('5');
		o.value('6');
		o.value('7');
		o.value('8');
		o.value('9');
		o.value('10');
*/
		return m.render();
	}
})
