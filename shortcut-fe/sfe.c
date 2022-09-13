/*
 * sfe.c
 *     API for shortcut forwarding engine.
 *
 * Copyright (c) 2015,2016, The Linux Foundation. All rights reserved.
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

#include <linux/module.h>
#include <linux/version.h>
#include <linux/sysfs.h>
#include <linux/skbuff.h>
#include <net/addrconf.h>
#include <linux/inetdevice.h>
#include <net/pkt_sched.h>
#include <net/vxlan.h>
#include <net/gre.h>

#include "sfe_debug.h"
#include "sfe_api.h"
#include "sfe.h"
#include "sfe_pppoe.h"
#include "sfe_pppoe_mgr.h"
#include "sfe_vlan.h"
#include "sfe_ipv4.h"
#include "sfe_ipv6.h"

extern int max_ipv4_conn;
extern int max_ipv6_conn;

#define SFE_MESSAGE_VERSION 0x1
#define sfe_ipv6_addr_copy(src, dest) memcpy((void *)(dest), (void *)(src), 16)
#define sfe_ipv4_stopped(CTX) (rcu_dereference((CTX)->ipv4_stats_sync_cb) == NULL)
#define sfe_ipv6_stopped(CTX) (rcu_dereference((CTX)->ipv6_stats_sync_cb) == NULL)
#define SFE_IPSEC_TUNNEL_TYPE 31

typedef enum sfe_exception {
	SFE_EXCEPTION_IPV4_MSG_UNKNOW,
	SFE_EXCEPTION_IPV6_MSG_UNKNOW,
	SFE_EXCEPTION_CONNECTION_INVALID,
	SFE_EXCEPTION_NOT_SUPPORT_BRIDGE,
	SFE_EXCEPTION_TCP_INVALID,
	SFE_EXCEPTION_PROTOCOL_NOT_SUPPORT,
	SFE_EXCEPTION_SRC_DEV_NOT_L3,
	SFE_EXCEPTION_DEST_DEV_NOT_L3,
	SFE_EXCEPTION_CFG_ERR,
	SFE_EXCEPTION_CREATE_FAILED,
	SFE_EXCEPTION_ENQUEUE_FAILED,
	SFE_EXCEPTION_NOT_SUPPORT_6RD,
	SFE_EXCEPTION_NO_SYNC_CB,
	SFE_EXCEPTION_MAX
} sfe_exception_t;

static char *sfe_exception_events_string[SFE_EXCEPTION_MAX] = {
	"IPV4_MSG_UNKNOW",
	"IPV6_MSG_UNKNOW",
	"CONNECTION_INVALID",
	"NOT_SUPPORT_BRIDGE",
	"TCP_INVALID",
	"PROTOCOL_NOT_SUPPORT",
	"SRC_DEV_NOT_L3",
	"DEST_DEV_NOT_L3",
	"CONFIG_ERROR",
	"CREATE_FAILED",
	"ENQUEUE_FAILED",
	"NOT_SUPPORT_6RD",
	"NO_SYNC_CB"
};

/*
 * Message type of queued response message
 */
typedef enum {
	SFE_MSG_TYPE_IPV4,
	SFE_MSG_TYPE_IPV6
} sfe_msg_types_t;

/*
 * Queued response message,
 * will be sent back to caller in workqueue
 */
struct sfe_response_msg {
	struct list_head node;
	sfe_msg_types_t type;
	void *msg[0];
};

/*
 * SFE context instance, private for SFE
 */
struct sfe_ctx_instance_internal {
	struct sfe_ctx_instance base;	/* Exported SFE context, is public to user of SFE*/

	/*
	 * Control state.
	 */
	struct kobject *sys_sfe;	/* Sysfs linkage */

	struct list_head msg_queue;	/* Response message queue*/
	spinlock_t lock;		/* Lock to protect message queue */

	struct work_struct work;	/* Work to send response message back to caller*/

	sfe_ipv4_msg_callback_t __rcu ipv4_stats_sync_cb;	/* Callback to call to sync ipv4 statistics */
	sfe_ipv4_msg_callback_t __rcu ipv4_stats_sync_many_cb;	/* Callback to call to sync many ipv4 statistics */
	void *ipv4_stats_sync_data;	/* Argument for above callback: ipv4_stats_sync_cb */

	sfe_ipv6_msg_callback_t __rcu ipv6_stats_sync_cb;	/* Callback to call to sync ipv6 statistics */
	sfe_ipv6_msg_callback_t __rcu ipv6_stats_sync_many_cb;	/* Callback to call to sync many ipv6 statistics */
	void *ipv6_stats_sync_data;	/* Argument for above callback: ipv6_stats_sync_cb */

	u32 exceptions[SFE_EXCEPTION_MAX];		/* Statistics for exception */

	int32_t l2_feature_support;		/* L2 feature support */

};

static struct sfe_ctx_instance_internal __sfe_ctx;

/*
 * Convert public SFE context to internal context
 */
#define SFE_CTX_TO_PRIVATE(base) (struct sfe_ctx_instance_internal *)(base)
/*
 * Convert internal SFE context to public context
 */
#define SFE_CTX_TO_PUBLIC(intrv) (struct sfe_ctx_instance *)(intrv)

/*
 * sfe_incr_exceptions()
 *	Increase an exception counter.
 *
 * TODO:  Merge sfe_ctx stats to ipv4 and ipv6 percpu stats.
 */
static inline void sfe_incr_exceptions(sfe_exception_t except)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;

	spin_lock_bh(&sfe_ctx->lock);
	sfe_ctx->exceptions[except]++;
	spin_unlock_bh(&sfe_ctx->lock);
}

/*
 * sfe_dev_is_layer_3_interface()
 * 	Check if a network device is ipv4 or ipv6 layer 3 interface
 *
 * @param dev network device to check
 * @param check_v4 check ipv4 layer 3 interface(which have ipv4 address) or ipv6 layer 3 interface(which have ipv6 address)
 */
inline bool sfe_dev_is_layer_3_interface(struct net_device *dev, bool check_v4)
{
	struct in_device *in4_dev;
	struct inet6_dev *in6_dev;

	BUG_ON(!dev);

	if (likely(check_v4)) {
		/*
		 * Does our input device support IPv4 processing?
		 */
		in4_dev = (struct in_device *)dev->ip_ptr;
		if (unlikely(!in4_dev)) {
			return false;
		}

		/*
		 * Does it have an IPv4 address?  If it doesn't then it
		 * could be map-t, dslite or tun6rd interface, otherwise we
		 * can't do anything interesting here!
		 */
		if (likely(in4_dev->ifa_list || (dev->priv_flags_ext & IFF_EXT_MAPT)
					     || (dev->rtnl_link_ops
					     && (!strcmp(dev->rtnl_link_ops->kind, "ip6tnl")
					     || !strcmp(dev->rtnl_link_ops->kind, "sit"))))) {
			return true;
		}
		return false;
	}

	/*
	 * Does our input device support IPv6 processing?
	 */
	in6_dev = (struct inet6_dev *)dev->ip6_ptr;
	if (unlikely(!in6_dev)) {
		return false;
	}

	/*
	 * Does it have an IPv6 address?  If it doesn't then it could be MAP-T interface,
	 * else we can't do anything interesting here!
	 */
	if (likely(!list_empty(&in6_dev->addr_list) || (dev->priv_flags_ext & IFF_EXT_MAPT))) {
		return true;
	}

	return false;
}

/*
 * sfe_routed_dev_allow()
 *	check whether routed acceleration allowed
 */
