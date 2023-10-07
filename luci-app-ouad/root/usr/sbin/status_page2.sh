#!/bin/sh

echo "router: $(uci -q get openmptcprouter.settings.version)"
echo "server: $(uci -q get openmptcprouter.vps.omr_version)"
echo "uptime: $(uptime | awk -F, '{sub(".*up ",x,$1);print $1,$2}' | sed 's/  */ /g')"
echo "temp: $(awk '{printf("%.1f°C",$1/1e3)}' /sys/class/thermal/thermal_zone0/temp)"