'use strict';
'require view';
'require form';

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

		o = s.taboption('general', form.Value, 'group', _('Run as group'));
		o.default = 'nogroup';

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

		o = s.taboption('general', form.Flag, 'decode_tunnel', _('Decode tunnels'),
			_('Decapsulate GRE Layer 4 tunnel protocols'));
		o.default = '0';

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

		o = s.taboption('general', form.Flag, 'external', _('External flows only'),
			_('Process only externally-initiated (dst→src) connections'));
		o.default = '0';

		o = s.taboption('general', form.Flag, 'compression', _('Flow compression'),
			_('Enable zLib compression of long-lasting flow memory'));
		o.default = '1';
		o.rmempty = false;

		o = s.taboption('general', form.Flag, 'analysis', _('Analysis events'),
			_('Generate per-flow statistical events for machine learning (requires more memory)'));
		o.default = '0';

		o = s.taboption('general', form.Flag, 'poll', _('Force poll()'),
			_('Use poll() even on systems that support epoll()'));
		o.default = '0';

		o = s.taboption('general', form.Flag, 'pfring', _('Use PF_RING'),
			_('Use PF_RING packet capture instead of libpcap'));
		o.default = '0';

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
		s = m.section(form.NamedSection, 'tuning', 'tuning', _('Performance Tuning'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'max_flows_per_thread', _('Max flows per thread'));
		o.datatype = 'uinteger';
		o.default = '2048';

		o = s.option(form.Value, 'max_idle_flows_per_thread', _('Max idle flows per thread'));
		o.datatype = 'uinteger';
		o.default = '64';

		o = s.option(form.Value, 'max_reader_threads', _('Max reader threads'));
		o.datatype = 'uinteger';
		o.default = '10';

		o = s.option(form.Value, 'daemon_status_interval', _('Daemon status interval'),
			_('Interval between daemon status events (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '600000000';

		o = s.option(form.Value, 'flow_scan_interval', _('Flow scan interval'),
			_('Interval between idle flow scans (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '10000000';

		o = s.option(form.Value, 'generic_max_idle_time', _('Generic max idle time'),
			_('Generic flow idle timeout (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '600000000';

		o = s.option(form.Value, 'icmp_max_idle_time', _('ICMP max idle time'),
			_('ICMP flow idle timeout (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '120000000';

		o = s.option(form.Value, 'tcp_max_idle_time', _('TCP max idle time'),
			_('TCP flow idle timeout (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '180000000';

		o = s.option(form.Value, 'udp_max_idle_time', _('UDP max idle time'),
			_('UDP flow idle timeout (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '7440000000';

		o = s.option(form.Value, 'tcp_max_post_end_flow_time', _('TCP post-end flow time'),
			_('Extra time to keep TCP flows after FIN/RST (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '120000000';

		o = s.option(form.Value, 'compression_scan_interval', _('Compression scan interval'),
			_('Interval between compression eligibility scans (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '20000000';

		o = s.option(form.Value, 'compression_flow_inactivity', _('Compression flow inactivity'),
			_('Inactivity threshold before compressing a flow (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '30000000';

		o = s.option(form.Value, 'max_packets_per_flow_to_send', _('Max packets to send per flow'),
			_('Maximum packets forwarded to collector per flow'));
		o.datatype = 'uinteger';
		o.default = '15';

		o = s.option(form.Value, 'max_packets_per_flow_to_process', _('Max packets to process per flow'),
			_('Maximum packets processed by nDPI per flow'));
		o.datatype = 'uinteger';
		o.default = '32';

		o = s.option(form.Value, 'max_packets_per_flow_to_analyse', _('Max packets to analyse per flow'),
			_('Maximum packets used for statistical analysis per flow'));
		o.datatype = 'uinteger';
		o.default = '32';

		o = s.option(form.Value, 'error_event_threshold_n', _('Error event threshold (count)'),
			_('Number of errors within the time window before an error event is emitted'));
		o.datatype = 'uinteger';
		o.default = '16';

		o = s.option(form.Value, 'error_event_threshold_time', _('Error event threshold (window)'),
			_('Time window for error event threshold (nanoseconds)'));
		o.datatype = 'uinteger';
		o.default = '10000000';

		// ── nDPI Library ──────────────────────────────────────────────────
		s = m.section(form.NamedSection, 'ndpi', 'ndpi', _('nDPI Library'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'packets_limit_per_flow', _('Packet limit per flow'),
			_('Maximum packets inspected by libnDPI per flow'));
		o.datatype = 'uinteger';
		o.default = '32';

		o = s.option(form.ListValue, 'flow_direction_detection', _('Flow direction detection'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'enable';

		o = s.option(form.ListValue, 'flow_track_payload', _('Track payload'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'disable';

		o = s.option(form.ListValue, 'tcp_ack_payload_heuristic', _('TCP ACK payload heuristic'),
			_('Use ACK packets for protocol detection'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'disable';

		o = s.option(form.ListValue, 'fully_encrypted_heuristic', _('Fully encrypted heuristic'),
			_('Detect fully-encrypted traffic'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'enable';

		o = s.option(form.Flag, 'libgcrypt_init', _('libgcrypt init'),
			_('Initialise libgcrypt for TLS/QUIC fingerprinting'));
		o.enabled  = '1';
		o.disabled = '0';
		o.default  = '1';

		o = s.option(form.Flag, 'dpi_compute_entropy', _('Compute entropy'),
			_('Compute per-flow entropy values'));
		o.enabled  = '1';
		o.disabled = '0';
		o.default  = '1';

		o = s.option(form.ListValue, 'fpc', _('Flow proto confidence (FPC)'),
			_('Report confidence level of protocol classification'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'disable';

		o = s.option(form.Value, 'dpi_guess_on_giveup', _('Guess on give-up'),
			_('Bitmask controlling best-guess on flow give-up: 0x01=by port, 0x02=by IP, 0x03=both'));
		o.default = '0x03';

		o = s.option(form.Flag, 'flow_risk_lists_load', _('Load flow risk lists'),
			_('Load built-in flow risk domain/IP lists'));
		o.enabled  = '1';
		o.disabled = '0';
		o.default  = '1';

		o = s.option(form.Value, 'log_level', _('Log level'),
			_('libnDPI log verbosity (0 = off, higher = more verbose)'));
		o.datatype = 'uinteger';
		o.default  = '0';

		// ── Protocol Settings ─────────────────────────────────────────────
		s = m.section(form.NamedSection, 'protos', 'protos', _('Protocol Settings'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Value, 'tls_cert_expire_threshold', _('TLS certificate expiry threshold'),
			_('Days before expiry to flag a TLS certificate as at risk'));
		o.datatype = 'uinteger';
		o.default  = '7';

		o = s.option(form.ListValue, 'tls_app_blocks_tracking', _('TLS application blocks tracking'),
			_('Track TLS application data blocks for deeper classification'));
		o.value('enable',  _('Enable'));
		o.value('disable', _('Disable'));
		o.default = 'enable';

		o = s.option(form.Value, 'stun_max_packets_extra_dissection', _('STUN extra dissection packets'),
			_('Additional packets examined for STUN protocol dissection'));
		o.datatype = 'uinteger';
		o.default  = '8';

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

		o = s.option(form.Value, 'tcp_address', _('TCP listen address'),
			_('IP address for TCP consumer connections (leave empty to disable)'));
		o.datatype = 'ipaddr';
		o.optional = true;
		o.rmempty = true;
		o.default = '127.0.0.1';

		o = s.option(form.Value, 'tcp_port', _('TCP listen port'),
			_('Port for TCP consumer connections (0 = disabled)'));
		o.datatype = 'port';
		o.default = '7000';

		o = s.option(form.Value, 'max_clients', _('Max clients'),
			_('Maximum number of simultaneous consumer connections'));
		o.datatype = 'uinteger';
		o.default = '10';

		// ── Compatibility ─────────────────────────────────────────────────
		s = m.section(form.NamedSection, 'compat', 'compat', _('Netifyd Compatibility'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable compatibility layer'),
			_('Write Netifyd-compatible status and flow JSON files'));
		o.default = '0';

		o = s.option(form.Value, 'status_file', _('Status file'),
			_('Path for Netifyd-compatible status JSON'));
		o.default = '/var/run/netifyd/status.json';

		o = s.option(form.Value, 'flows_file', _('Flows file'),
			_('Path for Netifyd-compatible flow JSON'));
		o.default = '/tmp/ndpid-flows.json';

		o = s.option(form.Value, 'update_interval', _('Update interval'),
			_('Seconds between status/flow file updates'));
		o.datatype = 'uinteger';
		o.default = '1';

		// ── Flow Actions ──────────────────────────────────────────────────
		s = m.section(form.NamedSection, 'actions', 'actions', _('Flow Actions'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable flow actions'),
			_('Populate ipsets based on detected application categories'));
		o.default = '0';

		o = s.option(form.Value, 'bittorrent_ipset', _('BitTorrent ipset name'));
		o.default = 'secubox-bittorrent';

		o = s.option(form.Value, 'bittorrent_timeout', _('BitTorrent ipset timeout (s)'));
		o.datatype = 'uinteger';
		o.default = '900';

		o = s.option(form.Value, 'streaming_ipset', _('Streaming ipset name'));
		o.default = 'secubox-streaming';

		o = s.option(form.Value, 'streaming_timeout', _('Streaming ipset timeout (s)'));
		o.datatype = 'uinteger';
		o.default = '1800';

		o = s.option(form.Value, 'blocked_ipset', _('Blocked ipset name'));
		o.default = 'secubox-blocked';

		o = s.option(form.Value, 'blocked_timeout', _('Blocked ipset timeout (s)'));
		o.datatype = 'uinteger';
		o.default = '3600';

		o = s.option(form.DynamicList, 'blocked_app', _('Blocked applications'),
			_('Application names to block (e.g. <code>bittorrent</code>, <code>tor</code>)'));

		return m.render();
	}
});
