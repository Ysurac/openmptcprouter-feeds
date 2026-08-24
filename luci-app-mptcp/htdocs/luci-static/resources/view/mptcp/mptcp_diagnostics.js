'use strict';
'require view';
'require poll';
'require rpc';

var callDiagnose = rpc.declare({
	object: 'luci.mptcp',
	method: 'diagnose',
	expect: { '': {} }
});

var COUNTER_LABELS = {
	/* Initial MP_CAPABLE handshake (does this connection become MPTCP at all?) */
	MPCapableSYNTX: _('MPTCP handshake attempts sent (SYN)'),
	MPCapableSYNRX: _('MPTCP handshake attempts received (SYN)'),
	MPCapableSYNACKRX: _('MPTCP handshake accepted by peer (SYN/ACK)'),
	MPCapableACKRX: _('MPTCP handshake completed (ACK)'),
	MPCapableFallbackSYNACK: _('Fallback to TCP (SYN/ACK stripped)'),
	MPCapableFallbackACK: _('Fallback to TCP (ACK stripped)'),
	MPCapableSYNTXDrop: _('MPTCP handshake dropped client-side, fell back to TCP'),
	MPCapableSYNTXDisabled: _('MPTCP handshake disabled client-side after past issues'),
	MPCapableEndpAttempt: _('MPTCP rejected on a port-only endpoint'),
	MPFallbackTokenInit: _('Could not allocate an MPTCP token, fell back to TCP'),

	/* MP_JOIN handshake (does a WAN succeed in adding a subflow?) */
	MPJoinSynTx: _('Subflow JOIN attempts sent (SYN)'),
	MPJoinSynTxCreatSkErr: _('Subflow JOIN failed: could not create socket'),
	MPJoinSynTxBindErr: _('Subflow JOIN failed: could not bind address'),
	MPJoinSynTxConnectErr: _('Subflow JOIN failed: could not connect'),
	MPJoinSynRx: _('Subflow JOIN attempts received (SYN)'),
	MPJoinSynBackupRx: _('Subflow JOIN attempts received (SYN, backup)'),
	MPJoinSynAckRx: _('Subflow JOIN accepted by peer (SYN/ACK)'),
	MPJoinSynAckBackupRx: _('Subflow JOIN accepted by peer (SYN/ACK, backup)'),
	MPJoinSynAckHMacFailure: _('JOIN SYN/ACK authentication failures'),
	MPJoinAckRx: _('Subflow JOIN completed (ACK)'),
	MPJoinAckHMacFailure: _('JOIN ACK authentication failures'),
	MPJoinNoTokenFound: _('JOIN attempts with unknown token'),
	MPJoinRejected: _('JOIN request rejected by the path manager'),
	MPJoinPortSynRx: _('Subflow JOIN SYN received on a different port'),
	MPJoinPortSynAckRx: _('Subflow JOIN SYN/ACK received on a different port'),
	MPJoinPortAckRx: _('Subflow JOIN ACK received on a different port'),
	MismatchPortSynRx: _('Subflow JOIN SYN with mismatched port'),
	MismatchPortAckRx: _('Subflow JOIN ACK with mismatched port'),

	/* Data-sequence mapping / data path integrity */
	MPTCPRetrans: _('MPTCP-level retransmissions'),
	DSSNotMatching: _('Data sequence mapping did not match the previous one'),
	DSSCorruptionFallback: _('DSS corruption detected, fell back to plain TCP'),
	DSSCorruptionReset: _('DSS corruption detected, subflow reset'),
	DSSNoMatchTCP: _('Data sequence mapping did not match TCP sequence numbers'),
	InfiniteMapTx: _('Infinite mapping sent (fell back to plain TCP semantics)'),
	InfiniteMapRx: _('Infinite mapping received (peer fell back to plain TCP semantics)'),
	DataCsumErr: _('Data checksum errors'),
	NoDSSInWindow: _('Segments received outside the MPTCP mapping window'),
	DuplicateData: _('Duplicate data segments discarded'),
	OFOQueueTail: _('Out-of-order segments queued at tail'),
	OFOQueue: _('Out-of-order segments queued'),
	OFOMerge: _('Out-of-order segments merged'),
	RcvPruned: _('Received segments pruned from the receive queue (memory pressure)'),

	/* Subflow lifecycle: stale/blackhole detection and removal */
	Blackhole: _('Blackhole detected on the path'),
	SubflowStale: _('Subflows marked stale (possible blackhole)'),
	SubflowRecover: _('Stale subflows recovered'),
	RmSubflow: _('Subflows removed'),

	/* ADD_ADDR / RM_ADDR signalling (extra WAN addresses advertised to the peer) */
	AddAddr: _('ADD_ADDR signals received'),
	AddAddrTx: _('ADD_ADDR signals sent'),
	AddAddrTxDrop: _('ADD_ADDR signals failed to send'),
	AddAddrDrop: _('ADD_ADDR signals dropped'),
	EchoAdd: _('ADD_ADDR echo received'),
	EchoAddTx: _('ADD_ADDR echo sent'),
	EchoAddTxDrop: _('ADD_ADDR echo failed to send'),
	PortAdd: _('ADD_ADDR received with a port number'),
	RmAddr: _('RM_ADDR signals received'),
	RmAddrTx: _('RM_ADDR signals sent'),
	RmAddrTxDrop: _('RM_ADDR signals failed to send'),
	RmAddrDrop: _('RM_ADDR signals dropped'),

	/* Subflow priority (MP_PRIO: backup/non-backup flag changes) */
	MPPrioTx: _('Subflow priority change sent (MP_PRIO)'),
	MPPrioRx: _('Subflow priority change received (MP_PRIO)'),

	/* Connection teardown */
	MPFailTx: _('Data mapping failures sent (MP_FAIL)'),
	MPFailRx: _('Data mapping failures received (MP_FAIL)'),
	MPFastcloseTx: _('Fastclose sent'),
	MPFastcloseRx: _('Fastclose received'),
	MPRstTx: _('MPTCP resets sent'),
	MPRstRx: _('MPTCP resets received'),

	/* Receive-window sharing across subflows */
	SndWndShared: _('Send window shared across subflows'),
	RcvWndShared: _('Receive window shared across subflows'),
	RcvWndConflictUpdate: _('Receive window conflict resolved on update'),
	RcvWndConflict: _('Receive window update conflicts'),

	/* Misc: whole-connection fallback reasons, gauges */
	MPCurrEstab: _('Established MPTCP connections (current)'),
	MPCapableDataFallback: _('Fell back to TCP: missing data on first established packet'),
	MD5SigFallback: _('Fell back to TCP: conflicting TCP MD5SIG option'),
	DssFallback: _('Fell back to TCP: bad or missing data sequence signal'),
	SimultConnectFallback: _('Fell back to TCP: simultaneous connect'),
	FallbackFailed: _("Couldn't fall back to TCP (connection state didn't allow it)"),
	WinProbe: _('MPTCP-level zero-window probes')
};

