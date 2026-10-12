'use strict';
'require form';
'require network';

/* netifd's "wwan" handler (package wwan, pulled in by uqmi, umbim and
 * comgt-ncm) finds the USB modem itself and hands over to the qmi, mbim, ncm
 * or 3g handler. network.js loads protocol/<handler>.js for every handler
 * netifd has: without this file, each page using it got a 404 for
 * protocol/wwan.js. */
return network.registerProtocol('wwan', {
	getI18n: function() {
		return _('Cellular modem (wwan)');
	},

	getPackageName: function() {
		return 'wwan';
	},

	isFloating: function() {
		return true;
	},

	isVirtual: function() {
		return true;
	},

	getDevices: function() {
		return null;
	},

	containsDevice: function(ifname) {
		return (network.getIfnameOf(ifname) == this.getIfname());
	},

	renderFormOptions: function(s) {
		var o;

		s.taboption('general', form.Value, 'apn', _('APN'));
		s.taboption('general', form.Value, 'pincode', _('PIN'));

		o = s.taboption('general', form.ListValue, 'auth', _('Authentication Type'));
		o.value('', 'NONE');
		o.value('both', 'PAP/CHAP');
		o.value('pap', 'PAP');
		o.value('chap', 'CHAP');

		o = s.taboption('general', form.Value, 'username', _('PAP/CHAP username'));
		o.depends('auth', 'pap');
		o.depends('auth', 'chap');
		o.depends('auth', 'both');

		o = s.taboption('general', form.Value, 'password', _('PAP/CHAP password'));
		o.depends('auth', 'pap');
		o.depends('auth', 'chap');
		o.depends('auth', 'both');
		o.password = true;

		o = s.taboption('advanced', form.Value, 'bus', _('Modem device'));
		o.placeholder = _('automatic');

		o = s.taboption('advanced', form.Value, 'delay', _('Modem init timeout'), _('Maximum amount of seconds to wait for the modem to become ready'));
		o.placeholder = '10';
		o.datatype    = 'min(1)';
	}
});
