#!/bin/sh

public_ip=$(uci -q get openmptcprouter.omr.detected_public_ipv4 | tr -d "\n")
if [ -n "$public_ip" ]; then
    echo "IP: ${public_ip}"
else
    echo "Waiting for server..."
fi