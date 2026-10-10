#!/bin/sh

# Secrets (passwords, keys, tokens, VLESS/VMess ids, PINs) lose their whole
# value: masking their last 6 characters left most of a key in what users
# paste in public bug reports. Addresses keep their first part, for debugging.
# The VPS addresses can be lists (several IPs of a server, the openvpn remote
# of each server): every element is masked, not only the last one.
uci show | \
    sed -e "/^[^=]*\.[^.=]*\(password\|key\|secret\|psk\|pincode\|token\|user_id\|passphrase\)[^.=]*=/s/=.*/='xxxxxx'/" \
	-e "/detected_public_ipv4=/s/......$/xxxxxx'/" \
	-e "/detected_ss_ipv4=/s/......$/xxxxxx'/" \
	-e "/detected_public_ipv6=/s/......$/xxxxxx'/" \
	-e "/detected_ss_ipv6=/s/......$/xxxxxx'/" \
	-e "/publicip=/s/......$/xxxxxx'/" \
	-e "/publicip6=/s/......$/xxxxxx'/" \
	-e "/\.host=/s/......$/xxxxxx'/" \
	-e "/\.ip=/s/.....'\( \|$\)/xxxxxx'\1/g" \
	-e "/\.ipv6='2/s/=....../='xxxxxx/" \
	-e "/openvpn\.omr[0-9]*\.remote=/s/.....'\( \|$\)/xxxxxx'\1/g" \
	-e "/shadowsocks-libev\.sss.*\.server=/s/......$/xxxxxx'/" \
	-e "/shadowsocks-rust\.sss.*\.server=/s/......$/xxxxxx'/" \
	-e "/external_ip=/s/......$/xxxxxx'/" \
	-e "/obfs_host=/s/..........$/xxxxxx'/" \
	-e "/vmess_address=/s/......$/xxxxxx'/" \
	-e "/vless_address=/s/......$/xxxxxx'/" \
	-e "/trojan_address=/s/......$/xxxxxx'/" \
	-e "/socks_address=/s/......$/xxxxxx'/" \
	-e "/vless_reality_address=/s/......$/xxxxxx'/" \
	-e "/ula_prefix=2/s/=.........../='xxxxxxxxxxx/"