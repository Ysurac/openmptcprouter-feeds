'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require ui';

var callBackupList = rpc.declare({
	object: 'openmptcprouter',
	method: 'backuplist',
	expect: { '': {} }
});

var callBackupGet = rpc.declare({
	object: 'openmptcprouter',
	method: 'backupget',
	params: ['server', 'backupfile'],
	expect: { '': {} }
});

var callBackupSend = rpc.declare({
	object: 'openmptcprouter',
	method: 'backupsend',
	expect: { '': {} }
});

return view.extend({
	load: function() {
		return callBackupList();
	},

	render: function(backupdata) {
		var m, s, o;

		m = new form.Map('openmptcprouter', _('Backup on server'));

		Object.keys(backupdata || {}).forEach(function(servername) {
			var serverdata = backupdata[servername];

			s = m.section(form.NamedSection, servername, 'server', servername);
			s.addremove = false;

			if (serverdata.backups && serverdata.backups.length > 0) {
				o = s.option(form.ListValue, 'backup_select', _('Backup available on server'));
				o.value('', '');
				serverdata.backups.forEach(function(b) {
					o.value(b.file, new Date(b.time * 1000).toLocaleString());
				});
				o.cfgvalue = function() { return ''; };
			} else if (serverdata.lastbackup) {
				o = s.option(form.DummyValue, '_lastbackup', _('Last available backup on server'));
				var dateStr = new Date(serverdata.lastbackup * 1000).toLocaleString();
				o.cfgvalue = function() { return dateStr; };
			} else {
				o = s.option(form.DummyValue, '_nobackup', ' ');
				o.cfgvalue = function() { return _('No available backup on server.'); };
			}
		});

		s = m.section(form.NamedSection, 'settings', 'settings');
		s.addremove = false;

		o = s.option(form.Button, '_restore');
		o.inputtitle = _('Restore backup');
		o.inputstyle = 'action important';
		o.onclick = function() {
			return m.parse().then(function() {
				var servers = uci.sections('openmptcprouter', 'server') || [];
				var promises = [];
				var anySelected = false;

				servers.forEach(function(srv) {
					var sel = uci.get('openmptcprouter', srv['.name'], 'backup_select');
					if (sel && sel !== '') {
						anySelected = true;
						promises.push(callBackupGet(srv['.name'], sel));
					}
				});

				if (!anySelected) {
					promises.push(callBackupGet('', ''));
				}

				uci.revert('openmptcprouter');
				return Promise.all(promises);
			}).then(function(res) {
				res.forEach(function(r) {
					if (!r || r.result !== true)
						throw new Error((r && r.error) || _('the server sent no valid backup'));
				});
				ui.addNotification(null, _('Backup restored successfully.'), 'info');
			}).catch(function(err) {
				uci.revert('openmptcprouter');
				ui.addNotification(null, _('Failed to restore backup: ') + ((err && err.message) || String(err)), 'error');
			});
		};

		o = s.option(form.Button, '_send');
		o.inputtitle = _('Send backup');
		o.inputstyle = 'action important';
		o.onclick = function() {
			return callBackupSend().then(function(r) {
				if (!r || r.result !== true)
					throw new Error(_('no server took it'));
				ui.addNotification(null, _('Backup sent successfully.'), 'info');
			}).catch(function(err) {
				ui.addNotification(null, _('Failed to send backup: ') + ((err && err.message) || String(err)), 'error');
			});
		};

		return m.render();
	},

	handleSaveApply: null,
	handleSave:      null,
	handleReset:     null
});
