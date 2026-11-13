'use strict';
'require view';
'require uci';
'require rpc';
'require poll';
'require ui';
'require dom';

var callStatus = rpc.declare({
	object: 'omr-adblock',
	method: 'status',
	expect: { }
});

var callCatalog = rpc.declare({
	object: 'omr-adblock',
	method: 'catalog',
	expect: { lists: [] }
});

/* --- lists ------------------------------------------------------------
 *
 * The file_url sections, shown like AdGuard Home's filter lists: the lists
 * are added, edited, switched on and off and deleted here with uci.add/
 * set/remove. Those are staged like any other change of the page and
 * saved with Save & Apply, which downloads them (the config change reloads
 * the service). */

var listsNode, listsTab = 'block', catalog = [], lastStatus = {}, listsDirty = false;

var resultLabels = {
	empty: _('No domain in the list'),
	html: _('Web page, not a list'),
	failed: _('Download failed')
};

function listSections(action) {
	return uci.sections('omr-adblock', 'file_url').filter(function(s) {
		return (s.action == 'allow' ? 'allow' : 'block') == action;
	});
}

/* what the last run says of a list, matched by its URL */
function listRun(url) {
	return ((lastStatus.run || {}).lists || []).filter(function(l) { return l.url == url; })[0];
}

function validUrl(url) {
	return /^(https?:\/\/\S+|file:\/\/\/\S+|\/\S+)$/.test(url);
}

function markDirty() {
	listsDirty = true;
	dom.content(listsNode, renderLists());
}

function addList(name, url, action) {
	var sid = uci.add('omr-adblock', 'file_url');
	uci.set('omr-adblock', sid, 'name', name);
	uci.set('omr-adblock', sid, 'url', url);
	uci.set('omr-adblock', sid, 'action', action);
	uci.set('omr-adblock', sid, 'enabled', '1');
}

/* catalog ids; the small variants, a router has little RAM */
var presets = [
	{ title: _('Security preset'), ids: [ 'hag_threat-intelligence.mini', 'phishing_army', 'hag_fake' ],
	  descr: _('Malware, phishing and scam domains') },
	{ title: _('Family preset'), ids: [ 'hag_nsfw', 'hag_gambling.medium', 'hag_nosafesearch' ],
	  descr: _('Adult content, gambling, and search engines without SafeSearch') }
];

/* adds the lists of the preset that are missing, turns on those that are off */
function applyPreset(p) {
	var entries = catalog.filter(function(l) { return p.ids.indexOf(l.id) >= 0; });
	if (!confirm(_('%s: use these lists?').format(p.title) + '\n\n' + entries.map(function(l) { return l.name; }).join('\n')))
		return;
	entries.forEach(function(l) {
		var s = uci.sections('omr-adblock', 'file_url').filter(function(s) { return s.url == l.url; })[0];
		if (s)
			uci.set('omr-adblock', s['.name'], 'enabled', '1');
		else
			addList(l.name, l.url, 'block');
	});
	markDirty();
}

function modalButtons(okTitle, ok) {
	return E('div', { 'class': 'right' }, [
		E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
		E('button', { 'class': 'btn cbi-button-positive', 'click': ok }, okTitle)
	]);
}

function sizeBadge(size) {
	if (!size || size == '-')
		return '';
	return E('span', {
		'title': _('Size: S under 10 000 domains, M under 30 000, L under 100 000, XL under 200 000, XXL above'),
		'style': 'margin-left:.5em;padding:0 .4em;border:1px solid currentColor;border-radius:.6em;font-size:smaller;opacity:.7' +
			(size == 'XXL' ? ';color:#c00;opacity:1' : '')
	}, size);
}

