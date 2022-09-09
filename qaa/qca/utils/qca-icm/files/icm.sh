# Copyright (c) 2014, 2019 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# 2014 Qualcomm Atheros, Inc.
#
# All Rights Reserved.
# Qualcomm Atheros Confidential and Proprietary.
#

. /lib/functions.sh
. /lib/functions/service.sh

SERVICE_NAME=icm
SERVICE_MATCH_EXEC=1
SERVICE_DAEMONIZE=1

icm_setup() {
	ICM_ARGS=

	config_get mode icm mode
	case ${mode} in
		standalone) ;;
		server) append ICM_ARGS "-v";;
		"") logger -t icm "Using default icm mode: Standlone";;
		*) logger -t icm "icm mode (${mode}) not supported. Using standlone";;
	esac

	[ ${1} == "cfg80211" ] && append ICM_ARGS "-c cfg "

	config_get_bool seldebug icm seldebug 0
	[ "${seldebug}" -gt 0 ] && append ICM_ARGS "-i"

	config_get dbglvl icm dbglvl
	[ -n "${dbglevel}" ] && append ICM_ARGS "-q ${dbglevel}"

	config_get dbgmask icm dbgmask
	[ -n "${dbgmask}" ] && append ICM_ARGS "-u ${dbgmask}"

	config_get_bool enable11axunii3pref icm enable11axunii3pref
	[ -n "${enable11axunii3pref}" ] && append ICM_ARGS "-b ${enable11axunii3pref}"

	config_get reptxpowerpolicy icm reptxpowerpolicy
	[ -n "${reptxpowerpolicy}" ] && append ICM_ARGS "-r ${reptxpowerpolicy}"

	config_get rejpolicybitmask icm rejpolicybitmask
	[ -n "${rejpolicybitmask}" ] && append ICM_ARGS "-S ${rejpolicybitmask}"

	config_get_bool enablechangradeusage icm enablechangradeusage
	[ -n "${enablechangradeusage}" ] && append ICM_ARGS "-g ${enablechangradeusage}"

	config_get_bool enablespectralscan icm enablespectralscan
	[ -n "${enablespectralscan}" ] && append ICM_ARGS "-x ${enablespectralscan}"

	# We don't use service_start here because we want to redirect the output
	# to syslog. However, we start it in such a way that service_stop can
	# find it when we want to shut it down.
	/usr/sbin/icm ${ICM_ARGS} -f | logger -t icm &
}

icm_teardown() {
	service_stop /usr/sbin/icm
}
