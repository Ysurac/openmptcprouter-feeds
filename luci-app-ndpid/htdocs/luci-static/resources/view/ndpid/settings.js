'use strict';
'require view';
'require form';

var idleTimes = [ 'generic_max_idle_time', 'icmp_max_idle_time',
	'tcp_max_idle_time', 'udp_max_idle_time' ];

// nDPId takes its times in microseconds: the page shows seconds and
// stores microseconds, so the uci values keep nDPId's unit
function secondsOption(s, name, title, description, def) {
	var o = s.option(form.Value, name, title, description);
	o.datatype = 'ufloat';
	o.default = def;
	o.rmempty = false;
	o.load = function(section_id) {
		var v = form.Value.prototype.load.apply(this, [section_id]);
		return (v != null && /^[0-9]+$/.test(v)) ? String(+v / 1e6) : v;
	};
	o.write = function(section_id, value) {
		return form.Value.prototype.write.apply(this,
			[section_id, String(Math.round(+value * 1e6))]);
	};
	return o;
}

// nDPId refuses to start unless the flow scan interval is below every
// idle time
function validateIdleTime(section_id, value) {
	var scan = this.section.formvalue(section_id, 'flow_scan_interval');

	if (value === '' || isNaN(+value) || scan == null || scan === '' || isNaN(+scan))
		return true;
	return (+value > +scan) ? true : _('Must be above the flow scan interval');
}

