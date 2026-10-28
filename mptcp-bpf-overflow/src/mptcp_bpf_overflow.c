// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2023, SUSE (get_retrans, from bpf_burst). */
/* Copyright (c) 2026, Yannick Chabanois (Ycarus) for OpenMPTCProuter */

/* Overflow: the WANs are used by weight, a lower one only for what the
 * higher ones cannot carry. With a fibre at weight 200 and a metered LTE at
 * 50, the LTE carries data only while the fibre's congestion window is full
 * and the data would complete sooner with the LTE's help, and nothing while
 * the fibre keeps up.
 *
 * The weights are bpf_weight's: the same pinned maps (endpoint_weights,
 * weight_remote_id, weight_local_id), set from network.<iface>.
 * multipath_weight by mptcp-scheduler-weight.sh and mirrored to the VPS.
 * A WAN without a weight has 100.
 *
 * bpf_weight also sends on the highest weight, but goes to the next one
 * only once the send buffer of the first is full, about a window of data
 * queued on it, and hands it 64 KB whatever its window. Here:
 * - a subflow takes data while its congestion window has room, and the
 *   burst is capped by that room (see bpf_ecf), so no data waits on the
 *   preferred WAN while a lower one sends;
 * - subflows of the same weight are shared by ECF, the lowest RTT first,
 *   where bpf_weight filled the first one listed;
 * - a lower weight is used only when ECF finds that waiting for the
 *   preferred WAN's window would complete later (bpf_ecf's two tests), and
 *   always when the preferred WAN is in RTO backoff;
 * - backup subflows are used only when no other subflow is active.
 */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_endian.h>

char _license[] SEC("license") = "GPL";

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern void mptcp_set_timeout(struct sock *sk) __ksym;
extern __u64 mptcp_wnd_end(const struct mptcp_sock *msk) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;
extern bool bpf_mptcp_subflow_queues_empty(struct sock *sk) __ksym;
extern void mptcp_pm_subflow_chk_stale(const struct mptcp_sock *msk, struct sock *ssk) __ksym;

#define MPTCP_SEND_BURST_SIZE	65428

/* skc_rcv_saddr of every native IPv6 socket (tcp_v6_connect() sets it) */
#define LOOPBACK4_IPV6		bpf_htonl(0x7f000006)

#define OVF_DEFAULT_WEIGHT	100

/* See bpf_ecf */
#define ECF_R_BETA		4
#define ECF_UNKNOWN_RTT_US	1000000
#define ECF_MAX_BYTES		(1ULL << 30)

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

/* The three maps are bpf_weight's, same names and definitions: libbpf reuses
 * the pinned ones, so the weights set for bpf_weight hold here too.
 */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u32);   /* local IP as stored in skc_rcv_saddr */
	__type(value, __u32); /* weight: higher = more preferred (like ip route weight); 100 = neutral */
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} endpoint_weights SEC(".maps");

/* VPS side: keyed by the MPTCP remote endpoint id, see bpf_weight */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);    /* subflow->remote_id */
	__type(value, __u32); /* weight, same semantics as endpoint_weights */
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} weight_remote_id SEC(".maps");

/* Router-side IPv6 subflows, keyed by their local endpoint id */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);    /* endpoint id, see ipv6_local_id() */
	__type(value, __u32); /* weight, same semantics as endpoint_weights */
	__uint(max_entries, 256);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} weight_local_id SEC(".maps");

/* The weight of a WAN without one. A variable, not the constant: the walk
 * compares weights, and between two subflows without a weight the verifier
 * would compare two known constants, track them exactly, and never see the
 * walk converge (1M instructions processed). Read from .data, the value is
 * unknown to it.
 */
volatile __u32 ovf_default_weight = OVF_DEFAULT_WEIGHT;

struct mptcp_ovf_storage {
	__u32 waiting;
};

struct {
	__uint(type, BPF_MAP_TYPE_SK_STORAGE);
	__uint(map_flags, BPF_F_NO_PREALLOC);
	__type(key, int);
	__type(value, struct mptcp_ovf_storage);
} mptcp_ovf_map SEC(".maps");

/* Only scalars, and the subflow_id rather than a pointer or a position:
 * see struct ecf_path in bpf_ecf for the verifier limits behind that.
 */
struct ovf_path {
	__u64 srtt;	/* us */
	__u64 mdev;	/* us */
	__u64 cwnd;	/* bytes */
	__u64 room;	/* bytes the cwnd still lets out */
	__u32 weight;
	__u32 id;	/* subflow_id, 0 if none */
	__u32 backoff;
};