return view.extend({
	load: function() {
		return callDiagnose().catch(function() { return null; });
	},

	pollData: function(container) {
		poll.add(L.bind(function() {
			return callDiagnose().then(L.bind(function(data) {
				this.renderAll(container, data);
			}, this)).catch(function() {
				/* Ignore transient poll errors -- keep showing the last good snapshot */
			});
		}, this), 15);
	},

	render: function(initialData) {
		if (!document.querySelector('link[href*="mptcp_diagnostics.css"]')) {
			var link = document.createElement('link');
			link.rel = 'stylesheet';
			link.type = 'text/css';
			link.href = L.resource('mptcp/css/mptcp_diagnostics.css');
			document.head.appendChild(link);
		}

		var container = E('div', { 'id': 'omrdiag-container' }, [
			E('img', { 'src': L.resource('spinner.gif') })
		]);

		var page = E('div', {}, [
			E('h2', {}, [ _('MPTCP Diagnostics') ]),
			E('div', { 'class': 'cbi-map-descr' }, [
				_('Helps explain why MPTCP might not be aggregating your WANs correctly: fallback to plain TCP, ' +
				  'blackholed/stale subflows, resets, checksum errors, and WANs that never got an MPTCP endpoint ' +
				  'registered at all. Refreshes automatically every 15 seconds.')
			]),
			container
		]);

		this.renderAll(container, initialData);
		this.pollData(container);

		return page;
	},

	renderAll: function(container, data) {
		if (!container) return;
		var d = data || {};

		container.textContent = '';
		container.appendChild(E('div', { 'class': 'omrdiag-updated' },
			[ _('Last updated:') + ' ' + (new Date()).toLocaleTimeString() ]));

		container.appendChild(this.renderIssues(d.issues || []));
		container.appendChild(this.renderWanTable(d.wans || []));
		container.appendChild(this.renderSubflowsTable(d.subflows || []));
		container.appendChild(this.renderSettings(d.settings || {}, d.limits || {}, d.established_count));
		container.appendChild(this.renderCounters(d.counters || {}));
	},

	renderIssues: function(issues) {
		var box = E('div', { 'class': 'omrdiag-summary' });
		if (!issues.length) {
			box.appendChild(E('div', { 'class': 'omrdiag-issue' }, [
				E('div', { 'class': 'omrdiag-dot' }),
				E('div', { 'class': 'omrdiag-body' }, [
					E('div', { 'class': 'omrdiag-message' }, [ _('No diagnostic data available yet.') ])
				])
			]));
			return box;
		}
		issues.forEach(function(issue) {
			var sev = issue.severity || 'warning';
			box.appendChild(E('div', { 'class': 'omrdiag-issue ' + sev }, [
				E('div', { 'class': 'omrdiag-dot' }),
				E('div', { 'class': 'omrdiag-body' }, [
					E('div', { 'class': 'omrdiag-message' }, [ issue.message || '' ]),
					issue.detail ? E('div', { 'class': 'omrdiag-detail' }, [ issue.detail ]) : ''
				])
			]));
		});
		return box;
	},

	renderWanTable: function(wans) {
		var wrap = E('div', {}, [ E('h3', {}, [ _('Per-WAN MPTCP endpoint status') ]) ]);
		if (!wans.length) {
			wrap.appendChild(E('p', {}, [ _('No multipath-enabled WAN interfaces found.') ]));
			return wrap;
		}
		var table = E('table', { 'class': 'omrdiag-wan-table' }, [
			E('tr', {}, [
				E('th', {}, [ _('WAN') ]),
				E('th', {}, [ _('Device') ]),
				E('th', {}, [ _('Mode') ]),
				E('th', {}, [ _('MPTCP endpoint') ]),
				E('th', {}, [ _('Endpoint flags') ])
			])
		]);
		wans.forEach(function(wan) {
			var ok = !!wan.has_endpoint;
			table.appendChild(E('tr', {}, [
				E('td', {}, [ wan.name || '' ]),
				E('td', {}, [ wan.device || '-' ]),
				E('td', {}, [ wan.multipath || 'off' ]),
				E('td', {}, [
					E('span', { 'class': 'omrdiag-badge ' + (ok ? 'ok' : 'error') },
						[ ok ? _('registered') : _('missing') ])
				]),
				E('td', {}, [ wan.endpoint_flags || '-' ])
			]));
		});
		wrap.appendChild(table);
		return wrap;
	},

	renderSubflowsTable: function(subflows) {
		var wrap = E('div', {}, [ E('h3', {}, [ _('Live MPTCP subflows') ]) ]);
		if (!subflows.length) {
			wrap.appendChild(E('p', {}, [
				_('No active MPTCP subflow found on any multipath-enabled WAN right now.')
			]));
			return wrap;
		}

		var fmtRate = function(bps) {
			if (bps === undefined || bps === null) return '-';
			if (bps >= 1000000000) return (bps / 1000000000).toFixed(1) + ' Gbps';
			if (bps >= 1000000) return (bps / 1000000).toFixed(1) + ' Mbps';
			if (bps >= 1000) return (bps / 1000).toFixed(1) + ' Kbps';
			return bps + ' bps';
		};
		var fmtPair = function(a, b) {
			if (a === undefined || a === null) return '-';
			return (b === undefined || b === null) ? String(a) : a + ' / ' + b;
		};

		var table = E('table', { 'class': 'omrdiag-wan-table' }, [
			E('tr', {}, [
				E('th', {}, [ _('WAN') ]),
				E('th', {}, [ _('Local') ]),
				E('th', {}, [ _('Remote') ]),
				E('th', {}, [ _('Backup') ]),
				E('th', {}, [ _('cwnd') ]),
				E('th', {}, [ _('RTT / var (ms)') ]),
				E('th', {}, [ _('Retrans / total') ]),
				E('th', {}, [ _('Pacing rate') ]),
				E('th', {}, [ _('Delivery rate') ])
			])
		]);
		subflows.forEach(function(sf) {
			table.appendChild(E('tr', {}, [
				E('td', {}, [ sf.wan || sf.dev || '-' ]),
				E('td', {}, [ (sf.local_ip || '-') + ':' + (sf.local_port != null ? sf.local_port : '') ]),
				E('td', {}, [ (sf.remote_ip || '-') + ':' + (sf.remote_port != null ? sf.remote_port : '') ]),
				E('td', {}, [
					// "backup" is a normal role (not a health issue), so it
					// deliberately gets no severity class -- only "active"
					// (the role actually carrying scheduled traffic) is
					// highlighted green.
					E('span', { 'class': 'omrdiag-badge' + (sf.backup ? '' : ' ok') },
						[ sf.backup ? _('backup') : _('active') ])
				]),
				E('td', {}, [ sf.cwnd != null ? String(sf.cwnd) : '-' ]),
				E('td', {}, [ fmtPair(sf.rtt, sf.rttvar) ]),
				E('td', {}, [ fmtPair(sf.retrans, sf.retrans_total) ]),
				E('td', {}, [ fmtRate(sf.pacing_rate) ]),
				E('td', {}, [ fmtRate(sf.delivery_rate) ])
			]));
		});
		wrap.appendChild(table);
		return wrap;
	},

	renderSettings: function(settings, limits, establishedCount) {
		// "1"/"0" mean enabled/disabled for the enabled and checksum sysctls --
		// but NOT for path_manager: on the in-kernel MPTCP sysctl layout,
		// net.mptcp.pm_type is a selector between two path manager
		// *implementations* (0 = in-kernel, 1 = userspace/mptcpd), not an
		// on/off switch -- "0" here is the normal default, not "disabled".
		// On the legacy out-of-tree sysctl layout path_manager is already a
		// name (e.g. "fullmesh"), not a 0/1 code, so leave those untouched.
		var formatBool = function(v) {
			if (v === '1') return _('Enabled') + ' (1)';
			if (v === '0') return _('Disabled') + ' (0)';
			return v;
		};
		var formatPathManager = function(v) {
			if (v === '0') return _('In-kernel') + ' (0)';
			if (v === '1') return _('Userspace') + ' (1)';
			return v;
		};
		var rows = [
			[ _('MPTCP enabled'), formatBool(settings.enabled) ],
			[ _('Path manager'), formatPathManager(settings.path_manager) ],
			[ _('Scheduler'), settings.scheduler ],
			[ _('Checksum'), formatBool(settings.checksum) ],
			[ _('Stale loss count threshold'), settings.stale_loss_cnt ],
			[ _('Blackhole timeout (s)'), settings.blackhole_timeout ],
			[ _('Add-addr timeout (s)'), settings.add_addr_timeout ],
			[ _('Close timeout (s)'), settings.close_timeout ],
			[ _('Subflow limit'), limits.subflows ],
			[ _('Accepted ADD_ADDR limit'), limits.add_addr_accepted ],
			[ _('Established MPTCP connections (right now)'), establishedCount ]
		];
		var wrap = E('div', {}, [ E('h3', {}, [ _('Kernel MPTCP configuration') ]) ]);
		var table = E('table', { 'class': 'omrdiag-wan-table' });
		rows.forEach(function(r) {
			if (r[1] === undefined || r[1] === null || r[1] === '') return;
			table.appendChild(E('tr', {}, [ E('th', {}, [ r[0] ]), E('td', {}, [ String(r[1]) ]) ]));
		});
		wrap.appendChild(table);
		return wrap;
	},

	renderCounters: function(counters) {
		var keys = Object.keys(counters || {});
		var wrap = E('div', {}, [ E('h3', {}, [ _('MPTCP kernel counters (since boot)') ]) ]);
		if (!keys.length) {
			wrap.appendChild(E('p', {}, [ _('No counters available (nstat/multipath -m returned nothing).') ]));
			return wrap;
		}
		keys.sort(function(a, b) {
			var av = counters[a] || 0, bv = counters[b] || 0;
			if (av !== bv) return bv - av;
			return a < b ? -1 : (a > b ? 1 : 0);
		});
		var table = E('table', { 'class': 'omrdiag-counters-table' }, [
			E('tr', {}, [ E('th', {}, [ _('Counter') ]), E('th', {}, [ _('Value') ]) ])
		]);
		keys.forEach(function(key) {
			var value = counters[key] || 0;
			var label = COUNTER_LABELS[key] ? (COUNTER_LABELS[key] + ' (' + key + ')') : key;
			table.appendChild(E('tr', {}, [
				E('td', {}, [ label ]),
				E('td', { 'class': value > 0 ? 'omrdiag-nonzero' : '' }, [ String(value) ])
			]));
		});
		wrap.appendChild(table);
		return wrap;
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
