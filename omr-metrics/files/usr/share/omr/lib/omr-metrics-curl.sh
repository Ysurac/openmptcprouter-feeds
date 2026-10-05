# Pin the public key of the custom omr-metrics server's API certificate.
#
# With omr-metrics.settings.use_custom_server the metrics, and the API
# username and password, go to a server of the user's choosing
# (omr-metrics.settings.server). omr_vps_curl only pins the hosts listed in an
# openmptcprouter server section's ip, so that server got a plain curl -k:
# anyone on the path could collect the credentials from POST /token
# (GHSA-qq6x-5r9f-2w3m again). It gets the same treatment here, its pin kept
# in omr-metrics.settings.custom_server_pin: the base64 SHA-256 of the
# certificate's SubjectPublicKeyInfo entered by the user, or else the one seen
# on first contact (trust on first use).
#
# Nothing is sent before the pin is known: the first contact is a bare GET /
# to learn it, and when that fails the call fails too. A key that does not
# match makes curl abort the handshake (exit 90) before any data goes out. A
# learned pin remembers the server it was learned from
# (custom_server_pin_host) and is learned again when the user points
# omr-metrics at another server; a pin typed in by the user applies to
# whatever server is set.
#
# omr-vps-curl.sh keeps its pins in openmptcprouter server sections, so it
# can't hold this one; this reuses its checks and mirrors its learning.
#
# Usage: omr_metrics_curl <curl arguments>, a drop-in for omr_vps_curl. A
# custom server that is also one of the VPS addresses keeps the VPS's pin.
# Needs omr-vps-curl.sh sourced first.

_omr_metrics_pin_warn() {
	logger -t "omr-metrics" -p daemon.warn "$@"
}

# Learn and store the pin of the custom server $1 (its host) from a bare GET
# on $2 (https://host:port/), connecting the way the curl arguments that
# follow do. Returns non-zero when no pin could be learned.
_omr_metrics_pin_learn() {
	local host="$1" root="$2" opts="" prev="" a rc pem pubkey pin
	shift 2
	for a in "$@"; do
		[ -n "$prev" ] && opts="$opts $prev $a"
		prev=""
		case "$a" in
			-4|-6|--ipv4|--ipv6) opts="$opts $a" ;;
			--interface|-m|--max-time|--connect-timeout) prev="$a" ;;
		esac
	done
	# $opts is only flags, numbers and interface names: word splitting is safe
	# shellcheck disable=SC2086
	pem="$(curl -s -k --max-time 10 $opts -w '%{certs}' -o /dev/null "$root" 2>/dev/null)"
	rc=$?
	[ "$rc" -eq 0 ] || return "$rc"
	pem="$(printf '%s\n' "$pem" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/{p;/-----END CERTIFICATE-----/q;}')"
	pubkey="$(printf '%s\n' "$pem" | openssl x509 -pubkey -noout 2>/dev/null)"
	[ -n "$pubkey" ] || return 1
	pin="$(printf '%s\n' "$pubkey" | openssl pkey -pubin -outform der 2>/dev/null | openssl dgst -sha256 -binary 2>/dev/null | openssl enc -base64 2>/dev/null)"
	_omr_vps_pin_valid "$pin" || return 1
	# A pin entered while we were connecting wins
	[ -z "$(uci -q get omr-metrics.settings.custom_server_pin)" ] || return 0
	uci -q set "omr-metrics.settings.custom_server_pin=${pin}"
	uci -q set "omr-metrics.settings.custom_server_pin_host=${host}"
	uci -q commit omr-metrics
	logger -t "omr-metrics" "Custom server ${host}: trusting the API certificate public key sha256//${pin} from now on"
}

omr_metrics_curl() {
	local a url="" hostport="" host="" custom pin pin_host rc flag now last
	custom="$(uci -q get omr-metrics.settings.server)"
	custom="${custom#\[}"
	custom="${custom%\]}"
	for a in "$@"; do
		case "$a" in
			https://*) url="$a" ;;
		esac
	done
	if [ -n "$url" ] && [ -n "$custom" ]; then
		hostport="${url#https://}"
		hostport="${hostport%%/*}"
		hostport="${hostport%%\?*}"
		case "$hostport" in
			\[*)
				host="${hostport#\[}"
				host="${host%%\]*}"
				host="${host%%\%*}"
				;;
			*) host="${hostport%%:*}" ;;
		esac
	fi
	# Not the custom server, or one of the VPS addresses: omr_vps_curl
	# pins it (or leaves it alone, as before)
	if [ -z "$host" ] || [ "$host" != "$custom" ] || [ -n "${OMR_VPS_SERVER:-}" ] ||
	   [ -n "$(_omr_vps_pin_lookup "$host")" ]; then
		omr_vps_curl "$@"
		return
	fi
	pin="$(uci -q get omr-metrics.settings.custom_server_pin)"
	pin_host="$(uci -q get omr-metrics.settings.custom_server_pin_host)"
	# Learned from another server: the user moved omr-metrics to a new one
	if [ -n "$pin" ] && [ -n "$pin_host" ] && [ "$pin_host" != "$host" ]; then
		uci -q delete omr-metrics.settings.custom_server_pin
		uci -q delete omr-metrics.settings.custom_server_pin_host
		uci -q commit omr-metrics
		pin=""
	fi
	if [ -z "$pin" ]; then
		if ! command -v openssl >/dev/null 2>&1; then
			_omr_metrics_pin_warn "Custom server ${host}: openssl is missing, the API certificate can't be pinned"
			curl "$@"
			return
		fi
		_omr_metrics_pin_learn "$host" "https://${hostport}/" "$@" || return
		pin="$(uci -q get omr-metrics.settings.custom_server_pin)"
	fi
	pin="${pin#sha256//}"
	_omr_vps_pin_valid "$pin" || {
		_omr_metrics_pin_warn "Custom server ${host}: custom_server_pin '${pin}' is not a base64 SHA-256, not talking to the server"
		return 1
	}
	curl --pinnedpubkey "sha256//${pin}" "$@"
	rc=$?
	# A mismatch is logged once an hour, as omr-vps-curl.sh does
	flag="${OMR_VPS_PIN_STATE:-/tmp/omr-vps-pin}/omr-metrics-custom.mismatch"
	if [ "$rc" = "90" ]; then
		mkdir -p "${flag%/*}"
		now="$(date +%s)"
		last="$(cat "$flag" 2>/dev/null)"
		[ -n "$last" ] || last=0
		[ "$((now - last))" -ge 3600 ] && {
			_omr_metrics_pin_warn "Custom server ${host}: the API certificate public key does not match the pinned sha256//${pin}, refusing to talk to it. Someone may be intercepting the connection. If the server was reinstalled, empty omr-metrics.settings.custom_server_pin to trust its new certificate."
			echo "$now" > "$flag"
		}
	elif [ "$rc" = "0" ] && [ -e "$flag" ]; then
		rm -f "$flag"
	fi
	return "$rc"
}
