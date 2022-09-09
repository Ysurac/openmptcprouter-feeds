#
#Copyright (c) 2016 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
. /lib/functions.sh
. /lib/functions/service.sh

SERVICE_NAME=lowi-server
SERVICE_MATCH_EXEC=1
SERVICE_DAEMONIZE=1

lowi_setup() {
	# We don't use service_start here because we want to redirect the output
	# to syslog. However, we start it in such a way that service_stop can
	# find it when we want to shut it down.
	/usr/sbin/lowi-server | logger -t lowi &
}

lowi_teardown() {
	service_stop /usr/sbin/lowi-server
}