static bool sfe_routed_dev_allow(struct net_device *dev, bool is_routed,  bool check_v4)
{
	if (!is_routed) {
		return true;
	}

	if (sfe_dev_is_layer_3_interface(dev, check_v4)) {
		return true;
	}

	/*
	 * in case of GRE / vxlan, these dev does not have IP address
	 * so l3 interface check will fail. allow rule creation between gre / vxlan
	 * and wan dev for routed flow.
	 */
	if (netif_is_vxlan(dev)) {
		return true;
	}

#ifdef SFE_GRE_TUN_ENABLE
	if (netif_is_gretap(dev) || netif_is_gre(dev)) {
		return true;
	}

	if (netif_is_ip6gre(dev) || netif_is_ip6gretap(dev)) {
		return true;
	}
#endif

	if (dev->type == SFE_IPSEC_TUNNEL_TYPE) {
		return true;
	}

	return false;
}

/* sfe_dev_has_hw_csum()
 *	check whether device supports hardware checksum offload
 */
bool sfe_dev_has_hw_csum(struct net_device *dev)
{
	if (netif_is_vxlan(dev)) {
		return false;
	}

#ifdef SFE_GRE_TUN_ENABLE
	if (netif_is_gre(dev) || netif_is_gretap(dev)) {
		return false;
	}

	if (netif_is_ip6gre(dev) || netif_is_ip6gretap(dev)) {
		return false;
	}
#endif
	/*
	 * Tunnel MAP-E/DS-LITE and Tun6rd share the same Routing netlink operator
	 * whose kind is "ip6tnl". The HW csum for these tunnel devices should be disabled.
	*/
	if (dev->rtnl_link_ops && !strcmp(dev->rtnl_link_ops->kind, "ip6tnl")) {
		return false;
	}

	if (dev->type == SFE_IPSEC_TUNNEL_TYPE) {
		return false;
	}

	return true;
}

/*
 * sfe_clean_response_msg_by_type()
 * 	clean response message in queue when ECM exit
 *
 * @param sfe_ctx SFE context
 * @param msg_type message type, ipv4 or ipv6
 */
static void sfe_clean_response_msg_by_type(struct sfe_ctx_instance_internal *sfe_ctx, sfe_msg_types_t msg_type)
{
	struct sfe_response_msg *response, *tmp;

	if (!sfe_ctx) {
		return;
	}

	spin_lock_bh(&sfe_ctx->lock);
	list_for_each_entry_safe(response, tmp, &sfe_ctx->msg_queue, node) {
		if (response->type == msg_type) {
			list_del(&response->node);
			/*
			 * Free response message
			 */
			kfree(response);
		}
	}
	spin_unlock_bh(&sfe_ctx->lock);

}

/*
 * sfe_process_response_msg()
 * 	Send all pending response message to ECM by calling callback function included in message
 *
 * @param work work structure
 */
static void sfe_process_response_msg(struct work_struct *work)
{
	struct sfe_ctx_instance_internal *sfe_ctx = container_of(work, struct sfe_ctx_instance_internal, work);
	struct sfe_response_msg *response;

	spin_lock_bh(&sfe_ctx->lock);
	while ((response = list_first_entry_or_null(&sfe_ctx->msg_queue, struct sfe_response_msg, node))) {
		list_del(&response->node);
		spin_unlock_bh(&sfe_ctx->lock);
		rcu_read_lock();

		/*
		 * Send response message back to caller
		 */
		if ((response->type == SFE_MSG_TYPE_IPV4) && !sfe_ipv4_stopped(sfe_ctx)) {
			struct sfe_ipv4_msg *msg = (struct sfe_ipv4_msg *)response->msg;
			sfe_ipv4_msg_callback_t callback = (sfe_ipv4_msg_callback_t)msg->cm.cb;
			if (callback) {
				callback((void *)msg->cm.app_data, msg);
			}
		} else if ((response->type == SFE_MSG_TYPE_IPV6) && !sfe_ipv6_stopped(sfe_ctx)) {
			struct sfe_ipv6_msg *msg = (struct sfe_ipv6_msg *)response->msg;
			sfe_ipv6_msg_callback_t callback = (sfe_ipv6_msg_callback_t)msg->cm.cb;
			if (callback) {
				callback((void *)msg->cm.app_data, msg);
			}
		}

		rcu_read_unlock();
		/*
		 * Free response message
		 */
		kfree(response);
		spin_lock_bh(&sfe_ctx->lock);
	}
	spin_unlock_bh(&sfe_ctx->lock);
}

/*
 * sfe_alloc_response_msg()
 * 	Alloc and construct new response message
 *
 * @param type message type
 * @param msg used to construct response message if not NULL
 *
 * @return !NULL, success; NULL, failed
 */
static struct sfe_response_msg *
sfe_alloc_response_msg(sfe_msg_types_t type, void *msg)
{
	struct sfe_response_msg *response;
	int size;

	switch (type) {
	case SFE_MSG_TYPE_IPV4:
		size = sizeof(struct sfe_ipv4_msg);
		break;
	case SFE_MSG_TYPE_IPV6:
		size = sizeof(struct sfe_ipv6_msg);
		break;
	default:
		DEBUG_ERROR("message type %d not supported\n", type);
		return NULL;
	}

	response = (struct sfe_response_msg *)kzalloc(sizeof(struct sfe_response_msg) + size, GFP_ATOMIC);
	if (!response) {
		DEBUG_ERROR("allocate memory failed\n");
		return NULL;
	}

	response->type = type;

	if (msg) {
		memcpy(response->msg, msg, size);
	}

	return response;
}

/*
 * sfe_fast_xmit_check()
 *	Check the fast transmit feasibility.
 *
 * This check the per direction's  attribute that could not go fast
 * transmit
 * xfrm packets, come from a local socket or need sk validation on the skb
 */
bool sfe_fast_xmit_check(struct sk_buff *skb, netdev_features_t features)
{

#ifdef CONFIG_SOCK_VALIDATE_XMIT
	if (skb->sk && sk_fullsock(skb->sk) && skb->sk->sk_validate_xmit_skb) {
		DEBUG_INFO("%px:need sk validation\n", skb);
		return false;
#ifdef CONFIG_TLS_DEVICE
	} else if (skb->decrypted) {
		DEBUG_INFO("%px:SK or decrypted\n", skb);
		return false;
#endif
	}
#endif
	if (skb_vlan_tag_present(skb)) {
		DEBUG_INFO("%px:Vlan is present\n", skb);
		return false;
	}

	if (netif_needs_gso(skb, features)) {
		DEBUG_INFO("%px:Need to be gso\n", skb);
		return false;
	}

	if (skb_sec_path(skb)) {
		DEBUG_INFO("%px:XFRM is present\n", skb);
		return false;
	}

	return true;
}

/*
 * sfe_enqueue_msg()
 * 	Queue response message
 *
 * @param sfe_ctx SFE context
 * @param response response message to be queue
 */
static inline void sfe_enqueue_msg(struct sfe_ctx_instance_internal *sfe_ctx, struct sfe_response_msg *response)
{
	spin_lock_bh(&sfe_ctx->lock);
	list_add_tail(&response->node, &sfe_ctx->msg_queue);
	spin_unlock_bh(&sfe_ctx->lock);

	schedule_work(&sfe_ctx->work);
}

/*
 * sfe_cmn_msg_init()
 *	Initialize the common message structure.
 *
 * @param ncm message to init
 * @param if_num interface number related with this message
 * @param type message type
 * @param cb callback function to process repsonse of this message
 * @param app_data argument for above callback function
 */
static void sfe_cmn_msg_init(struct sfe_cmn_msg *ncm, u16 if_num, u32 type,  u32 len, void *cb, void *app_data)
{
	ncm->interface = if_num;
	ncm->version = SFE_MESSAGE_VERSION;
	ncm->type = type;
	ncm->len = len;
	ncm->cb = (sfe_ptr_t)cb;
	ncm->app_data = (sfe_ptr_t)app_data;
}

