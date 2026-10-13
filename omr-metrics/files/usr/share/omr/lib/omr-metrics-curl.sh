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

# Login to the metrics API, shared by omr-metrics-send, omr-weight-sync and
# the metrics rpcd. Each of them used to log in on its own: the rpcd on every
# LuCI call (three every 5 s with the Metrics page open) and omr-weight-sync
# every 5 s, with no back-off, so a wrong key earned fail2ban strikes much
# faster than omr-metrics-send's back-off was meant to allow. They now share
# one back-off, kept in the same files.
#
# The callers define _log. The credentials and token being used are in
# SRV_USERNAME, SRV_PASSWORD, SRV_TOKEN and SRV_TOKEN_KEY (_server_creds).

# Login backoff caps, in seconds. A POST /token the server *answers* with a
# rejection is a failed login on the VPS side: fail2ban's omradmin jail counts
# it and bans the router's public IP off port 65500 after a handful of them,
# which then looks exactly like "can ping server vps, no server API answer"
# and takes the whole VPS API -- not just metrics -- down with it. So a
# rejection backs off much harder than a path that simply did not answer.
LOGIN_BACKOFF_REJECTED="${LOGIN_BACKOFF_REJECTED:-${OMR_METRICS_LOGIN_BACKOFF_REJECTED:-1800}}"
LOGIN_BACKOFF_NO_ANSWER="${LOGIN_BACKOFF_NO_ANSWER:-${OMR_METRICS_LOGIN_BACKOFF_NO_ANSWER:-300}}"

# First delay after each kind of failure, before the doubling starts.
#
# A rejection has to start high, not at the poll interval: doubling from 30s
# puts login attempts at t=0, 30, 90, 210 and 450 seconds, i.e. five failed
# logins inside the ten minutes a fail2ban jail configured maxretry 5 /
# findtime 600 looks at -- which bans the router's own public IP off port
# 65500 and takes the whole VPS API down with it, the exact outcome this
# backoff exists to avoid. Starting at 300s puts the first two retries at
# t=300 and t=900: at most two strikes per findtime window, whatever the
# jail's maxretry is. A request nobody answered is not a failed login and
# does not earn a strike, so that path keeps retrying from the poll interval.
LOGIN_FIRST_REJECTED="${LOGIN_FIRST_REJECTED:-${OMR_METRICS_LOGIN_FIRST_REJECTED:-300}}"
LOGIN_FIRST_NO_ANSWER="${LOGIN_FIRST_NO_ANSWER:-${OMR_METRICS_LOGIN_FIRST_NO_ANSWER:-${INTERVAL:-30}}}"

_omr_metrics_login_dir() {
	printf '%s' "${OMR_METRICS_STATE_DIR:-/tmp/omr-metrics-send}"
}

_is_ip6() {
	case "$1" in *:*) return 0 ;; esac
	return 1
}

# State-file stem for one (server section, server address) pair: each address
# is a distinct network path with its own public IP, so it earns its own
# fail2ban strikes and its own backoff.
_state_key() {
	printf '%s' "${1}_${2}" | tr -c 'A-Za-z0-9._-' '_'
}

# Credentials change (wizard save, key paste) invalidate a backoff: the user
# just told us the old ones were wrong, retry immediately.
_cred_fingerprint() {
	printf '%s:%s' "$SRV_USERNAME" "$SRV_PASSWORD" | md5sum 2>/dev/null | cut -c1-8
}

# True when a login attempt for this server path is allowed right now.
_login_allowed() {
	local file fails next fprint now
	file="$(_omr_metrics_login_dir)/${1}.login_backoff"
	[ -f "$file" ] || return 0
	read -r fails next fprint < "$file" 2>/dev/null
	[ -z "$next" ] && return 0
	[ "$fprint" != "$(_cred_fingerprint)" ] && {
		rm -f "$file" 2>/dev/null
		return 0
	}
	now=$(date +%s)
	[ "$now" -ge "$next" ]
}

# Record a failed login and arm the next retry. $2 is the backoff cap for this
# kind of failure and $3 the delay it starts from; the delay doubles from $3
# up to $2, so the attempts a fail2ban jail can see stay under its maxretry.
_login_failed() {
	local key="$1" cap="$2" first="$3" dir file fails next delay now
	dir="$(_omr_metrics_login_dir)"
	file="${dir}/${key}.login_backoff"
	fails=0
	[ -f "$file" ] && read -r fails next < "$file" 2>/dev/null
	case "$fails" in ''|*[!0-9]*) fails=0 ;; esac
	fails=$((fails + 1))
	case "$first" in ''|*[!0-9]*) first="${INTERVAL:-30}" ;; esac
	delay="$first"
	local n=1
	while [ "$n" -lt "$fails" ] && [ "$delay" -lt "$cap" ]; do
		delay=$((delay * 2))
		n=$((n + 1))
	done
	[ "$delay" -gt "$cap" ] && delay="$cap"
	now=$(date +%s)
	[ -d "$dir" ] || mkdir -p "$dir"
	printf '%s %s %s\n' "$fails" "$((now + delay))" "$(_cred_fingerprint)" > "$file"
	echo "$delay"
}

_login_ok() {
	rm -f "$(_omr_metrics_login_dir)/${1}.login_backoff" 2>/dev/null
}

