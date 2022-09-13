/*
 * sfe_vlan.h
 *	Shortcut flow acceleration for 802.1AD/802.1Q flow
 *
 * Copyright (c) 2022 Qualcomm Innovation Center, Inc. All rights reserved.
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef __SFE_VLAN_H
#define __SFE_VLAN_H

#include <linux/if_vlan.h>

/*
 * sfe_vlan_check_and_parse_tag()
 *
 * case 1: QinQ frame (e.g. outer tag = 88a80032, inner tag = 81000001):
 * When entering this function:
 * ----+-----------------+-----|-----+-----------+-----+---------
 *     |DMAC    |SMAC    |88|a8|00|32|81|00|00|01|08|00|45|00|
 * ----+-----------------+-----A-----+-----------+-----+---------
 *                            skb->data
 *   skb->protocol = ntohs(ETH_P_8021AD)
 *   skb->vlan_proto = 0
 *   skb->vlan_tci = 0
 *   skb->vlan_present = 0
 * When exiting:
 * ----+-----------------+-----------+-----------+-----+---------
 *     |DMAC    |SMAC    |88|a8|00|32|81|00|00|01|08|00|45|00|
 * ----+-----------------+-----------+-----------+-----A---------
 *                                                    skb->data
 *   skb->protocol = ntohs(ETH_P_IP)
 *   skb->vlan_proto = 0
 *   skb->vlan_tci = 0
 *   skb->vlan_present = 0
 *   l2_info->vlan_hdr_cnt = 2
 *   l2_info->vlan_hdr[0].tpid = ntohs(ETH_P_8021AD)
 *   l2_info->vlan_hdr[0].tci = 0x0032
 *   l2_info->vlan_hdr[1].tpid = ntohs(ETH_P_8021Q)
 *   l2_info->vlan_hdr[1].tci = 0x0001
 *   l2_info->protocol = ETH_P_IP
 *
 * case 2: 802.1Q frame (e.g. the tag is 81000001):
 * When entering this function:
 * ----+-----------------+-----|-----+-----+---------
 *     |DMAC    |SMAC    |81|00|00|01|08|00|45|00|
 * ----+-----------------+-----A-----+-----+---------
 *                            skb->data
 *   skb->protocol = ntohs(ETH_P_8021Q)
 *   skb->vlan_proto = 0
 *   skb->vlan_tci = 0
 *   skb->vlan_present = 0
 * When exiting:
 * ----+-----------------+-----------+-----+---------
 *     |DMAC    |SMAC    |81|00|00|01|08|00|45|00|
 * ----+-----------------+-----------+-----A---------
 *                                        skb->data
 *   skb->protocol = ntohs(ETH_P_IP)
 *   skb->vlan_proto = 0
 *   skb->vlan_tci = 0
 *   skb->vlan_present = 0
 *   l2_info->vlan_hdr_cnt = 1
 *   l2_info->vlan_hdr[0].tpid = ntohs(ETH_P_8021Q)
 *   l2_info->vlan_hdr[0].tci = 0x0001
 *   l2_info->protocol = ETH_P_IP
 *
 * case 3: untagged frame
 * When entering this function:
 * ----+-----------------+-----|---------------------
 *     |DMAC    |SMAC    |08|00|45|00|
 * ----+-----------------+-----A---------------------
 *                            skb->data
 *   skb->protocol = ntohs(ETH_P_IP)
 *   skb->vlan_proto = 0
 *   skb->vlan_tci = 0
 *   skb->vlan_present = 0
 * When exiting:
 * ----+-----------------+-----|---------------------
 *     |DMAC    |SMAC    |08|00|45|00|
 * ----+-----------------+-----A---------------------
 *                            skb->data
 *   skb->protocol = ntohs(ETH_P_IP)
 *   skb->vlan_proto = 0
 *   skb->vlan_tci = 0
 *   skb->vlan_present = 0
 *   l2_info->vlan_hdr_cnt = 0
 *   l2_info->protocol = ETH_P_IP
 */