SEC("struct_ops")
void BPF_PROG(mptcp_sched_ovf_init, struct mptcp_sock *msk)
{
	bpf_sk_storage_get(&mptcp_ovf_map, msk, 0,
			   BPF_LOCAL_STORAGE_GET_F_CREATE);
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_ovf_release, struct mptcp_sock *msk)
{
	bpf_sk_storage_delete(&mptcp_ovf_map, msk);
}

static __always_inline bool ovf_backup(struct mptcp_subflow_context *subflow)
{
	return subflow->backup || subflow->request_bkup;
}

/* The endpoint id of the local address of an IPv6 subflow: the initial
 * subflow has the address id 0 whatever its endpoint, which the in-kernel
 * path manager keeps in mpc_endpoint_id.
 */
static __always_inline __u8 ipv6_local_id(const struct mptcp_sock *msk,
					  const struct mptcp_subflow_context *subflow)
{
	__u8 id = subflow->local_id;

	return id ? id : msk->mpc_endpoint_id;
}

/* bpf_weight's lookup: the local IPv4 address on the router, the local
 * endpoint id for IPv6, then the remote endpoint id (the VPS side, where
 * every subflow has the same local address).
 */
static __always_inline __u32 ovf_weight(const struct mptcp_sock *msk,
					struct mptcp_subflow_context *subflow,
					const struct sock *ssk)
{
	__u32 local_ip = ssk->__sk_common.skc_rcv_saddr;
	__u8 remote_id = subflow->remote_id;
	__u32 *w_ptr;

	if (local_ip == LOOPBACK4_IPV6) {
		__u8 local_id = ipv6_local_id(msk, subflow);

		w_ptr = bpf_map_lookup_elem(&weight_local_id, &local_id);
	} else {
		w_ptr = bpf_map_lookup_elem(&endpoint_weights, &local_ip);
	}
	if (!w_ptr)
		w_ptr = bpf_map_lookup_elem(&weight_remote_id, &remote_id);
	if (w_ptr && *w_ptr > 0)
		return *w_ptr;
	return ovf_default_weight;
}

/* Whether a ranks before b: the higher weight, then the lower RTT */
static __always_inline bool ovf_before(__u32 wa, __u64 srtta,
				       const struct ovf_path *b)
{
	return wa > b->weight || (wa == b->weight && srtta < b->srtt);
}

/* Fills fast with the first active subflow in that order and avail with the
 * first one that can take data now, both among the backup or the
 * non-backup subflows. Returns whether one of those is active.
 */
static __always_inline bool ovf_walk(struct mptcp_sock *msk, bool backup,
				    struct ovf_path *fast,
				    struct ovf_path *avail)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	bool found = false;

	__builtin_memset(fast, 0, sizeof(*fast));
	__builtin_memset(avail, 0, sizeof(*avail));
	fast->srtt = -1;
	avail->srtt = -1;

	bpf_for_each(mptcp_subflow, subflow, sk) {
		const struct tcp_sock *tp;
		__u64 srtt, cwnd, used;
		__u32 mss, in_flight, weight;
		struct sock *ssk;

		if (ovf_backup(subflow) != backup ||
		    !mptcp_subflow_active(subflow))
			continue;
		ssk = mptcp_subflow_tcp_sock(subflow);
		if (!ssk)
			continue;
		found = true;

		tp = bpf_core_cast(ssk, struct tcp_sock);
		mss = tp->mss_cache;
		if (!mss)
			continue;

		weight = ovf_weight(msk, subflow, ssk);
		/* srtt_us is 8 times the smoothed RTT */
		srtt = tp->srtt_us >> 3;
		if (!srtt)
			srtt = ECF_UNKNOWN_RTT_US;
		cwnd = (__u64)tp->snd_cwnd * mss;
		/* tcp_packets_in_flight(), then what waits in the queue */
		in_flight = tp->packets_out - (tp->sacked_out + tp->lost_out) +
			    tp->retrans_out;
		used = (__u64)in_flight * mss + (__u32)(tp->write_seq - tp->snd_nxt);

		if (ovf_before(weight, srtt, fast)) {
			fast->srtt = srtt;
			/* mdev_us is 4 times the RTT mean deviation */
			fast->mdev = tp->mdev_us >> 2;
			fast->cwnd = cwnd;
			fast->weight = weight;
			fast->id = subflow->subflow_id;
			fast->backoff = tp->inet_conn.icsk_backoff;
		}
		if (used + mss <= cwnd && ovf_before(weight, srtt, avail) &&
		    bpf_sk_stream_memory_free(ssk)) {
			avail->srtt = srtt;
			avail->mdev = tp->mdev_us >> 2;
			avail->cwnd = cwnd;
			avail->room = cwnd - used;
			avail->weight = weight;
			avail->id = subflow->subflow_id;
		}
	}

	return found;
}