// A field's error depends on its siblings: recheck them when it changes,
// or a fixed conflict keeps blocking the save
function revalidateScanAndIdle(ev, section_id) {
	var names = [ 'flow_scan_interval' ].concat(idleTimes);

	this.section.children.forEach(function(c) {
		if (c !== this && names.indexOf(c.option) >= 0)
			c.triggerValidation(section_id);
	}, this);
}

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('ndpid', _('nDPId Settings'),
			_('Configure the nDPId Deep Packet Inspection daemon and its components.'));

		// ── General ───────────────────────────────────────────────────────
		s = m.section(form.NamedSection, 'main', 'ndpid', _('Daemon'));
		s.addremove = false;
		s.anonymous = true;
		s.tab('general', _('General'));
		s.tab('files',   _('Data Files'));
		s.tab('tls',     _('TLS'));

		o = s.taboption('general', form.Flag, 'enabled', _('Enable nDPId'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('general', form.DynamicList, 'interface', _('Interfaces'),
			_('Network interfaces to capture traffic on'));
		o.datatype = 'network';

		o = s.taboption('general', form.Value, 'collector', _('Collector endpoint'),
			_('UNIX socket path or <code>IP:port</code> for the nDPIsrvd collector'));
		o.default = '/var/run/ndpid/collector.sock';
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'user', _('Run as user'));
		o.default = 'nobody';
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'group', _('Run as group'));
		o.default = 'nogroup';
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'bpf', _('BPF filter'),
			_('Berkeley Packet Filter expression (e.g. <code>tcp or udp</code>)'));
		o.optional = true;
		o.rmempty = true;

		o = s.taboption('general', form.Flag, 'no_promisc', _('Restrict to interface traffic'),
			_('Auto-generate a BPF filter (<code>ether host &lt;mac&gt;</code>) so nDPId only ' +
			  'processes packets addressed to/from the monitored interface(s). ' +
			  'The interface is still opened in promiscuous mode by libpcap, but foreign ' +
			  'frames are discarded before DPI. Combined with any manual BPF filter above.'));
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('general', form.Flag, 'decode_tunnel', _('Decode tunnels'),
			_('Decapsulate GRE Layer 4 tunnel protocols'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'alias', _('Instance alias'),
			_('Human-readable name for this nDPId instance'));
		o.optional = true;
		o.rmempty = true;

		o = s.taboption('general', form.Value, 'uuid', _('Instance UUID'),
			_('UUID string, or a path starting with <code>/</code> or <code>.</code> to read it from a file'));
		o.optional = true;
		o.rmempty = true;

		o = s.taboption('general', form.Flag, 'internal', _('Internal flows only'),
			_('Process only internally-initiated (src→dst) connections'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('general', form.Flag, 'external', _('External flows only'),
			_('Process only externally-initiated (dst→src) connections'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('general', form.Flag, 'compression', _('Flow compression'),
			_('Enable zLib compression of long-lasting flow memory'));
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('general', form.Flag, 'analysis', _('Analysis events'),
			_('Generate per-flow statistical events for machine learning (requires more memory)'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('general', form.Flag, 'poll', _('Force poll()'),
			_('Use poll() even on systems that support epoll()'));
		o.default = '0';
		o.rmempty = false;

		o = s.taboption('general', form.Flag, 'pfring', _('Use PF_RING'),
			_('Use PF_RING packet capture instead of libpcap'));
		o.default = '0';
		o.rmempty = false;

		// Data Files tab
		o = s.taboption('files', form.Value, 'riskdomains', _('Risky domains list'),
			_('Path to libnDPI risky domains file'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/risky_domains.txt';

		o = s.taboption('files', form.Value, 'protocols', _('Custom protocols list'),
			_('Path to libnDPI custom protocols definition file'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/protos.txt';

		o = s.taboption('files', form.Value, 'categories', _('Categories list'),
			_('Path to libnDPI categories definition file'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/categories.txt';

		o = s.taboption('files', form.Value, 'ja4', _('JA4 fingerprints'),
			_('Path to JA4 TLS fingerprints CSV file'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/ja4_fingerprints.csv';

		o = s.taboption('files', form.Value, 'sha1', _('SHA1 fingerprints'),
			_('Path to SHA1 certificate fingerprints CSV file'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/sha1_fingerprints.csv';

		// TLS tab
		o = s.taboption('tls', form.Value, 'cert_pem_file', _('Client certificate PEM'),
			_('Client certificate PEM file for TCP collector TLS (generated with scripts/gen-cacerts.sh)'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/client-crt.pem';

		o = s.taboption('tls', form.Value, 'key_pem_file', _('Client private key PEM'),
			_('Client private key PEM file'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/client-key.pem';

		o = s.taboption('tls', form.Value, 'ca_pem_file', _('CA certificate PEM'),
			_('CA certificate PEM file'));
		o.optional = true;
		o.rmempty = true;
		o.placeholder = '/path/to/ca.pem';

		// ── Performance Tuning ────────────────────────────────────────────
		// The limits are the ones nDPId's validate_options() enforces: it
		// refuses to start on a value outside them.
		s = m.section(form.NamedSection, 'tuning', 'tuning', _('Performance Tuning'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'max_flows_per_thread', _('Max flows per thread'));
		o.datatype = 'and(uinteger,range(128,65536))';
		o.default = '32768';
		o.rmempty = false;

		o = s.option(form.Value, 'max_idle_flows_per_thread', _('Max idle flows per thread'));
		o.datatype = 'and(uinteger,range(64,2048))';
		o.default = '1024';
		o.rmempty = false;

		o = s.option(form.Value, 'max_reader_threads', _('Max reader threads'));
		o.datatype = 'and(uinteger,range(1,32))';
		o.default = '2';
		o.rmempty = false;

		secondsOption(s, 'daemon_status_interval', _('Daemon status interval'),
			_('Interval between daemon status events (seconds)'), '600');

		o = secondsOption(s, 'flow_scan_interval', _('Flow scan interval'),
			_('Interval between idle flow scans (seconds), at least 5 and below every idle time'), '10');
		o.validate = function(section_id, value) {
			if (value === '' || isNaN(+value))
				return true;
			if (+value < 5)
				return _('Must be at least 5 seconds');
			for (var i = 0; i < idleTimes.length; i++) {
				var t = this.section.formvalue(section_id, idleTimes[i]);
				if (t != null && t !== '' && !isNaN(+t) && +value >= +t)
					return _('Must be below every idle time');
			}
			return true;
		};
		o.onchange = revalidateScanAndIdle;

		o = secondsOption(s, 'generic_max_idle_time', _('Generic max idle time'),
			_('Generic flow idle timeout (seconds)'), '600');
		o.validate = validateIdleTime;
		o.onchange = revalidateScanAndIdle;

		o = secondsOption(s, 'icmp_max_idle_time', _('ICMP max idle time'),
			_('ICMP flow idle timeout (seconds)'), '120');
		o.validate = validateIdleTime;
		o.onchange = revalidateScanAndIdle;

		o = secondsOption(s, 'tcp_max_idle_time', _('TCP max idle time'),
			_('TCP flow idle timeout (seconds)'), '7440');
		o.validate = validateIdleTime;
		o.onchange = revalidateScanAndIdle;

		o = secondsOption(s, 'udp_max_idle_time', _('UDP max idle time'),
			_('UDP flow idle timeout (seconds)'), '180');
		o.validate = validateIdleTime;
		o.onchange = revalidateScanAndIdle;

		secondsOption(s, 'tcp_max_post_end_flow_time', _('TCP post-end flow time'),
			_('Extra time to keep TCP flows after FIN/RST (seconds)'), '120');

		secondsOption(s, 'compression_scan_interval', _('Compression scan interval'),
			_('Interval between compression eligibility scans (seconds)'), '20');

		secondsOption(s, 'compression_flow_inactivity', _('Compression flow inactivity'),
			_('Inactivity threshold before compressing a flow (seconds)'), '30');

		o = s.option(form.Value, 'max_packets_per_flow_to_send', _('Max packets to send per flow'),
			_('Maximum packets forwarded to collector per flow'));
		o.datatype = 'uinteger';
		o.default = '15';
		o.rmempty = false;

		o = s.option(form.Value, 'max_packets_per_flow_to_process', _('Max packets to process per flow'),
			_('Maximum packets processed by nDPI per flow'));
		o.datatype = 'and(uinteger,range(1,65535))';
		o.default = '32';
		o.rmempty = false;

		o = s.option(form.Value, 'max_packets_per_flow_to_analyse', _('Max packets to analyse per flow'),
			_('Maximum packets used for statistical analysis per flow'));
		o.datatype = 'and(uinteger,range(2,65535))';
		o.default = '32';
		o.rmempty = false;

		o = s.option(form.Value, 'error_event_threshold_n', _('Error event threshold (count)'),
			_('Number of errors within the time window before an error event is emitted'));
		o.datatype = 'uinteger';
		o.default = '16';
		o.rmempty = false;

		secondsOption(s, 'error_event_threshold_time', _('Error event threshold (window)'),
			_('Time window for error event threshold (seconds)'), '10');

		// ── nDPI Library ──────────────────────────────────────────────────
		s = m.section(form.NamedSection, 'ndpi', 'ndpi', _('nDPI Library'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'packets_limit_per_flow', _('Packet limit per flow'),
			_('Maximum packets inspected by libnDPI per flow'));
		o.datatype = 'uinteger';
		o.default = '32';
		o.rmempty = false;

		o = s.option(form.ListValue, 'flow_direction_detection', _('Flow direction detection'),
			_('Not supported by the bundled libnDPI 5: this setting is ignored'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'enable';
		o.rmempty = false;

		o = s.option(form.ListValue, 'flow_track_payload', _('Track payload'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'disable';
		o.rmempty = false;

		o = s.option(form.ListValue, 'tcp_ack_payload_heuristic', _('TCP ACK payload heuristic'),
			_('Use ACK packets for protocol detection'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'disable';
		o.rmempty = false;

		o = s.option(form.ListValue, 'fully_encrypted_heuristic', _('Fully encrypted heuristic'),
			_('Detect fully-encrypted traffic'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'enable';
		o.rmempty = false;

		o = s.option(form.Flag, 'libgcrypt_init', _('libgcrypt init'),
			_('Initialise libgcrypt for TLS/QUIC fingerprinting'));
		o.enabled  = '1';
		o.disabled = '0';
		o.default  = '1';
		o.rmempty  = false;

		o = s.option(form.Flag, 'dpi_compute_entropy', _('Compute entropy'),
			_('Compute per-flow entropy values'));
		o.enabled  = '1';
		o.disabled = '0';
		o.default  = '1';
		o.rmempty  = false;

		o = s.option(form.ListValue, 'fpc', _('Flow proto confidence (FPC)'),
			_('Report confidence level of protocol classification'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'disable';
		o.rmempty = false;

		o = s.option(form.Value, 'dpi_guess_on_giveup', _('Guess on give-up'),
			_('Bitmask controlling best-guess on flow give-up: 0x01=by port, 0x02=by IP, 0x03=both'));
		o.default = '0x03';
		o.rmempty = false;

		o = s.option(form.Flag, 'flow_risk_lists_load', _('Load flow risk lists'),
			_('Load built-in flow risk domain/IP lists'));
		o.enabled  = '1';
		o.disabled = '0';
		o.default  = '1';
		o.rmempty  = false;

		o = s.option(form.Value, 'log_level', _('Log level'),
			_('libnDPI log verbosity (0 = off, higher = more verbose)'));
		o.datatype = 'uinteger';
		o.default  = '0';
		o.rmempty  = false;

		// ── Protocol Settings ─────────────────────────────────────────────
		s = m.section(form.NamedSection, 'protos', 'protos', _('Protocol Settings'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'tls_cert_expire_threshold', _('TLS certificate expiry threshold'),
			_('Days before expiry to flag a TLS certificate as at risk'));
		o.datatype = 'uinteger';
		o.default  = '7';
		o.rmempty  = false;

		o = s.option(form.ListValue, 'tls_app_blocks_tracking', _('TLS application blocks tracking'),
			_('Track TLS application data blocks for deeper classification'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'enable';
		o.rmempty = false;

		o = s.option(form.Value, 'stun_max_packets_extra_dissection', _('STUN extra dissection packets'),
			_('Additional packets examined for STUN protocol dissection'));
		o.datatype = 'uinteger';
		o.default  = '8';
		o.rmempty  = false;

		// ── Distributor (nDPIsrvd) ────────────────────────────────────────
		s = m.section(form.NamedSection, 'distributor', 'ndpisrvd', _('Distributor (nDPIsrvd)'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable nDPIsrvd'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'listen_socket', _('Listen socket'),
			_('UNIX socket path for consumer connections'));
		o.default = '/var/run/ndpid/distributor.sock';
		o.rmempty = false;

		o = s.option(form.Value, 'tcp_address', _('TCP listen address'),
			_('IP address for TCP consumer connections (empty means 127.0.0.1)'));
		o.datatype = 'ipaddr';
		o.optional = true;
		o.rmempty = true;
		// a placeholder, not a default: an optional option holding its
		// default is removed by every save
		o.placeholder = '127.0.0.1';

		o = s.option(form.Value, 'tcp_port', _('TCP listen port'),
			_('Port for TCP consumer connections (0 = disabled)'));
		o.datatype = 'port';
		o.default = '7000';
		o.rmempty = false;

		o = s.option(form.Value, 'max_clients', _('Max clients'),
			_('Maximum number of simultaneous consumer connections'));
		o.datatype = 'uinteger';
		o.default = '10';
		o.rmempty = false;

		// The "compat" (Netifyd compatibility) and "actions" (flow actions)
		// sections of the config have no reader: their settings did nothing.

		return m.render();
	}
});
