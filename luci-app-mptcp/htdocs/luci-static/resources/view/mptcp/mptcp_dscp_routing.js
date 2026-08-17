'use strict';
'require form';
'require uci';

/*
 * Copyright (C) 2026 Ycarus (Yannick Chabanois) <contact@openmptcprouter.com> for OpenMPTCProuter
 * This is free software, licensed under the GNU General Public License v3.
 * See /LICENSE for more information
 */

// Same class/value pairs as mptcp-scheduler-dscp.sh's dscp_to_val.
var DSCP_CLASSES = [
	['cs0', _('CS0 (0) - Best effort')],
	['cs1', _('CS1 (8) - Low priority')],
	['cs2', _('CS2 (16) - High priority')],
	['cs3', _('CS3 (24) - SIP/signaling')],
	['cs4', _('CS4 (32) - Real-time interactive')],
	['cs5', _('CS5 (40) - Broadcast video')],
	['cs6', _('CS6 (48) - Network control')],
	['cs7', _('CS7 (56) - Latency sensitive')],
	['le',  _('LE (1) - Lower effort')],
	['af11', 'AF11 (10)'],
	['af12', 'AF12 (12)'],
	['af13', 'AF13 (14)'],
	['af21', 'AF21 (18)'],
	['af22', 'AF22 (20)'],
	['af23', 'AF23 (22)'],
	['af31', 'AF31 (26)'],
	['af32', 'AF32 (28)'],
	['af33', 'AF33 (30)'],
	['af41', 'AF41 (34)'],
	['af42', 'AF42 (36)'],
	['af43', 'AF43 (38)'],
	['ef',  _('EF (46) - Voice')]
];

// Same WAN filter as this app's own mptcp.js "Interfaces Settings"
// section: excludes the pseudo-interfaces that are never a real WAN.
function isEligibleIface(name) {
	return !!name && !name.match(/^oip/) && !name.match(/^lo/) &&
		name !== 'omrvpn' && name !== 'OWVPN' && name !== 'omr6in4';
}

// Same "multipath actually turned on" whitelist as the bandwidth page's
// _getMultipathIfaces (multipath.js) and the rpcd backend's
// multipath_bandwidth: "off"/unset doesn't count.
function isMultipathEnabledIface(name) {
	var multipath = uci.get('network', name, 'multipath');
	return multipath === 'on' || multipath === 'master' ||
		multipath === 'backup' || multipath === 'handover';
}

function fillIfaceOptions(option) {
	option.value('', _('-- not pinned --'));
	uci.sections('network', 'interface', function(ifc) {
		if (isEligibleIface(ifc['.name']))
			option.value(ifc['.name'], ifc.label || ifc['.name']);
	});
}

// Same normalization as mptcp.js's own normalizeSchedulerValue, so
// "mptcp_bpf_dscp.o" (the raw .o filename, seen on older saves / before a
// kernel>=6.18 write ever normalizes it) and "bpf_dscp" compare equal.
function normalizeSchedulerValue(value) {
	if (value == null)
		return value;
	var normalized = String(value).trim();
	if (normalized.slice(-2) === '.o')
		normalized = normalized.slice(0, -2);
	if (normalized.slice(0, 6) === 'mptcp_')
		normalized = normalized.slice(6);
	return normalized;
}

