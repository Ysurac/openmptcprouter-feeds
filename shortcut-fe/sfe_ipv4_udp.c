/*
 * sfe_ipv4_udp.c
 *	Shortcut forwarding engine - IPv4 UDP implementation
 *
 * Copyright (c) 2013-2016, 2019-2020, The Linux Foundation. All rights reserved.
 * Copyright (c) 2021-2022 Qualcomm Innovation Center, Inc. All rights reserved.
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

#include <linux/skbuff.h>
#include <net/udp.h>
#include <linux/etherdevice.h>
#include <linux/lockdep.h>
#include <linux/version.h>

#include "sfe_debug.h"
#include "sfe_api.h"
#include "sfe.h"
#include "sfe_flow_cookie.h"
#include "sfe_ipv4.h"
#include "sfe_pppoe.h"
#include "sfe_vlan.h"

/*
 * sfe_ipv4_udp_sk_deliver()
 *	Deliver the packet to the protocol handler registered with Linux.
 *	To be called under rcu_read_lock()
 *	Returns:
 *	1 if the packet needs to be passed to Linux.
 *	0 if the packet is processed successfully.
 *	-1 if the packet is dropped in SFE.
 */
static int sfe_ipv4_udp_sk_deliver(struct sk_buff *skb, struct sfe_ipv4_connection_match *cm, unsigned int ihl)
{
	struct udp_sock *up;
	struct sock *sk;
	int ret;
	int (*encap_rcv)(struct sock *sk, struct sk_buff *skb);
	struct udphdr *uh;
	unsigned short ulen;

	/*
	 * Call the decap handler for valid encap_rcv handler.
	 */
	up = rcu_dereference(cm->up);
	encap_rcv = READ_ONCE(up->encap_rcv);
	if (!encap_rcv) {
		DEBUG_ERROR("%px: sfe: Error: up->encap_rcv is NULL\n", skb);
		return 1;
	}

#if (LINUX_VERSION_CODE < KERNEL_VERSION(4, 13, 0))
	nf_reset(skb);
#else
	nf_reset_ct(skb);
#endif
	skb_pull(skb, ihl);
	skb_reset_transport_header(skb);
	sk = (struct sock *)up;

	uh = udp_hdr(skb);
	ulen = ntohs(uh->len);
	if (ulen < sizeof(*uh) || pskb_trim_rcsum(skb, ulen)) {
		DEBUG_TRACE("%px: short packet", skb);
		goto except;
	}
	uh = udp_hdr(skb);

	/*
	 * Verify checksum before giving to encap_rcv handler function.
	 * TODO: The following approach is ignorant for UDPLITE for now.
	 * Instead, consider calling Linux API to do checksum validation.
	 */
	if (unlikely(skb->ip_summed != CHECKSUM_UNNECESSARY && skb->ip_summed != CHECKSUM_COMPLETE) && uh->check) {

		UDP_SKB_CB(skb)->partial_cov = 0;
		UDP_SKB_CB(skb)->cscov = skb->len;

		if (skb_checksum_init(skb, IPPROTO_UDP, inet_compute_pseudo)) {
			DEBUG_TRACE("%px: checksum initilization failed", skb);
			goto except;
		}

		if (inet_get_convert_csum(sk)) {
			skb_checksum_try_convert(skb, IPPROTO_UDP, inet_compute_pseudo);
		}

		if (udp_lib_checksum_complete(skb)) {
			DEBUG_TRACE("%px: udp checksum validation failed", skb);
			goto except;
		}
		DEBUG_TRACE("%px: sfe: udp checksum verified in s/w correctly.\n", skb);
	}

	/*
	 * At this point, L4 checksum has already been verified and pkt is going
	 * to Linux's tunnel decap-handler. Setting ip_summed field to CHECKSUM_NONE,
	 * to ensure that later packet's inner header checksum is validated correctly.
	 * TODO: Find the fix to set skb->ip_summed = CHECKSUM_NONE;
	 */

	/*
	 * encap_rcv() returns the following value:
	 * =0 if skb was successfully passed to the encap
	 *    handler or was discarded by it.
	 * >0 if skb should be passed on to UDP.
	 * <0 if skb should be resubmitted as proto -N
	 */
	ret = encap_rcv(sk, skb);
	if (unlikely(ret)) {
		DEBUG_TRACE("%px: sfe: udp-decap API return error: %d\n", skb, ret);
		goto except;
	}

	return 0;

except:
	/*
	 * The packet could be restored with the original L2 Information for L2
	 * flow, but it couldn't restore the NATed IP in the packets.
	 */
	skb_push(skb, ihl);
	return 1;
}

