#!/bin/sh
#
# Copyright (c) 2020 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

[ -f /tmp/BTHOST_BD_ADDR ] && export BTHOST_BD_ADDR=$(cat /tmp/BTHOST_BD_ADDR)
[ -f /tmp/BTHOST_XCAL_TRIM ] && export BTHOST_XCAL_TRIM=$(cat /tmp/BTHOST_XCAL_TRIM)