static inline bool sfe_vlan_check_and_parse_tag(struct sk_buff *skb, struct sfe_l2_info *l2_info)
{
	struct vlan_hdr *vhdr;

	while ((skb->protocol == htons(ETH_P_8021AD) || skb->protocol == htons(ETH_P_8021Q)) &&
			l2_info->vlan_hdr_cnt < SFE_MAX_VLAN_DEPTH) {
		if (unlikely(!pskb_may_pull(skb, VLAN_HLEN))) {
			return false;
		}
		vhdr = (struct vlan_hdr *)skb->data;
		l2_info->vlan_hdr[l2_info->vlan_hdr_cnt].tpid = skb->protocol;
		l2_info->vlan_hdr[l2_info->vlan_hdr_cnt].tci = ntohs(vhdr->h_vlan_TCI);
		skb->protocol = vhdr->h_vlan_encapsulated_proto;
		l2_info->vlan_hdr_cnt++;
		/*
		 * strip VLAN header
		 */
		__skb_pull(skb, VLAN_HLEN);
		skb_reset_network_header(skb);
	}

	l2_info->protocol = htons(skb->protocol);
	return true;
}

/*
 * sfe_vlan_undo_parse()
 *      Restore some skb fields which are modified when parsing VLAN tags.
 */
static inline void sfe_vlan_undo_parse(struct sk_buff *skb, struct sfe_l2_info *l2_info)
{
	if (l2_info->vlan_hdr_cnt == 0) {
		return;
	}

	skb->protocol = l2_info->vlan_hdr[0].tpid;
	__skb_push(skb, l2_info->vlan_hdr_cnt * VLAN_HLEN);
}

/*
 * sfe_vlan_validate_ingress_tag()
 *      Validate ingress packet's VLAN tag
 */
static inline bool sfe_vlan_validate_ingress_tag(
		struct sk_buff *skb, u8 count, struct sfe_vlan_hdr *vlan_hdr, struct sfe_l2_info *l2_info)
{
	u8 i;

	if (likely(!sfe_is_l2_feature_enabled())) {
		return true;
	}

	if (unlikely(count != l2_info->vlan_hdr_cnt)) {
		return false;
	}

	for (i = 0; i < count; i++) {
		if (unlikely(vlan_hdr[i].tpid != l2_info->vlan_hdr[i].tpid)) {
			return false;
		}

		if (unlikely((vlan_hdr[i].tci & VLAN_VID_MASK) !=
			     (l2_info->vlan_hdr[i].tci & VLAN_VID_MASK))) {
			return false;
		}
	}

	return true;
}

/*
 * sfe_vlan_add_tag()
 *      Add VLAN tags at skb->data.
 *      Normally, it is called just before adding 14-byte Ethernet header.
 *
 *      This function does not update skb->mac_header so later code
 *      needs to call skb_reset_mac_header()/skb_reset_mac_len() to
 *      get correct skb->mac_header/skb->mac_len.
 *
 *      It assumes:
 *      - skb->protocol is set
 *      - skb has enough headroom to write VLAN tags
 *      - 0 < count <= SFE_MAX_VLAN_DEPTH
 *
 * When entering (e.g. skb->protocol = ntohs(ETH_P_IP) or ntohs(ETH_P_PPP_SES)):
 *  -------------------------------+---------------------
 *                                 |45|00|...
 *  -------------------------------A---------------------
 *                                skb->data
 *  -------------------------------v-----------------+-----+----------
 *                                 |11|00|xx|xx|xx|xx|00|21|45|00|...
 *  -------------------------------+-----------------+-----+----------
 *
 * When exiting (e.g. to add outer/inner tag = 88a80032/81000001):
 *  -------------+-----------+-----+---------------------
 *         |00|32|81|00|00|01|08|00|45|00|05|d8|....
 *  -------A-----+-----------+-----+---------------------
 *        skb->data
 *  -------v-----+-----------+-----+-----------------+-----+----------
 *         |00|32|81|00|00|01|88|64|11|00|xx|xx|xx|xx|00|21|45|00|
 *  -------------+-----------+-----+-----------------+-----+----------
 *  skb->protocol = ntohs(ETH_P_8021AD)
 */
static inline void sfe_vlan_add_tag(struct sk_buff *skb, int count, struct sfe_vlan_hdr *vlan)
{
	struct vlan_hdr *vhdr;
	int i;
	vlan += (count - 1);

	for (i = 0; i < count; i++) {
		vhdr = (struct vlan_hdr *)skb_push(skb, VLAN_HLEN);
		vhdr->h_vlan_TCI = htons(vlan->tci);
		vhdr->h_vlan_encapsulated_proto = skb->protocol;
		skb->protocol = vlan->tpid;
		vlan--;
	}
}

#endif /* __SFE_VLAN_H */