/*
 * sfe_ipv4_recv_udp()
 *	Handle UDP packet receives and forwarding.
 */
int sfe_ipv4_recv_udp(struct sfe_ipv4 *si, struct sk_buff *skb, struct net_device *dev,
			     unsigned int len, struct iphdr *iph, unsigned int ihl,
			     bool sync_on_find, struct sfe_l2_info *l2_info, bool tun_outer)
{
	struct udphdr *udph;
	__be32 src_ip;
	__be32 dest_ip;
	__be16 src_port;
	__be16 dest_port;
	struct sfe_ipv4_connection_match *cm;
	u8 ttl;
	u32 service_class_id;
	struct net_device *xmit_dev;
	bool hw_csum;
	int err;
	bool bridge_flow;
	int ret;
	bool fast_xmit;
	netdev_features_t features;

	/*
	 * Is our packet too short to contain a valid UDP header?
	 */
	if (unlikely(!pskb_may_pull(skb, (sizeof(struct udphdr) + ihl)))) {
		sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_UDP_HEADER_INCOMPLETE);
		DEBUG_TRACE("%px: packet too short for UDP header\n", skb);
		return 0;
	}

	/*
	 * Read the IP address and port information.  Read the IP header data first
	 * because we've almost certainly got that in the cache.  We may not yet have
	 * the UDP header cached though so allow more time for any prefetching.
	 */
	src_ip = iph->saddr;
	dest_ip = iph->daddr;

	udph = (struct udphdr *)(skb->data + ihl);
	src_port = udph->source;
	dest_port = udph->dest;

	rcu_read_lock();

	/*
	 * Look for a connection match.
	 */
#ifdef CONFIG_NF_FLOW_COOKIE
	cm = si->sfe_flow_cookie_table[skb->flow_cookie & SFE_FLOW_COOKIE_MASK].match;
	if (unlikely(!cm)) {
		cm = sfe_ipv4_find_connection_match_rcu(si, dev, IPPROTO_UDP, src_ip, src_port, dest_ip, dest_port);
	}
#else
	/*
	 * 5-tuple lookup for UDP flow.
	 */
	cm = sfe_ipv4_find_connection_match_rcu(si, dev, IPPROTO_UDP, src_ip, src_port, dest_ip, dest_port);
#endif
	if (unlikely(!cm)) {

		/*
		 * Try a 4-tuple lookup; required for tunnels like vxlan.
		 */
		cm = sfe_ipv4_find_connection_match_rcu(si, dev, IPPROTO_UDP, src_ip, 0, dest_ip, dest_port);
		if (unlikely(!cm)) {
			rcu_read_unlock();
			sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_UDP_NO_CONNECTION);
			DEBUG_TRACE("%px: sfe: no connection found in 4-tuple lookup.\n", skb);
			return 0;
		}
	}

	/*
	 * Source interface validate.
	 */
	if (unlikely((cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_SRC_INTERFACE_CHECK) && (cm->match_dev != dev))) {
		if (!(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_SRC_INTERFACE_CHECK_NO_FLUSH)) {
			struct sfe_ipv4_connection *c = cm->connection;
			DEBUG_TRACE("flush on source interface check failure\n");
			spin_lock_bh(&si->lock);
			ret = sfe_ipv4_remove_connection(si, c);
			spin_unlock_bh(&si->lock);

			if (ret) {
				sfe_ipv4_flush_connection(si, c, SFE_SYNC_REASON_FLUSH);
			}
		}
		rcu_read_unlock();
		sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_INVALID_SRC_IFACE);
		DEBUG_TRACE("exception the packet on source interface check failure\n");
		return 0;
	}

	/*
	 * If our packet has been marked as "sync on find" we can't actually
	 * forward it in the fast path, but now that we've found an associated
	 * connection we need sync its status before exception it to slow path.
	 */
	if (unlikely(sync_on_find)) {
		sfe_ipv4_sync_status(si, cm->connection, SFE_SYNC_REASON_STATS);
		rcu_read_unlock();
		sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_UDP_IP_OPTIONS_OR_INITIAL_FRAGMENT);
		DEBUG_TRACE("%px: sync on find\n", cm);
		return 0;
	}

