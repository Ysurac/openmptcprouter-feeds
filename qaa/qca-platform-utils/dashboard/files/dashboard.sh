: '
/*
 * Copyright (c) 2019 Qualcomm Technologies, Inc.
 *
 * All Rights Reserved.
 * Confidential and Proprietary - Qualcomm Technologies, Inc.
 */

'
#!/bin/ash

trap tearDown EXIT INT TERM
VERSION=0.1.0
#Add warnings
WARNINGS=""
#For memoization
PREV_OUTPUT=""
#IFACES
LAN=""
WAN=""
#TZ state
TZ_ENABLED="no"
#teardown variable
TEARDOWN=true
#Data for the Commands to be used
LINUX_VERSION="/proc/version"
MODEL="/tmp/sysinfo/model"
CPU_CORES="/proc/cpuinfo"
CMDLINE="/proc/cmdline"
INIT="/sbin/init"
DEVICETREE_PATH="/sys/firmware/devicetree/base/"
BOOT_VERSION=${DEVICETREE_PATH}"boot_version"
TZ_VERSION=${DEVICETREE_PATH}"tz_version"
RPM_VERSION=${DEVICETREE_PATH}"rpm_version"
SOC_VERSION_MAJOR=${DEVICETREE_PATH}"soc_version_major"
SOC_VERSION_MINOR=${DEVICETREE_PATH}"soc_version_minor"
WCSS="/lib/firmware/IPQ8074/WIFI_FW/fw_version.txt"
CPUCORES_FILE=".tmpcpucores"
CPUCORES=''
CPU_SCALING="/sys/devices/system/cpu/"
NSS_SCALING="/proc/sys/dev/nss/clock/"
MEMINFO="/proc/meminfo"
IOMEM="/proc/iomem"
NW_STATE="/tmp/state/network"
IPC_ROUTER="/sys/kernel/debug/msm_ipc_router/"
TZ_LOG="/sys/kernel/debug/qcom_debug_logs/tz_log"
PACKAGE_CMD="opkg list"
MODULE_CMD="lsmod"
Q6_NODE_ID="0x00000007"
QMI_SERVICE_ID1="0x00000045"
QMI_SERVICE_ID2="0x0000041e"
DIAG_SERVICE_ID="0x00001001"
CRASHMAGIC_ADDR="0x193d100"
JTAG_ID_ADDR="0xa607c"
Q6_WDOG_STATE="0xcd82004"
Q6_WDOG_BARK="0xcd8200c"
Q6_WDOG_BITE="0xcd82014"
Q6_WDOG_NMI="0xcd82010"

usage() {
	cat  << EOM
	Usage:
	$(basename $0) OPTION

EOM
	exit 0
}

help() {
	cat << EOM
	Usage:
	$(basename $0) OPTION
	Show sytem information
		-s	start system test
			(Run all tests excluding Module info and Package info)
		-h	display this help and exit
		-m	show modules loaded
		-p	show packages installed
		-v	output version information and exit
EOM
	exit 0
}

parse_arguments() {
	while getopts "shmpv" opt;
	do
		case $opt in
			s)
				startTest
			;;
			h)
				TEARDOWN=''
				help
			;;
			m)
				getModuleInfo
			;;
			p)
				getPackageInfo
			;;
			v)
				TEARDOWN=''
				printf "Version: "$VERSION"\n"
				exit 0
			;;
			*)
				TEARDOWN=''
				usage
			;;
		esac
	done
	if [ "$OPTIND" = "1" ]; then
		TEARDOWN=''
		cat << EOM
	$(basename $0) requires an option to process
	Try -h for more information
EOM
	exit 0
	fi
}

