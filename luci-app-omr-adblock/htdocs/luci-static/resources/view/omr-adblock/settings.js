'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require poll';
'require ui';
'require dom';
'require tools.widgets as widgets';

var callStatus = rpc.declare({
	object: 'omr-adblock',
	method: 'status',
	expect: { }
});

var callAction = rpc.declare({
	object: 'omr-adblock',
	method: 'action',
	params: [ 'action', 'seconds' ],
	expect: { }
});

var statusLabels = {
	active: [ _('Active'), 'green' ],
	paused: [ _('Paused'), 'orange' ],
	processing: [ _('Downloading and processing the lists'), 'orange' ],
	waiting: [ _('Waiting for the network'), 'orange' ],
	error: [ _('Error'), 'red' ],
	stopped: [ _('Stopped'), 'red' ],
	disabled: [ _('Disabled'), 'gray' ]
};

/* the message that goes with each code omr-adblock reports; the info of
 * the code (a list name, a dnsmasq error) is shown after it */
var codeLabels = {
	noLists: _('No list nor blocked domain is enabled'),
	noRoute: _('No default route: the lists can not be downloaded'),
	allListsFailed: _('No block-list could be downloaded'),
	processingFailed: _('The lists could not be processed'),
	dnsmasqTestFailed: _('dnsmasq refused the new blocklist'),
	blocklistNotLoaded: _('dnsmasq did not load the blocklist'),
	dnsmasqRestartFailed: _('dnsmasq did not answer after a restart'),
	addnmountMissing: _('The dnsmasq jail mounts could not be added'),
	confWriteFailed: _('The dnsmasq configuration could not be written'),
	noInstance: _('No dnsmasq instance matches the configuration'),
	confScriptUnsupported: _('This dnsmasq is too old (no --conf-script)'),
	downloadFailed: _('Download failed'),
	htmlList: _('The server sent a web page, not a list'),
	emptyList: _('No domain in the downloaded list'),
	heartbeatFailed: _('The heartbeat domain did not resolve'),
	restoredPrevious: _('The previous blocklist was loaded again'),
	badSchedule: _('The update schedule is not a cron time'),
	badList: _('A tab or a line break in the name or the URL of a list')
};

function formatSize(bytes) {
	return bytes ? '%1024.2mB'.format(bytes) : '-';
}

function formatTime(epoch) {
	return epoch ? new Date(epoch * 1000).toLocaleString() : '-';
}

function renderMessages(list, cls) {
	return (list || []).map(function(m) {
		return E('div', { 'class': 'alert-message ' + cls }, [
			E('strong', {}, codeLabels[m.code] || m.code), ' ', m.info || ''
		]);
	});
}

function renderStatus(st) {
	var run = st.run || {},
	    label = statusLabels[run.status] || [ run.status ? run.status : _('Not started'), 'gray' ],
	    rows = [];

	rows.push([ _('Status'), E('span', { 'style': 'color:' + label[1] + ';font-weight:bold' }, label[0]) ]);
	if (run.status == 'paused' && run.paused_until)
		rows.push([ _('Paused until'), formatTime(run.paused_until) ]);
	if (run.entries) {
		rows.push([ _('Blocked domains'), String(run.entries) ]);
		rows.push([ _('Blocklist size'), _('%s compressed in RAM, %s for dnsmasq').format(formatSize(run.size_gz), formatSize(run.size_raw)) ]);
		rows.push([ _('Last update'), _('%s, from %s in %d s').format(formatTime(run.updated),
			run.source == 'cache' ? _('the cache') : _('the download'), run.duration || 0) ]);
	}

	var table = E('table', { 'class': 'table' }, rows.map(function(r) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '33%' }, r[0]),
			E('td', { 'class': 'td left' }, r[1])
		]);
	}));

	return E('div', {}, [ table ]
		.concat(renderMessages(run.errors, 'danger'))
		.concat(renderMessages(run.warnings, 'warning')));
}

function runAction(action, seconds) {
	return callAction(action, seconds).then(function(res) {
		if (res && res.result === false)
			ui.addNotification(null, E('p', {}, res.message || _('The action failed')), 'danger');
		return refresh();
	});
}

function renderButtons(st) {
	var run = st.run || {}, buttons = [];
	var btn = function(title, cls, action, seconds) {
		return E('button', {
			'class': 'btn ' + cls,
			'click': ui.createHandlerFn(this, function() { return runAction(action, seconds); })
		}, title);
	};

	if (!st.enabled) {
		buttons.push(btn(_('Enable'), 'cbi-button-positive', 'enable'));
	} else {
		if (run.status == 'paused')
			buttons.push(btn(_('Resume'), 'cbi-button-positive', 'resume'));
		else if (run.status != 'active')
			buttons.push(btn(_('Start'), 'cbi-button-positive', 'start'));
		buttons.push(btn(_('Download the lists'), 'cbi-button-action', 'dl'));
		if (run.status == 'active')
			buttons.push(btn(_('Pause'), 'cbi-button-neutral', 'pause'));
		if (run.status == 'active' || run.status == 'paused')
			buttons.push(btn(_('Stop'), 'cbi-button-negative', 'stop'));
		buttons.push(btn(_('Disable'), 'cbi-button-negative', 'disable'));
	}
	return E('div', { 'class': 'cbi-page-actions', 'style': 'text-align:left' }, buttons);
}

var statusNode, buttonsNode;

