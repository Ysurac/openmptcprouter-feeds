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
TLMM_GPIO_CFGn_Base_Address=$(( 0x00801000 ))
OFFSET_MULTIPLIER=$(( 0x10 ))
START_PIN=0
END_PIN=68
FUNCTION_SELECT_MAPPING=$(cat <<-END
0, mdio, NA, NA, NA, NA, NA, NA, NA, NA, NA
1, mdio, NA, NA, NA, NA, NA, NA, NA, NA, NA
2, gsbi5_spi_cs3, rgmii2, mdio, NA, NA, NA, NA, NA, NA, NA
3, pcie1_rst, pcie1_prsnt, pdm, NA, NA, NA, NA, NA, NA, NA
4, pcie1_pwren_n, pcie1_pwren, NA, NA, NA, NA, NA, NA, NA, NA
5, pcie1_clk_req, pcie1_pwrflt, NA, NA, NA, NA, NA, NA, NA, NA
6, gsbi7, usb_fs, gsbi5_spi_cs1, usb_fs_n, NA, NA, NA, NA, NA, NA
7, gsbi7, usb_fs, gsbi5_spi_cs2, NA, NA, NA, NA, NA, NA, NA
8, gsbi7, usb_fs, NA, NA, NA, NA, NA, NA, NA, NA
9, gsbi7, NA, NA, NA, NA, NA, NA, NA, NA, NA
10, gsbi4, spdif, sata, ssbi, mdio, spmi, NA, NA, NA, NA
11, gsbi4, pcie2_prsnt, pcie1_prsnt, pcie3_prsnt, ssbi, mdio, spmi, NA, NA, NA
12, gsbi4, pcie2_pwren_n, pcie1_pwren_n, pcie3_pwren_n, pcie2_pwren, pcie1_pwren, pcie3_pwren, NA, NA, NA
13, gsbi4, pcie2_pwrflt, pcie1_pwrflt, pcie3_pwrflt, NA, NA, NA, NA, NA, NA
14, audio_pcm, nss_spi, NA, NA, NA, NA, NA, NA, NA, NA
15, audio_pcm, nss_spi, NA, NA, NA, NA, NA, NA, NA, NA
16, audio_pcm, nss_spi, pdm, NA, NA, NA, NA, NA, NA, NA
17, audio_pcm, nss_spi, pdm, NA, NA, NA, NA, NA, NA, NA
18, gsbi5, NA, NA, NA, NA, NA, NA, NA, NA, NA
19, gsbi5, NA, NA, NA, NA, NA, NA, NA, NA, NA
20, gsbi5, NA, NA, NA, NA, NA, NA, NA, NA, NA
21, gsbi5, NA, NA, NA, NA, NA, NA, NA, NA, NA
22, gsbi2, pdm, NA, NA, NA, NA, NA, NA, NA, NA
23, gsbi2, NA, NA, NA, NA, NA, NA, NA, NA, NA
24, gsbi2, NA, NA, NA, NA, NA, NA, NA, NA, NA
25, gsbi2, NA, NA, NA, NA, NA, NA, NA, NA, NA
26, ps_hold, NA, NA, NA, NA, NA, NA, NA, NA, NA
27, mi2s, rgmii2, gsbi6, NA, NA, NA, NA, NA, NA, NA
28, mi2s, rgmii2, gsbi6, NA, NA, NA, NA, NA, NA, NA
29, mi2s, rgmii2, gsbi6, NA, NA, NA, NA, NA, NA, NA
30, mi2s, rgmii2, gsbi6, pdm, NA, NA, NA, NA, NA, NA
31, mi2s, rgmii2, pdm, NA, NA, NA, NA, NA, NA, NA
32, mi2s, rgmii2, NA, NA, NA, NA, NA, NA, NA, NA
33, mi2s, NA, NA, NA, NA, NA, NA, NA, NA, NA
34, nand, pdm, NA, NA, NA, NA, NA, NA, NA, NA
35, nand, pdm, NA, NA, NA, NA, NA, NA, NA, NA
36, nand, NA, NA, NA, NA, NA, NA, NA, NA, NA
37, nand, NA, NA, NA, NA, NA, NA, NA, NA, NA
38, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
39, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
40, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
41, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
42, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
43, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
44, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
45, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
46, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
47, nand, sdc1, NA, NA, NA, NA, NA, NA, NA, NA
48, pcie2_rst, spdif, NA, NA, NA, NA, NA, NA, NA, NA
49, pcie2_pwren_n, pcie2_pwren, NA, NA, NA, NA, NA, NA, NA, NA
50, pcie2_clk_req, pcie2_pwrflt, NA, NA, NA, NA, NA, NA, NA, NA
51, gsbi1, rgmii2, NA, NA, NA, NA, NA, NA, NA, NA
52, gsbi1, rgmii2, pdm, NA, NA, NA, NA, NA, NA, NA
53, gsbi1, NA, NA, NA, NA, NA, NA, NA, NA, NA
54, gsbi1, NA, NA, NA, NA, NA, NA, NA, NA, NA
55, tsif1, mi2s, gsbi6, pdm, nss_spi, NA, NA, NA, NA, NA
56, tsif1, mi2s, gsbi6, pdm, nss_spi, NA, NA, NA, NA, NA
57, tsif1, mi2s, gsbi6, nss_spi, NA, NA, NA, NA, NA, NA
58, tsif1, mi2s, gsbi6, pdm, nss_spi, NA, NA, NA, NA, NA
59, tsif2, rgmii2, pdm, NA, NA, NA, NA, NA, NA, NA
60, tsif2, rgmii2, NA, NA, NA, NA, NA, NA, NA, NA
61, tsif2, rgmii2, gsbi5_spi_cs1, NA, NA, NA, NA, NA, NA, NA
62, tsif2, rgmii2, gsbi5_spi_cs2, NA, NA, NA, NA, NA, NA, NA
63, pcie3_rst, NA, NA, NA, NA, NA, NA, NA, NA, NA
64, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA
65, pcie3_clk_req, NA, NA, NA, NA, NA, NA, NA, NA, NA
66, rgmii2, mdio, NA, NA, NA, NA, NA, NA, NA, NA
67, usb2_hsic, NA, NA, NA, NA, NA, NA, NA, NA, NA
68, usb2_hsic, NA, NA, NA, NA, NA, NA, NA, NA, NA
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

