'use strict';
'require baseclass';
'require fs';
'require rpc';
'require network';

var callSystemBoard = rpc.declare({
	object: 'system',
	method: 'board'
});

var callSystemInfo = rpc.declare({
	object: 'system',
	method: 'info'
});

var callOpenMPTCProuterInfo = rpc.declare({
	object: 'openmptcprouter',
	method: 'status'
});


return baseclass.extend({

	params: [],

	formatBytes: function(a,b=2){if(0===a)return"0 Bytes";const c=0>b?0:b,d=Math.floor(Math.log(a)/Math.log(1024));return parseFloat((a/Math.pow(1024,d)).toFixed(c))+" "+["Bytes","KiB","MiB","GiB","TiB","PiB","EiB","ZiB","YiB"][d]},
	load: function() {
		return Promise.all([
			network.getWANNetworks(),
			network.getWAN6Networks(),
			L.resolveDefault(callSystemBoard(), {}),
			L.resolveDefault(callSystemInfo(), {}),
			L.resolveDefault(callOpenMPTCProuterInfo(), {})
		]);
	},

	renderHtml: function(data, type) {

		var icon = type;
		var title = 'router' == type ? _('System') : _('Internet');
		var container_wapper = E('div', { 'class': type + '-status-self dashboard-bg box-s1'});
		var container_box = E('div', { 'class': type + '-status-info'});
		var container_item = E('div', { 'class': 'settings-info'});

		if ('internet' == type) {
			icon = (data.internet.v4.connected.value || data.internet.v6.connected.value) ? type : 'not-internet';
		}

		container_box.appendChild(E('div', { 'class': 'title'}, [
			E('img', {
				'src': L.resource('view/dashboard/icons/' + icon + '.svg'),
				'width': 'router' == type ? 64 : 54,
				'title': title,
				'class': 'middle'
			}),
			E('h3', title)
		]));

		container_box.appendChild(E('hr'));

		if ('internet' == type) {
			
			var container_internet_v4 = E('div');
			var container_internet_v6 = E('div');
			var container_internet_vps = E('div');

			for(var idx in data['vps']) {
				var classname = ver,
					suppelements = '',
					visible = data['vps'][idx].visible;
				if ('title' === idx) {
					container_internet_vps.appendChild(
						E('p', { 'class': 'mt-2'}, [
							E('h4', {'class': ''}, [ data['vps'].title ]),
						])
					);
					continue;
				}
				if (visible) {
					container_internet_vps.appendChild(
						E('p', { 'class': 'mt-2'}, [
							E('span', {'class': ''}, [ data['vps'][idx].title + '：' ]),
							E('span', {'class': ''}, [ data['vps'][idx].value ]),
							suppelements
						])
					);
				}
			}


			for(var idx in data['internet']) {

				for(var ver in data['internet'][idx]) {
					var classname = ver,
						suppelements = '',
						visible = data['internet'][idx][ver].visible;

					if('connected' === ver) {
						classname = data['internet'][idx][ver].value ? 'label label-success' : 'label label-danger';
						data['internet'][idx][ver].value = data['internet'][idx][ver].value ? _('yes') : _('no');
					}

					if ('v4' === idx) {

						if ('title' === ver) {
							container_internet_v4.appendChild(
								E('p', { 'class': 'mt-2'}, [
									E('h4', {'class': ''}, [ data['internet'][idx].title ]),
								])
							);
							continue;
						}

						if ('addrsv4' === ver) {
							var addrs = data['internet'][idx][ver].value;
							if(Array.isArray(addrs) && addrs.length) {
								for(var ip in addrs) {
									data['internet'][idx][ver].value = addrs[ip].split('/')[0];
								}
							}
						}

						if (visible) {
							container_internet_v4.appendChild(
								E('p', { 'class': 'mt-2'}, [
									E('span', {'class': ''}, [ data['internet'][idx][ver].title + '：' ]),
									E('span', {'class': classname }, [ data['internet'][idx][ver].value ]),
									suppelements
								])
							);
						}

					} else {

						if ('title' === ver) {
							container_internet_v6.appendChild(
								E('p', { 'class': 'mt-2'}, [
									E('h4', {'class': ''}, [ data['internet'][idx].title ]),
								])
							);
							continue;
						}

						if (visible) {
							container_internet_v6.appendChild(
								E('p', {'class': 'mt-2'}, [
									E('span', {'class': ''}, [data['internet'][idx][ver].title + '：']),
									E('span', {'class': classname}, [data['internet'][idx][ver].value]),
									suppelements
								])
							);
						}
					}
				}
			}

			container_item.appendChild(E('p', { 'class': 'table'}, [
				E('div', { 'class': 'tr' }, [
					E('div', { 'class': 'td' }, [ container_internet_vps ])
				]),
				E('div', { 'class': 'tr' }, [
					E('div', { 'class': 'td' }, [ 
						container_internet_v4
					]),
					E('div', { 'class': 'td' }, [ 
						container_internet_v6
					])
				])
			]));
		} else {
			for(var idx in data) {
				container_item.appendChild(
					E('p', { 'class': 'mt-2'}, [
						E('span', {'class': ''}, [ data[idx].title + '：' ]),
						E('span', {'class': ''}, [ data[idx].value ])
					])
				);
			}
		}

		container_box.appendChild(container_item);
		container_box.appendChild(E('hr'));
		container_wapper.appendChild(container_box);
		return container_wapper;
	},

	renderUpdateWanData: function(data, v6) {
		for (var i = 0; i < data.length; i++) {
			 var ifc = data[i];

			 if (v6) {
				this.params.internet.v6.ipprefixv6.value =  ifc.getIP6Prefix() || '-';
				this.params.internet.v6.gatewayv6.value =  ifc.getGateway6Addr() || '-';
				this.params.internet.v6.protocol.value=  ifc.getI18n() || E('em', _('Not connected'));
				this.params.internet.v6.addrsv6.value = ifc.getIP6Addrs() || [ '-' ];
				this.params.internet.v6.dnsv6.value = ifc.getDNS6Addrs() || [ '-' ];
				this.params.internet.v6.connected.value = ifc.isUp();
			 } else {
				var uptime = ifc.getUptime();
				this.params.internet.v4.uptime.value = (uptime > 0) ? '%t'.format(uptime) : '-';
				this.params.internet.v4.protocol.value=  ifc.getI18n() || E('em', _('Not connected'));
				this.params.internet.v4.gatewayv4.value =  ifc.getGatewayAddr() || '0.0.0.0';
				this.params.internet.v4.connected.value = ifc.isUp();
				this.params.internet.v4.addrsv4.value = ifc.getIPAddrs() || [ '-'];
				this.params.internet.v4.dnsv4.value = ifc.getDNSAddrs() || [ '-' ];
			 }
		}
	},
	renderUpdateOpenMPTCProuterData: function(data, v6) {
		if (data.openmptcprouter != undefined) {
			if (data.openmptcprouter.wan_addr != '') this.params.omrvps.internet.v4.connected.value = true;
			if (data.openmptcprouter.wan_addr) this.params.omrvps.internet.v4.addrsv4.value = data.openmptcprouter.wan_addr || [ '-'];
			if (data.openmptcprouter.wan_addr6) this.params.omrvps.internet.v6.addrsv6.value = data.openmptcprouter.wan_addr6 || [ '-'];
			if (data.openmptcprouter.vps_kernel) this.params.omrvps.vps.version.value = data.openmptcprouter.vps_kernel + ' ' + data.openmptcprouter.vps_omr_version || [ '-'];
			if (data.openmptcprouter.vps_loadavg) {
				var vps_loadavg = data.openmptcprouter.vps_loadavg.split(" ");
				this.params.omrvps.vps.load.value = '%s, %s, %s'.format(vps_loadavg[0],vps_loadavg[1],vps_loadavg[2]);
			}
			if (data.openmptcprouter.vps_uptime) this.params.omrvps.vps.uptime.value = String.format('%t', data.openmptcprouter.vps_uptime) || [ '-'];
			if (data.openmptcprouter.proxy_traffic) this.params.omrvps.vps.trafficproxy.value = this.formatBytes(data.openmptcprouter.proxy_traffic) || [ '-'];
			if (data.openmptcprouter.vpn_traffic) this.params.omrvps.vps.trafficvpn.value = this.formatBytes(data.openmptcprouter.vpn_traffic) || [ '-'];
			if (data.openmptcprouter.total_traffic) this.params.omrvps.vps.traffictotal.value = this.formatBytes(data.openmptcprouter.total_traffic) || [ '-'];
			if (data.openmptcprouter.ipv6 != 'disabled') this.params.omrvps.internet.v6.connected.value = true;
		}
	},

	renderInternetBox: function(data) {

		this.params.omrvps = {
			vps: {
				title: _('Server'),

				version: {
					title: _('Version'),
					visible: true,
					value: [ '-' ]
				},

				load: {
					title: _('Load'),
					visible: true,
					value: [ '-' ]
				},

				uptime: {
					title: _('Uptime'),
					visible: true,
					value: [ '-' ]
				},

				trafficproxy: {
					title: _('Proxy traffic'),
					visible: true,
					value: [ '-' ]
				},

				trafficvpn: {
					title: _('VPN traffic'),
					visible: true,
					value: [ '-' ]
				},

				traffictotal: {
					title: _('Total traffic'),
					visible: true,
					value: [ '-' ]
				}
			},

			internet: {

				v4: {
					title: _('IPv4 Internet'),

					connected: {
						title: _('Connected'),
						visible: true,
						value: false
					},

					addrsv4: {
						title: _('IPv4'),
						visible: true,
						value: [ '-' ]
					}
				},

				v6: {
					title: _('IPv6 Internet'),

					connected: {
						title: _('Connected'),
						visible: true,
						value: false
					},

					ipprefixv6 : {
						title: _('IPv6 prefix'),
						visible: false,
						value: ' - '
					},

					addrsv6: {
						title: _('IPv6'),
						visible: true,
						value: [ '-' ]
					}

				}
			}
		};

		//this.renderUpdateWanData(data[0], false);
		//this.renderUpdateWanData(data[1], true);
		this.renderUpdateOpenMPTCProuterData(data[4], true);

		return this.renderHtml(this.params.omrvps, 'internet');
	},

	renderRouterBox: function(data) {

		var boardinfo   = data[2],
			systeminfo  = data[3];

		var datestr = null;

		if (systeminfo.localtime) {
			var date = new Date(systeminfo.localtime * 1000);

			datestr = '%04d-%02d-%02d %02d:%02d:%02d'.format(
				date.getUTCFullYear(),
				date.getUTCMonth() + 1,
				date.getUTCDate(),
				date.getUTCHours(),
				date.getUTCMinutes(),
				date.getUTCSeconds()
			);
		}

		this.params.router = {
			uptime: {
				title: _('Uptime'),
				value: systeminfo.uptime ? '%t'.format(systeminfo.uptime) : null,
			},

			localtime: {
				title: _('Local Time'),
				value: datestr
			},

			load: {
				title: _('Load Average'),
				value: Array.isArray(systeminfo.load) ? '%.2f, %.2f, %.2f'.format(systeminfo.load[0] / 65535.0,systeminfo.load[1] / 65535.0,systeminfo.load[2] / 65535.0) : null
			},

			kernel: {
				title: _('Kernel Version'),
				value: boardinfo.kernel
			},

			model: {
				title: _('Model'),
				value: boardinfo.model
			},

			system: {
				title: _('Architecture'),
				value: boardinfo.system
			},

			release: {
				title: _('Firmware Version'),
				value: (typeof boardinfo.release !== "undefined") ? ((typeof boardinfo.release.description !== "undefined") ? boardinfo.release.description : null) : null
			}
		};

		return this.renderHtml(this.params.router, 'router');
	},

	render: function(data) {
		return [this.renderInternetBox(data), this.renderRouterBox(data)];
	}
});