print_header() {
	local title="$1"
	local hyphen=''
	for i in $(seq 1 ${#title})
	do
		local hyphen=$hyphen"-"
	done
	echo ""
	printf "%s\n" "$title"
	printf "%s\n" "$hyphen"
}

printOutput() {
	local var="$1"
	local val="$2"
	local redundant="$3"
	if [ "${val}" = "${PREV_OUTPUT}" -a -z "${redundant}" ]; then
		return
	fi
	eval PREV_OUTPUT="\$val"
	printf "%s\t%s" "${var}" "${val}" > .tmpprop
	awk -vRS="\n" -vORS="," '1' .tmpprop > .tmpprops
	awk -F '\t' '{ printf "%-36s ==>  %s\n", $1, $2 }' .tmpprops
}

runCmdFile() {
	local heading="$1"
	local cmd_str="$2"
	local cmd_path="$3"
	local process_str="$4"
	out=""
	if [ -e "${cmd_path}" ]; then
		out=$(eval "${cmd_str}" "${cmd_path}" "${process_str}")
		if [ "${heading}" = "CPU Cores Online" ]; then
			echo "${out}" > "${CPUCORES_FILE}"
		elif [ "${heading}" = "Lan Interface" ]; then
			LAN=${out}
		elif [ "${heading}" = "Wan Interface" ]; then
			WAN=${out}
		elif [ "${heading}" = "SMMU Status" -o "${heading}" = "XPU Status" ]; then
			if [ "${TZ_ENABLED}" = "no" -a -n "${out}" ]; then
				TZ_ENABLED="yes"
			fi
			if [ "${TZ_ENABLED}" = "no" ]; then
				printOutput "${heading}" "DISABLED"
				return
			fi

		fi
	else
		WARNINGS=$WARNINGS"No entry found for "$heading"\n"
		return
	fi
	printOutput "${heading}" "${out}"
}
runCmd() {
	local heading="$1"
	local cmd_str="$2"
	local cmd_arg="$3"
	out=$(eval "${cmd_str}" "${cmd_arg}")
	if [ -z "${out}" ]; then
		WARNINGS=$WARNINGS"No output found for "$heading"\n"
		return
	fi
	printOutput "${heading}" "${out}"
}
getIpqString(){
	IPQ_STRING=$(eval "grep -o IPQ[0-9][0-9]" "${MODEL}")
}
getArchitecture() {
	ARCH=$(eval "file" "${INIT}" "| grep -o [0-9][0-9]-bit")
}
getWcssPath() {
	getIpqString
	getArchitecture
	local arch=''
	if [ "${ARCH}" = "64-bit" ]; then
		arch='64'
	fi
	if [ -z ${IPQ_STRING} ]; then
		WARNINGS=$WARNINGS"No output found for IPQ string\n"
		return
	fi
	WCSS="/lib${arch}/firmware/${IPQ_STRING}*/WIFI_FW/fw_version.txt"
}
getPackageInfo() {
	out=$(eval "${PACKAGE_CMD}" "| awk '{ printf \"%-36s ==> \t%s\n\", \$1, \$3}'")
	if [ -z "${out}" ]; then
                WARNINGS=$WARNINGS"No output found for package info\n"
                return
        fi
	print_header "Packages Installed"
	printf "${out}\n"
}
getModuleInfo() {
	out=$(eval "${MODULE_CMD}" "| awk '{ printf \"%-28s ==>  %-8s ==> %s\n\", \$1, \$2, \$3 }'")
	if [ -z "${out}" ]; then
                WARNINGS=$WARNINGS"No output found for modules info\n"
                return
        fi
        print_header "Modules loaded"
        printf "${out}\n"
}
getSocVersion() {
	local major_path="$1"
	local minor_path="$2"
	local cmd_str="hexdump -Cv"
	local awk_str="| awk '{ print \$2 }'"
	if [ -e "${major_path}" ]; then
		out=$(eval "${cmd_str}" "${major_path}" "${awk_str}")
		local major="${out:1:1}"
	else
		WARNINGS=$WARNINGS"No entry found for SOC major version\n"
	fi
	if [ -e "${minor_path}" ]; then
		out=$(eval "${cmd_str}" "${minor_path}" "${awk_str}")
		local minor="${out:1:1}"
        else
		WARNINGS=$WARNINGS"No entry found for SOC minor version\n"
		return
	fi
	SOC_VERSION="${major}"".""${minor}"
	printOutput "SOC Version" ${SOC_VERSION}
}
getCpuScaling() {
	if [ -e "${CPUCORES_FILE}" ]; then
                CPUCORES=$(awk -vRS="\n" -vORS=" " '1' "${CPUCORES_FILE}")
        fi
        if [ -n "$CPUCORES" ]; then
                for c in ${CPUCORES}
                do
                        runCmd "CPU Scaling Governor: ${c}" "cat" "${CPU_SCALING}cpu${c}/cpufreq/scaling_governor"
                done
                for c in ${CPUCORES}
                do
                        runCmd "CPU Current Frequency: ${c}" "cat" "${CPU_SCALING}cpu${c}/cpufreq/scaling_cur_freq"
                done
                for c in ${CPUCORES}
                do
                        runCmd "CPU Available frequencies: ${c}" "cat" "${CPU_SCALING}cpu${c}/cpufreq/scaling_available_frequencies"
                done
        fi
}
getNssScaling() {
	if [ ! -e "${NSS_SCALING}current_freq" ]; then
		WARNINGS=$WARNINGS"No entry found for NSS current frequency\n"
	fi
	if [ ! -e "${NSS_SCALING}freq_table" ]; then
		WARNINGS=$WARNINGS"No entry found for NSS frequency table\n"
		return
	fi
	eval "cat" "${NSS_SCALING}current_freq"
	eval "cat" "${NSS_SCALING}freq_table"
        runCmd "NSS Current frequency" "dmesg" "| grep 'Frequency Set to' | awk END'{print \$NF}'"
	runCmd "NSS Available frequencies" "dmesg" "| grep 'Frequency Supported' | awk END'{print}' | cut -d'-' -f2"
}
getCpuUtilization() {
	printf "Getting CPU utilization...\n"
	eval "sar -P ALL 5 1" "| grep 'Average:' | awk 'NR>1 {print \$2, \$5, \$8}' > .tmpcpuutil"
	while IFS= read line
	do
		tit=$(eval "echo ${line}" "| awk '{print \$1}'")
		use=$(eval "echo ${line}" "| awk '{print \$2}'")
		idl=$(eval "echo ${line}" "| awk '{print \$3}'")
		printOutput "CPU Utilization: ${tit}" "Used: ${use}% Idle: ${idl}%" "True"
	done < '.tmpcpuutil'
}
getReservedMem() {
	if [ ! -e "${IOMEM}" ]; then
		WARNINGS=$WARNINGS"No entry found for IO mem\n"
                return
        fi
	eval "grep 'System RAM'" "${IOMEM}" "| cut -d':' -f1" > .tmpprop
	local start=$(eval "awk -F '-' 'NR==1 {print \$2}' .tmpprop")
	local end=$(eval "awk -F '-' 'NR==2 {print \$1}' .tmpprop")
	start="0x"${start}
	start=$(printf "0x%X" $((${start} + 1)))
	end="0x"${end}
	local reserved=$(printf "%X" $((${end} - ${start})))
	printOutput "Reserved Memory: " "Start ${start}; End ${end}; Size 0x${reserved}"
}
getMmcInfo(){
	print_header "SD/eMMC details"
	for i in 0 1
	do
		local out=$(eval "dmesg" "| grep \"mmc${i}:.* at address\" | cut -d']' -f2-")
		local cap_str=$(eval "echo ${out}" "| awk '{ print \$1 \$NF }'")
		local cap=$(eval "dmesg" "| grep \"${cap_str}.*\" | awk 'NR==1 { print \$(NF-1) \$NF}'")
		if [ -n "${out}" -a -n "${cap}" ]; then
			printOutput "Type" "${out}"
			printOutput "Capacity" "$cap"
		fi
	done
}
getQmiDiagInfo() {
	local status=''
	local qmi_services=''
	local diag_service=''
	status=$(eval "cat" "${IPC_ROUTER}dump_xprt_info" "| awk -F '|' '{ if(\$4==${Q6_NODE_ID}) print \$3}'")
	if [ -z "${status}" ]; then
		WARNINGS=$WARNINGS"No status found for Q6-Node ID ${Q6_NODE_ID}\n"
		return
	fi
	printOutput "Q6 Status" "${status}"
	out=$(eval "cat" "${IPC_ROUTER}dump_servers" "| awk -F '|' '{ if(\$3==${Q6_NODE_ID}) print \$1 }' | tr '\n' ' '")
	for val in ${out}
	do
		if [ "${val}" = "${QMI_SERVICE_ID1}" -o "${val}" = "${QMI_SERVICE_ID2}" ]; then
			qmi_services=$qmi_services" "${val}
		elif [ "${val}" = "${DIAG_SERVICE_ID}" ]; then
			diag_service=$diag_service" "${val}
		fi
	done
	if [ -n "${qmi_services}" ]; then
		printOutput "QMI Service status" "UP (${qmi_services})"
	else
		printOutput "QMI Service status" "Disabled (${qmi_services})"
	fi
	if [ -n "${diag_service}" ]; then
		printOutput "Diag Service status" "UP (${diag_service})"
	else
		printOutput "Diag Service status" "Disabled (${diag_service})"
	fi
}
getWarnings() {
	print_header "WARNINGS"
	count=$(echo "${WARNINGS}" | grep -o 'No.*found' | wc -l)
	[ -z "${WARNINGS}" ] && printf "Warnings: 0\n" || printf "Warnings: ${count}""\n${WARNINGS}"
	echo ""
}
tearDown() {
	if [ -z "${TEARDOWN}" ]; then
		return
	fi
	echo ""
	echo "Running teardown..."
	getWarnings
	eval "rm" "-rf" ".tmp*"
	echo "Teardown completed"
}
startTest() {
	print_header "HW Info"
	runCmdFile "Board Model" "cat" "${MODEL}"
	getSocVersion "${SOC_VERSION_MAJOR}" "${SOC_VERSION_MINOR}"
	print_header "NAND flash details"
	runCmd "NAND Part No." "dmesg | grep 'nand: ONFI' | cut -d: -f2-"
	runCmd "NAND configuration" "dmesg | grep 'nand: [0-9]' | cut -d: -f2-"
	getMmcInfo
	print_header "SW Info"
	runCmdFile "Kernel Version" "cat" "${LINUX_VERSION}"
	runCmdFile "Boot Version" "cat" "${BOOT_VERSION}"
	runCmdFile "Tz Version" "cat" "${TZ_VERSION}"
	runCmdFile "RPM version" "cat" "${RPM_VERSION}"
	runCmdFile "NHSS Version" "sed -e 's/[^0-9. ]*//g' -e  's/ \+/ /g'" "${LINUX_VERSION}" " | awk '{ print \$5}'"
	getWcssPath
	runCmd "WCSS Version" "cat" "${WCSS}"
	print_header "CPU Cores Info"
	runCmdFile "CPU Cores Online" "awk '{ if(\$1==\"processor\")print \$3 }'" "${CPU_CORES}"
	getCpuScaling
	print_header "NSS Info"
	getNssScaling
	print_header "CPU Utilization stats"
	getCpuUtilization
	print_header "Memory Info"
	runCmdFile "Total Memory" "awk 'FNR==1 { print \$2, \$3 }'" "${MEMINFO}"
	runCmdFile "Free Memory" "awk 'FNR==2 { print \$2, \$3 }'" "${MEMINFO}"
	runCmdFile "Available Memory" "awk 'FNR==3 { print \$2, \$3 }'" "${MEMINFO}"
	getReservedMem
	print_header "APSS Watchdog Info"
	runCmd "APSS Wdog status" "ubus call system watchdog" "| grep 'status' | cut -d":" -f2"
	runCmd "APSS Wdog timeout" "ubus call system watchdog" "| grep 'timeout' | cut -d":" -f2"
	print_header "Interface details"
	runCmdFile "Lan Interface" "awk -F'=' '{ if(\$1==\"network.lan.ifname\") print \$2 }'" "${NW_STATE}"
	runCmd "Lan device IP" "ip addr show ${LAN} | grep 'inet\\b' | awk '{print \$2}' | cut -d/ -f1"
	runCmd "Lan device MAC" "ip addr show ${LAN} | grep 'link/ether\\b' | awk '{print \$2}'"
	echo "--------"
	runCmdFile "Wan Interface" "awk -F'=' '{ if(\$1==\"network.wan.device\") print \$2 }'" "${NW_STATE}"
	runCmd "Wan device IP" "ip addr show ${WAN} | grep 'inet\\b' | awk '{print \$2}' | cut -d/ -f1"
	runCmd "Wan device MAC" "ip addr show ${WAN} | grep 'link/ether\\b' | awk '{print \$2}'"
	print_header "TZ Info"
	runCmdFile "SMMU Status" "cat" "${TZ_LOG}" " | grep -i SMMU | awk -F'\r' '{ print \$1 }'"
	runCmdFile "XPU Status" "cat" "${TZ_LOG}" " | grep -i XPU | awk -F'\r' '{ print \$1 }'"
	print_header "Q6 Info"
	if [ "${TZ_ENABLED}" = "no" ]; then
		runCmd "Q6 Wdog Status" "devmem" "${Q6_WDOG_STATE}"
		runCmd "Q6 Wdog bark timer" "devmem" "${Q6_WDOG_BARK}"
		runCmd "Q6 Wdog bite timer" "devmem" "${Q6_WDOG_BITE}"
		runCmd "Q6 Wdog NMI timer" "devmem" "${Q6_WDOG_NMI}"
	fi
	getQmiDiagInfo
	print_header "OTHERS"
	runCmd "JTAG ID" "devmem" "${JTAG_ID_ADDR}"
	runCmdFile "Kernel Command line" "cat" "${CMDLINE}"
	runCmd "Crash magic" "devmem" "${CRASHMAGIC_ADDR}"
	runCmd "tmpfs Size" "df -h" " | grep tmpfs | awk '{ if(\$6==\"/tmp\") printf \"%-12s %-8s %-8s %-8s %-3s %s\", \$1, \$2, \$3, \$4, \$5, \$6 }'"
	runCmd "Overlay Size" "df -h" " | grep /dev/ubi.* | awk '{ if(\$6==\"/overlay\") printf \"%-12s %-8s %-8s %-8s %-3s %s\", \$1, \$2, \$3, \$4, \$5, \$6 }'"
}

parse_arguments $@
