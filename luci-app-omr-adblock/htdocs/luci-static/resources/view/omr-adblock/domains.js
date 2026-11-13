'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require ui';

var callDomain = function(method, domain) {
	return rpc.declare({
		object: 'omr-adblock',
		method: method,
		params: [ 'domain' ],
		expect: { }
	})(domain);
};

/* a domain checked against the loaded blocklist or the enabled lists, and
 * allowed or blocked at once, without a download */
function renderDomainTools() {
	var input = E('input', { 'type': 'text', 'class': 'cbi-input-text', 'placeholder': 'ads.example.com' }),
	    out = E('pre', { 'style': 'display:none;white-space:pre-wrap' });

	var run = function(method) {
		var domain = input.value.trim();
		if (!domain)
			return Promise.resolve();
		out.style.display = '';
		out.textContent = method == 'check_lists' ? _('Downloading the enabled lists…') : '…';
		return callDomain(method, domain).then(function(res) {
			out.textContent = (res && res.message) || '';
			/* omr-adblock writes the domain into the config: the form below
			 * shows the config as loaded, and a Save would remove it again */
			if (res && res.result && (method == 'allow' || method == 'block'))
				window.setTimeout(function() { window.location.reload(); }, 5000);
		});
	};

	return E('div', { 'class': 'cbi-section' }, [
		E('h3', {}, _('Check a domain')),
		E('div', { 'class': 'cbi-section-descr' },
			_('Allow and Block take effect at once, without downloading the lists again, and add the domain to the lists above.')),
		E('div', { 'class': 'cbi-value' }, [
			input, ' ',
			E('button', { 'class': 'btn cbi-button-action', 'click': ui.createHandlerFn(this, run, 'check') }, _('Check the blocklist')), ' ',
			E('button', { 'class': 'btn cbi-button-action', 'click': ui.createHandlerFn(this, run, 'check_lists') }, _('Check the lists')), ' ',
			E('button', { 'class': 'btn cbi-button-positive', 'click': ui.createHandlerFn(this, run, 'allow') }, _('Allow')), ' ',
			E('button', { 'class': 'btn cbi-button-negative', 'click': ui.createHandlerFn(this, run, 'block') }, _('Block'))
		]),
		out
	]);
}

return view.extend({
	load: function() {
		return uci.load('omr-adblock');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('omr-adblock', _('Allowed and blocked domains'),
			_('Domains allowed or blocked by hand, on top of the lists.'));

		s = m.section(form.NamedSection, 'config', 'omr-adblock');

		o = s.option(form.DynamicList, 'allowed_domain', _('Allowed domains'),
			_('Never blocked, with their subdomains, even when a list has them.'));
		o.datatype = 'hostname';

		o = s.option(form.DynamicList, 'blocked_domain', _('Blocked domains'),
			_('Blocked with their subdomains, in addition to the lists.'));
		o.datatype = 'hostname';

		o = s.option(form.Flag, 'canary_domains_mozilla', _('Block the Mozilla canary domain'),
			_('Firefox does not turn on its own DNS over HTTPS.'));
		o.rmempty = false;

		o = s.option(form.Flag, 'canary_domains_icloud', _('Block the iCloud Private Relay domains'),
			_('Apple devices do not use iCloud Private Relay, which would bypass the blocklist.'));
		o.rmempty = false;

		return m.render().then(function(node) {
			return E([], [ node, renderDomainTools() ]);
		});
	}
});
