#!/bin/sh

uci show | \
    sed -e "/password=/s/......$/xxxxxx'/" \
	-e "/detected_public_ipv4=/s/......$/xxxxxx'/" \
	-e "/detected_ss_ipv4=/s/......$/xxxxxx'/" \
	-e "/detected_public_ipv6=/s/......$/xxxxxx'/" \
	-e "/detected_ss_ipv6=/s/......$/xxxxxx'/" \
	-e "/publicip=/s/......$/xxxxxx'/" \
	-e "/\.host=/s/......$/xxxxxx'/" \
	-e "/\.ip=/s/......$/xxxxxx'/" \
	-e "/\.ipv6='2/s/=....../='xxxxxx/" \
	-e "/user_id=/s/......$/xxxxxx'/" \
	-e "/openvpn\.omr\.remote=/s/......$/xxxxxx'/" \
	-e "/shadowsocks-libev\.sss.*\.server=/s/......$/xxxxxx'/" \
	-e "/shadowsocks-libev\.sss.*\.key=/s/......$/xxxxxx'/" \
	-e "/external_ip=/s/......$/xxxxxx'/" \
	-e "/obfs_host=/s/..........$/xxxxxx'/" \
	-e "/vmess_address=/s/......$/xxxxxx'/" \
	-e "/vless_address=/s/......$/xxxxxx'/" \
	-e "/vpn\.key=/s/......$/xxxxxx'/" \
	-e "/vps\.key=/s/......$/xxxxxx'/" \
	-e "/wgkey=/s/......$/xxxxxx'/" \
	-e "/ula_prefix=2/s/=.........../='xxxxxxxxxxx/" \
	-e "/token=/s/............$/xxxxxx'/"