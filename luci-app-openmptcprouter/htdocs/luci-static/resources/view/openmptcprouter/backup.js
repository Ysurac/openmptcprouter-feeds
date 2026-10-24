'use strict';
'require view';
'require form';
'require rpc';
'require ui';
'require dom';

var callBackupList = rpc.declare({
	object: 'openmptcprouter',
	method: 'backuplist',
	expect: { '': {} }
});

/* What the last listing found, without asking the servers again */
var callBackupListCached = rpc.declare({
	object: 'openmptcprouter',
	method: 'backuplist',
	params: ['refresh'],
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

var callBackupJob = rpc.declare({
	object: 'openmptcprouter',
	method: 'backupjob',
	params: ['job'],
	expect: { '': {} }
});

/* A server that doesn't answer keeps the job going past the RPC timeout:
 * the call then answers { running: true } and the job is polled until it
 * ends, for 10 minutes at most */
function waitJob(job, res, tries) {
	tries = tries || 0;
	if (!res || !res.running)
		return Promise.resolve(res);
	if (tries >= 200)
		return Promise.resolve({ result: false, error: _('the server did not answer in time') });
	return new Promise(function(resolve) { window.setTimeout(resolve, 3000); }).then(function() {
		return callBackupJob(job);
	}).then(function(r) {
		return waitJob(job, r, tries + 1);
	});
}

return view.extend({
	/* backuplist is in the ACL's write section (it asks the servers): a
	 * read-only login is refused it, and the page then spun forever */
	load: function() {
		return callBackupList().catch(function(err) {
			if (/-32002|Access denied|Permission denied/.test(String(err && err.message)))
				return null;
			throw err;
		});
	},

	render: function(backupdata) {
		if (backupdata === null)
			return E('div', { 'class': 'cbi-map' }, [
				E('h2', {}, _('Backup on server')),
				E('div', { 'class': 'cbi-map-descr' },
					_('The backups on the server need a login with write access to this page.'))
			]);

		var container = E('div');
		return this.renderList(container, backupdata).then(function() {
			return container;
		});
	},

	/* While the servers are still asked, the previous listing is shown and
	 * the page is drawn again once they all answered */
	renderList: function(container, backupdata) {
		var self = this;
		var m, s, o;
		var pending = Object.keys(backupdata || {}).some(function(name) {
			return backupdata[name] && backupdata[name].pending;
		});

		m = new form.Map('openmptcprouter', _('Backup on server'),
			pending ? _('Asking the servers for their backups...') : null);

		/* The picked backups are read from the widgets: nothing on this page
		 * is ever saved to uci */
		var selects = {};

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
				selects[servername] = o;
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
			var picked = Object.keys(selects).filter(function(name) {
				return selects[name].formvalue(name);
			});

			/* Two restores at once unpack over each other */
			if (picked.length > 1) {
				ui.addNotification(null, _('Pick a backup on one server only.'), 'error');
				return;
			}

			var call = picked.length
				? callBackupGet(picked[0], selects[picked[0]].formvalue(picked[0]))
				: callBackupGet('', '');

			return call.then(function(r) {
				return waitJob('get', r);
			}).then(function(r) {
				if (!r || r.result !== true)
					throw new Error((r && r.error) || _('the server sent no valid backup'));
				ui.addNotification(null, _('Backup restored successfully.'), 'info');
			}).catch(function(err) {
				ui.addNotification(null, _('Failed to restore backup: ') + ((err && err.message) || String(err)), 'error');
			});
		};

		o = s.option(form.Button, '_send');
		o.inputtitle = _('Send backup');
		o.inputstyle = 'action important';
		o.onclick = function() {
			return callBackupSend().then(function(r) {
				return waitJob('send', r);
			}).then(function(r) {
				if (!r || r.result !== true)
					throw new Error((r && r.error) || _('no server took it'));
				ui.addNotification(null, _('Backup sent successfully.'), 'info');
			}).catch(function(err) {
				ui.addNotification(null, _('Failed to send backup: ') + ((err && err.message) || String(err)), 'error');
			});
		};

		return m.render().then(function(node) {
			dom.content(container, node);
			if (pending)
				self.pollList(container);
		});
	},

	pollList: function(container) {
		var self = this;
		window.setTimeout(function() {
			callBackupListCached(false).then(function(data) {
				var still = Object.keys(data || {}).some(function(name) {
					return data[name] && data[name].pending;
				});
				return still ? self.pollList(container) : self.renderList(container, data);
			}).catch(function() {
				self.pollList(container);
			});
		}, 5000);
	},

	handleSaveApply: null,
	handleSave:      null,
	handleReset:     null
});