/*
 * sfe_ipv4_stats_many_sync_callback()
 *	Synchronize many connection's state.
 *
 * @param SFE statistics from SFE core engine
 */
static void sfe_ipv4_stats_many_sync_callback(struct sfe_ipv4_msg *msg)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	sfe_ipv4_msg_callback_t sync_cb;

	rcu_read_lock();
	sync_cb = rcu_dereference(sfe_ctx->ipv4_stats_sync_many_cb);
	rcu_read_unlock();
	if (!sync_cb) {
		sfe_incr_exceptions(SFE_EXCEPTION_NO_SYNC_CB);
		return;
	}
	sync_cb(sfe_ctx->ipv4_stats_sync_data, msg);
}

/*
 * sfe_ipv4_stats_convert()
 *	Convert the internal message format to ecm format.
 *
 * @param sync_msg stat msg to ecm
 * @param sis SFE statistics from SFE core engine
 */
void sfe_ipv4_stats_convert(struct sfe_ipv4_conn_sync *sync_msg, struct sfe_connection_sync *sis)
{
	/*
	 * Fill connection specific information
	 */
	sync_msg->protocol = (u8)sis->protocol;
	sync_msg->flow_ip = sis->src_ip.ip;
	sync_msg->flow_ip_xlate = sis->src_ip_xlate.ip;
	sync_msg->flow_ident = sis->src_port;
	sync_msg->flow_ident_xlate = sis->src_port_xlate;

	sync_msg->return_ip = sis->dest_ip.ip;
	sync_msg->return_ip_xlate = sis->dest_ip_xlate.ip;
	sync_msg->return_ident = sis->dest_port;
	sync_msg->return_ident_xlate = sis->dest_port_xlate;

	/*
	 * Fill TCP protocol specific information
	 */
	if (sis->protocol == IPPROTO_TCP) {
		sync_msg->flow_max_window = sis->src_td_max_window;
		sync_msg->flow_end = sis->src_td_end;
		sync_msg->flow_max_end = sis->src_td_max_end;

		sync_msg->return_max_window = sis->dest_td_max_window;
		sync_msg->return_end = sis->dest_td_end;
		sync_msg->return_max_end = sis->dest_td_max_end;
	}

	/*
	 * Fill statistics information
	 */
	sync_msg->flow_rx_packet_count = sis->src_new_packet_count;
	sync_msg->flow_rx_byte_count = sis->src_new_byte_count;
	sync_msg->flow_tx_packet_count = sis->dest_new_packet_count;
	sync_msg->flow_tx_byte_count = sis->dest_new_byte_count;

	sync_msg->return_rx_packet_count = sis->dest_new_packet_count;
	sync_msg->return_rx_byte_count = sis->dest_new_byte_count;
	sync_msg->return_tx_packet_count = sis->src_new_packet_count;
	sync_msg->return_tx_byte_count = sis->src_new_byte_count;

	/*
	 * Fill expiration time to extend, in unit of msec
	 */
	sync_msg->inc_ticks = (((u32)sis->delta_jiffies) * MSEC_PER_SEC)/HZ;

	/*
	 * Fill other information
	 */
	switch (sis->reason) {
	case SFE_SYNC_REASON_DESTROY:
		sync_msg->reason = SFE_RULE_SYNC_REASON_DESTROY;
		break;
	case SFE_SYNC_REASON_FLUSH:
		sync_msg->reason = SFE_RULE_SYNC_REASON_FLUSH;
		break;
	default:
		sync_msg->reason = SFE_RULE_SYNC_REASON_STATS;
		break;
	}
	return;
}

/*
 * sfe_ipv4_stats_one_sync_callback()
 *	Synchronize a connection's state.
 *
 * @param sis SFE statistics from SFE core engine
 */
static void sfe_ipv4_stats_one_sync_callback(struct sfe_connection_sync *sis)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	struct sfe_ipv4_msg msg;
	struct sfe_ipv4_conn_sync *sync_msg;
	sfe_ipv4_msg_callback_t sync_cb;

	rcu_read_lock();
	sync_cb = rcu_dereference(sfe_ctx->ipv4_stats_sync_cb);
	rcu_read_unlock();
	if (!sync_cb) {
		sfe_incr_exceptions(SFE_EXCEPTION_NO_SYNC_CB);
		return;
	}

	sync_msg = &msg.msg.conn_stats;

	memset(&msg, 0, sizeof(msg));
	sfe_cmn_msg_init(&msg.cm, 0, SFE_RX_CONN_STATS_SYNC_MSG,
			sizeof(struct sfe_ipv4_conn_sync), NULL, NULL);

	sfe_ipv4_stats_convert(sync_msg, sis);

	/*
	 * SFE sync calling is excuted in a timer, so we can redirect it to ECM directly.
	 */
	sync_cb(sfe_ctx->ipv4_stats_sync_data, &msg);
}

/*
 * sfe_recv_parse_l2()
 *	Parse L2 headers
 *
 * Returns true if the packet is parsed and false otherwise.
 */
static bool sfe_recv_parse_l2(struct net_device *dev, struct sk_buff *skb, struct sfe_l2_info *l2_info)
{
	/*
	 * VLAN parsing
	 */
	if (unlikely(!sfe_vlan_check_and_parse_tag(skb, l2_info))) {
		return false;
	}

	/*
	 * Parse only PPPoE session packets
	 */
	if (htons(ETH_P_PPP_SES) == skb->protocol) {
		if (!sfe_pppoe_parse_hdr(skb, l2_info)) {

			/*
			 * For exception from PPPoE return from here without modifying the skb->data
			 * This includes non-IPv4/v6 cases also
			 */
			return false;
		}
	}
	return true;
}

/*
 * sfe_recv_undo_parse_l2()
 */
static void sfe_recv_undo_parse_l2(struct net_device *dev, struct sk_buff *skb, struct sfe_l2_info *l2_info)
{
	/*
	 * PPPoE undo
	 */
	sfe_pppoe_undo_parse(skb, l2_info);

	/*
	 * VLAN undo
	 */
	sfe_vlan_undo_parse(skb, l2_info);

	/*
	 * packet is not handled by SFE, so reset the network header
	 */
	skb_reset_network_header(skb);
}