return L.view.extend({
	load: function() {
		return Promise.all([
			uci.load('network'),
			// mqvpn may not be installed at all -- resolve to null instead
			// of rejecting the whole page's load() in that case.
			L.resolveDefault(uci.load('mqvpn'), null)
		]);
	},

	render: function() {
		var m, s, o;

		var mptcpScheduler = normalizeSchedulerValue(uci.get('network', 'globals', 'mptcp_scheduler'));
		var mptcpHasDscpScheduler = (mptcpScheduler === 'bpf_dscp');
		var mptcpHasWeightScheduler = (mptcpScheduler === 'bpf_weight' || mptcpScheduler === 'bpf_weight_rr' || mptcpScheduler === 'bpf_burstweight');

		var mqvpnEnabled = (uci.get('mqvpn', 'settings', 'enable') === '1');
		var mqvpnScheduler = uci.get('mqvpn', 'multipath', 'scheduler');
		// mqvpn has no scheduler value dedicated to DSCP the way MPTCP has
		// bpf_dscp -- 007-mqvpn-dscp pushes the DSCP mask unconditionally
		// whenever mqvpn is enabled, regardless of which scheduler is
		// running (unlike weight below, which mqvpn only reads for wrtt/
		// wrr). So "mqvpn wants the DSCP table" just means "mqvpn is
		// enabled" -- there's no narrower signal to gate on.
		var mqvpnHasDscpScheduler = mqvpnEnabled;
		// Matches 006-mqvpn-weight's own gate exactly (it no-ops for any
		// other scheduler).
		var mqvpnHasWeightScheduler = mqvpnEnabled && (mqvpnScheduler === 'wrtt' || mqvpnScheduler === 'wrr');

		var showDscp = mptcpHasDscpScheduler || mqvpnHasDscpScheduler;
		var showWeight = mptcpHasWeightScheduler || mqvpnHasWeightScheduler;

		m = new form.Map('network', _('DSCP / Weight Routing'),
			_('Choose which WAN carries each DSCP-tagged traffic class -- for the MPTCP bpf_dscp scheduler and for mqvpn -- and review the per-WAN weight used by the *weight schedulers on both. This page only edits the pins/weights; pick the scheduler that actually uses them on the MPTCP and MQVPN pages themselves.'));

		if (!showDscp && !showWeight) {
			m.description += '<br /><br />' + _('Nothing to show yet: no DSCP scheduler (bpf_dscp) or weight scheduler (bpf_weight/bpf_weight_rr/bpf_burstweight, or mqvpn’s Weighted RTT/Weighted Round Robin) is currently selected on the MPTCP or MQVPN pages.');
			return m.render();
		}

		// Same option as luci-app-mptcp's main MPTCP page -- one uci value,
		// editable from either page. The Download column below only has an
		// effect while this is enabled (it's what gets pushed to the
		// gateway as dscp_remote_id); showing it while sync is off would be
		// a dead control, so its visibility is decided from this option's
		// *persisted* value at page load, not live -- toggling the box
		// below needs Save & Apply, then a reload of this page, before the
		// Download column itself appears/disappears to match.
		s = m.section(form.TypedSection, 'globals', _('Gateway sync'));

		o = s.option(form.Flag, 'mptcp_dscp_weight_vps_sync', _('Mirror DSCP/weight pins to gateway'),
			_('When using a DSCP or weight BPF scheduler, also sync each WAN’s pin to the gateway (VPS) so it also holds for traffic the gateway sends (downloads), not just traffic the router sends (uploads). Disabling this only stops future syncs -- it does not remove pins already pushed to the gateway.') + '<br />' +
			_('While disabled, the DSCP table below only shows Upload -- Download has no effect until this is re-enabled and applied.'));
		o.default = '1';

		var vpsSyncEnabled = (uci.get('network', 'globals', 'mptcp_dscp_weight_vps_sync') !== '0');

		if (showDscp) {
			s = m.section(form.TableSection, 'dscp_pin', _('DSCP class pins'));
			s.anonymous = true;
			s.addremove = true;
			s.sortable = true;

			o = s.option(form.ListValue, 'dscp', _('DSCP class'));
			o.rmempty = false;
			DSCP_CLASSES.forEach(function(c) { o.value(c[0], c[1]); });

			o = s.option(form.ListValue, 'upload_interface', _('Upload interface'),
				_('Router → internet. Pins this class to a WAN for MPTCP’s bpf_dscp scheduler (local dscp_iface map) and, for mqvpn, announces the class on this path’s DSCP mask via the control API.'));
			o.load = function(section_id) {
				fillIfaceOptions(this);
				return this.super('load', [section_id]);
			};

			if (vpsSyncEnabled) {
				o = s.option(form.ListValue, 'download_interface', _('Download interface'),
					_('Gateway (VPS) → router. Only takes effect for MPTCP’s bpf_dscp scheduler (pins the VPS’s own send-side choice via dscp_remote_id) and can be a different WAN than Upload.') + ' ' +
					_('Leave empty to just mirror this row’s Upload interface to the gateway instead -- the same "download always follows upload" behavior mqvpn already has built in natively.') + ' ' +
					_('mqvpn has no equivalent: its downlink always mirrors whichever WAN carries the class on upload, so this field has no effect on mqvpn.'));
				o.load = function(section_id) {
					fillIfaceOptions(this);
					return this.super('load', [section_id]);
				};
			}
		}

		if (showWeight) {
			s = m.section(form.TypedSection, 'interface', _('WAN weight'),
				_('Used by the *weight MPTCP schedulers (bpf_weight/bpf_weight_rr) and by mqvpn’s "Weighted RTT"/"Weighted Round Robin" schedulers -- same value, applies to both upload and download (mirrored to the gateway automatically). Unlike the DSCP pins above, weight is a single value per WAN, not per traffic class.') + ' ' +
				_('Only WANs with Multipath TCP enabled (the “Multipath TCP” option on the MPTCP page’s Interfaces Settings) are listed below.'));
			s.filter = function(section) {
				return isEligibleIface(section) && isMultipathEnabledIface(section);
			};

			o = s.option(form.Value, 'multipath_weight', _('Weight'),
				_('A weight >100 makes a WAN more attractive, a weight <100 makes it less attractive. Max 256.'));
			o.datatype = 'uinteger';
			o.rmempty = false;
			o.default = 100;
		}

		return m.render();
	}
});