#ifdef CONFIG_XFRM
	/*
	 * We can't accelerate the flow on this direction, just let it go
	 * through the slow path.
	 */
	if (unlikely(!cm->flow_accel)) {
		rcu_read_unlock();
		this_cpu_inc(si->stats_pcpu->packets_not_forwarded64);
		return 0;
	}
#endif

	/*
	 * Do we expect an ingress VLAN tag for this flow?
	 */
	if (unlikely(!sfe_vlan_validate_ingress_tag(skb, cm->ingress_vlan_hdr_cnt, cm->ingress_vlan_hdr, l2_info))) {
		rcu_read_unlock();
		sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_INGRESS_VLAN_TAG_MISMATCH);
		DEBUG_TRACE("VLAN tag mismatch. skb=%px\n", skb);
		return 0;
	}

	bridge_flow = !!(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_BRIDGE_FLOW);

	/*
	 * Does our TTL allow forwarding?
	 */
	if (likely(!bridge_flow)) {
		ttl = iph->ttl;
		if (unlikely(ttl < 2)) {
			sfe_ipv4_sync_status(si, cm->connection, SFE_SYNC_REASON_STATS);
			rcu_read_unlock();

			DEBUG_TRACE("%px: sfe: TTL too low\n", skb);
			sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_UDP_SMALL_TTL);
			return 0;
		}
	}

	/*
	 * If our packet is larger than the MTU of the transmit interface then
	 * we can't forward it easily.
	 */
	if (unlikely((len > cm->xmit_dev_mtu) && (!cm->up))) {
		sfe_ipv4_sync_status(si, cm->connection, SFE_SYNC_REASON_STATS);
		rcu_read_unlock();
		sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_UDP_NEEDS_FRAGMENTATION);
		DEBUG_TRACE("%px: sfe: larger than MTU\n", cm);
		return 0;
	}

	/*
	 * Check if skb was cloned. If it was, unshare it. Because
	 * the data area is going to be written in this path and we don't want to
	 * change the cloned skb's data section.
	 */
	if (unlikely(skb_cloned(skb))) {
		DEBUG_TRACE("%px: skb is a cloned skb\n", skb);
		skb = skb_unshare(skb, GFP_ATOMIC);
		if (!skb) {
			DEBUG_WARN("%px: Failed to unshare the cloned skb\n", skb);
			rcu_read_unlock();
			return 0;
		}

		/*
		 * Update the iph and udph pointers with the unshared skb's data area.
		 */
		iph = (struct iphdr *)skb->data;
		udph = (struct udphdr *)(skb->data + ihl);
	}

	/*
	 * Check if skb has enough headroom to write L2 headers
	 */
	if (unlikely(skb_headroom(skb) < cm->l2_hdr_size)) {
		rcu_read_unlock();
		DEBUG_WARN("%px: Not enough headroom: %u\n", skb, skb_headroom(skb));
		sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_NO_HEADROOM);
		return 0;
	}

	/*
	 * For PPPoE packets, match server MAC and session id
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_PPPOE_DECAP)) {
		struct ethhdr *eth;
		bool pppoe_match;

		if (unlikely(!sfe_l2_parse_flag_check(l2_info, SFE_L2_PARSE_FLAGS_PPPOE_INGRESS))) {
			rcu_read_unlock();
			DEBUG_TRACE("%px: PPPoE header not present in packet for PPPoE rule\n", skb);
			sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_INCORRECT_PPPOE_PARSING);
			return 0;
		}

		eth = eth_hdr(skb);

		pppoe_match = (cm->pppoe_session_id == sfe_l2_pppoe_session_id_get(l2_info)) &&
				ether_addr_equal((u8*)cm->pppoe_remote_mac, (u8 *)eth->h_source);

		if (unlikely(!pppoe_match)) {
			DEBUG_TRACE("%px: PPPoE session ID %d and %d or MAC %pM and %pM did not match\n",
					skb, cm->pppoe_session_id, sfe_l2_pppoe_session_id_get(l2_info),
					cm->pppoe_remote_mac, eth->h_source);
			rcu_read_unlock();
			sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_INVALID_PPPOE_SESSION);
			return 0;
		}

		skb->protocol = htons(l2_info->protocol);
		this_cpu_inc(si->stats_pcpu->pppoe_decap_packets_forwarded64);
	} else if (unlikely(sfe_l2_parse_flag_check(l2_info, SFE_L2_PARSE_FLAGS_PPPOE_INGRESS))) {

		/*
		 * If packet contains PPPoE header but CME doesn't contain PPPoE flag yet we are exceptioning
		 * the packet to linux
		 */
		if (unlikely(!bridge_flow)) {
			rcu_read_unlock();
			DEBUG_TRACE("%px: CME doesn't contain PPPoE flag but packet has PPPoE header\n", skb);
			sfe_ipv4_exception_stats_inc(si, SFE_IPV4_EXCEPTION_EVENT_PPPOE_NOT_SET_IN_CME);
			return 0;
		}

		/*
		 * For bridged flows when packet contains PPPoE header, restore the header back and forward
		 * to xmit interface
		 */
		__skb_push(skb, PPPOE_SES_HLEN);
		this_cpu_inc(si->stats_pcpu->pppoe_bridge_packets_forwarded64);
	}

	/*
	 * From this point on we're good to modify the packet.
	 */

	/*
	 * For PPPoE flows, add PPPoE header before L2 header is added.
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_PPPOE_ENCAP)) {
		sfe_pppoe_add_header(skb, cm->pppoe_session_id, PPP_IP);
		this_cpu_inc(si->stats_pcpu->pppoe_encap_packets_forwarded64);
	}

	/*
	 * Enable HW csum if rx checksum is verified and xmit interface is CSUM offload capable.
	 * Note: If L4 csum at Rx was found to be incorrect, we (router) should use incremental L4 checksum here
	 * so that HW does not re-calculate/replace the L4 csum
	 */
	hw_csum = !!(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_CSUM_OFFLOAD) && (skb->ip_summed == CHECKSUM_UNNECESSARY);

	/*
	 * Do we have to perform translations of the source address/port?
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_XLATE_SRC)) {
		u16 udp_csum;

		iph->saddr = cm->xlate_src_ip;
		udph->source = cm->xlate_src_port;

		/*
		 * Do we have a non-zero UDP checksum?  If we do then we need
		 * to update it.
		 */
		if (unlikely(!hw_csum)) {
			udp_csum = udph->check;
			if (likely(udp_csum)) {
				u32 sum;

				if (unlikely(skb->ip_summed == CHECKSUM_PARTIAL)) {
					sum = udp_csum + cm->xlate_src_partial_csum_adjustment;
				} else {
					sum = udp_csum + cm->xlate_src_csum_adjustment;
				}

				sum = (sum & 0xffff) + (sum >> 16);
				udph->check = (u16)sum;
			}
		}
	}

	/*
	 * Do we have to perform translations of the destination address/port?
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_XLATE_DEST)) {
		u16 udp_csum;

		iph->daddr = cm->xlate_dest_ip;
		udph->dest = cm->xlate_dest_port;

		/*
		 * Do we have a non-zero UDP checksum?  If we do then we need
		 * to update it.
		 */
		if (unlikely(!hw_csum)) {
			udp_csum = udph->check;
			if (likely(udp_csum)) {
				u32 sum;

				/*
				 * TODO: Use a common API for below incremental checksum calculation
				 * for IPv4/IPv6 UDP/TCP
				 */
				if (unlikely(skb->ip_summed == CHECKSUM_PARTIAL)) {
					sum = udp_csum + cm->xlate_dest_partial_csum_adjustment;
				} else {
					sum = udp_csum + cm->xlate_dest_csum_adjustment;
				}

				sum = (sum & 0xffff) + (sum >> 16);
				udph->check = (u16)sum;
			}
		}
	}

	/*
	 * UDP sock will be valid only in decap-path.
	 * Call encap_rcv function associated with udp_sock in cm.
	 */
	if (unlikely(cm->up)) {
		/*
		 * Call decap handler associated with sock.
		 * Also validates UDP checksum before calling decap handler.
		 */
		err = sfe_ipv4_udp_sk_deliver(skb, cm, ihl);
		if (unlikely(err == 1)) {
			rcu_read_unlock();
			this_cpu_inc(si->stats_pcpu->packets_not_forwarded64);
			return 0;
		}

		/*
		 * Update traffic stats.
		 */
		atomic_inc(&cm->rx_packet_count);
		atomic_add(len, &cm->rx_byte_count);

		rcu_read_unlock();
		this_cpu_inc(si->stats_pcpu->packets_forwarded64);
		DEBUG_TRACE("%px: sfe: sfe_ipv4_recv_udp -> encap_rcv done.\n", skb);
		return 1;
	}

	/*
	 * Decrement our TTL
	 * Except when called from hook function in post-decap.
	 */
	if (likely(!bridge_flow)) {
		iph->ttl -= (u8)(!tun_outer);
	}

	/*
	 * Update DSCP
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_DSCP_REMARK)) {
		iph->tos = (iph->tos & SFE_IPV4_DSCP_MASK) | cm->dscp;
	}

	/*
	 * If HW checksum offload is not possible, full L3 checksum and incremental L4 checksum
	 * are used to update the packet. Setting ip_summed to CHECKSUM_UNNECESSARY ensures checksum is
	 * not recalculated further in packet path.
	 */
	if (likely(hw_csum)) {
		skb->ip_summed = CHECKSUM_PARTIAL;
	} else {
		iph->check = sfe_ipv4_gen_ip_csum(iph);
	}

	/*
	 * Update traffic stats.
	 */
	atomic_inc(&cm->rx_packet_count);
	atomic_add(len, &cm->rx_byte_count);

	xmit_dev = cm->xmit_dev;
	skb->dev = xmit_dev;

	/*
	 * Check to see if we need to add VLAN tags
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_INSERT_EGRESS_VLAN_TAG)) {
		sfe_vlan_add_tag(skb, cm->egress_vlan_hdr_cnt, cm->egress_vlan_hdr);
	}

	/*
	 * Check to see if we need to write an Ethernet header.
	 */
	if (likely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_WRITE_L2_HDR)) {
		if (unlikely(!(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_WRITE_FAST_ETH_HDR))) {
			dev_hard_header(skb, xmit_dev, ntohs(skb->protocol),
					cm->xmit_dest_mac, cm->xmit_src_mac, len);
		} else {
			/*
			 * For the simple case we write this really fast.
			 */
			struct ethhdr *eth = (struct ethhdr *)__skb_push(skb, ETH_HLEN);
			eth->h_proto = skb->protocol;
			ether_addr_copy((u8 *)eth->h_dest, (u8 *)cm->xmit_dest_mac);
			ether_addr_copy((u8 *)eth->h_source, (u8 *)cm->xmit_src_mac);
		}
	}

	/*
	 * Update priority of skb.
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_PRIORITY_REMARK)) {
		skb->priority = cm->priority;
	}

	/*
	 * Mark outgoing packet.
	 */
	if (unlikely(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_MARK)) {
		skb->mark = cm->mark;
		/*
		 * Update service class stats if SAWF is valid.
		 */
		if (likely(cm->sawf_valid)) {
			service_class_id = SFE_GET_SAWF_SERVICE_CLASS(cm->mark);
			sfe_ipv4_service_class_stats_inc(si, service_class_id, len);
		}
	}

	/*
	 * For the first packets, check if it could got fast xmit.
	 */
	if (unlikely(!(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_FAST_XMIT_FLOW_CHECKED)
				&& (cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_FAST_XMIT_DEV_ADMISSION))){
		cm->features = netif_skb_features(skb);
		if (likely(sfe_fast_xmit_check(skb, cm->features))) {
			cm->flags |= SFE_IPV4_CONNECTION_MATCH_FLAG_FAST_XMIT;
		}
		cm->flags |= SFE_IPV4_CONNECTION_MATCH_FLAG_FAST_XMIT_FLOW_CHECKED;
	}
	features = cm->features;

	fast_xmit = !!(cm->flags & SFE_IPV4_CONNECTION_MATCH_FLAG_FAST_XMIT);

	rcu_read_unlock();

	this_cpu_inc(si->stats_pcpu->packets_forwarded64);

	/*
	 * We're going to check for GSO flags when we transmit the packet so
	 * start fetching the necessary cache line now.
	 */
	prefetch(skb_shinfo(skb));

	/*
	 * We do per packet condition check before we could fast xmit the
	 * packet.
	 */
	if (likely(fast_xmit && dev_fast_xmit(skb, xmit_dev, features))) {
		this_cpu_inc(si->stats_pcpu->packets_fast_xmited64);
		return 1;
	}

	/*
	 * Mark that this packet has been fast forwarded.
	 */
	skb->fast_forwarded = 1;

	/*
	 * Send the packet on its way.
	 */
	dev_queue_xmit(skb);

	return 1;
}