/*
 * sfe_create_ipv4_rule_msg()
 * 	Convert create message format from ecm to sfe
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv4 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_create_ipv4_rule_msg(struct sfe_ctx_instance_internal *sfe_ctx, struct sfe_ipv4_msg *msg)
{
	struct net_device *src_dev = NULL;
	struct net_device *dest_dev = NULL;
	struct sfe_response_msg *response;
	enum sfe_cmn_response ret = SFE_TX_SUCCESS;
	bool is_routed = true;
	bool cfg_err;

	response = sfe_alloc_response_msg(SFE_MSG_TYPE_IPV4, msg);
	if (!response) {
		sfe_incr_exceptions(SFE_EXCEPTION_ENQUEUE_FAILED);
		return SFE_TX_FAILURE_QUEUE;
	}

	if (!(msg->msg.rule_create.valid_flags & SFE_RULE_CREATE_CONN_VALID)) {
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CONNECTION_INVALID);
		goto failed_ret;
	}

	switch (msg->msg.rule_create.tuple.protocol) {
	case IPPROTO_TCP:
		if (!(msg->msg.rule_create.valid_flags & SFE_RULE_CREATE_TCP_VALID)) {
			ret = SFE_CMN_RESPONSE_EMSG;
			sfe_incr_exceptions(SFE_EXCEPTION_TCP_INVALID);
			goto failed_ret;
		}
		break;

	case IPPROTO_UDP:
		break;

	case IPPROTO_GRE:
		break;

	case IPPROTO_IPV6:
		break;

	case IPPROTO_ESP:
		break;

	case IPPROTO_RAW:
		/*
		 * for accelerating PPPoE bridged flows using 3-tuple information
		 */
		break;

	default:
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_PROTOCOL_NOT_SUPPORT);
		goto failed_ret;
	}

	/*
	 * Bridge flows are accelerated if L2 feature is enabled.
	 */
	if (msg->msg.rule_create.rule_flags & SFE_RULE_CREATE_FLAG_BRIDGE_FLOW) {
		if (!sfe_is_l2_feature_enabled()) {
			ret = SFE_CMN_RESPONSE_EINTERFACE;
			sfe_incr_exceptions(SFE_EXCEPTION_NOT_SUPPORT_BRIDGE);
			goto failed_ret;
		}

		is_routed = false;
	}

	/*
	 * Does our input device support IP processing?
	 */
	src_dev = dev_get_by_index(&init_net, msg->msg.rule_create.conn_rule.flow_top_interface_num);
	if (!src_dev || !sfe_routed_dev_allow(src_dev, is_routed, true)) {
		ret = SFE_CMN_RESPONSE_EINTERFACE;
		sfe_incr_exceptions(SFE_EXCEPTION_SRC_DEV_NOT_L3);
		goto failed_ret;
	}

	/*
	 * Check whether L2 feature is disabled and rule flag is configured to use bottom interface
	 */
	cfg_err = (msg->msg.rule_create.rule_flags & SFE_RULE_CREATE_FLAG_USE_FLOW_BOTTOM_INTERFACE) && !sfe_is_l2_feature_enabled();
	if (cfg_err) {
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CFG_ERR);
		goto failed_ret;
	}

	/*
	 * Does our output device support IP processing?
	 */
	dest_dev = dev_get_by_index(&init_net, msg->msg.rule_create.conn_rule.return_top_interface_num);
	if (!dest_dev || !sfe_routed_dev_allow(dest_dev, is_routed, true)) {
		ret = SFE_CMN_RESPONSE_EINTERFACE;
		sfe_incr_exceptions(SFE_EXCEPTION_DEST_DEV_NOT_L3);
		goto failed_ret;
	}

	/*
	 * Check whether L2 feature is disabled and rule flag is configured to use bottom interface
	 */
	cfg_err = (msg->msg.rule_create.rule_flags & SFE_RULE_CREATE_FLAG_USE_RETURN_BOTTOM_INTERFACE) && !sfe_is_l2_feature_enabled();
	if (cfg_err) {
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CFG_ERR);
		goto failed_ret;
	}

	if (!sfe_ipv4_create_rule(&msg->msg.rule_create)) {
		/* success */
		ret = SFE_CMN_RESPONSE_ACK;
	} else {
		/* Failed */
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CREATE_FAILED);
	}

	/*
	 * Fall through
	 */
failed_ret:
	if (src_dev) {
		dev_put(src_dev);
	}

	if (dest_dev) {
		dev_put(dest_dev);
	}

	/*
	 * Try to queue response message
	 */
	((struct sfe_ipv4_msg *)response->msg)->cm.response = msg->cm.response = ret;
	sfe_enqueue_msg(sfe_ctx, response);

	return SFE_TX_SUCCESS;
}

/*
 * sfe_destroy_ipv4_rule_msg()
 * 	Convert destroy message format from ecm to sfe
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv4 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_destroy_ipv4_rule_msg(struct sfe_ctx_instance_internal *sfe_ctx, struct sfe_ipv4_msg *msg)
{
	struct sfe_response_msg *response;

	response = sfe_alloc_response_msg(SFE_MSG_TYPE_IPV4, msg);
	if (!response) {
		sfe_incr_exceptions(SFE_EXCEPTION_ENQUEUE_FAILED);
		return SFE_TX_FAILURE_QUEUE;
	}

	sfe_ipv4_destroy_rule(&msg->msg.rule_destroy);

	/*
	 * Try to queue response message
	 */
	((struct sfe_ipv4_msg *)response->msg)->cm.response = msg->cm.response = SFE_CMN_RESPONSE_ACK;
	sfe_enqueue_msg(sfe_ctx, response);

	return SFE_TX_SUCCESS;
}

/*
 * sfe_sync_ipv4_stats_many_msg()
 * 	sync con stats msg from the ecm
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv4 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_sync_ipv4_stats_many_msg(struct sfe_ctx_instance_internal *sfe_ctx, struct sfe_ipv4_msg *msg)
{
	struct sfe_ipv4_conn_sync_many_msg *nicsm;
	nicsm = &(msg->msg.conn_stats_many);

	if (sfe_ipv4_sync_invoke(nicsm->index)) {
		return SFE_TX_SUCCESS;
	}
	return SFE_TX_FAILURE;
}

/*
 * sfe_ipv4_tx()
 * 	Transmit an IPv4 message to the sfe
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv4 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_ipv4_tx(struct sfe_ctx_instance *sfe_ctx, struct sfe_ipv4_msg *msg)
{
	switch (msg->cm.type) {
	case SFE_TX_CREATE_RULE_MSG:
		return sfe_create_ipv4_rule_msg(SFE_CTX_TO_PRIVATE(sfe_ctx), msg);
	case SFE_TX_DESTROY_RULE_MSG:
		return sfe_destroy_ipv4_rule_msg(SFE_CTX_TO_PRIVATE(sfe_ctx), msg);
	case SFE_TX_CONN_STATS_SYNC_MANY_MSG:
		return sfe_sync_ipv4_stats_many_msg(SFE_CTX_TO_PRIVATE(sfe_ctx),msg);
	default:
		sfe_incr_exceptions(SFE_EXCEPTION_IPV4_MSG_UNKNOW);
		return SFE_TX_FAILURE_NOT_ENABLED;
	}
}
EXPORT_SYMBOL(sfe_ipv4_tx);

/*
 * sfe_ipv4_msg_init()
 *	Initialize IPv4 message.
 */
void sfe_ipv4_msg_init(struct sfe_ipv4_msg *nim, u16 if_num, u32 type, u32 len,
			sfe_ipv4_msg_callback_t cb, void *app_data)
{
	sfe_cmn_msg_init(&nim->cm, if_num, type, len, (void *)cb, app_data);
}
EXPORT_SYMBOL(sfe_ipv4_msg_init);

/*
 * sfe_ipv4_max_conn_count()
 * 	Return maximum number of entries SFE supported
 */
int sfe_ipv4_max_conn_count(void)
{
	return max_ipv4_conn;
}
EXPORT_SYMBOL(sfe_ipv4_max_conn_count);

/*
 * sfe_ipv4_notify_register()
 * 	Register a notifier callback for IPv4 messages from SFE
 *
 * @param cb The callback pointer
 * @param app_data The application context for this message
 *
 * @return struct sfe_ctx_instance * The SFE context
 */
struct sfe_ctx_instance *sfe_ipv4_notify_register(sfe_ipv4_msg_callback_t one_rule_cb,
		sfe_ipv4_msg_callback_t many_rules_cb,void *app_data)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;

	spin_lock_bh(&sfe_ctx->lock);
	/*
	 * Hook the shortcut sync callback.
	 */
	if (one_rule_cb && !sfe_ctx->ipv4_stats_sync_cb) {
		sfe_ipv4_register_sync_rule_callback(sfe_ipv4_stats_one_sync_callback);
	}
	rcu_assign_pointer(sfe_ctx->ipv4_stats_sync_cb, one_rule_cb);

	if (many_rules_cb && !sfe_ctx->ipv4_stats_sync_many_cb) {
		sfe_ipv4_register_many_sync_callback(sfe_ipv4_stats_many_sync_callback);
	}
	rcu_assign_pointer(sfe_ctx->ipv4_stats_sync_many_cb, many_rules_cb);

	sfe_ctx->ipv4_stats_sync_data = app_data;

	spin_unlock_bh(&sfe_ctx->lock);

	return SFE_CTX_TO_PUBLIC(sfe_ctx);
}
EXPORT_SYMBOL(sfe_ipv4_notify_register);

