#!/bin/sh

alldata=$(ubus call openmptcprouter status)
labels=$(echo $alldata | jsonfilter -e '@.wans[@.multipath!="off"].label')
for wan in $labels; do
	wandata=$(echo $alldata | jsonfilter -e "@.wans[@.label=\"${wan}\"]")
	status=$(echo $wandata | jsonfilter -e '@.status')
	signal=$(echo $wandata | jsonfilter -e '@.signal')
	echo -n "$wan $status "
	if [ "$signal" != "" ]; then
		if [ "$signal" -eq "0" ]; then
			echo -n "0/4"
		elif [ "$signal" -lt "25" ]; then
			echo -n "1/4"
		elif [ "$signal" -lt "50" ]; then
			echo -n "2/4"
		elif [ "$signal" -lt "75" ]; then
			echo -n "3/4"
		else
			echo -n "4/4"
		fi
	else
		echo -n "$(echo $wandata | jsonfilter -e '@.state')"
	fi
	echo
done