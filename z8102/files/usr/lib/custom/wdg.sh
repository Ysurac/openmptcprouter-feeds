#!/bin/sh

#i=457
#echo $i > /sys/class/gpio/export
#echo "out" > /sys/class/gpio/gpio${i}/direction
	
while true
do
	#echo "1" > /sys/class/gpio/gpio${i}/value
	gpioset `gpiofind "watchdog"`=1 2>&1 >/dev/null
	gpioset --hold-period 100ms -t0 watchdog=1 2>&1 >/dev/null
	sleep 1
	#echo "0" > /sys/class/gpio/gpio${i}/value
	gpioset `gpiofind "watchdog"`=0 2>&1 >/dev/null
	gpioset --hold-period 100ms -t0 watchdog=0 2>&1 >/dev/null
	sleep 1
done