/*
 * sfe_ipv4_notify_unregister()
 * 	Un-Register the notifier callback for IPv4 messages from SFE
 */
void sfe_ipv4_notify_unregister(void)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;

	spin_lock_bh(&sfe_ctx->lock);

	/*
	 * Unregister our single rule msg sync callback.
	 */
	if (sfe_ctx->ipv4_stats_sync_cb) {
		sfe_ipv4_register_sync_rule_callback(NULL);
		rcu_assign_pointer(sfe_ctx->ipv4_stats_sync_cb, NULL);
	}

	/*
	 * Unregister our many rule msg sync callback.
	 */
	if (sfe_ctx->ipv4_stats_sync_many_cb) {
		sfe_ipv4_register_many_sync_callback(NULL);
		rcu_assign_pointer(sfe_ctx->ipv4_stats_sync_many_cb, NULL);
	}

	sfe_ctx->ipv4_stats_sync_data = NULL;

	spin_unlock_bh(&sfe_ctx->lock);

	sfe_clean_response_msg_by_type(sfe_ctx, SFE_MSG_TYPE_IPV4);
	return;
}
EXPORT_SYMBOL(sfe_ipv4_notify_unregister);

/*
 * sfe_ipv6_many_stats_sync_callback()
 *	Synchronize many connection's state.
 */
static void sfe_ipv6_many_stats_sync_callback(struct sfe_ipv6_msg *msg)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	sfe_ipv6_msg_callback_t sync_cb;

	rcu_read_lock();
	sync_cb = rcu_dereference(sfe_ctx->ipv6_stats_sync_many_cb);
	rcu_read_unlock();
	if (!sync_cb) {
		sfe_incr_exceptions(SFE_EXCEPTION_NO_SYNC_CB);
		return;
	}

	sync_cb(sfe_ctx->ipv6_stats_sync_data, msg);
}

/*
 * sfe_ipv6_stats_convert()
 *	Convert the internal message format to ecm format.
 *
 * @param sync_msg stat msg to ecm
 * @param sis SFE statistics from SFE core engine
 */
void sfe_ipv6_stats_convert(struct sfe_ipv6_conn_sync *sync_msg, struct sfe_connection_sync *sis)
{
	/*
	 * Fill connection specific information
	 */
	sync_msg->protocol = (u8)sis->protocol;
	sfe_ipv6_addr_copy(sis->src_ip.ip6, sync_msg->flow_ip);
	sync_msg->flow_ident = sis->src_port;

	sfe_ipv6_addr_copy(sis->dest_ip.ip6, sync_msg->return_ip);
	sync_msg->return_ident = sis->dest_port;

	/*
	 * Fill TCP protocol specific information
	 */
	if (sis->protocol == IPPROTO_TCP) {
		sync_msg->flow_max_window = sis->src_td_max_window;
		sync_msg->flow_end = sis->src_td_end;
		sync_msg->flow_max_end = sis->src_td_max_end;

		sync_msg->return_max_window = sis->dest_td_max_window;
		sync_msg->return_end = sis->dest_td_end;
		sync_msg->return_max_end = sis->dest_td_max_end;
	}

	/*
	 * Fill statistics information
	 */
	sync_msg->flow_rx_packet_count = sis->src_new_packet_count;
	sync_msg->flow_rx_byte_count = sis->src_new_byte_count;
	sync_msg->flow_tx_packet_count = sis->dest_new_packet_count;
	sync_msg->flow_tx_byte_count = sis->dest_new_byte_count;

	sync_msg->return_rx_packet_count = sis->dest_new_packet_count;
	sync_msg->return_rx_byte_count = sis->dest_new_byte_count;
	sync_msg->return_tx_packet_count = sis->src_new_packet_count;
	sync_msg->return_tx_byte_count = sis->src_new_byte_count;

	/*
	 * Fill expiration time to extend, in unit of msec
	 */
	sync_msg->inc_ticks = (((u32)sis->delta_jiffies) * MSEC_PER_SEC)/HZ;

	/*
	 * Fill other information
	 */
	switch (sis->reason) {
	case SFE_SYNC_REASON_DESTROY:
		sync_msg->reason = SFE_RULE_SYNC_REASON_DESTROY;
		break;
	case SFE_SYNC_REASON_FLUSH:
		sync_msg->reason = SFE_RULE_SYNC_REASON_FLUSH;
		break;
	default:
		sync_msg->reason = SFE_RULE_SYNC_REASON_STATS;
		break;
	}

	return;
}

/*
 * sfe_ipv6_stats_sync_callback()
 *	Synchronize a connection's state.
 */
static void sfe_ipv6_stats_sync_callback(struct sfe_connection_sync *sis)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	struct sfe_ipv6_msg msg;
	struct sfe_ipv6_conn_sync *sync_msg;
	sfe_ipv6_msg_callback_t sync_cb;

	rcu_read_lock();
	sync_cb = rcu_dereference(sfe_ctx->ipv6_stats_sync_cb);
	rcu_read_unlock();
	if (!sync_cb) {
		sfe_incr_exceptions(SFE_EXCEPTION_NO_SYNC_CB);
		return;
	}

	sync_msg = &msg.msg.conn_stats;

	memset(&msg, 0, sizeof(msg));
	sfe_cmn_msg_init(&msg.cm, 0, SFE_RX_CONN_STATS_SYNC_MSG,
			sizeof(struct sfe_ipv6_conn_sync), NULL, NULL);

	sfe_ipv6_stats_convert(sync_msg, sis);

	/*
	 * SFE sync calling is excuted in a timer, so we can redirect it to ECM directly.
	 */
	sync_cb(sfe_ctx->ipv6_stats_sync_data, &msg);
}