function refresh() {
	return callStatus().then(function(st) {
		dom.content(statusNode, renderStatus(st));
		dom.content(buttonsNode, renderButtons(st));
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			callStatus(),
			uci.load('omr-adblock')
		]);
	},

	render: function(data) {
		var m, s, o;

		statusNode = E('div', {}, renderStatus(data[0]));
		buttonsNode = E('div', {}, renderButtons(data[0]));
		poll.add(refresh, 5);

		m = new form.Map('omr-adblock', _('Ad blocking'),
			_('Blocks ads, trackers and malware domains in dnsmasq. The lists are downloaded, merged and kept compressed in RAM; dnsmasq unpacks them when it starts.'));

		s = m.section(form.NamedSection, 'config', 'omr-adblock');
		s.tab('basic', _('Basic settings'));
		s.tab('stats', _('Statistics'));
		s.tab('advanced', _('Advanced settings'));
		o = s.taboption('basic', form.Flag, 'force_dns', _('Force the router DNS'),
			_('DNS queries sent to another server on port 53 are answered by the router, the other ports below (853: DNS over TLS and QUIC) are refused.'));
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('basic', widgets.NetworkSelect, 'force_dns_interface', _('Interfaces'));
		o.multiple = true;
		o.nocreate = true;
		o.depends('force_dns', '1');
		o.retain = true;

		o = s.taboption('basic', form.DynamicList, 'force_dns_port', _('Ports'),
			_('Port 53 is redirected to dnsmasq, the others are refused.'));
		o.datatype = 'port';
		o.depends('force_dns', '1');
		o.retain = true;

		o = s.taboption('basic', form.Value, 'update_schedule', _('Update schedule'),
			_('When the lists are downloaded again, as a cron time (minute hour day month weekday). Empty: never.'));
		o.value('', _('Never'));
		o.value('30 4 * * *', _('Every day at 4:30'));
		o.value('30 4 * * 1', _('Every Monday at 4:30'));
		o.validate = function(section_id, value) {
			if (value && !/^[0-9*\/,-]+( +[0-9*\/,-]+){4}$/.test(value))
				return _('Expecting a cron time of five fields');
			return true;
		};

		o = s.taboption('basic', form.Value, 'heartbeat_domain', _('Heartbeat domain'),
			_('A domain that must still resolve once the blocklist is loaded.'));
		o.datatype = 'hostname';

		o = s.taboption('stats', form.Flag, 'stats', _('Query statistics'),
			_('dnsmasq logs the DNS queries to a file in RAM, added up once a minute for the dashboard. Its other messages (DHCP...) still reach the system log, a minute later at most.'));
		/* not written when on (the default config has none, nor a config from
		 * before this option): only "off" is written
		 */
		o.default = '1';

		o = s.taboption('stats', form.Value, 'stats_hours', _('Period (hours)'),
			_('How long the statistics are kept, at most 168 hours (a week).'));
		o.datatype = 'range(1,168)';
		o.placeholder = '24';
		o.depends('stats', '1');
		o.retain = true;

		o = s.taboption('advanced', form.DynamicList, 'dnsmasq_instance', _('dnsmasq instances'),
			_('The dnsmasq sections the blocklist is loaded into, * for all of them.'));
		o.placeholder = '*';

		o = s.taboption('advanced', form.Flag, 'compressed_cache', _('Keep a copy on flash'),
			_('The compressed blocklist is loaded at boot without waiting for the network. It is written only when it changed.'));
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'compressed_cache_dir', _('Directory of the copy'));
		o.placeholder = '/etc/omr-adblock';
		o.depends('compressed_cache', '1');
		o.retain = true;

		o = s.taboption('advanced', form.ListValue, 'unload_before_update', _('Unload the blocklist during an update'),
			_('Frees the RAM dnsmasq holds for the blocklist while the new one is built: ads are not blocked during the update.'));
		o.value('auto', _('Automatic (under 400 MB of RAM)'));
		o.value('1', _('Always'));
		o.value('0', _('Never'));
		o.default = 'auto';
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'parallel_downloads', _('Parallel downloads'));
		o.datatype = 'range(1,16)';
		o.placeholder = '4';

		o = s.taboption('advanced', form.Value, 'download_timeout', _('Connection timeout (s)'));
		o.datatype = 'range(1,120)';
		o.placeholder = '10';

		o = s.taboption('advanced', form.Value, 'download_max_time', _('Download timeout (s)'));
		o.datatype = 'range(1,3600)';
		o.placeholder = '120';

		o = s.taboption('advanced', form.Value, 'curl_retry', _('Download retries'));
		o.datatype = 'range(0,30)';
		o.placeholder = '3';

		o = s.taboption('advanced', form.Value, 'curl_max_file_size', _('Largest list (bytes)'));
		o.datatype = 'uinteger';
		o.placeholder = '30000000';

		o = s.taboption('advanced', form.Value, 'pause_timeout', _('Pause (s)'));
		o.datatype = 'range(1,86400)';
		o.placeholder = '60';

		o = s.taboption('advanced', form.Flag, 'allow_non_ascii', _('Keep non-ASCII domains'));
		o.rmempty = false;

		o = s.taboption('advanced', form.Value, 'led', _('LED'),
			_('Name of a LED in /sys/class/leds, lit while the blocklist is loaded.'));
		o.rmempty = true;

		o = s.taboption('advanced', form.ListValue, 'verbosity', _('Log'));
		o.value('0', _('Errors only'));
		o.value('1', _('Errors and results'));
		o.value('2', _('Every step'));
		o.default = '2';
		o.rmempty = false;

		return m.render().then(function(node) {
			return E([], [
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, _('Status')),
					statusNode,
					buttonsNode
				]),
				node
			]);
		});
	}
});