function openAddModal(action) {
	var present = {}, boxes = [], groups = {}, groupNodes = [];

	uci.sections('omr-adblock', 'file_url').forEach(function(s) { present[s.url] = true; });

	catalog.filter(function(l) { return l.action == action; }).forEach(function(l) {
		var box = E('input', { 'type': 'checkbox' });
		if (present[l.url]) {
			box.checked = true;
			box.disabled = true;
		}
		box.entry = l;
		boxes.push(box);
		var item = E('label', { 'style': 'display:block;margin:.25em 0 .25em 1em;cursor:pointer', 'data-name': (l.name + ' ' + l.group).toLowerCase() }, [
			box, ' ', l.name, sizeBadge(l.size),
			present[l.url] ? E('em', { 'style': 'opacity:.6' }, ' - ' + _('already in the lists')) : ''
		]);
		if (!groups[l.group]) {
			groups[l.group] = E('details', {}, [ E('summary', { 'style': 'cursor:pointer;font-weight:bold;margin:.3em 0' },
				l.group == 'Others' ? _('Others') : l.group) ]);
			groupNodes.push(groups[l.group]);
		}
		groups[l.group].appendChild(item);
	});
	groupNodes.forEach(function(g) {
		var summary = g.querySelector('summary');
		summary.textContent += ' (%d)'.format(g.querySelectorAll('label').length);
	});

	var search = E('input', {
		'type': 'search', 'class': 'cbi-input-text', 'style': 'width:100%',
		'placeholder': _('Search a list: hagezi, tracking, porn, gambling…')
	});
	search.addEventListener('input', function() {
		var q = search.value.trim().toLowerCase();
		groupNodes.forEach(function(g) {
			var shown = 0;
			g.querySelectorAll('label').forEach(function(item) {
				var match = !q || item.getAttribute('data-name').indexOf(q) >= 0;
				item.style.display = match ? 'block' : 'none';
				shown += match;
			});
			g.style.display = shown ? '' : 'none';
			g.open = !!q && shown > 0;
		});
	});

	var name = E('input', { 'type': 'text', 'class': 'cbi-input-text', 'style': 'width:100%', 'placeholder': _('My list') }),
	    url = E('input', { 'type': 'text', 'class': 'cbi-input-text', 'style': 'width:100%', 'placeholder': 'https://example.com/hosts.txt' }),
	    customError = E('div', { 'style': 'color:red' });

	var paneCatalog = E('div', {}, [
		search,
		E('div', { 'style': 'max-height:50vh;overflow:auto;margin:.5em 0' },
			groupNodes.length ? groupNodes : E('em', {}, _('The catalog has no list of this kind.')))
	]);
	var paneCustom = E('div', { 'style': 'display:none' }, [
		E('p', {}, _('Hosts files, lists of domains (also with "*." wildcards), dnsmasq files, the domain rules of Adblock Plus lists ("||domain^"), a .tar.gz archive (its <name>/domains file, or the file given after #), or a local file as file:///path.')),
		E('label', {}, _('Name')), name,
		E('label', { 'style': 'display:block;margin-top:.5em' }, _('URL')), url,
		customError
	]);

	var tabCatalog = E('button', { 'class': 'btn cbi-button-action' }, _('From the catalog')),
	    tabCustom = E('button', { 'class': 'btn' }, _('Custom list'));
	var showTab = function(custom) {
		paneCatalog.style.display = custom ? 'none' : '';
		paneCustom.style.display = custom ? '' : 'none';
		tabCatalog.className = 'btn' + (custom ? '' : ' cbi-button-action');
		tabCustom.className = 'btn' + (custom ? ' cbi-button-action' : '');
	};
	tabCatalog.addEventListener('click', function() { showTab(false); });
	tabCustom.addEventListener('click', function() { showTab(true); });

	var ok = function() {
		if (paneCustom.style.display != 'none') {
			var n = name.value.trim(), u = url.value.trim();
			if (!n || !validUrl(u))
				return (customError.textContent = _('Give a name and an http(s) URL or a local file.'));
			if (present[u])
				return (customError.textContent = _('This URL is already in the lists.'));
			addList(n, u, action);
		} else {
			var picked = boxes.filter(function(b) { return b.checked && !b.disabled; });
			if (!picked.length)
				return ui.hideModal();
			picked.forEach(function(b) { addList(b.entry.name, b.entry.url, action); });
		}
		ui.hideModal();
		markDirty();
	};

	ui.showModal(action == 'block' ? _('Add blocklists') : _('Add allowlists'), [
		E('div', { 'style': 'margin-bottom:.8em' }, [ tabCatalog, ' ', tabCustom ]),
		paneCatalog,
		paneCustom,
		modalButtons(_('Add'), ok)
	]);
	search.focus();
}

