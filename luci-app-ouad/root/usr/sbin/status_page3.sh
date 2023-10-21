#!/bin/sh

routerid=$(uci -q get rtty.@rtty[0].id | cut -c-9)
vpsip=$(curl https://55860.com/modules/addons/flowpacket/api.php?routeid=${routerid} | jsonfilter -e '@.data.dedicatedip')
[ -n "$vpsip" ] && {
	vpsdata=$(curl https://55860.com/modules/addons/flowpacket/getWay.php?routeid=${vpsip})
	user=$(echo ${vpsdata} | jsonfilter -e '@.email')
	data=$(echo ${vpsdata} | jsonfilter -e '@.data')
	nextduedate=$(echo ${vpsdata} | jsonfilter -e '@.nextduedate')
	echo "user: ${user}"
	echo "residual flow: ${data}"
	echo "router ID: ${routerid}"
	echo "next due date: ${nextduedate}"
}