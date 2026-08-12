#!/bin/sh
# Report whether a package is installed, trying apk then falling back to opkg.
# Usage: detect-pkg.sh <package-name>
#
# Split out of a "/bin/sh -c '[ -x /usr/bin/apk ] && ... || ...'" one-liner in
# wizard.js so the rpcd ACL can grant exec on this fixed script path instead
# of on /bin/sh itself (rpcd's file-exec ACL matches the full command line
# with fnmatch(FNM_NOESCAPE), so literal '[' ']' in a shell test can't be
# escaped there and effectively can't be scoped tightly inline).

pkg="$1"

if [ -x /usr/bin/apk ]; then
	if apk list 2>/dev/null | grep installed | grep -q "$pkg"; then
		echo -n 1
	else
		echo -n 0
	fi
else
	if opkg list-installed | grep -q "$pkg"; then
		echo -n 1
	else
		echo -n 0
	fi
fi
