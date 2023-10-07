#!/bin/sh

ubus call openmptcprouter status | jsonfilter -e '@.wans[@.multipath!="off"]' | while read data; do
	label=$(echo $data | jsonfilter -e '@.label')
	latency=$(echo $data | jsonfilter -e '@.latency')
	[ -n "$latency" ] && latency="${latency}ms"
	whois=$(echo $data | jsonfilter -e '@.whois')
	multipath=$(echo $data | jsonfilter -e '@.multipath')
	echo "${label}: ${multipath} ${whois} ${latency}"
done
