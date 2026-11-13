'use strict';
'require view';
'require rpc';
'require poll';
'require dom';
'require ui';
'require network';

/* Query statistics of omr-adblock, in the Status menu. The service itself
 * is controlled from its Settings page. Nothing runs on the router for them
 * but dnsmasq's own query log and one awk pass a minute; this page asks
 * for one JSON summary and draws it, the chart as plain SVG. */

var callStats = rpc.declare({
	object: 'omr-adblock',
	method: 'stats',
	expect: { }
});

var callStatus = rpc.declare({
	object: 'omr-adblock',
	method: 'status',
	expect: { }
});

var callReset = rpc.declare({
	object: 'omr-adblock',
	method: 'stats_reset',
	expect: { }
});

var callDomain = function(method, domain) {
	return rpc.declare({
		object: 'omr-adblock',
		method: method,
		params: [ 'domain' ],
		expect: { }
	})(domain);
};

var stateLabels = {
	active: _('Active'),
	paused: _('Paused'),
	processing: _('Downloading and processing the lists'),
	waiting: _('Waiting for the network'),
	error: _('Error'),
	stopped: _('Stopped'),
	disabled: _('Disabled')
};

var COLOR_QUERIES = '#5b8def', COLOR_BLOCKED = '#e5534b';

var css = '\
.omr-ab-cards { display:flex; flex-wrap:wrap; gap:1em; margin-bottom:1em }\
.omr-ab-card { flex:1 1 11em; padding:.8em 1em; border:1px solid rgba(128,128,128,.3); border-radius:.5em }\
.omr-ab-card .v { font-size:1.8em; font-weight:bold; line-height:1.3 }\
.omr-ab-card .t { opacity:.7 }\
.omr-ab-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(25em, 1fr)); gap:1em }\
.omr-ab-grid table { width:100% }\
.omr-ab-bar { height:.3em; border-radius:.15em; margin-top:.2em }\
.omr-ab-grid td { vertical-align:middle }\
.omr-ab-grid .btn { padding:.2em .6em; font-size:smaller }';

function fmt(n) {
	return Number(n || 0).toLocaleString();
}

function pct(part, all) {
	return all ? (100 * part / all).toFixed(1) + ' %' : '0 %';
}

function card(title, value, sub, color) {
	return E('div', { 'class': 'omr-ab-card' }, [
		E('div', { 'class': 't' }, title),
		E('div', { 'class': 'v', 'style': color ? 'color:' + color : '' }, value),
		E('div', { 'class': 't' }, sub || ' ')
	]);
}

/* one bar per hour: the queries, the blocked ones over them */
function chart(series) {
	var w = 24, h = 120, max = 1, svg = [], i;

	series.forEach(function(p) { max = Math.max(max, p.queries); });
	for (i = 0; i < series.length; i++) {
		var p = series[i], x = i * w,
		    hq = Math.round(p.queries / max * h), hb = Math.round(p.blocked / max * h),
		    d = new Date(p.time * 1000),
		    label = '%02d:00'.format(d.getHours());
		svg.push('<g><title>' + label + ' - ' + _('%s queries, %s blocked').format(fmt(p.queries), fmt(p.blocked)) + '</title>' +
			'<rect x="' + (x + 3) + '" y="' + (h - hq) + '" width="' + (w - 6) + '" height="' + hq + '" fill="' + COLOR_QUERIES + '" opacity=".45"/>' +
			'<rect x="' + (x + 3) + '" y="' + (h - hb) + '" width="' + (w - 6) + '" height="' + hb + '" fill="' + COLOR_BLOCKED + '"/>' +
			'<rect x="' + x + '" y="0" width="' + w + '" height="' + h + '" fill="transparent"/></g>');
		if (i % 6 == 0)
			svg.push('<text x="' + (x + 2) + '" y="' + (h + 14) + '" font-size="10" fill="currentColor" opacity=".7">' + label + '</text>');
	}

	var node = E('div', { 'style': 'margin:.5em 0 1em' });
	node.innerHTML = '<svg viewBox="0 0 ' + (series.length * w) + ' ' + (h + 18) + '" preserveAspectRatio="none" ' +
		'style="width:100%;height:10em;display:block">' + svg.join('') + '</svg>';
	return E('div', {}, [
		node,
		E('div', { 'style': 'font-size:smaller' }, [
			E('span', { 'style': 'color:' + COLOR_QUERIES }, '■'), ' ', _('Queries'), ' ',
			E('span', { 'style': 'color:' + COLOR_BLOCKED }, '■'), ' ', _('Blocked')
		])
	]);
}

