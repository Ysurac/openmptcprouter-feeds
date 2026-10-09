'use strict';
'require dom';
'require form';
'require fs';
'require poll';
'require rpc';
'require ui';
'require view';
'require uci';

var cfgtypes = ['server'];

var callUciState = rpc.declare({
	object: 'uci',
	method: 'state',
	params: [ 'config' ],
	expect: { values: {} }
});

// The master that omr-tracker-server keeps waiting while a backup server
// is in use (failback delayed or manual), and that backup
function getFailbackHold() {
	return L.resolveDefault(callUciState('openmptcprouter'), {}).then(function(sections) {
		var hold = { held: false, master: null, backup: null };

		if (!sections.omr || sections.omr.failback_hold != '1')
			return hold;
		hold.held = true;
		for (var name in sections) {
			var sec = sections[name];
			if (sec['.type'] != 'server' || sec.disabled == '1')
				continue;
			if (sec.master == '1' && !hold.master)
				hold.master = name;
			if (sec.backup == '1' && sec.current == '1')
				hold.backup = name;
		}
		return hold;
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			L.resolveDefault(fs.stat('/usr/bin/httping'), {}),
			L.resolveDefault(fs.stat('/usr/bin/dig'), {}),
//			L.resolveDefault(fs.stat('/usr/bin/nping'), {}),
//			L.resolveDefault(fs.stat('/usr/bin/arping'), {}),
			uci.load('network'),
			getFailbackHold()
		]);
	},

	handleFailback: function(holdNode) {
		if (!confirm(_('Return to the master server now? The proxy and the VPNs restart, which drops the open connections.')))
			return;
		return fs.exec('/etc/init.d/omr-tracker', [ 'failback' ]).then(function(res) {
			if (res.code !== 0)
				throw new Error((res.stdout || res.stderr || '').trim() || String(res.code));
			holdNode.style.display = 'none';
			ui.addNotification(null, E('p', _('The router goes back to the master server at its next check.')), 'info');
		}).catch(function(e) {
			ui.addNotification(null, E('p', _('Unable to return to the master server: %s').format(e.message)), 'error');
		});
	},

	renderFailbackHold: function(holdNode, hold) {
		if (!hold.held) {
			holdNode.style.display = 'none';
			return;
		}
		dom.content(holdNode, [
			E('p', _('The master server %s answers again, but the backup server %s is still in use.').format(hold.master || '?', hold.backup || '?')),
			E('button', {
				'class': 'cbi-button cbi-button-action',
				'click': ui.createHandlerFn(this, 'handleFailback', holdNode)
			}, _('Return to the master server now'))
		]);
		holdNode.style.display = '';
	},

	render: function (stats) {
		var m, s, o;
		var holdNode = E('div', { 'class': 'cbi-section', 'style': 'display:none' });

		this.renderFailbackHold(holdNode, stats[3]);
		poll.add(L.bind(function() {
			return getFailbackHold().then(L.bind(this.renderFailbackHold, this, holdNode));
		}, this), 10);

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

		o = s.option(form.Flag, 'enabled', _('Enabled'),
			_('Enable server monitoring and automatic fallback to a backup server when checks fail.'));
		// omr-tracker runs a section without the option (enabled:bool:1):
		// show it ticked, and write the 0, since an unticked box equal to
		// the default was removed and the tracker kept running
		o.default = o.enabled;
		o.rmempty = false;

		o = s.option(form.ListValue, 'initial_state', _('Initial state'),
			_('Expect interface state on up event'));
		o.default = 'online';
		o.value('online', _('Online'));
		o.value('offline', _('Offline'));
		o.modalonly = true;

		o = s.option(form.ListValue, 'type', _('Tracking method'),_('Choose whether server health is verified through the API, ping probes, or both.'));
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
		o = s.option(form.ListValue, 'tries', _('Test count'),
			_('Number of probes sent during each server test cycle.'));
		o.default = '1';
		o.value('1');
		o.value('2');
		o.value('3');
		o.value('4');
		o.value('5');
		o.modalonly = true;

		o = s.option(form.Flag, 'check_quality', _('Check link quality'),
			_('Use latency and packet loss thresholds to detect degraded server connectivity.'));
		o.depends('type', 'ping');
		o.depends('type', 'apiping');
		o.default = false;
		o.modalonly = true;

		o = s.option(form.Value, 'failure_latency', _('Failure latency [ms]'),
			_('Latency above this value is treated as a failure while quality checks are enabled.'));
		o.depends('check_quality', '1');
		o.default = '1000';
		o.value('25');
		o.value('50');
		o.value('75');
		o.value('100');
		o.value('150');
		o.value('200');
		o.value('250');
		o.value('300');
		o.modalonly = true;

		o = s.option(form.Value, 'failure_loss', _('Failure packet loss [%]'),
			_('Packet loss above this percentage is treated as a failure.'));
		o.depends('check_quality', '1');
		o.default = '40';
		o.value('2');
		o.value('5');
		o.value('10');
		o.value('20');
		o.value('25');
		o.modalonly = true;

		o = s.option(form.Value, 'recovery_latency', _('Recovery latency [ms]'),
			_('Latency must fall below this value before the server is considered healthy again.'));
		o.depends('check_quality', '1');
		o.default = '500';
		o.value('25');
		o.value('50');
		o.value('75');
		o.value('100');
		o.value('150');
		o.value('200');
		o.value('250');
		o.value('300');
		o.modalonly = true;

		o = s.option(form.Value, 'recovery_loss', _('Recovery packet loss [%]'),
			_('Packet loss must fall below this percentage before the server is considered healthy again.'));
		o.depends('check_quality', '1');
		o.default = '10';
		o.value('2');
		o.value('5');
		o.value('10');
		o.value('20');
		o.value('25');
		o.modalonly = true;

		o = s.option(form.ListValue, "timeout", _("Test timeout"),
			_('Maximum time to wait for each API or ping test before it is counted as failed.'));
		o.default = '4';
		o.value('1', _('%d second').format('1'));
		for (var i = 2; i <= 10; i++)
			o.value(String(i), _('%d seconds').format(i));
		o.modalonly = true;

		o = s.option(form.ListValue, 'interval', _('Test interval'),
			_('Delay between regular server health checks while the server is considered available.'));
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

		// omr-tracker-server and the tracker use the same defaults
		o = s.option(form.ListValue, 'failback', _('Return to the master server'),
			_('When to go back to the master server once it answers again while a backup server is in use. Changing server restarts the proxy and the VPNs, which drops the open connections. When the backup server stops answering, the router goes back to the master server at once. Manually: with the button shown on this page while the backup server is kept in use, or with "/etc/init.d/omr-tracker failback".'));
		o.default = 'immediate';
		o.value('immediate', _('Immediately'));
		o.value('delayed', _('After a delay'));
		o.value('manual', _('Manually'));

		o = s.option(form.Value, 'failback_delay', _('Failback delay [s]'),
			_('How long the master server must answer without interruption before the router goes back to it.'));
		o.depends('failback', 'delayed');
		o.retain = true;
		o.datatype = 'uinteger';
		o.default = '300';
		o.value('60', _('%d minute').format('1'));
		o.value('300', _('%d minutes').format('5'));
		o.value('900', _('%d minutes').format('15'));
		o.value('1800', _('%d minutes').format('30'));
		o.value('3600', _('%d hour').format('1'));
		o.modalonly = true;
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
		return m.render().then(function(node) {
			var descr = node.querySelector('.cbi-map-descr');
			if (descr)
				descr.parentNode.insertBefore(holdNode, descr.nextSibling);
			else
				node.insertBefore(holdNode, node.firstChild);
			return node;
		});
	}
})
