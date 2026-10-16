#!/bin/sh
#
# Copyright (C) 2026 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter
#
# This is free software, licensed under the GNU General Public License v3 or later.
# See /LICENSE for more information.
#
# confgen behind omr_remote_log() (/etc/syslog-ng.d/omr-remote.conf): on
# images that log through syslog-ng, logd is disabled (uci-defaults
# 2062-omr-syslog) and with it the only reader of log_ip, log_port and
# log_proto, so a remote log server set in System > Logging was ignored.
# Print a network() destination for it, fed by the sources the stock
# /var/log/messages log path uses. syslog-ng runs this each time it loads
# its config; /etc/init.d/omr-syslog reloads it when the system config is
# applied.
#
# The output is parsed as syslog-ng config: a value from uci only gets there
# once it is known to hold nothing but host, port or protocol characters.

_omr_sngconf="${OMR_SYSLOG_CONF:-/etc/syslog-ng.conf}"

_omr_remote_skip() {
	logger -t omr-syslog "remote log server not used: $*" 2>/dev/null
	exit 0
}

# same defaults and switch as logd (/etc/init.d/log)
case "$(uci -q get system.@system[0].log_remote)" in
	0|no|off|false|disabled) exit 0 ;;
esac
_omr_ip="$(uci -q get system.@system[0].log_ip)"
[ -n "$_omr_ip" ] || exit 0
_omr_port="$(uci -q get system.@system[0].log_port)"
_omr_port="${_omr_port:-514}"
_omr_proto="$(uci -q get system.@system[0].log_proto)"
_omr_proto="${_omr_proto:-udp}"

case "$_omr_ip" in
	*[!0-9A-Za-z.:-]*) _omr_remote_skip "invalid log_ip" ;;
esac
case "$_omr_port" in
	''|*[!0-9]*) _omr_remote_skip "invalid log_port" ;;
esac
[ "$_omr_port" -ge 1 ] && [ "$_omr_port" -le 65535 ] || _omr_remote_skip "invalid log_port"
case "$_omr_proto" in
	udp|tcp) ;;
	*) _omr_remote_skip "invalid log_proto" ;;
esac

_omr_family=""
case "$_omr_ip" in
	*:*) _omr_family=" ip-protocol(6)" ;;
esac

# Only the sources the stock syslog-ng.conf defines: referring to one that a
# hand-written config dropped would stop syslog-ng from loading at all.
# network_localhost() ("net") listens on UDP 514 on the loopback, a server on
# the router itself would get its own messages back there, forever.
_omr_sources=""
for _omr_src in src net kernel; do
	if [ "$_omr_src" = "net" ]; then
		case "$_omr_ip" in
			127.*|0.0.0.0|::|::1|localhost|localhost.*) continue ;;
		esac
	fi
	grep -qE "^[[:space:]]*source[[:space:]]+${_omr_src}[[:space:]]*\{" "$_omr_sngconf" 2>/dev/null &&
		_omr_sources="${_omr_sources} source(${_omr_src});"
done
[ -n "$_omr_sources" ] || _omr_remote_skip "no src, net or kernel source in $_omr_sngconf"

echo "destination d_omr_remote { network(\"${_omr_ip}\" transport(\"${_omr_proto}\") port(${_omr_port})${_omr_family}); };"
echo "log {${_omr_sources} destination(d_omr_remote); };"