SEC("struct_ops")
int BPF_PROG(bpf_overflow_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	__u64 k, delta, cwnd_f, cwnd_s, wnd_end;
	struct mptcp_ovf_storage *ptr;
	struct ovf_path fast, avail;
	bool backup = false;

	mptcp_set_timeout(sk);

	ptr = bpf_sk_storage_get(&mptcp_ovf_map, msk, 0,
				 BPF_LOCAL_STORAGE_GET_F_CREATE);
	if (!ptr)
		return -1;

	if (!ovf_walk(msk, false, &fast, &avail)) {
		backup = true;
		if (!ovf_walk(msk, true, &fast, &avail))
			return -1;
	}

	/* every cwnd is full: the next ack pushes again */
	if (!avail.id)
		return -1;

	/* avail is the preferred subflow, or a lower one that is no slower
	 * than it: nothing to wait for
	 */
	if (avail.id == fast.id || avail.srtt <= fast.srtt || fast.backoff)
		goto send;

	/* bpf_ecf's decision between the preferred subflow, whose cwnd is
	 * full, and avail, the next one in the order that has room
	 */
	k = min(msk->write_seq - msk->snd_nxt, ECF_MAX_BYTES);
	cwnd_f = min(fast.cwnd, ECF_MAX_BYTES);
	cwnd_s = min(avail.cwnd, ECF_MAX_BYTES);
	delta = max(fast.mdev, avail.mdev);

	if (ECF_R_BETA * fast.srtt * (k + cwnd_f) <
	    (ECF_R_BETA + ptr->waiting) * cwnd_f * (avail.srtt + delta)) {
		if (avail.srtt * max(k, cwnd_s) >=
		    cwnd_s * (2 * fast.srtt + delta)) {
			ptr->waiting = 1;
			return -1;
		}
	} else {
		ptr->waiting = 0;
	}

send:
	wnd_end = mptcp_wnd_end(msk);

	bpf_for_each(mptcp_subflow, subflow, sk) {
		if (subflow->subflow_id != avail.id)
			continue;
		if (ovf_backup(subflow) != backup ||
		    !mptcp_subflow_active(subflow))
			return -1;

		if (wnd_end > msk->snd_nxt)
			msk->snd_burst = min(min(avail.room, MPTCP_SEND_BURST_SIZE),
					     wnd_end - msk->snd_nxt);
		mptcp_subflow_set_scheduled(subflow, true);
		return 0;
	}

	return -1;
}

static __always_inline bool tcp_rtx_and_write_queues_empty(struct sock *sk)
{
	const struct tcp_sock *tp = bpf_skc_to_tcp_sock(sk);

	return bpf_mptcp_subflow_queues_empty(sk) &&
	       (!tp || tp->write_seq == tp->snd_nxt);
}

/* MPTCP-level retransmissions: the default scheduler's choice, as in
 * bpf_ecf, whatever the weights: the data is late already.
 */
SEC("struct_ops.s")
int BPF_PROG(bpf_overflow_get_retrans, struct mptcp_sock *msk)
{
	struct sock *backup = NULL, *pick = NULL;
	struct mptcp_subflow_context *subflow;
	int min_stale_count = __INT_MAX__;

	bpf_for_each(mptcp_subflow, subflow, (struct sock *)msk) {
		struct sock *ssk = bpf_mptcp_subflow_tcp_sock(subflow);

		if (!ssk || !mptcp_subflow_active(subflow))
			continue;

		/* still data outstanding at TCP level? skip this */
		if (!tcp_rtx_and_write_queues_empty(ssk)) {
			mptcp_pm_subflow_chk_stale(msk, ssk);
			if (subflow->stale_count < min_stale_count)
				min_stale_count = subflow->stale_count;
			continue;
		}

		if (subflow->backup || subflow->request_bkup) {
			if (!backup)
				backup = ssk;
			continue;
		}

		if (!pick)
			pick = ssk;
	}

	if (!pick && min_stale_count > 1)
		pick = backup;
	if (!pick)
		return -1;

	subflow = bpf_mptcp_subflow_ctx(pick);
	if (!subflow)
		return -1;

	mptcp_subflow_set_scheduled(subflow, true);
	return 0;
}

SEC(".struct_ops.link")
struct mptcp_sched_ops overflow = {
	.init		= (void *)mptcp_sched_ovf_init,
	.release	= (void *)mptcp_sched_ovf_release,
	.get_send	= (void *)bpf_overflow_get_send,
	.get_retrans	= (void *)bpf_overflow_get_retrans,
	.name		= "bpf_overflow",
};
