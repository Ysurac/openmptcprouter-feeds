#!/bin/sh

#i=457
#echo $i > /sys/class/gpio/export
#echo "out" > /sys/class/gpio/gpio${i}/direction
	
while true
do
	#echo "1" > /sys/class/gpio/gpio${i}/value
	gpioset `gpiofind "watchdog"`=1
	sleep 1
	#echo "0" > /sys/class/gpio/gpio${i}/value
	gpioset `gpiofind "watchdog"`=0
	sleep 1
done