#!/bin/ash
#
# Copyright (c) 2018 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.

. /lib/ipq806x.sh

#Initial Settings

gpio_pwd=21
gpio_edl=33
gpio_usb_mux=27

if [[ ! -e /sys/class/gpio/gpio$gpio_pwd ]]; then
    echo $gpio_pwd > /sys/class/gpio/export
    echo out > /sys/class/gpio/gpio$gpio_pwd/direction
fi

if [[ ! -e /sys/class/gpio/gpio$gpio_edl ]]; then
    echo $gpio_edl > /sys/class/gpio/export
    echo out > /sys/class/gpio/gpio$gpio_edl/direction
fi

if [[ ! -e /sys/class/gpio/gpio$gpio_usb_mux ]]; then
    echo $gpio_usb_mux > /sys/class/gpio/export
    echo out > /sys/class/gpio/gpio$gpio_usb_mux/direction
fi

Usage="Usage : $0 {flash/usb-select/edl} {on/off}"

if [ "$#" -ne 2 ]; then
    echo $Usage
    exit 1
fi

case "$1" in
    flash)
        if [ "$2" == "on" ]; then
            # Stop iotd
            /etc/init.d/qca-iot stop
            #Put Quartz in reset mode
            echo 0 > /sys/class/gpio/gpio$gpio_pwd/value
            #Put Quartz in EDL mode
            echo 1 > /sys/class/gpio/gpio$gpio_edl/value
            #USB mux select Quartz
            echo 0 > /sys/class/gpio/gpio$gpio_usb_mux/value
            #Reset out of Quartz
            echo 1 > /sys/class/gpio/gpio$gpio_pwd/value
        elif [ "$2" == "off" ]; then
            #Bring Quartz out of EDL
            echo 0 > /sys/class/gpio/gpio$gpio_edl/value
            #Reset Quartz
            echo 0 > /sys/class/gpio/gpio$gpio_pwd/value
            echo 1 > /sys/class/gpio/gpio$gpio_pwd/value
        else
            echo $Usage
        fi
        ;;

    usb-select)
        if [ "$2" == "on" ]; then
            #USB mux select Quartz
            echo 0 > /sys/class/gpio/gpio$gpio_usb_mux/value
        elif [ "$2" == "off" ]; then
            #USB mux select HK
            echo 1 > /sys/class/gpio/gpio$gpio_usb_mux/value
        else
            echo $Usage
        fi
        ;;

    edl)
        if [ "$2" == "on" ]; then
            #Put Quartz into EDL mode
            echo 1 > /sys/class/gpio/gpio$gpio_edl/value
        elif [ "$2" == "off" ]; then
            #Bring Quartz out of EDL mode
            echo 0 > /sys/class/gpio/gpio$gpio_edl/value
        else
            echo $Usage
        fi
        ;;

    *)
        echo $Usage
        exit 1
esac