/*
 * sfe_create_ipv6_rule_msg()
 * 	convert create message format from ecm to sfe
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv6 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_create_ipv6_rule_msg(struct sfe_ctx_instance_internal *sfe_ctx, struct sfe_ipv6_msg *msg)
{
	struct net_device *src_dev = NULL;
	struct net_device *dest_dev = NULL;
	struct sfe_response_msg *response;
	enum sfe_cmn_response ret = SFE_TX_SUCCESS;
	bool is_routed = true;
	bool cfg_err;

	response = sfe_alloc_response_msg(SFE_MSG_TYPE_IPV6, msg);
	if (!response) {
		sfe_incr_exceptions(SFE_EXCEPTION_ENQUEUE_FAILED);
		return SFE_TX_FAILURE_QUEUE;
	}

	if (!(msg->msg.rule_create.valid_flags & SFE_RULE_CREATE_CONN_VALID)) {
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CONNECTION_INVALID);
		goto failed_ret;
	}

	/*
	 * Bridge flows are accelerated if L2 feature is enabled.
	 */
	if (msg->msg.rule_create.rule_flags & SFE_RULE_CREATE_FLAG_BRIDGE_FLOW) {
		if (!sfe_is_l2_feature_enabled()) {
			ret = SFE_CMN_RESPONSE_EINTERFACE;
			sfe_incr_exceptions(SFE_EXCEPTION_NOT_SUPPORT_BRIDGE);
			goto failed_ret;
		}
		is_routed = false;
	}

	switch(msg->msg.rule_create.tuple.protocol) {

	case IPPROTO_TCP:
		if (!(msg->msg.rule_create.valid_flags & SFE_RULE_CREATE_TCP_VALID)) {
			ret = SFE_CMN_RESPONSE_EMSG;
			sfe_incr_exceptions(SFE_EXCEPTION_TCP_INVALID);
			goto failed_ret;
		}

		break;

	case IPPROTO_UDP:
		break;

	case IPPROTO_IPIP:
		break;

	case IPPROTO_GRE:
		break;

	case IPPROTO_ESP:
		break;

	case IPPROTO_RAW:
		/*
		 * for accelerating PPPoE bridged flows using 3-tuple information
		 */
		break;

	default:
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_PROTOCOL_NOT_SUPPORT);
		goto failed_ret;
	}

	/*
	 * Does our input device support IP processing?
	 */
	src_dev = dev_get_by_index(&init_net, msg->msg.rule_create.conn_rule.flow_top_interface_num);
	if (!src_dev || !sfe_routed_dev_allow(src_dev, is_routed, false)) {
		ret = SFE_CMN_RESPONSE_EINTERFACE;
		sfe_incr_exceptions(SFE_EXCEPTION_SRC_DEV_NOT_L3);
		goto failed_ret;
	}

	/*
	 * Check whether L2 feature is disabled and rule flag is configured to use bottom interface
	 */
	cfg_err = (msg->msg.rule_create.rule_flags & SFE_RULE_CREATE_FLAG_USE_FLOW_BOTTOM_INTERFACE) && !sfe_is_l2_feature_enabled();
	if (cfg_err) {
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CFG_ERR);
		goto failed_ret;
	}

	/*
	 * Does our output device support IP processing?
	 */
	dest_dev = dev_get_by_index(&init_net, msg->msg.rule_create.conn_rule.return_top_interface_num);
	if (!dest_dev || !sfe_routed_dev_allow(dest_dev, is_routed, false)) {
		ret = SFE_CMN_RESPONSE_EINTERFACE;
		sfe_incr_exceptions(SFE_EXCEPTION_DEST_DEV_NOT_L3);
		goto failed_ret;
	}

	/*
	 * Check whether L2 feature is disabled and rule flag is configured to use bottom interface
	 */
	cfg_err = (msg->msg.rule_create.rule_flags & SFE_RULE_CREATE_FLAG_USE_RETURN_BOTTOM_INTERFACE) && !sfe_is_l2_feature_enabled();
	if (cfg_err) {
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CFG_ERR);
		goto failed_ret;
	}

	if (!sfe_ipv6_create_rule(&msg->msg.rule_create)) {
		/* success */
		ret = SFE_CMN_RESPONSE_ACK;
	} else {
		/* Failed */
		ret = SFE_CMN_RESPONSE_EMSG;
		sfe_incr_exceptions(SFE_EXCEPTION_CREATE_FAILED);
	}

	/*
	 * Fall through
	 */
failed_ret:
	if (src_dev) {
		dev_put(src_dev);
	}

	if (dest_dev) {
		dev_put(dest_dev);
	}

	/*
	 * Try to queue response message
	 */
	((struct sfe_ipv6_msg *)response->msg)->cm.response = msg->cm.response = ret;
	sfe_enqueue_msg(sfe_ctx, response);

	return SFE_TX_SUCCESS;
}

/*
 * sfe_destroy_ipv6_rule_msg()
 * 	Convert destroy message format from ecm to sfe
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv6 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_destroy_ipv6_rule_msg(struct sfe_ctx_instance_internal *sfe_ctx, struct sfe_ipv6_msg *msg)
{
	struct sfe_response_msg *response;

	response = sfe_alloc_response_msg(SFE_MSG_TYPE_IPV6, msg);
	if (!response) {
		sfe_incr_exceptions(SFE_EXCEPTION_ENQUEUE_FAILED);
		return SFE_TX_FAILURE_QUEUE;
	}

	sfe_ipv6_destroy_rule(&msg->msg.rule_destroy);

	/*
	 * Try to queue response message
	 */
	((struct sfe_ipv6_msg *)response->msg)->cm.response = msg->cm.response = SFE_CMN_RESPONSE_ACK;
	sfe_enqueue_msg(sfe_ctx, response);

	return SFE_TX_SUCCESS;
}

/*
 * sfe_sync_ipv6_stats_many_msg()
 * 	sync con stats msg from the ecm
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv6 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_sync_ipv6_stats_many_msg(struct sfe_ctx_instance_internal *sfe_ctx, struct sfe_ipv6_msg *msg)
{
	struct sfe_ipv6_conn_sync_many_msg *nicsm;
	nicsm = &(msg->msg.conn_stats_many);

	if (sfe_ipv6_sync_invoke(nicsm->index)) {
		return SFE_TX_SUCCESS;
	}
	return SFE_TX_FAILURE;
}

/*
 * sfe_ipv6_tx()
 * 	Transmit an IPv6 message to the sfe
 *
 * @param sfe_ctx SFE context
 * @param msg The IPv6 message
 *
 * @return sfe_tx_status_t The status of the Tx operation
 */
sfe_tx_status_t sfe_ipv6_tx(struct sfe_ctx_instance *sfe_ctx, struct sfe_ipv6_msg *msg)
{
	switch (msg->cm.type) {
	case SFE_TX_CREATE_RULE_MSG:
		return sfe_create_ipv6_rule_msg(SFE_CTX_TO_PRIVATE(sfe_ctx), msg);
	case SFE_TX_DESTROY_RULE_MSG:
		return sfe_destroy_ipv6_rule_msg(SFE_CTX_TO_PRIVATE(sfe_ctx), msg);
	case SFE_TX_CONN_STATS_SYNC_MANY_MSG:
		return sfe_sync_ipv6_stats_many_msg(SFE_CTX_TO_PRIVATE(sfe_ctx), msg);
	default:
		sfe_incr_exceptions(SFE_EXCEPTION_IPV6_MSG_UNKNOW);
		return SFE_TX_FAILURE_NOT_ENABLED;
	}
}
EXPORT_SYMBOL(sfe_ipv6_tx);

/*
 * sfe_ipv6_msg_init()
 *	Initialize IPv6 message.
 */
void sfe_ipv6_msg_init(struct sfe_ipv6_msg *nim, u16 if_num, u32 type, u32 len,
			sfe_ipv6_msg_callback_t cb, void *app_data)
{
	sfe_cmn_msg_init(&nim->cm, if_num, type, len, (void *)cb, app_data);
}
EXPORT_SYMBOL(sfe_ipv6_msg_init);

/*
 * sfe_ipv6_max_conn_count()
 * 	Return maximum number of entries SFE supported
 */
int sfe_ipv6_max_conn_count(void)
{
	return max_ipv6_conn;
}
EXPORT_SYMBOL(sfe_ipv6_max_conn_count);

/*
 * sfe_ipv6_notify_register()
 * 	Register a notifier callback for IPv6 messages from SFE
 *
 * @param one_rule_cb The callback pointer of one rule sync
 * @param many_rule_cb The callback pointer of many rule sync
 * @param app_data The application context for this message
 *
 * @return struct sfe_ctx_instance * The SFE context
 */
struct sfe_ctx_instance *sfe_ipv6_notify_register(sfe_ipv6_msg_callback_t one_rule_cb,
		sfe_ipv6_msg_callback_t many_rule_cb, void *app_data)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;

	spin_lock_bh(&sfe_ctx->lock);
	/*
	 * Hook the shortcut sync callback.
	 */
	if (one_rule_cb && !sfe_ctx->ipv6_stats_sync_cb) {
		sfe_ipv6_register_sync_rule_callback(sfe_ipv6_stats_sync_callback);
	}
	rcu_assign_pointer(sfe_ctx->ipv6_stats_sync_cb, one_rule_cb);

	if (many_rule_cb && !sfe_ctx->ipv6_stats_sync_many_cb) {
		sfe_ipv6_register_many_sync_callback(sfe_ipv6_many_stats_sync_callback);
	}
	rcu_assign_pointer(sfe_ctx->ipv6_stats_sync_many_cb, many_rule_cb);

	sfe_ctx->ipv6_stats_sync_data = app_data;

	spin_unlock_bh(&sfe_ctx->lock);

	return SFE_CTX_TO_PUBLIC(sfe_ctx);
}
EXPORT_SYMBOL(sfe_ipv6_notify_register);

