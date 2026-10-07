#!/bin/bash
# FTP to the VPS's address, forwarded to the LAN (openmptcprouter#4365):
# zone_vpn masquerades, so fw4 assigns it no helper automatically, and passive
# FTP fails unless a rule assigns the ftp helper to what comes from the VPS.
# 1980-omr-firewall adds that rule, only where nf_conntrack_ftp is loaded (a
# rule naming a helper fw4 doesn't declare would make nft reject the whole
# ruleset), and leaves it alone once there.
#
# Runs against the router's own uci and BusyBox (from an OpenWrt build root),
# skipped when none is found.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/testlib.sh"

UCI_DEFAULTS_1980="$(cd "$SCRIPT_DIR/../files/etc/uci-defaults" 2>/dev/null && pwd)/1980-omr-firewall"
OMR_TARGET_ROOT="${OMR_TARGET_ROOT:-/mnt/data/download/openmtcprouter/test/build_test/omr-latest/x86_64/6.18/source/build_dir/target-x86_64_musl/root-x86}"

_t028_have_target() {
    [ -x "$OMR_TARGET_ROOT/sbin/uci" ] && [ -x "$OMR_TARGET_ROOT/bin/busybox" ] &&
        [ -e "$OMR_TARGET_ROOT/lib/ld-musl-x86_64.so.1" ]
}

# $1: yes if nf_conntrack_ftp is loaded
_t028_setup() {
    T28=$(mktemp -d /tmp/omr_t028_XXXXXX)
    mkdir -p "$T28/config" "$T28/state" "$T28/bin" "$T28/sys/module"
    [ "$1" = yes ] && mkdir -p "$T28/sys/module/nf_conntrack_ftp"
    local ld="$OMR_TARGET_ROOT/lib/ld-musl-x86_64.so.1 --library-path $OMR_TARGET_ROOT/lib:$OMR_TARGET_ROOT/usr/lib"
    printf '#!/bin/sh\nexec %s %s -c %s -t %s "$@"\n' "$ld" "$OMR_TARGET_ROOT/sbin/uci" "$T28/config" "$T28/state" > "$T28/bin/uci"
    printf '#!/bin/sh\nexec %s %s "$@"\n' "$ld" "$OMR_TARGET_ROOT/bin/busybox" > "$T28/bin/busybox"
    printf '#!/bin/sh\n:\n' > "$T28/bin/lsmod"
    printf '#!/bin/sh\n:\n' > "$T28/bin/rmmod"
    chmod +x "$T28/bin/"*
    sed -e "s|/usr/share/ucode/fw4.uc|$T28/fw4.uc|" -e "s|/tmp/luci-indexcache|$T28/luci-indexcache|" \
        -e "s|/sys/module/|$T28/sys/module/|g" \
        "$UCI_DEFAULTS_1980" > "$T28/1980"
    touch "$T28/fw4.uc" "$T28/config/network"
    printf 'config defaults\n' > "$T28/config/firewall"
}

_t028_run() {
    PATH="$T28/bin:$PATH" "$T28/bin/busybox" ash "$T28/1980" >/dev/null 2>&1
}

_t028_uci() { PATH="$T28/bin:$PATH" uci -q "$@"; }

test_028_ftp_helper_assigned_from_vpn() {
    _t028_have_target || { skip_test "no OpenWrt build root at $OMR_TARGET_ROOT"; return; }
    _t028_setup yes
    _t028_run
    assert_eq "the rule is made" "rule" "$(_t028_uci get firewall.ftphelpervpn)"
    assert_eq "from the vpn zone" "vpn" "$(_t028_uci get firewall.ftphelpervpn.src)"
    assert_eq "for tcp" "tcp" "$(_t028_uci get firewall.ftphelpervpn.proto)"
    assert_eq "to port 21" "21" "$(_t028_uci get firewall.ftphelpervpn.dest_port)"
    assert_eq "assigning a helper" "HELPER" "$(_t028_uci get firewall.ftphelpervpn.target)"
    assert_eq "the ftp helper" "ftp" "$(_t028_uci get firewall.ftphelpervpn.set_helper)"
    rm -rf "$T28"
}

test_028_ftp_helper_kept_as_the_user_left_it() {
    _t028_have_target || { skip_test "no OpenWrt build root at $OMR_TARGET_ROOT"; return; }
    _t028_setup yes
    _t028_run
    _t028_uci set firewall.ftphelpervpn.enabled='0'
    _t028_uci commit firewall
    _t028_run
    assert_eq "an upgrade keeps it disabled" "0" "$(_t028_uci get firewall.ftphelpervpn.enabled)"
    assert_eq "and doesn't add another" "1" "$(_t028_uci show firewall | grep -c "set_helper='ftp'")"
    rm -rf "$T28"
}

test_028_no_ftp_helper_without_the_module() {
    _t028_have_target || { skip_test "no OpenWrt build root at $OMR_TARGET_ROOT"; return; }
    _t028_setup no
    _t028_run
    assert_eq "no rule naming a helper fw4 won't declare" "" "$(_t028_uci get firewall.ftphelpervpn)"
    rm -rf "$T28"
}

run_test test_028_ftp_helper_assigned_from_vpn
run_test test_028_ftp_helper_kept_as_the_user_left_it
run_test test_028_no_ftp_helper_without_the_module
