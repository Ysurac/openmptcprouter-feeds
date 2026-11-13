'use strict';
'require view';
'require form';
'require fs';
'require rpc';
'require ui';
'require uci';
'require network';
'require tools.widgets as widgets';

var callStatus = rpc.declare({
	object: 'omr-parental',
	method: 'status',
	expect: { rules: {} }
});

var callReward = rpc.declare({
	object: 'omr-parental',
	method: 'reward',
	params: [ 'rule', 'minutes' ]
});

var callPause = rpc.declare({
	object: 'omr-parental',
	method: 'pause',
	params: [ 'rule', 'minutes' ]
});

var callResume = rpc.declare({
	object: 'omr-parental',
	method: 'resume',
	params: [ 'rule' ]
});

var callRequests = rpc.declare({
	object: 'omr-parental',
	method: 'requests',
	expect: { requests: [] }
});

var callAnswer = rpc.declare({
	object: 'omr-parental',
	method: 'answer',
	params: [ 'id', 'approve', 'minutes' ]
});

var callReport = rpc.declare({
	object: 'omr-parental',
	method: 'report',
	params: [ 'rule' ]
});

/* lists of the omr-adblock catalog, downloaded for the rules that block them */
var categories = [
	[ 'hag_nsfw', _('Adult content') ],
	[ 'hag_gambling', _('Gambling') ],
	[ 'ipf_dating', _('Dating') ],
	[ 'hag_social', _('Social networks') ],
	[ 'utc_chat', _('Chat') ],
	[ 'ipf_games', _('Games') ],
	[ 'ipf_streaming', _('Video and music streaming') ],
	[ 'ipf_shopping', _('Shopping') ],
	[ 'utc_ai', _('Artificial intelligence') ],
	[ 'ipf_violence', _('Violence') ],
	[ 'utc_drogue', _('Drugs') ],
	[ 'hag_anti.piracy', _('Piracy') ],
	[ 'hag_fake', _('Scams and fake shops') ],
	[ 'hag_threat-intelligence.mini', _('Malware and phishing') ],
	[ 'hag_doh-vpn-proxy-bypass', _('VPNs, proxies and encrypted DNS (ways around the filter)') ]
];

var usage = {};
var hostHints = null;

function hhmm(epoch) {
	var d = new Date(epoch * 1000);
	return '%02d:%02d'.format(d.getHours(), d.getMinutes());
}

function dateTime(epoch) {
	var d = new Date(epoch * 1000);
	return '%04d-%02d-%02d %02d:%02d'.format(d.getFullYear(), d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes());
}

function usageText(sid) {
	var r = usage[sid], state;
	if (!r)
		return '-';
	if (r.paused != null)
		state = r.paused ? _('Paused until %s').format(hhmm(r.paused)) : _('Paused');
	else if (r.allowed != null)
		state = _('Allowed until %s').format(hhmm(r.allowed));
	else if (r.state == 'window')
		state = _('Cut (time window)');
	else if (r.state == 'limit')
		state = _('Cut (limit used)');
	else
		state = null;
	var used = (r.limit != null) ? _('%d of %d min').format(r.used, (+r.limit) + (+r.bonus)) : null;
	return [ state, used ].filter(function(t) { return t; }).join(' · ') || '-';
}

function refreshUsage(sid) {
	return callStatus().then(function(st) {
		usage = st || {};
		var node = document.querySelector('output[for="cbid.omr-parental.%s._used"]'.format(sid));
		if (node)
			node.textContent = usageText(sid);
		var btn = document.querySelector('[data-pause="%s"]'.format(sid));
		if (btn)
			btn.textContent = (usage[sid] && usage[sid].paused != null) ? _('Resume') : _('Pause');
	});
}

function deviceName(mac, ip) {
	var name = null;
	if (hostHints && mac && mac != '-')
		name = hostHints.getHostnameByMACAddr(mac);
	if (!name && hostHints && ip)
		name = hostHints.getHostnameByIPAddr(ip);
	return name ? '%s (%s)'.format(name, ip) : ip;
}

function ruleName(sid) {
	return uci.get('omr-parental', sid, 'name') || sid;
}

function table(headers, rows) {
	return E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr table-titles' }, headers.map(function(h) { return E('th', { 'class': 'th' }, h); }))
	].concat(rows.length ? rows.map(function(r) {
		return E('tr', { 'class': 'tr' }, r.map(function(c) { return E('td', { 'class': 'td' }, c); }));
	}) : [ E('tr', { 'class': 'tr placeholder' }, E('td', { 'class': 'td', 'colspan': headers.length }, E('em', {}, _('None')))) ]));
}