/*
 * sfe_ipv6_notify_unregister()
 * 	Un-Register a notifier callback for IPv6 messages from SFE
 */
void sfe_ipv6_notify_unregister(void)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;

	spin_lock_bh(&sfe_ctx->lock);
	/*
	 * Unregister our sync callback.
	 */
	if (sfe_ctx->ipv6_stats_sync_cb) {
		sfe_ipv6_register_sync_rule_callback(NULL);
		rcu_assign_pointer(sfe_ctx->ipv6_stats_sync_cb, NULL);
	}

	if (sfe_ctx->ipv6_stats_sync_many_cb) {
		sfe_ipv6_register_many_sync_callback(NULL);
		rcu_assign_pointer(sfe_ctx->ipv6_stats_sync_many_cb, NULL);
	}

	sfe_ctx->ipv6_stats_sync_data = NULL;
	spin_unlock_bh(&sfe_ctx->lock);

	sfe_clean_response_msg_by_type(sfe_ctx, SFE_MSG_TYPE_IPV6);
	return;
}
EXPORT_SYMBOL(sfe_ipv6_notify_unregister);

/*
 * sfe_tun6rd_tx()
 * 	Transmit a tun6rd message to sfe engine
 */
sfe_tx_status_t sfe_tun6rd_tx(struct sfe_ctx_instance *sfe_ctx, struct sfe_tun6rd_msg *msg)
{
	sfe_incr_exceptions(SFE_EXCEPTION_NOT_SUPPORT_6RD);
	return SFE_TX_FAILURE_NOT_ENABLED;
}
EXPORT_SYMBOL(sfe_tun6rd_tx);

/*
 * sfe_tun6rd_msg_init()
 *      Initialize sfe_tun6rd msg.
 */
void sfe_tun6rd_msg_init(struct sfe_tun6rd_msg *ncm, u16 if_num, u32 type,  u32 len, void *cb, void *app_data)
{
	sfe_cmn_msg_init(&ncm->cm, if_num, type, len, cb, app_data);
}
EXPORT_SYMBOL(sfe_tun6rd_msg_init);

/*
 * sfe_recv()
 *	Handle packet receives.
 *
 * Returns 1 if the packet is forwarded or 0 if it isn't.
 */
int sfe_recv(struct sk_buff *skb)
{
	struct net_device *dev;
	struct sfe_l2_info l2_info;
	int ret;

	dev = skb->dev;

	/*
	 * Setting parse flags to 0 since l2_info is passed for non L2.5 header case as well
	 */
	l2_info.parse_flags = 0;
	l2_info.vlan_hdr_cnt = 0;

#ifdef CONFIG_NET_CLS_ACT
	/*
	 * If ingress Qdisc configured, and packet not processed by ingress Qdisc yet
	 * We can not accelerate this packet.
	 */
#if (LINUX_VERSION_CODE < KERNEL_VERSION(5, 4, 0))
	if (dev->ingress_queue && !(skb->tc_verd & TC_NCLS)) {
		return 0;
	}
#else
	if (rcu_access_pointer(dev->miniq_ingress) && !skb->tc_skip_classify) {
		return 0;
	}
#endif
#endif

	/*
	 * If l2_feature is enabled, we need not check if src dev is L3 interface since bridge flow offload is supported.
	 * If l2_feature is disabled, then we make sure src dev is L3 interface to avoid cost of rule lookup for L2 flows
	 */
	switch (ntohs(skb->protocol)) {
	case ETH_P_IP:
		if (likely(sfe_is_l2_feature_enabled()) || sfe_dev_is_layer_3_interface(dev, true)) {
			return sfe_ipv4_recv(dev, skb, &l2_info, false);
		}

		DEBUG_TRACE("No IPv4 address for device: %s skb=%px\n", dev->name, skb);
		return 0;

	case ETH_P_IPV6:
		if (likely(sfe_is_l2_feature_enabled()) || sfe_dev_is_layer_3_interface(dev, false)) {
			return sfe_ipv6_recv(dev, skb, &l2_info, false);
		}

		DEBUG_TRACE("No IPv6 address for device: %s skb=%px\n", dev->name, skb);
		return 0;

	default:
		break;
	}

	/*
	 * Stop L2 processing if L2 feature is disabled.
	 */
	if (!sfe_is_l2_feature_enabled()) {
		DEBUG_TRACE("Unsupported protocol %#x %s (L2 feature is disabled) skb=%px\n",
				ntohs(skb->protocol), dev->name, skb);
		return 0;
	}

	/*
	 * Parse the L2 headers to find the L3 protocol and the L2 header offset
	 */
	if (unlikely(!sfe_recv_parse_l2(dev, skb, &l2_info))) {
		DEBUG_TRACE("%px: Invalid L2.5 header format with protocol : %x\n", skb, ntohs(skb->protocol));
		goto send_to_linux;
	}

	/*
	 * Protocol in l2_info is expected to be in host byte order.
	 * PPPoE is doing it in the sfe_pppoe_parse_hdr()
	 */
	if (likely(l2_info.protocol == ETH_P_IP)) {
		ret = sfe_ipv4_recv(dev, skb, &l2_info, false);
		if (unlikely(!ret)) {
			goto send_to_linux;
		}
		return ret;
	}

	if (likely(l2_info.protocol == ETH_P_IPV6)) {
		ret = sfe_ipv6_recv(dev, skb, &l2_info, false);
		if (unlikely(!ret)) {
			goto send_to_linux;
		}
		return ret;
	}

	DEBUG_TRACE("Non-IP(%x) %s skb=%px skb_vlan:%x/%x/%x skb_proto=%x\n",
			l2_info.protocol, dev->name, skb,
			ntohs(skb->vlan_proto), skb->vlan_tci, skb_vlan_tag_present(skb),
		       	htons(skb->protocol));

send_to_linux:
	/*
	 * Push the data back before sending to linux if -
	 * a. There is any exception from IPV4/V6
	 * b. If the next protocol is neither IPV4 nor IPV6
	 */
	sfe_recv_undo_parse_l2(dev, skb, &l2_info);

	return 0;
}

/*
 * sfe_get_exceptions()
 *	Dump exception counters
 */
static ssize_t sfe_get_exceptions(struct device *dev,
				     struct device_attribute *attr,
				     char *buf)
{
	int idx, len;
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;

	spin_lock_bh(&sfe_ctx->lock);
	for (len = 0, idx = 0; idx < SFE_EXCEPTION_MAX; idx++) {
		if (sfe_ctx->exceptions[idx]) {
			len += snprintf(buf + len, (ssize_t)(PAGE_SIZE - len), "%s = %d\n", sfe_exception_events_string[idx], sfe_ctx->exceptions[idx]);
		}
	}
	spin_unlock_bh(&sfe_ctx->lock);

	return len;
}

/*
 * sysfs attributes.
 */
static const struct device_attribute sfe_exceptions_attr =
	__ATTR(exceptions, S_IRUGO, sfe_get_exceptions, NULL);


/*
 * sfe_service_class_stats_get()
 *	Collects ipv4 and ipv6 service class statistics and aggregates them.
 */
bool sfe_service_class_stats_get(uint8_t sid, uint64_t *bytes, uint64_t *packets)
{
	*bytes = 0;
	*packets = 0;

	if (!sfe_ipv4_service_class_stats_get(sid, bytes, packets)) {
		return false;
	}

	if (!sfe_ipv6_service_class_stats_get(sid, bytes, packets)) {
		return false;
	}

	return true;
}
EXPORT_SYMBOL(sfe_service_class_stats_get);

/*
 * sfe_is_l2_feature_enabled()
 *	Check if l2 features flag feature is enabled or not. (VLAN, PPPOE, BRIDGE and tunnels)
 *
 * 32bit read is atomic. No need of locks.
 */
