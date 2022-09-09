#
# Copyright (c) 2014 Qualcomm Atheros, Inc
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#
. /lib/functions.sh
. /lib/functions/service.sh

SERVICE_NAME=wpc
SERVICE_MATCH_EXEC=1
SERVICE_DAEMONIZE=1

wpc_setup() {
	# We don't use service_start here because we want to redirect the output
	# to syslog. However, we start it in such a way that service_stop can
	# find it when we want to shut it down.
	/usr/sbin/wpc -d -f | logger -t wpc &
}

wpc_teardown() {
	service_stop /usr/sbin/wpc
}