function openEditModal(s) {
	var name = E('input', { 'type': 'text', 'class': 'cbi-input-text', 'style': 'width:100%', 'value': s.name || '' }),
	    url = E('input', { 'type': 'text', 'class': 'cbi-input-text', 'style': 'width:100%', 'value': s.url || '' }),
	    action = E('select', { 'class': 'cbi-input-select' }, [
		E('option', { 'value': 'block' }, _('Blocklist')),
		E('option', { 'value': 'allow' }, _('Allowlist'))
	    ]),
	    err = E('div', { 'style': 'color:red' });
	action.value = s.action == 'allow' ? 'allow' : 'block';

	ui.showModal(_('Edit the list'), [
		E('label', {}, _('Name')), name,
		E('label', { 'style': 'display:block;margin-top:.5em' }, _('URL')), url,
		E('label', { 'style': 'display:block;margin-top:.5em' }, _('Kind')), action,
		err,
		modalButtons(_('Save'), function() {
			var n = name.value.trim(), u = url.value.trim();
			if (!n || !validUrl(u))
				return (err.textContent = _('Give a name and an http(s) URL or a local file.'));
			uci.set('omr-adblock', s['.name'], 'name', n);
			uci.set('omr-adblock', s['.name'], 'url', u);
			uci.set('omr-adblock', s['.name'], 'action', action.value);
			ui.hideModal();
			markDirty();
		})
	]);
}

function renderListRow(s) {
	var enabled = s.enabled != '0', run = listRun(s.url), state;

	if (!enabled)
		state = E('span', { 'style': 'opacity:.6' }, _('Disabled'));
	else if (!run)
		state = E('span', { 'style': 'opacity:.6' }, _('Not downloaded yet'));
	else if (run.result == 'ok')
		state = E('span', { 'style': 'color:green' }, '✔ ' + _('OK'));
	else
		state = E('span', { 'style': 'color:red' }, '✘ ' + (resultLabels[run.result] || resultLabels.failed));

	var toggle = E('input', { 'type': 'checkbox', 'title': enabled ? _('Turn this list off') : _('Turn this list on') });
	toggle.checked = enabled;
	toggle.addEventListener('change', function() {
		uci.set('omr-adblock', s['.name'], 'enabled', toggle.checked ? '1' : '0');
		markDirty();
	});

	var link = /^https?:\/\//.test(s.url || '') ? 'a' : 'span';
	return E('tr', { 'class': 'tr', 'style': enabled ? '' : 'opacity:.6' }, [
		E('td', { 'class': 'td', 'style': 'width:2em' }, toggle),
		E('td', { 'class': 'td' }, [
			E('strong', {}, s.name || _('Unnamed list')), E('br'),
			E(link, {
				'href': link == 'a' ? s.url : null, 'target': '_blank', 'rel': 'noreferrer', 'title': s.url,
				'style': 'font-size:smaller;opacity:.7;display:inline-block;max-width:32em;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;vertical-align:bottom'
			}, s.url || '')
		]),
		E('td', { 'class': 'td', 'style': 'text-align:right' },
			run && run.result == 'ok' && enabled ? Number(run.entries).toLocaleString() : '-'),
		E('td', { 'class': 'td' }, state),
		E('td', { 'class': 'td', 'style': 'text-align:right;white-space:nowrap' }, [
			E('button', { 'class': 'btn cbi-button-edit', 'click': function() { openEditModal(s); } }, _('Edit')), ' ',
			E('button', { 'class': 'btn cbi-button-remove', 'click': function() {
				if (!confirm(_('Delete the list "%s"?').format(s.name || s.url)))
					return;
				uci.remove('omr-adblock', s['.name']);
				markDirty();
			} }, _('Delete'))
		])
	]);
}

