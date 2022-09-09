
: '
/*
 * Copyright (c) 2017 Qualcomm Technologies, Inc.
 *
 * All Rights Reserved.
 * Confidential and Proprietary - Qualcomm Technologies, Inc.
 */
'

#!/bin/ash
IO_MASK=$(( 0x00000200 ))
BIAS_STATUS_MASK=$(( 0x00000003 ))
FUNC_SEL_MASK=$(( 0x0000003c ))
DRV_STRENGTH_MASK=$(( 0x000001c0 ))
PU_RES_MASK=$((0x00006000 ))
VM_MASK=$(( 0x00000800 ))
OD_EN_MASK=$(( 0x00001000 ))
TLMM_GPIO_CFGn_Base_Address=$(( 0x01000000 ))
OFFSET_MULTIPLIER=$(( 0x00001000 ))
START_PIN=0
END_PIN=99
FUNCTION_SELECT_MAPPING=$(cat <<-END
0, jtag_tdi, smart0, i2s_rx_bclk, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
1, jtag_tck, smart0, i2s_rx_fsync, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
2, jtag_tms, smart0, i2s_rxd, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
3, jtag_tdo, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
4, jtag_rst, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
5, jtag_trst, smart0, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
6, mdio0, NA, wcss0_dbg18, wcss1_dbg18, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA, NA, NA
7, mdc, NA, wcss0_dbg19, wcss1_dbg19, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA, NA, NA
8, blsp_uart1, wifi0_uart, wifi1_uart, smart1, NA, wcss0_dbg20, wcss1_dbg20, NA, qdss_tracedata_a, NA, NA, NA, NA, NA
9, blsp_uart1, wifi0_uart0, wifi1_uart0, smart1, wifi0_uart, NA, wcss0_dbg21, wcss1_dbg21, NA, qdss_tracedata_a, NA, NA, NA, NA
10, blsp_uart1, wifi0_uart0, wifi1_uart0, blsp_i2c0, NA, wcss0_dbg22, wcss1_dbg22, NA, qdss_tracedata_a, NA, NA, NA, NA, NA
11, blsp_uart1, wifi0_uart, wifi1_uart, blsp_i2c0, NA, wcss0_dbg23, wcss1_dbg23, NA, qdss_tracedata_a, NA, NA, NA, NA, NA
12, blsp_spi0, blsp_i2c1, NA, wcss0_dbg24, wcss1_dbg24, NA, NA, NA, NA, NA, NA, NA, NA, NA
13, blsp_spi0, blsp_i2c1, NA, wcss0_dbg25, wcss1_dbg25, NA, NA, NA, NA, NA, NA, NA, NA, NA
14, blsp_spi0, NA, wcss0_dbg26, wcss1_dbg26, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
15, blsp_spi0, NA, wcss0_dbg, wcss1_dbg, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
16, blsp_uart0, led0, smart1, NA, wcss0_dbg28, wcss1_dbg28, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
17, blsp_uart0, led1, smart1, NA, wcss0_dbg29, wcss1_dbg29, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
18, wifi0_uart1, wifi1_uart1, NA, wcss0_dbg30, wcss1_dbg30, NA, NA, NA, NA, NA, NA, NA, NA, NA
19, wifi0_uart, wifi1_uart, NA, wcss0_dbg31, wcss1_dbg31, NA, NA, NA, NA, NA, NA, NA, NA, NA
20, blsp_i2c0, i2s_rx_mclk, NA, wcss0_dbg16, wcss1_dbg16, NA, NA, NA, NA, NA, NA, NA, NA, NA
21, blsp_i2c0, i2s_rx_bclk, NA, wcss0_dbg17, wcss1_dbg17, NA, NA, NA, NA, NA, NA, NA, NA, NA
22, rgmii0, i2s_rx_fsync, NA, wcss0_dbg18, wcss1_dbg18, NA, NA, NA, NA, NA, NA, NA, NA, NA
23, sdio0, rgmii1, i2s_rxd, NA, wcss0_dbg19, wcss1_dbg19, NA, NA, NA, NA, NA, NA, NA, NA
24, sdio1, rgmii2, i2s_tx_mclk, NA, wcss0_dbg20, wcss1_dbg20, NA, NA, NA, NA, NA, NA, NA, NA
25, sdio2, rgmii3, i2s_tx_bclk, NA, wcss0_dbg21, wcss1_dbg21, NA, NA, NA, NA, NA, NA, NA, NA
26, sdio3, rgmii_rx, i2s_tx_fsync, NA, wcss0_dbg22, wcss1_dbg22, NA, NA, NA, NA, NA, NA, NA, NA
27, sdio_clk, rgmii_txc, i2s_td1, NA, wcss0_dbg23, wcss1_dbg23, NA, NA, NA, NA, NA, NA, NA, NA
28, sdio_cmd, rgmii0, i2s_td2, NA, wcss0_dbg24, wcss1_dbg24, NA, NA, NA, NA, NA, NA, NA, NA
29, sdio4, rgmii1, i2s_td3, NA, wcss0_dbg25, wcss1_dbg25, NA, NA, NA, NA, NA, NA, NA, NA
30, sdio5, rgmii2, audio_pwm0, NA, wcss0_dbg26, wcss1_dbg26, NA, NA, NA, NA, NA, NA, NA, NA
31, sdio6, rgmii3, audio_pwm1, NA, wcss0_dbg27, wcss1_dbg27, NA, NA, NA, NA, NA, NA, NA, NA
32, sdio7, rgmii_rxc, audio_pwm2, NA, wcss0_dbg28, wcss1_dbg28, NA, NA, NA, NA, NA, NA, NA, NA
33, rgmii_tx, audio_pwm3, NA, wcss0_dbg29, wcss1_dbg29, NA, boot2, NA, NA, NA, NA, NA, NA, NA
34, blsp_i2c1, i2s_spdif_in, NA, wcss0_dbg30, wcss1_dbg30, NA, NA, NA, NA, NA, NA, NA, NA, NA
35, blsp_i2c1, i2s_spdif_out, NA, wcss0_dbg31, wcss1_dbg31, NA, NA, NA, NA, NA, NA, NA, NA, NA
36, rmii00, led2, led0, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
37, rmii01, wifi0_wci, wifi1_wci, led1, NA, NA, wcss0_dbg16, wcss1_dbg16, NA, qdss_tracedata_a, boot4, NA, NA, NA
38, rmii0_tx, led2, NA, NA, wcss0_dbg17, wcss1_dbg17, NA, qdss_tracedata_a, boot5, NA, NA, NA, NA, NA
39, rmii0_rx, pcie_clk1, led3, NA, NA, wcss0_dbg18, wcss1_dbg18, NA, NA, qdss_tracedata_a, NA, NA, NA, NA
40, rmii0_refclk, wifi0_rfsilient0, wifi1_rfsilient0, smart2, led4, NA, NA, wcss0_dbg19, wcss1_dbg19, NA, NA, qdss_tracedata_a, NA, NA
41, rmii00, wifi0_cal, wifi1_cal, smart2, NA, NA, wcss0_dbg20, wcss1_dbg20, NA, NA, qdss_tracedata_a, NA, NA, NA
42, rmii01, wifi_wci0, NA, NA, wcss0_dbg21, wcss1_dbg21, NA, NA, qdss_tracedata_a, NA, NA, NA, NA, NA
43, rmii0_dv, wifi_wci1, NA, NA, wcss0_dbg22, wcss1_dbg22, NA, NA, qdss_tracedata_a, NA, NA, NA, NA, NA
44, rmii1_refclk, blsp_spi1, smart0, led5, NA, NA, wcss0_dbg23, wcss1_dbg23, NA, NA, NA, NA, NA, NA
45, rmii10, blsp_spi1, blsp_spi0, smart0, led6, NA, NA, wcss0_dbg24, wcss1_dbg24, NA, NA, NA, NA, NA
46, rmii11, blsp_spi1, smart0, led7, NA, NA, wcss0_dbg25, wcss1_dbg25, NA, NA, NA, NA, NA, NA
47, rmii1_dv, blsp_spi1, smart0, led8, NA, NA, wcss0_dbg26, wcss1_dbg26, NA, NA, NA, NA, NA, NA
48, rmii1_tx, aud_pin, smart2, led9, NA, NA, wcss0_dbg27, wcss1_dbg27, NA, NA, NA, NA, NA, NA
49, rmii1_rx, aud_pin, smart2, led10, NA, NA, wcss0_dbg28, wcss1_dbg28, NA, NA, NA, NA, NA, NA
50, rmii10, aud_pin, wifi0_rfsilient1, wifi1_rfsilient1, led11, NA, NA, wcss0_dbg29, wcss1_dbg29, NA, NA, NA, NA, NA
51, rmii11, aud_pin, wifi0_cal, wifi1_cal, NA, NA, wcss0_dbg30, wcss1_dbg30, NA, boot7, NA, NA, NA, NA
52, qpic_pad, mdc, pcie_clk, i2s_tx_mclk, NA, NA, wcss0_dbg31, tm_clk0, wifi00, wifi10, NA, NA, NA, NA
53, qpic_pad, mdio1, i2s_tx_bclk, prng_rosc, dbg_out, tm0, wifi01, wifi11, NA, NA, NA, NA, NA, NA
54, qpic_pad, blsp_spi0, i2s_td1, atest_char3, pmu0, NA, NA, boot8, tm1, NA, NA, NA, NA, NA
55, qpic_pad, blsp_spi0, i2s_td2, atest_char2, pmu1, NA, NA, boot9, tm2, NA, NA, NA, NA, NA
56, qpic_pad, blsp_spi0, i2s_td3, atest_char1, NA, tm_ack, wifi03, wifi13, NA, NA, NA, NA, NA, NA
57, qpic_pad4, blsp_spi0, i2s_tx_fsync, atest_char0, NA, tm3, wifi02, wifi12, NA, NA, NA, NA, NA, NA
58, qpic_pad5, led2, blsp_i2c0, smart3, smart1, i2s_rx_mclk, NA, wcss0_dbg14, tm4, wifi04, wifi14, NA, NA, NA
59, qpic_pad6, blsp_i2c0, smart3, smart1, i2s_spdif_in, NA, NA, wcss0_dbg15, qdss_tracectl_a, boot18, tm5, NA, NA, NA
60, qpic_pad7, blsp_uart0, smart1, smart3, led0, i2s_tx_bclk, i2s_rx_bclk, atest_char, NA, wcss0_dbg4, qdss_traceclk_a, boot19, tm6, NA
61, qpic_pad, blsp_uart0, smart1, smart3, led1, i2s_tx_fsync, i2s_rx_fsync, NA, NA, wcss0_dbg5, qdss_cti_trig_out_a0, boot14, tm7, NA
62, qpic_pad, chip_rst, wifi0_uart, wifi1_uart, i2s_spdif_out, NA, NA, wcss0_dbg6, qdss_cti_trig_out_b0, boot11, tm8, NA, NA, NA
63, qpic_pad, wifi0_uart1, wifi1_uart1, wifi1_uart, i2s_td1, i2s_rxd, i2s_spdif_out, i2s_spdif_in, NA, wcss0_dbg7, wcss1_dbg7, boot20, tm9, NA
64, qpic_pad1, audio_pwm0, NA, wcss0_dbg8, wcss1_dbg8, NA, NA, NA, NA, NA, NA, NA, NA, NA
65, qpic_pad2, audio_pwm1, NA, wcss0_dbg9, wcss1_dbg9, NA, NA, NA, NA, NA, NA, NA, NA, NA
66, qpic_pad3, audio_pwm2, NA, wcss0_dbg10, wcss1_dbg10, NA, NA, NA, NA, NA, NA, NA, NA, NA
67, qpic_pad0, audio_pwm3, NA, wcss0_dbg11, wcss1_dbg11, NA, NA, NA, NA, NA, NA, NA, NA, NA
68, qpic_pad8, NA, wcss0_dbg12, wcss1_dbg12, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
69, qpic_pad, NA, wcss0_dbg, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
70, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
71, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
72, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
73, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
74, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
75, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
76, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
77, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
78, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
79, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
80, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
81, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
82, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
83, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
84, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
85, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
86, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
87, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
88, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
89, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
90, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
91, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
92, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
93, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
94, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
95, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
96, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
97, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
98, wifi034, wifi134, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
99, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
END
)
OD_EN_VALID_ARRAY=$(cat <<-END
6, 7, 10, 11, 12, 13, 15, 20, 21, 34, 35, 39, 40, 50, 52, 53, 58, 59
END
)

