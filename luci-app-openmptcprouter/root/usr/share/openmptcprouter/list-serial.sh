#!/bin/sh
# List device nodes for a known modem device class.
# Usage: list-serial.sh <ttyUSB|cdc-wdm>
#
# Split out of "/bin/sh -c 'ls /dev/ttyUSB* ... || true'" one-liners in
# wizard.js: rpcd's file-exec ACL matches the full command line with
# fnmatch(FNM_NOESCAPE), so a literal '*' there is always a glob wildcard,
# never an escapable literal character - any ACL entry built from that
# one-liner would let extra shell text ride through the wildcard gap. A
# fixed script path with a plain literal argument avoids that entirely.

case "$1" in
	ttyUSB)
		ls /dev/ttyUSB* 2>/dev/null
		;;
	cdc-wdm)
		ls /dev/cdc-wdm* 2>/dev/null
		;;
esac
exit 0