bool sfe_is_l2_feature_enabled()
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	return (sfe_ctx->l2_feature_support == 1);
}
EXPORT_SYMBOL(sfe_is_l2_feature_enabled);

/*
 * sfe_get_l2_feature()
 *	L2 feature is enabled/disabled
 */
ssize_t sfe_get_l2_feature(struct device *dev,
				     struct device_attribute *attr,
				     char *buf)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	ssize_t len;

	spin_lock_bh(&sfe_ctx->lock);
	len = snprintf(buf, (ssize_t)(PAGE_SIZE), "L2 feature is %s\n", sfe_ctx->l2_feature_support ? "enabled" : "disabled");
	spin_unlock_bh(&sfe_ctx->lock);
	return len;
}

/*
 * sfe_set_l2_feature()
 *	Enable or disable l2 features flag.
 */
ssize_t sfe_set_l2_feature(struct device *dev, struct device_attribute *attr,
                         const char *buf, size_t count)
{
        unsigned long val;
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	int ret;
        ret = sscanf(buf, "%lu", &val);

	if (ret != 1) {
		pr_err("Wrong input, %s\n", buf);
		return -EINVAL;
	}

	if (val != 1 && val != 0) {
		pr_err("Input should be either 1 or 0, (%s)\n", buf);
		return -EINVAL;
	}

	spin_lock_bh(&sfe_ctx->lock);

	if (sfe_ctx->l2_feature_support && val) {
		spin_unlock_bh(&sfe_ctx->lock);
		pr_err("L2 feature is already enabled\n");
		return -EINVAL;
	}

	if (!sfe_ctx->l2_feature_support && !val) {
		spin_unlock_bh(&sfe_ctx->lock);
		pr_err("L2 feature is already disabled\n");
		return -EINVAL;
	}

	sfe_ctx->l2_feature_support = val;
	spin_unlock_bh(&sfe_ctx->lock);

	return count;
}

static const struct device_attribute sfe_l2_feature_attr =
	__ATTR(l2_feature,  0644, sfe_get_l2_feature, sfe_set_l2_feature);

/*
 * sfe_get_pppoe_br_accel_mode()
 *	Get PPPoE bridge acceleration mode
 */
static ssize_t sfe_get_pppoe_br_accel_mode(struct device *dev,
					struct device_attribute *attr,
					char *buf)
{
	int len;
	sfe_pppoe_br_accel_mode_t mode;
	char *str;

	mode = sfe_pppoe_get_br_accel_mode();
	switch ((int)mode) {
	case SFE_PPPOE_BR_ACCEL_MODE_DISABLED:
		str = "ACCEL_MODE_DISABLED";
		break;

	case SFE_PPPOE_BR_ACCEL_MODE_EN_5T:
		str = "ACCEL_MODE_5_TUPLE";
		break;

	case SFE_PPPOE_BR_ACCEL_MODE_EN_3T:
		str = "ACCEL_MODE_3_TUPLE";
		break;

	default:
		str = "Unknown ACCEL_MODE";
		break;
	}
	len = snprintf(buf, PAGE_SIZE, "%s\n", str);

	return len;
}

/*
 * sfe_set_pppoe_br_accel_mode()
 *	Set PPPoE bridge acceleration mode
 */
static ssize_t sfe_set_pppoe_br_accel_mode(struct device *dev,
				struct device_attribute *attr,
				const char *buf,
				size_t count)
{
        uint32_t val;
	int ret;

        ret = sscanf(buf, "%u", &val);
	if (ret != 1) {
		DEBUG_ERROR("Unable to write the mode\n");
		return -EINVAL;
	}

	ret = sfe_pppoe_set_br_accel_mode(val);
	if (ret) {
		DEBUG_ERROR("Wrong input: %d\n"
			    "Input should be %u or %u or %u\n"
			    "(%u==ACCEL_MODE_DISABLED %u==ACCEL_MODE_EN_5T %u==ACCEL_MODE_EN_3T)\n",
			val,
			SFE_PPPOE_BR_ACCEL_MODE_DISABLED, SFE_PPPOE_BR_ACCEL_MODE_EN_5T, SFE_PPPOE_BR_ACCEL_MODE_EN_3T,
			SFE_PPPOE_BR_ACCEL_MODE_DISABLED, SFE_PPPOE_BR_ACCEL_MODE_EN_5T, SFE_PPPOE_BR_ACCEL_MODE_EN_3T);
		return -EINVAL;
	}

	return count;
}

static const struct device_attribute sfe_pppoe_br_accel_mode_attr =
	__ATTR(pppoe_br_accel_mode, 0644, sfe_get_pppoe_br_accel_mode, sfe_set_pppoe_br_accel_mode);

/*
 * sfe_init_if()
 */
int sfe_init_if(void)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;
	int result = -1;

	/*
	 * L2 feature is enabled by default
	 */
	sfe_ctx->l2_feature_support = 1;

	/*
	 * Create sys/sfe
	 */
	sfe_ctx->sys_sfe = kobject_create_and_add("sfe", NULL);
	if (!sfe_ctx->sys_sfe) {
		DEBUG_ERROR("failed to register sfe\n");
		goto exit1;
	}

	/*
	 * Create sys/sfe/exceptions
	 */
	result = sysfs_create_file(sfe_ctx->sys_sfe, &sfe_exceptions_attr.attr);
	if (result) {
		DEBUG_ERROR("failed to register exceptions file: %d\n", result);
		goto exit2;
	}

	/*
	 * Create sys/sfe/l2_feature
	 */
	result = sysfs_create_file(sfe_ctx->sys_sfe, &sfe_l2_feature_attr.attr);
	if (result) {
		DEBUG_ERROR("failed to register L2 feature flag sysfs file: %d\n", result);
		goto exit2;
	}

	/*
	 * Create sys/sfe/pppoe_br_accel_mode
	 */
	result = sysfs_create_file(sfe_ctx->sys_sfe, &sfe_pppoe_br_accel_mode_attr.attr);
	if (result) {
		DEBUG_ERROR("failed to create pppoe_br_accel_mode: %d\n", result);
		goto exit2;
	}

	sfe_pppoe_mgr_init();

	spin_lock_init(&sfe_ctx->lock);

	INIT_LIST_HEAD(&sfe_ctx->msg_queue);
	INIT_WORK(&sfe_ctx->work, sfe_process_response_msg);

	/*
	 * Hook the receive path in the network stack.
	 */
	BUG_ON(athrs_fast_nat_recv);
	RCU_INIT_POINTER(athrs_fast_nat_recv, sfe_recv);

	return 0;
exit2:
	kobject_put(sfe_ctx->sys_sfe);
exit1:
	return result;
}

/*
 * sfe_exit_if()
 */
void sfe_exit_if(void)
{
	struct sfe_ctx_instance_internal *sfe_ctx = &__sfe_ctx;

	/*
	 * Unregister our receive callback.
	 */
	RCU_INIT_POINTER(athrs_fast_nat_recv, NULL);

	sfe_pppoe_mgr_exit();

	/*
	 * Wait for all callbacks to complete.
	 */
	rcu_barrier();

	/*
	 * Destroy all connections.
	 */
	sfe_ipv4_destroy_all_rules_for_dev(NULL);
	sfe_ipv6_destroy_all_rules_for_dev(NULL);

	/*
	 * stop work queue, and flush all pending message in queue
	 */
	cancel_work_sync(&sfe_ctx->work);
	sfe_process_response_msg(&sfe_ctx->work);

	/*
	 * Unregister our sync callback.
	 */
	sfe_ipv4_notify_unregister();
	sfe_ipv6_notify_unregister();

	kobject_put(sfe_ctx->sys_sfe);

	return;
}
