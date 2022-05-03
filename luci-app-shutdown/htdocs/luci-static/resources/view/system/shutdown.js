'use strict';
'require fs';
'require uci';
'require ui';

return L.view.extend({
	render: function(changes) {
		var body = E([
		    E('h2', _('Shutdown')),
		    E('p', {}, _('Shutdown the operating system of your device'))
		]);

		for (var config in (changes || {})) {
			body.appendChild(E('p', { 'class': 'alert-message warning' },
			_('Warning: There are unsaved changes that will get lost on shutdown!')));
			break;
		}

		body.appendChild(E('hr'));
		body.appendChild(E('button', {
		    'class': 'cbi-button cbi-button-action important',
		    'click': ui.createHandlerFn(this, 'handleShutdown')
		}, _('Perform shutdown')));

	return body;
	},

	handleShutdown: function(ev) {
		return fs.exec('/sbin/poweroff').then(function(res) {
			if (res.code != 0) {
				L.ui.addNotification(null, E('p', _('The poweroff command failed with code %d').format(res.code)));
				L.raise('Error', 'Poweroff failed');
			}
		})
		.catch(function(e) { L.ui.addNotification(null, E('p', e.message)) });
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