FUNCTION_SEL()
{
 pin=$1
 pin=$( expr "$pin" + "1" )
 func_col=$2
 func_col=$( expr "$func_col" + "1" )
 FUNCTION_SEL_VALUE=`echo "$FUNCTION_SELECT_MAPPING" | sed -n "$pin"p`
 func_value=`echo "$FUNCTION_SEL_VALUE" | cut -d, -f$func_col`
 printf "\t"
 printf "  $2 -$func_value"
}

GPIO_DUMP()
{
 printf $1
 PIN_OFFSET=$( expr "$OFFSET_MULTIPLIER" \* "$1" )
 STATUS_REGISTER_ADDRESS=$( expr "$TLMM_GPIO_CFGn_Base_Address" + "$PIN_OFFSET" )
 printf "\t"
 printf '0x%08x' $STATUS_REGISTER_ADDRESS
 STATUS_MUX=$( devmem $STATUS_REGISTER_ADDRESS )
 printf "\t\t"
 printf $STATUS_MUX
 BIAS_STATUS=$(( $STATUS_MUX & $BIAS_STATUS_MASK ))
 if [ "$BIAS_STATUS" == "0" ]
 then
        printf "\tNO PULL   "
 elif [ "$BIAS_STATUS" == "1" ]
 then
        printf "\tPULL DOWN "
 elif [ "$BIAS_STATUS" == "2" ]
 then
        printf "\tPULL UP   "
 elif [ "$BIAS_STATUS" == "3" ]
 then
        printf "\tUNSUPPORT "
 else
        printf "CANNOT BE DETERMINED"
 fi
 FUNC_SEL=$(( $STATUS_MUX & $FUNC_SEL_MASK ))
 FUNC_SEL=$(( $FUNC_SEL >> 2 ))
 if [ "$FUNC_SEL" == "0" ]
 then
        IO_STATUS=$(( $STATUS_MUX & $IO_MASK ))
        IO_STATUS=$(( $IO_STATUS >> 9 ))
        if [ "$IO_STATUS" == "0" ]
        then
                printf "\tIP"
        else
                printf "\tOP"
        fi
 else
        printf "\tNA"
 fi
 DRV_STRENGTH=$(( $STATUS_MUX & $DRV_STRENGTH_MASK ))
 DRV_STRENGTH=$(( $DRV_STRENGTH >> 6 ))
 if [ $1 -ge 22 -a $1 -le 33 ]
 then
        VM=$(( $STATUS_MUX & $VM_MASK ))
        VM=$(( $VM >> 11 ))
        if [ "$DRV_STRENGTH" == "7" -a "$VM" == "1" ]
        then
                printf " \t    Type A(x1.5)    "
        elif [ "$DRV_STRENGTH" == "3" ]
        then
                printf " \t    Type B(x1,50ohm)"
        elif [ "$DRV_STRENGTH" == "1" ]
        then
                printf "  \t   Type C(x0.75)   "
        elif [ "$DRV_STRENGTH" == "0" ]
        then
                printf "  \t   Type D(x0.5)    "
        elif [ "$DRV_STRENGTH" == "7" -a "$VM" == "0" ]
        then
                printf "  \t   Optional(x1.25) "
        fi
        if [ "$VM" == "0" ]
        then
                printf " \t 2.8v/3.3v"
        else
                printf "\t\t1.8v"
        fi
        PU_RES=$(( $STATUS_MUX & $PU_RES_MASK ))
        PU_RES=$(( $PU_RES >> 13 ))
        if [ "$PU_RES" == "0" ]
        then
                printf "\t10Kohm"
        elif [ "$PU_RES" == "1" ]
        then
                printf "\t1.5Kohm"
        elif [ "$PU_RES" == "2" ]
        then
                printf "\t35Kohm"
        else
                printf "\t20Kohm"
        fi
 else
        if [ "$DRV_STRENGTH" == "0" ]
        then
                printf "     Highest drive capability        "
        elif [ "$DRV_STRENGTH" == "1" ]
        then
                printf "     Half of Highest drive capability"
        else
                printf "     1/4 of Highest drive capability "
        fi
        printf "   NA"
        printf "\t  NA   "
 fi
 OD_EN=$(( $STATUS_MUX & $OD_EN_MASK ))
 OD_EN=$(( $OD_EN >> 12 ))
 if echo "$OD_EN_VALID_ARRAY" | grep -q "$1";
 then
        printf "\t   $OD_EN"
 else
        printf "\t   NA"
 fi
 if [ "$FUNC_SEL" == "0" ]
 then
	printf " General purpose"
 else
	FUNCTION_SEL "$1" "$FUNC_SEL"
 fi
}

printf "PIN TLMM_GPIO_CFGn_REG_ADD    TLMM_GPIO_CFGn  BIAS_STATUS   I/P or O/P \t      DRV_STRENGTH \t \t  VM\tPU_RES\t OD_EN \t    FUNC_SEL\n\n"

if [ $1 == "all" ]
then
        for i in `seq $START_PIN $END_PIN`
        do
        GPIO_DUMP "$i"
        printf "\n"
        done
else
        for i in "$@"
        do
        GPIO_DUMP "$i"
        printf "\n"
        done
fi

