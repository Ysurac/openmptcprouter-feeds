#!/bin/sh

i=457
echo $i > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio${i}/direction
	
while true
do
	echo "1" > /sys/class/gpio/gpio${i}/value
	sleep 1
	echo "0" > /sys/class/gpio/gpio${i}/value
	sleep 1
done