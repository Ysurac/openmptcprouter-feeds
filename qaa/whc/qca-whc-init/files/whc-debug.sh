if [ -n "${SERVICE_DEBUG_OUTPUT}" ]; then
	[ "${SERVICE_DEBUG_OUTPUT}" -eq 1 ] && export SVCDBG="debug_"
fi
 
debug_service_start() {
        local serv="`echo $1 | awk -F'/' '{print $NF}'`"

        "$@" >/dev/console 2>/dev/console &
        echo `ps | grep $1 | grep -v grep | awk '{print \$1}'`> /var/run/${serv}.pid
}

debug_service_stop() {
        local serv="`echo $1 | awk -F'/' '{print $NF}'`"
        local serv_pid="`ps | grep $1 | grep -v grep | awk '{print \$1}'`"

        [ -z "$serv_pid" ] || kill $serv_pid
        rm -f /var/run/${serv}.pid
}

whc_debug() {
	if [ -n "$WHC_DEBUG_OUTPUT" ]; then
		if [ "$WHC_DEBUG_OUTPUT" -gt 0 ]; then
				echo "${1}: ""$2"> /dev/console
		fi
	fi
}

whc_echo() {
	echo "${1}: ""$2"> /dev/console
}

whc_error() {
	echo "${1}: ERROR: ""$2"> /dev/console
}

__CONFIG_LOCK_SUFFIX='-wifi-config'

# Protect against simultaneous changes to the Wi-Fi configuration (via WHC
# components) by grabbing this lock.
whc_wifi_config_lock() {
    __whc_lock $__CONFIG_LOCK_SUFFIX
}

# Release the lock used to protect against simultaneous changes to Wi-Fi
# configuration by WHC components.
whc_wifi_config_unlock() {
    __whc_unlock $__CONFIG_LOCK_SUFFIX
}

__whc_trap_cb() {
	whc_error $0 "unexpected termination"
}

# whc_lock
# input: $1: (optional) lock suffix, $2: (optional) trap callback
__whc_lock() {
	local trap_cb="$2"

	local lock=/var/run/whc${1}.lock
	lock $lock
	[ -z "$trap_cb" ] && trap_cb=__whc_trap_cb
	trap $trap_cb INT TERM ABRT QUIT ALRM
}

# whc_unlock
# input: $1: (optional) lock suffix
__whc_unlock() {
	local lock=/var/run/whc${1}.lock

	trap - INT TERM ABRT QUIT ALRM
	lock -u $lock
}