function renderLists() {
	var action = listsTab, sections = listSections(action);

	var tab = function(a, title) {
		var on = listSections(a).filter(function(s) { return s.enabled != '0'; }).length;
		return E('button', {
			'class': 'btn' + (a == action ? ' cbi-button-action' : ''),
			'click': function() { listsTab = a; dom.content(listsNode, renderLists()); }
		}, '%s (%d/%d)'.format(title, on, listSections(a).length));
	};

	/* the lists in use first, each part in the config order */
	var rows = sections.filter(function(s) { return s.enabled != '0'; })
		.concat(sections.filter(function(s) { return s.enabled == '0'; }))
		.map(renderListRow);
	if (!rows.length)
		rows.push(E('tr', { 'class': 'tr placeholder' }, E('td', { 'class': 'td', 'colspan': 5 }, E('em', {},
			action == 'block' ? _('No blocklist: add one from the catalog.') : _('No allowlist.')))));

	return E('div', {}, [
		E('div', { 'style': 'margin-bottom:.8em' }, [ tab('block', _('Blocklists')), ' ', tab('allow', _('Allowlists')) ]),
		E('div', { 'class': 'cbi-section-descr' }, action == 'block'
			? _('The domains of the enabled blocklists, and their subdomains, are blocked.')
			: _('The domains of an allowlist, and their subdomains, are never blocked, even when a blocklist has them.')),
		listsDirty ? E('div', { 'class': 'alert-message notice' },
			_('The lists changed: press Save & Apply at the bottom of the page to download them.')) : '',
		E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, ''),
				E('th', { 'class': 'th' }, _('Name')),
				E('th', { 'class': 'th', 'style': 'text-align:right' }, _('Domains')),
				E('th', { 'class': 'th' }, _('Last download')),
				E('th', { 'class': 'th' }, '')
			])
		].concat(rows)),
		E('div', { 'class': 'cbi-page-actions', 'style': 'text-align:left' }, [
			E('button', { 'class': 'btn cbi-button-add', 'click': function() { openAddModal(action); } },
				action == 'block' ? _('Add blocklists') : _('Add allowlists'))
		/* flat: E() stringifies nested arrays */
		].concat(action == 'block' ? presets.reduce(function(nodes, p) {
			return nodes.concat([ ' ', E('button', { 'class': 'btn cbi-button-action', 'title': p.descr, 'click': function() { applyPreset(p); } }, p.title) ]);
		}, []) : []))
	]);
}

function refresh() {
	return callStatus().then(function(st) {
		lastStatus = st;
		dom.content(listsNode, renderLists());
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			callStatus(),
			uci.load('omr-adblock'),
			L.resolveDefault(callCatalog(), [])
		]);
	},

	render: function(data) {
		lastStatus = data[0];
		catalog = data[2] || [];
		listsNode = E('div', {}, renderLists());
		poll.add(refresh, 10);

		return E([], [
			E('h2', {}, _('Lists')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Hosts files, lists of domains (also with "*." wildcards), dnsmasq files and the domain rules of Adblock Plus lists ("||domain^") are understood.')),
			E('div', { 'class': 'cbi-section' }, listsNode)
		]);
	},

	/* no form here: the lists are uci changes of their own */
	handleSave: function() {
		return uci.save().then(function() {
			listsDirty = false;
			dom.content(listsNode, renderLists());
		});
	},

	handleReset: function() {
		window.location.reload();
	}
});
