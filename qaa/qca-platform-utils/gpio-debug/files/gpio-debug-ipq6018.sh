: '
/*
 * Copyright (c) 2019 Qualcomm Technologies, Inc.
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
TLMM_GPIO_CFGn_Base_Address=$(( 0x01000000 ))
OFFSET_MULTIPLIER=$(( 0x00001000 ))
START_PIN=0
END_PIN=79
FUNCTION_SELECT_MAPPING=$(cat <<-END
0, qpic_pad, wci20, qdss_traceclk_b, NA, burn0, NA, NA, NA, NA
1, qpic_pad, mac12, qdss_tracectl_b, NA, burn1, NA, NA, NA, NA
2, qpic_pad, wci20, qdss_tracedata_b, NA, NA, NA, NA, NA, NA
3, qpic_pad, mac01, qdss_tracedata_b, NA, NA, NA, NA, NA, NA
4, qpic_pad, mac01, qdss_tracedata_b, NA, NA, NA, NA, NA, NA
5, qpic_pad4, mac21, qdss_tracedata_b, NA, NA, NA, NA, NA, NA
6, qpic_pad5, mac21, qdss_tracedata_b, NA, NA, NA, NA, NA, NA
7, qpic_pad6, qdss_tracedata_b, NA, NA, NA, NA, NA, NA, NA
8, qpic_pad7, qdss_tracedata_b, NA, NA, NA, NA, NA, NA, NA
9, qpic_pad, atest_char, cxc0, mac13, dbg_out, qdss_tracedata_b, NA, NA, NA
10, qpic_pad, qdss_tracedata_b, NA, NA, NA, NA, NA, NA, NA
11, qpic_pad, wci22, mac12, qdss_tracedata_b, NA, NA, NA, NA, NA
12, qpic_pad1, qdss_tracedata_b, NA, NA, NA, NA, NA, NA, NA
13, qpic_pad2, qdss_tracedata_b, NA, NA, NA, NA, NA, NA, NA
14, qpic_pad3, qdss_tracedata_b, NA, NA, NA, NA, NA, NA, NA
15, qpic_pad0, qdss_tracedata_b, NA, NA, NA, NA, NA, NA, NA
16, qpic_pad8, cxc0, mac13, qdss_tracedata_b, NA, NA, NA, NA, NA
17, qpic_pad, qdss_tracedata_b, wci22, NA, NA, NA, NA, NA, NA
18, pwm00, atest_char0, wci23, mac11, NA, NA, NA, NA, NA
19, pwm10, atest_char1, wci23, mac11, NA, NA, NA, NA, NA
20, pwm20, atest_char2, NA, NA, NA, NA, NA, NA, NA
21, pwm30, atest_char3, NA, NA, NA, NA, NA, NA, NA
22, audio_txmclk, audio_txmclkin, pwm02, tx_swrm0, NA, qdss_cti_trig_out_b0, NA, NA, NA
23, audio_txbclk, pwm12, wsa_swrm, tx_swrm1, NA, qdss_cti_trig_in_b0, NA, NA, NA
24, audio_txfsync, pwm22, wsa_swrm, tx_swrm2, NA, qdss_cti_trig_out_b1, NA, NA, NA
25, audio0, pwm32, tx_swrm, NA, qdss_cti_trig_in_b1, NA, NA, NA, NA
26, audio1, pwm04, NA, NA, NA, NA, NA, NA, NA
27, audio2, pwm14, NA, NA, NA, NA, NA, NA, NA
28, audio3, pwm24, NA, NA, NA, NA, NA, NA, NA
29, audio_rxmclk, audio_rxmclkin, pwm03, lpass_pdm, lpass_aud, qdss_cti_trig_in_a1, NA, NA, NA
30, audio_rxbclk, pwm13, lpass_pdm, lpass_aud0, rx_swrm, NA, qdss_cti_trig_out_a1, NA, NA
31, audio_rxfsync, pwm23, lpass_pdm, lpass_aud1, rx_swrm0, NA, qdss_cti_trig_in_a0, NA, NA
32, audio0, pwm33, lpass_pdm, lpass_aud2, rx_swrm1, NA, qdss_cti_trig_out_a0, NA, NA
33, audio1, NA, NA, NA, NA, NA, NA, NA, NA
34, lpass_pcm, mac10, mac00, NA, NA, NA, NA, NA, NA
35, lpass_pcm, mac10, mac00, NA, NA, NA, NA, NA, NA
36, lpass_pcm, mac20, NA, NA, NA, NA, NA, NA, NA
37, lpass_pcm, mac20, NA, NA, NA, NA, NA, NA, NA
38, blsp0_uart, blsp0_i2c, blsp0_spi, NA, NA, NA, NA, NA, NA
39, blsp0_uart, blsp0_i2c, blsp0_spi, NA, NA, NA, NA, NA, NA
40, blsp0_uart, blsp0_spi, NA, NA, NA, NA, NA, NA, NA
41, blsp0_uart, blsp0_spi, NA, NA, NA, NA, NA, NA, NA
42, blsp2_uart, blsp2_i2c, blsp2_spi, NA, NA, NA, NA, NA, NA
43, blsp2_uart, blsp2_i2c, blsp2_spi, NA, NA, NA, NA, NA, NA
44, blsp2_uart, blsp2_spi, NA, NA, NA, NA, NA, NA, NA
45, blsp2_uart, blsp2_spi, NA, NA, NA, NA, NA, NA, NA
46, blsp5_i2c, NA, NA, NA, NA, NA, NA, NA, NA
47, blsp5_i2c, NA, NA, NA, NA, NA, NA, NA, NA
48, blsp5_uart, NA, qdss_traceclk_a, NA, NA, NA, NA, NA, NA
49, blsp5_uart, NA, qdss_tracectl_a, NA, NA, NA, NA, NA, NA
50, pwm01, NA, NA, NA, NA, NA, NA, NA, NA
51, pta1_1, pwm11, NA, rx1, NA, NA, NA, NA, NA
52, pta1_2, pwm21, NA, NA, NA, NA, NA, NA, NA
53, pta1_0, pwm31, prng_rosc, NA, NA, NA, NA, NA, NA
54, NA, NA, NA, NA, NA, NA, NA, NA, NA
55, blsp4_uart, blsp4_i2c, blsp4_spi, NA, NA, NA, NA, NA, NA
56, blsp4_uart, blsp4_i2c, blsp4_spi, NA, NA, NA, NA, NA, NA
57, blsp4_uart, blsp4_spi, NA, NA, NA, NA, NA, NA, NA
58, blsp4_uart, blsp4_spi, NA, NA, NA, NA, NA, NA, NA
59, pcie0_clk, NA, NA, cri_trng0, NA, NA, NA, NA, NA
60, pcie0_rst, NA, NA, cri_trng1, NA, NA, NA, NA, NA
61, pcie0_wake, NA, NA, cri_trng, NA, NA, NA, NA, NA
62, sd_card, NA, NA, NA, NA, NA, NA, NA, NA
63, sd_write, rx0, NA, tsens_max, NA, NA, NA, NA, NA
64, mdc, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
65, mdio, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
66, pta2_0, wci21, cxc1, qdss_tracedata_a, NA, NA, NA, NA, NA
67, pta2_1, qdss_tracedata_a, NA, NA, NA, NA, NA, NA, NA
68, pta2_2, wci21, cxc1, qdss_tracedata_a, NA, NA, NA, NA, NA
69, blsp1_uart, blsp1_i2c, blsp1_spi, gcc_plltest, qdss_tracedata_a, NA, NA, NA, NA
70, blsp1_uart, blsp1_i2c, blsp1_spi, gcc_tlmm, qdss_tracedata_a, NA, NA, NA, NA
71, blsp1_uart, blsp1_spi, gcc_plltest, qdss_tracedata_a, NA, NA, NA, NA, NA
72, blsp1_uart, blsp1_spi, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
73, blsp3_uart, blsp3_i2c, blsp3_spi, NA, qdss_tracedata_a, NA, NA, NA, NA
74, blsp3_uart, blsp3_i2c, blsp3_spi, NA, qdss_tracedata_a, NA, NA, NA, NA
75, blsp3_uart, blsp3_spi, NA, qdss_tracedata_a, NA, NA, NA, NA, NA
76, blsp3_uart, blsp3_spi, NA, qdss_tracedata_a, NA, NA, NA, NA, NA
77, blsp3_spi, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
78, blsp3_spi, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
79, blsp3_spi, NA, qdss_tracedata_a, NA, NA, NA, NA, NA, NA
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
 printf "\t\t"
 printf '0x%08x' $STATUS_REGISTER_ADDRESS
 STATUS_MUX=$( devmem $STATUS_REGISTER_ADDRESS )
 printf "\t\t"
 printf $STATUS_MUX
 BIAS_STATUS=$(( $STATUS_MUX & $BIAS_STATUS_MASK ))
 if [ "$BIAS_STATUS" == "0" ]
 then
        printf "\t\tNO PULL  "
 elif [ "$BIAS_STATUS" == "1" ]
 then
        printf "\t\tPULL DOWN"
 elif [ "$BIAS_STATUS" == "2" ]
 then
        printf "\t\tKEEPER   "
 elif [ "$BIAS_STATUS" == "3" ]
 then
        printf "\t\tPULL UP  "
 else
        printf "\tCANNOT BE DETERMINED"
 fi
 FUNC_SEL=$(( $STATUS_MUX & $FUNC_SEL_MASK ))
 FUNC_SEL=$(( $FUNC_SEL >> 2 ))
 if [ "$FUNC_SEL" == "0" ]
 then
        IO_STATUS=$(( $STATUS_MUX & $IO_MASK ))
        IO_STATUS=$(( $IO_STATUS >> 9 ))
        if [ "$IO_STATUS" == "0" ]
        then
                printf "\t\tIP"
        else
                printf "\t\tOP"
        fi
 else
        printf "\t\tNA"
 fi
 DRV_STRENGTH=$(( $STATUS_MUX & $DRV_STRENGTH_MASK ))
 DRV_STRENGTH=$(( $DRV_STRENGTH >> 6 ))
 printf "\t\t$( expr "$DRV_STRENGTH" + "$DRV_STRENGTH" + "2" ) MA"
 if [ "$FUNC_SEL" == "0" ]
 then
	printf " General purpose"
 else
	FUNCTION_SEL "$1" "$FUNC_SEL"
 fi
}

printf "PIN\t    TLMM_GPIO_CFGn_REG_ADD    TLMM_GPIO_CFGn\t      BIAS_STATUS\t     I/P or O/P\t   DRV_STRENGTH\t    FUNC_SEL\n\n"

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