return view.extend({
	load: function() {
		return Promise.all([
			network.getHostHints(),
			L.resolveDefault(fs.read_direct('/usr/share/omr-bypass/omr-bypass-proto.json', 'json'), []),
			L.resolveDefault(callStatus(), {}),
			L.resolveDefault(callRequests(), []),
			uci.load('omr-parental')
		]);
	},

	renderRequests: function(requests) {
		var self = this;
		var pending = requests.filter(function(r) { return r.status == 'pending'; }).reverse();
		var answer = function(r, approve) {
			return callAnswer(r.id, approve, 0).then(function(res) {
				if (!res || !res.result)
					ui.addNotification(null, E('p', (res && res.message) || _('The request could not be answered')));
				return callRequests();
			}).then(function(reqs) {
				var node = document.getElementById('omr-parental-requests');
				if (node)
					node.replaceWith(self.renderRequests(reqs || []));
				return refreshUsage(r.rule);
			});
		};
		return E('div', { 'class': 'cbi-section', 'id': 'omr-parental-requests' }, [
			E('h3', {}, _('Requests')),
			E('div', { 'class': 'cbi-section-descr' }, _('Sent from the request page of the devices. A time request gives their Internet access back for that long, whatever cut it; a site is added to the allowed sites of the rule.')),
			table([ _('Time'), _('Device'), _('Rule'), _('Request'), _('Message'), '' ], pending.map(function(r) {
				return [
					dateTime(r.ts),
					deviceName(r.mac, r.ip),
					ruleName(r.rule),
					(r.type == 'time') ? _('%d more minutes').format(+r.value) : _('Unblock %s').format(r.value),
					r.message || '',
					E('div', {}, [
						E('button', { 'class': 'btn cbi-button-positive', 'click': ui.createHandlerFn(this, answer, r, true) }, _('Approve')), ' ',
						E('button', { 'class': 'btn cbi-button-negative', 'click': ui.createHandlerFn(this, answer, r, false) }, _('Deny'))
					])
				];
			}))
		]);
	},

	showReport: function(sid) {
		return callReport(sid).then(function(rep) {
			rep = rep || {};
			var hist = (rep.history || []).slice().reverse().map(function(h) {
				return [ '%s-%s-%s'.format(h.date.substr(0, 4), h.date.substr(4, 2), h.date.substr(6, 2)), _('%d min').format(h.used) ];
			});
			if (usage[sid] && usage[sid].limit != null)
				hist.unshift([ _('Today'), _('%d min').format(usage[sid].used) ]);
			var blocked = (rep.blocked || []).slice().reverse().map(function(b) {
				return [ dateTime(b.ts), deviceName(null, b.ip), b.domain ];
			});
			var sites = (rep.sites || []).map(function(s) { return [ s.domain, String(s.count) ]; });
			ui.showModal(_('Report: %s').format(ruleName(sid)), [
				E('h4', {}, _('Internet time per day')),
				E('p', { 'class': 'cbi-section-descr' }, _('Rules with a daily limit only.')),
				table([ _('Day'), _('Used') ], hist),
				E('h4', {}, _('Blocked sites')),
				table([ _('Time'), _('Device'), _('Site') ], blocked),
				E('h4', {}, _('Sites visited (last 7 days)')),
				E('p', { 'class': 'cbi-section-descr' }, _('Names asked to the DNS filter of the rule, with "Log the sites visited" on. Kept in memory: a reboot empties it.')),
				table([ _('Site'), _('Queries') ], sites),
				E('div', { 'class': 'right' }, E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Close')))
			], 'cbi-modal');
		});
	},

	render: function(data) {
		var hosts = data[0], protos = data[1] || [], m, s, o, self = this;
		hostHints = hosts;
		usage = data[2] || {};

		m = new form.Map('omr-parental', _('Parental control'),
			_('Each rule targets devices and networks, on its days (every day when none is chosen). During its time window, their Internet access is cut. With a daily limit, each minute they use the Internet counts and their access is cut once the limit is used; Reward gives more minutes for today. Pause cuts it at once, for a while or until resumed. Otherwise, the blocked applications, categories and sites are cut, and with SafeSearch the search engines only show safe results. A rule with no time window, no limit and no filter cuts all day. A window whose end is before its start ends the next day: it counts for the day it starts. The router itself (DNS, DHCP, this interface) stays reachable.'));

		s = m.section(form.NamedSection, 'settings', 'parental');
		s.tab('general', _('General Settings'));
		s.tab('alerts', _('Alerts'));

		o = s.taboption('general', form.Flag, 'enabled', _('Enable'));
		o.default = o.enabled;
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'activity_packets', _('Activity threshold'),
			_('Packets a device sends in a minute for that minute to count in its daily limit. Lower counts the background traffic of an idle phone, higher misses a light use.'));
		o.datatype = 'range(1,100000)';
		o.placeholder = '100';

		o = s.taboption('general', form.Flag, 'requests', _('Request page'),
			_('The devices of a rule can see why their Internet access is cut and ask for more time or for a blocked site at %s. Their requests are listed on this page.').format(
				'http://%s/cgi-bin/omr-parental'.format(window.location.hostname)));
		o.default = o.enabled;
		o.rmempty = false;

		o = s.taboption('alerts', form.Flag, 'alert_limit', _('Daily limit used'));
		o.default = o.enabled;
		o.rmempty = false;

		o = s.taboption('alerts', form.Flag, 'alert_request', _('New request'));
		o.default = o.enabled;
		o.rmempty = false;

		o = s.taboption('alerts', form.Flag, 'alert_blocked', _('Blocked site visited'),
			_('Once a day per site and rule.'));

		o = s.taboption('alerts', form.Flag, 'alert_mail', _('Send alerts by mail'),
			_('Alerts always go to the system log and to the event history; by mail they go to the recipient of the mail settings.'));

		s = m.section(form.GridSection, 'rule', _('Rules'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.nodescriptions = true;
		s.tab('general', _('General Settings'));
		s.tab('sites', _('Sites and applications'));

		o = s.taboption('general', form.Flag, 'enabled', _('Enable'));
		o.default = o.enabled;
		o.rmempty = false;
		o.editable = true;

		o = s.taboption('general', form.Value, 'name', _('Name'));
		o.validate = function(section_id, value) {
			/* the state of a rule is kept by name */
			return (value == '' && this.section.formvalue(section_id, 'daily_limit')) ? _('A rule with a daily limit needs a name') : true;
		};

		o = s.taboption('general', form.DynamicList, 'mac', _('Devices'));
		o.datatype = 'macaddr';
		hosts.getMACHints().forEach(function(h) {
			o.value(h[0], h[1] ? '%s (%s)'.format(h[0], h[1]) : h[0]);
		});

		o = s.taboption('general', widgets.NetworkSelect, 'network', _('Networks'),
			_('Every device connected to these networks, for example a kids network.'));
		o.multiple = true;
		o.nocreate = true;
		o.modalonly = true;
		o.validate = function(section_id, value) {
			var macs = this.section.formvalue(section_id, 'mac');
			return (value || (macs && macs.length)) ? true : _('Choose devices or networks');
		};

		o = s.taboption('general', form.MultiValue, 'days', _('Days'));
		o.value('mon', _('Monday'));
		o.value('tue', _('Tuesday'));
		o.value('wed', _('Wednesday'));
		o.value('thu', _('Thursday'));
		o.value('fri', _('Friday'));
		o.value('sat', _('Saturday'));
		o.value('sun', _('Sunday'));
		o.placeholder = _('Every day');

		var hhmmValid = function(section_id, value) {
			return (value == '' || /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(value)) ? true : _('Expecting a time as HH:MM');
		};

		o = s.taboption('general', form.Value, 'start_time', _('Blocked from'));
		o.placeholder = _('All day');
		o.validate = hhmmValid;

		o = s.taboption('general', form.Value, 'stop_time', _('Blocked until'));
		o.placeholder = _('All day');
		o.validate = function(section_id, value) {
			var res = hhmmValid(section_id, value);
			if (res !== true)
				return res;
			var start = this.section.formvalue(section_id, 'start_time');
			return ((start == '') == (value == '')) ? true : _('Set both times, or none to block all day');
		};

		o = s.taboption('general', form.Value, 'daily_limit', _('Daily limit (min)'));
		o.datatype = 'range(1,1440)';
		o.placeholder = _('No limit');

		o = s.taboption('sites', form.MultiValue, 'app', _('Blocked applications'),
			_('Blocked by the addresses their domains resolve to: the devices must use the router as DNS server (Force DNS of the ad blocker), and an application that shares its addresses with another (CDN) can cut both.'));
		o.modalonly = true;
		protos.filter(function(p) { return p.type == 'application'; })
			.sort(function(a, b) { return a.proto < b.proto ? -1 : 1; })
			.forEach(function(p) { o.value(p.proto, '%s (%s)'.format(p.proto, p.category)); });

		o = s.taboption('sites', form.MultiValue, 'category', _('Blocked categories'),
			_('Lists of sites downloaded each night. Their DNS queries go to a filter of the rule: the devices must use the router as DNS server, and a browser with its own DNS over HTTPS bypasses it, unless "VPNs, proxies and encrypted DNS" is blocked too.'));
		o.modalonly = true;
		categories.forEach(function(c) { o.value(c[0], c[1]); });

		var domainValid = function(section_id, value) {
			return (value == '' || /^[A-Za-z0-9_]([A-Za-z0-9_-]{0,62})(\.[A-Za-z0-9_-]{1,63})+$/.test(value)) ? true : _('Expecting a domain, such as example.com');
		};

		o = s.taboption('sites', form.DynamicList, 'block_domain', _('Blocked sites'),
			_('A domain blocks its subdomains too.'));
		o.modalonly = true;
		o.validate = domainValid;

		o = s.taboption('sites', form.DynamicList, 'allow_domain', _('Allowed sites'),
			_('Never blocked by the categories or the blocked sites. An approved request adds its site here.'));
		o.modalonly = true;
		o.validate = domainValid;

		o = s.taboption('sites', form.Flag, 'safesearch', _('SafeSearch'),
			_('Forces the safe results of Google, YouTube (restricted mode), Bing, DuckDuckGo, Brave and Yandex: the DNS queries of these devices go to the router and get the safe servers of these engines. A browser with its own DNS over HTTPS bypasses it.'));
		o.modalonly = true;

		o = s.taboption('sites', form.Flag, 'log', _('Log the sites visited'),
			_('The names their devices ask the DNS filter of the rule, for its report.'));
		o.modalonly = true;

		o = s.option(form.DummyValue, '_used', _('Today'));
		/* editable: a widget with an id to update, not the grid's plain text */
		o.editable = true;
		o.modalonly = false;
		o.cfgvalue = function(section_id) { return usageText(section_id); };

		o = s.option(form.Button, '_reward', _('Reward'));
		o.editable = true;
		o.modalonly = false;
		o.inputtitle = _('Reward');
		/* not depends(): in a grid it can't read the daily_limit text cell; and only a saved limit counts */
		o.renderWidget = function(section_id) {
			return (usage[section_id] && usage[section_id].limit != null) ? form.Button.prototype.renderWidget.apply(this, arguments) : E('span', {}, '-');
		};
		o.onclick = function(ev, section_id) {
			var give = function(minutes) {
				return callReward(section_id, minutes).then(function(res) {
					if (!res || !res.result)
						ui.addNotification(null, E('p', (res && res.message) || _('Saving the rule first is needed')));
					return refreshUsage(section_id);
				}).then(ui.hideModal);
			};
			ui.showModal(_('Reward'), [
				E('p', {}, _('More minutes of Internet today for this rule.')),
				/* flat: E() stringifies nested arrays */
				E('div', { 'class': 'right' }, [ 15, 30, 60 ].reduce(function(nodes, min) {
					return nodes.concat([ E('button', { 'class': 'btn cbi-button-positive', 'click': ui.createHandlerFn(this, give, min) }, '+%d min'.format(min)), ' ' ]);
				}, []).concat([ E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')) ]))
			]);
		};

		o = s.option(form.DummyValue, '_pause', _('Pause'));
		o.editable = true;
		o.modalonly = false;
		o.renderWidget = function(section_id) {
			if (!usage[section_id])
				return E('span', {}, '-');
			return E('button', {
				'class': 'btn cbi-button-action',
				'data-pause': section_id,
				'click': ui.createHandlerFn(self, 'pauseDialog', section_id)
			}, (usage[section_id].paused != null) ? _('Resume') : _('Pause'));
		};

		o = s.option(form.DummyValue, '_report', _('Report'));
		o.editable = true;
		o.modalonly = false;
		o.renderWidget = function(section_id) {
			if (!usage[section_id])
				return E('span', {}, '-');
			return E('button', { 'class': 'btn', 'click': ui.createHandlerFn(self, 'showReport', section_id) }, _('Report'));
		};

		return m.render().then(function(node) {
			return E('div', {}, [ self.renderRequests(data[3] || []), node ]);
		});
	},

	pauseDialog: function(sid) {
		var done = function(p) {
			return p.then(function(res) {
				if (!res || !res.result)
					ui.addNotification(null, E('p', (res && res.message) || _('Saving the rule first is needed')));
				return refreshUsage(sid);
			}).then(ui.hideModal);
		};
		if (usage[sid] && usage[sid].paused != null)
			return done(callResume(sid));
		ui.showModal(_('Pause: %s').format(ruleName(sid)), [
			E('p', {}, _('Cut the Internet access of the devices of this rule now.')),
			E('div', { 'class': 'right' }, [ [ 15, _('15 min') ], [ 60, _('1 hour') ], [ 120, _('2 hours') ], [ 0, _('Until resumed') ] ].reduce(function(nodes, p) {
				return nodes.concat([ E('button', { 'class': 'btn cbi-button-negative', 'click': ui.createHandlerFn(this, function() { return done(callPause(sid, p[0])); }) }, p[1]), ' ' ]);
			}, []).concat([ E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')) ]))
		]);
	}
});