# Keep a token for the next cycles. The custom server's is runtime state: in
# the omr-metrics config, the next "uci commit omr-metrics" (a LuCI save, a
# learned certificate pin) wrote it to flash. A VPS token is shared with
# openmptcprouter-vps, which keeps it in its config.
_token_store() {
	case "$1" in
		omr-metrics.settings.token) omr_state_set omr-metrics settings token "$2" ;;
		*) uci -q set "${1}=${2}" ;;
	esac
}

# Forget a token the server refused (HTTP 401). Kept, it went out again on
# every call while the login was backing off.
_token_drop() {
	case "$1" in
		omr-metrics.settings.token) omr_state_del omr-metrics settings token ;;
		*) uci -q delete "$1" ;;
	esac
}

# Load the credentials and any stored token for one server into SRV_*.
# The omr-metrics ones are the custom server's, and only its: picked as soon
# as a username was set there, they also went to the VPS once the custom
# server was turned off (the settings page keeps them), which rejected them.
_server_creds() {
	local servername="$1"

	if [ "$servername" = "omr_metrics_custom" ]; then
		SRV_TOKEN=$(omr_state_get "omr-metrics.settings.token")
		SRV_USERNAME=$(uci -q get "omr-metrics.settings.username" 2>/dev/null)
		SRV_PASSWORD=$(uci -q get "omr-metrics.settings.password" 2>/dev/null)
		SRV_TOKEN_KEY="omr-metrics.settings.token"
	else
		SRV_TOKEN=$(uci -q get "openmptcprouter.${servername}.token" 2>/dev/null)
		SRV_USERNAME=$(uci -q get "openmptcprouter.${servername}.username" 2>/dev/null)
		SRV_PASSWORD=$(uci -q get "openmptcprouter.${servername}.password" 2>/dev/null)
		SRV_TOKEN_KEY="openmptcprouter.${servername}.token"
	fi
}

# Obtain a Bearer token via POST /token and save it with _token_store and in
# SRV_TOKEN, unless the backoff of this server path says to wait.
# $1 = server section name (for the backoff state), $2 = address, $3 = port.
# Returns 0 when SRV_TOKEN holds a token.
_login() {
	local servername="$1" server="$2" serverport="$3"
	local key resp code body delay

	key=$(_state_key "$servername" "$server")

	if [ -z "$SRV_USERNAME" ] || [ -z "$SRV_PASSWORD" ]; then
		# Nothing to send yet (wizard not filled in): don't touch the API
		# at all, and let the backoff rate-limit the log line. The
		# credential fingerprint clears it as soon as a key is entered.
		_login_allowed "$key" && {
			_login_failed "$key" "$LOGIN_BACKOFF_NO_ANSWER" "$LOGIN_FIRST_NO_ANSWER" >/dev/null
			_log "no credentials for ${server} yet, skipping login"
		}
		return 1
	fi

	_login_allowed "$key" || return 1

	# Both fields URL-encoded by curl, the password read on stdin: pasted
	# raw into the form body, a password with a '&', '+', '=' or '%' reached
	# the API altered, and on the command line it showed in ps.
	if _is_ip6 "$server"; then
		resp=$(printf '%s' "$SRV_PASSWORD" | omr_metrics_curl -6 --max-time 10 -s -k -w '%{http_code}' \
			-H "accept: application/json" \
			-H "Content-Type: application/x-www-form-urlencoded" \
			-X POST --data-urlencode "username=${SRV_USERNAME}" --data-urlencode "password@-" \
			"https://[${server}]:${serverport}/token" 2>/dev/null)
	else
		resp=$(printf '%s' "$SRV_PASSWORD" | omr_metrics_curl --max-time 10 -s -k -w '%{http_code}' \
			-H "accept: application/json" \
			-H "Content-Type: application/x-www-form-urlencoded" \
			-X POST --data-urlencode "username=${SRV_USERNAME}" --data-urlencode "password@-" \
			"https://${server}:${serverport}/token" 2>/dev/null)
	fi
	# -w appends the status to the body, so the last three characters are
	# the code ("000" when the connection never happened).
	code=$(printf '%s' "$resp" | tail -c 3)
	body=${resp%???}

	SRV_TOKEN=$(printf '%s' "$body" | jsonfilter -q -e '@.access_token' 2>/dev/null)
	if [ -n "$SRV_TOKEN" ]; then
		_token_store "$SRV_TOKEN_KEY" "$SRV_TOKEN"
		_login_ok "$key"
		return 0
	fi

	case "$code" in
		4*|5*)
			# The API answered and turned us down: credentials, not path.
			delay=$(_login_failed "$key" "$LOGIN_BACKOFF_REJECTED" "$LOGIN_FIRST_REJECTED")
			_log "login rejected by ${server} (HTTP ${code}), next try in ${delay}s"
			;;
		2*)
			delay=$(_login_failed "$key" "$LOGIN_BACKOFF_REJECTED" "$LOGIN_FIRST_REJECTED")
			_log "no access_token in the answer from ${server} (HTTP ${code}), next try in ${delay}s"
			;;
		*)
			delay=$(_login_failed "$key" "$LOGIN_BACKOFF_NO_ANSWER" "$LOGIN_FIRST_NO_ANSWER")
			_log "no answer from the API on ${server}, next try in ${delay}s"
			;;
	esac
	return 1
}
