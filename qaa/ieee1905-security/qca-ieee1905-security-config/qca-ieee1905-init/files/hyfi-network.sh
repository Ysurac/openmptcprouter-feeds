hyfi_network_sync() {
        lock -w /var/run/hyfi_network.lock
}

hyfi_network_restart() {
	trap __hyfi_trap_cb INT ABRT QUIT ALRM

	lock /var/run/hyfi_network.lock
	hyfi_echo "hyfi network" "process $0 ($$) requested network restart"
	/etc/init.d/network restart

	local radios=`uci show wireless | grep ".disabled=" | grep -v "@" | wc -l`
	local vaps=`uci show wireless | grep "].disabled=0" | wc -l`
	if [ $vaps -gt $radios ]; then
		# Workaround for Wi-Fi, needs a clean environment
		env -i /sbin/wifi
	fi

	lock -u /var/run/hyfi_network.lock

	trap - INT ABRT QUIT ALRM
}