function domainAction(method, domain) {
	return callDomain(method, domain).then(function(res) {
		ui.addNotification(null, E('p', {}, (res && res.message) || ''), res && res.result ? 'info' : 'danger');
	});
}

/* a ranking: name, count with a bar, and an action button per row */
function ranking(title, rows, color, total, action, actionTitle, extra) {
	var max = rows.length ? rows[0].count : 1;
	var body = rows.map(function(r) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td', 'style': 'overflow-wrap:anywhere' }, [
				r.label || r.name,
				E('div', { 'class': 'omr-ab-bar', 'style': 'width:' + Math.max(2, 100 * r.count / max) + '%;background:' + color })
			]),
			E('td', { 'class': 'td', 'style': 'text-align:right;white-space:nowrap' }, [
				fmt(r.count), E('br'),
				E('small', { 'style': 'opacity:.7' }, extra ? extra(r) : pct(r.count, total))
			]),
			E('td', { 'class': 'td', 'style': 'text-align:right;width:1%' }, action ? E('button', {
				'class': 'btn cbi-button-' + (action == 'allow' ? 'positive' : 'negative'),
				'click': ui.createHandlerFn(this, domainAction, action, r.name)
			}, actionTitle) : '')
		]);
	});
	if (!body.length)
		body.push(E('tr', { 'class': 'tr placeholder' }, E('td', { 'class': 'td', 'colspan': 3 }, E('em', {}, _('Nothing yet')))));
	return E('div', { 'class': 'cbi-section' }, [
		E('h3', {}, title),
		E('table', { 'class': 'table' }, body)
	]);
}

var container, hints;

function renderAll(stats, status) {
	var run = (status && status.run) || {};

	if (!stats || !stats.enabled)
		return E('div', { 'class': 'cbi-section' }, [
			E('p', {}, _('The query statistics are off.')),
			E('a', { 'class': 'btn cbi-button-action', 'href': L.url('admin/services/omr-adblock/settings') }, _('Settings'))
		]);

	var clients = (stats.top_clients || []).map(function(c) {
		var name = (c.name == '127.0.0.1' || c.name == '::1') ? _('This router')
			: (hints ? hints.getHostnameByIPAddr(c.name) : null);
		return { name: c.name, label: name ? '%s (%s)'.format(name, c.name) : c.name, count: c.count, blocked: c.blocked };
	});

	return E('div', {}, [
		E('div', { 'class': 'omr-ab-cards' }, [
			card(_('DNS queries'), fmt(stats.queries), _('last %d h').format(stats.hours)),
			card(_('Blocked'), fmt(stats.blocked), pct(stats.blocked, stats.queries), COLOR_BLOCKED),
			card(_('Domains in the blocklist'), fmt(run.entries), stateLabels[run.status] || run.status || '-'),
			card(_('Clients'), fmt(stats.clients), _('%s different domains').format(fmt(stats.domains)))
		]),
		E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Queries per hour')),
			chart(stats.series || [])
		]),
		E('div', { 'class': 'omr-ab-grid' }, [
			ranking(_('Top queried domains'), stats.top_queried || [], COLOR_QUERIES, stats.queries, 'block', _('Block')),
			ranking(_('Top blocked domains'), stats.top_blocked || [], COLOR_BLOCKED, stats.blocked, 'allow', _('Allow')),
			ranking(_('Top clients'), clients, COLOR_QUERIES, stats.queries, null, null, function(r) {
				return _('%s blocked').format(pct(r.blocked, r.count));
			})
		]),
		E('div', { 'class': 'cbi-section-descr', 'style': 'margin-top:1em' }, [
			_('Statistics of the last %d hours, kept in RAM: they start again after a reboot.').format(stats.hours), ' ',
			E('button', { 'class': 'btn cbi-button-reset', 'click': ui.createHandlerFn(this, function() {
				if (!confirm(_('Reset the statistics?')))
					return;
				return callReset().then(refresh);
			}) }, _('Reset the statistics'))
		])
	]);
}

function refresh() {
	return Promise.all([ callStats(), callStatus() ]).then(function(data) {
		dom.content(container, renderAll(data[0], data[1]));
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			callStats(),
			callStatus(),
			L.resolveDefault(network.getHostHints(), null)
		]);
	},

	render: function(data) {
		hints = data[2];
		container = E('div', {}, renderAll(data[0], data[1]));
		poll.add(refresh, 10);
		return E([], [
			E('style', {}, css),
			E('h2', {}, _('Ad blocking')),
			container
		]);
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
