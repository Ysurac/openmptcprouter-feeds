#!/bin/sh

###############################################################################
#
#      Script for reading switch ports' link status...
#      Usage: vhyfi.sh dev mgmtdev command [MAC] [PORTID]
#		command - 0: Read switch ports'	link status, output format: port:x link:down[/up]
#			  1: Read switch port id by sepcify MAC, output format: port:x
#			  2: Read switch port link speed, output format: [0/100/1000]
#
#	e.g. vhyfi.sh eth1 switch0 0
#		port:0 link:up
#		port:1 link:down
#		port:2 link:down
#		port:3 link:up
#		port:4 link:down
#	     vhyfi.sh eth1 switch0 1 00:03:7f:00:12:34
#		port:3
#	     vhyfi.sh eth1 switch0 2 1
#		100
###############################################################################

if [ -n "${1}" ]; then
	IFNAME=${1}
else
	exit 1
fi

if [ -n "${2}" ]; then
	MGMTIFNAME=${2}
else
	exit 1
fi

if [ -n "${3}" ]; then
        COMMAND=${3}
else
        exit 1
fi

print_port_id() {
	case $1 in
		0x01) echo "port:0";;
		0x02) echo "port:1";;
		0x04) echo "port:2";;
		0x08) echo "port:3";;
		0x10) echo "port:4";;
		0x20) echo "port:5";;
		0x40) echo "port:6";;
		0x80) echo "port:7";;
		*)    echo "port:";;
	esac
}

case $COMMAND in
	0)
		swconfig dev $MGMTIFNAME show |grep link |cut -f 2,3 -d " "
	;;
	1)
		if [ -n "${4}" ]; then
			MAC=${4}
		else
			exit 1
		fi

		swconfig dev $MGMTIFNAME set flush_arl
		plchost -i $IFNAME -r > /dev/null
		sleep 1
		PORTMAP=`swconfig dev $MGMTIFNAME get dump_arl |grep $MAC |cut -f 4 -d " "`

		print_port_id $PORTMAP
	;;
	2)
		Speed=`swconfig dev $MGMTIFNAME show |grep "port:$3" |cut -f 5 -d ":" |sed s/[a-z,A-Z,-]//g`
		[ -n "${Speed}" ] || Speed=0
		echo "${Speed}"
	;;
	*)
		echo "error: invalid command $COMMAND"
	;;
esac

# exit successfully
exit 0
