# Pin the public key of the OMR VPS API certificate.
#
# The VPS API answers with a self-signed certificate, so every call used to be
# a plain `curl -k`: the router trusted whoever answered on the VPS address. An
# on-path attacker could collect the API username and password from POST
# /token, then hand the router any VPN or proxy key it liked
# (GHSA-qq6x-5r9f-2w3m).
#
# omr_vps_curl replaces the missing chain verification by a public key pin, the
# base64 SHA-256 of the server's SubjectPublicKeyInfo kept in
# openmptcprouter.<server>.api_pin (curl's --pinnedpubkey format). The pin is
# the one the VPS installer prints, entered in the wizard, or else the one seen
# on first contact (trust on first use). Pinning the key rather than the
# certificate survives a certificate renewal that keeps its key, which is what
# the VPS installer and acme.sh both do.
#
# Nothing is sent to a server before its pin is known: the first contact is a
# bare GET / to learn it, and when that fails the call fails too. A key that
# does not match makes curl abort the handshake (exit 90) before any data goes
# out; that is logged, and flagged for the status page until a call matches
# again. The wizard drops the pin when the server's address or key changes.
#
# Usage: omr_vps_curl <curl arguments>, a drop-in for curl. The server is the
# openmptcprouter server section listing the https:// URL's host among its ip;
# any other host is curled unchanged. A caller that connects to an address the
# ip list doesn't spell out (a resolved hostname) names the section in
# OMR_VPS_SERVER instead.

OMR_VPS_PIN_STATE="${OMR_VPS_PIN_STATE:-/tmp/omr-vps-pin}"

# SHA-256 of zero bytes: what a broken openssl pipeline would hash
_OMR_VPS_PIN_EMPTY='47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='

_omr_vps_pin_valid() {
	case "$1" in
		"$_OMR_VPS_PIN_EMPTY") return 1 ;;
	esac
	expr "$1" : '[A-Za-z0-9+/]\{43\}=$' >/dev/null
}

# Echo "<section> <pin>" for the server section listing host $1, nothing when
# no server does.
_omr_vps_pin_lookup() {
	uci -q show openmptcprouter 2>/dev/null | awk -v host="$1" '
		{
			eq = index($0, "=")
			n = split(substr($0, 1, eq - 1), k, ".")
			val = substr($0, eq + 1)
			gsub(/\047/, "", val)
		}
		n == 2 && val == "server" { srv[k[2]] = 1 }
		n == 3 && k[3] == "ip" {
			m = split(val, ips, " ")
			for (i = 1; i <= m; i++)
				if (ips[i] == host && !(k[2] in hit)) { hit[k[2]] = 1; order[++nhit] = k[2] }
		}
		n == 3 && k[3] == "api_pin" { pin[k[2]] = val }
		END {
			for (i = 1; i <= nhit; i++)
				if (order[i] in srv) { print order[i], pin[order[i]]; exit }
		}'
}

# Learn and store the pin of server $1 from a bare GET on $2 (https://host:port/),
# connecting the way the curl arguments that follow do. Returns non-zero when no
# pin could be learned.
_omr_vps_pin_learn() {
	local section="$1" root="$2" opts="" prev="" a rc pem pubkey pin
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
	[ -z "$(uci -q get "openmptcprouter.${section}.api_pin")" ] || return 0
	uci -q set "openmptcprouter.${section}.api_pin=${pin}"
	uci -q commit openmptcprouter
	logger -t "OMR-VPS" "Server ${section}: trusting the API certificate public key sha256//${pin} from now on"
}

# Flag a pin mismatch of server $1 (logged once an hour), clear the flag once a
# call matches again.
_omr_vps_pin_result() {
	local section="$1" rc="$2" pin="$3" flag now last
	flag="${OMR_VPS_PIN_STATE}/${section}.mismatch"
	if [ "$rc" = "90" ]; then
		mkdir -p "$OMR_VPS_PIN_STATE"
		now="$(date +%s)"
		last="$(cat "$flag" 2>/dev/null)"
		[ -n "$last" ] || last=0
		[ "$((now - last))" -ge 3600 ] && {
			logger -t "OMR-VPS" -p daemon.warn "Server ${section}: the API certificate public key does not match the pinned sha256//${pin}, refusing to talk to it. Someone may be intercepting the connection. If the VPS was reinstalled, empty the server's API certificate pin in the wizard to trust its new certificate."
			echo "$now" > "$flag"
		}
	elif [ "$rc" = "0" ] && [ -e "$flag" ]; then
		rm -f "$flag"
	fi
}

omr_vps_curl() {
	local a url="" hostport host lookup section="" pin="" rc
	for a in "$@"; do
		case "$a" in
			https://*) url="$a" ;;
		esac
	done
	if [ -n "$url" ]; then
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
		if [ -n "$OMR_VPS_SERVER" ]; then
			section="$OMR_VPS_SERVER"
			pin="$(uci -q get "openmptcprouter.${section}.api_pin")"
		else
			lookup="$(_omr_vps_pin_lookup "$host")"
			section="${lookup%% *}"
			pin="${lookup#* }"
		fi
	fi
	[ -n "$section" ] || {
		curl "$@"
		return
	}
	if [ -z "$pin" ]; then
		if ! command -v openssl >/dev/null 2>&1; then
			logger -t "OMR-VPS" -p daemon.warn "Server ${section}: openssl is missing, the API certificate can't be pinned"
			curl "$@"
			return
		fi
		_omr_vps_pin_learn "$section" "https://${hostport}/" "$@" || return
		pin="$(uci -q get "openmptcprouter.${section}.api_pin")"
	fi
	pin="${pin#sha256//}"
	_omr_vps_pin_valid "$pin" || {
		logger -t "OMR-VPS" -p daemon.warn "Server ${section}: api_pin '${pin}' is not a base64 SHA-256, not talking to the server"
		return 1
	}
	curl --pinnedpubkey "sha256//${pin}" "$@"
	rc=$?
	_omr_vps_pin_result "$section" "$rc" "$pin"
	return "$rc"
}
