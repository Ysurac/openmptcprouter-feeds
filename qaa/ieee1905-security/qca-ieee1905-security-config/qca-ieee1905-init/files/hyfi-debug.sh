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

hyfi_debug() {
	if [ -n "$HYFI_DEBUG_OUTPUT" ]; then
		if [ "$HYFI_DEBUG_OUTPUT" -gt 0 ]; then
				echo "${1}: ""$2"> /dev/console
		fi
	fi
}

hyfi_echo() {
	echo "${1}: ""$2"> /dev/console
}

hyfi_error() {
	echo "${1}: ERROR: ""$2"> /dev/console
}

__LOCK=/var/run/`echo $0 | awk -F/ '{print $NF}'`${1}.lock

__hyfi_trap_cb() {
	hyfi_error $0 "unexpected termination"
}

# hyfi_lock
# input: $1: (optional) lock suffix, $2: (optional) trap callback
hyfi_lock() {
	local trap_cb="$2"

	__LOCK=/var/run/`echo $0 | awk -F/ '{print $NF}'`${1}.lock
	lock $__LOCK
	[ -z "$trap_cb" ] && trap_cb=__hyfi_trap_cb
	trap $trap_cb INT TERM ABRT QUIT ALRM
}

# hyfi_unlock
hyfi_unlock() {
	trap - INT TERM ABRT QUIT ALRM
	lock -u $__LOCK
}
