// SPDX-License-Identifier: GPL-2.0
/* Based on Burst scheduler */
/* Copyright (c) 2023, SUSE. */
/* Copyright (c) 2025-2026, Yannick Chabanois */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>
#include "limits.h"

char _license[] SEC("license") = "GPL";

#define MPTCP_SEND_BURST_SIZE	65428

#define SSK_MODE_ACTIVE	0
#define SSK_MODE_BACKUP	1
#define SSK_MODE_MAX	2

#define min(a, b) ((a) < (b) ? (a) : (b))

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern void mptcp_set_timeout(struct sock *sk) __ksym;
extern __u64 mptcp_wnd_end(const struct mptcp_sock *msk) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;
extern bool bpf_mptcp_subflow_queues_empty(struct sock *sk) __ksym;
extern void mptcp_pm_subflow_chk_stale(const struct mptcp_sock *msk, struct sock *ssk) __ksym;

/* Use a distinct name to avoid conflict with subflow_send_info from vmlinux.h */
struct weight_subflow_send_info {
	struct sock *ssk;
	__u64 linger_time;
};

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u32);   /* local IP as stored in skc_rcv_saddr */
	__type(value, __u32); /* weight: higher = more preferred (like ip route weight); 100 = neutral */
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} endpoint_weights SEC(".maps");

/* Server/VPS-side counterpart of endpoint_weights: every subflow shares
 * the same local IP there, so a local-IP-keyed weight can't distinguish
 * WANs. Keys on the MPTCP remote endpoint id instead (the address id the
 * router assigned to the originating WAN, stable across the router's WAN
 * IP changing) -- same map shape/purpose as mptcp_bpf_dscp's
 * dscp_remote_id, set via mptcp-scheduler-weight.sh set id <N> <weight>.
 */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);    /* subflow->remote_id */
	__type(value, __u32); /* weight, same semantics as endpoint_weights */
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} weight_remote_id SEC(".maps");

static __always_inline __u64 div_u64(__u64 dividend, __u32 divisor)
{
	return dividend / divisor;
}

static __always_inline bool tcp_write_queue_empty(struct sock *sk)
{
	const struct tcp_sock *tp = bpf_skc_to_tcp_sock(sk);

	return tp ? tp->write_seq == tp->snd_nxt : true;
}

static __always_inline bool tcp_rtx_and_write_queues_empty(struct sock *sk)
{
	return bpf_mptcp_subflow_queues_empty(sk) && tcp_write_queue_empty(sk);
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_weight_init, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_weight_release, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
int BPF_PROG(bpf_weight_get_send, struct mptcp_sock *msk)
{
	struct weight_subflow_send_info send_info[SSK_MODE_MAX];
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	__u32 pace, burst, wmem;
	int nr_active = 0;
	__u64 linger_time;
	struct sock *ssk;

	for (int i = 0; i < SSK_MODE_MAX; ++i) {
		send_info[i].ssk = NULL;
		send_info[i].linger_time = 0;
	}

	bpf_for_each(mptcp_subflow, subflow, sk) {
		bool backup = subflow->backup || subflow->request_bkup;
		__u32 local_ip, weight;
		__u32 *w_ptr;

		ssk = mptcp_subflow_tcp_sock(subflow);
		if (!mptcp_subflow_active(subflow))
			continue;

		nr_active += !backup;
		pace = subflow->avg_pacing_rate;
		if (!pace) {
			subflow->avg_pacing_rate = ssk->sk_pacing_rate;
			pace = subflow->avg_pacing_rate;
			if (!pace)
				continue;
		}

		local_ip = ssk->__sk_common.skc_rcv_saddr;
		weight = 100; /* neutral default */
		w_ptr = bpf_map_lookup_elem(&endpoint_weights, &local_ip);
		if (!w_ptr) {
			__u8 remote_id = subflow->remote_id;

			/* endpoint_weights (local-IP-keyed) found nothing --
			 * fall back to remote_id keying. On the router this
			 * is a harmless no-op: subflow->remote_id there
			 * identifies the peer's (VPS's) address, which is
			 * the same single id for every WAN, so it's never a
			 * useful key on that side. On the VPS, where every
			 * subflow's local IP is identical (so
			 * endpoint_weights always misses), remote_id is the
			 * id the router assigned to the WAN that opened this
			 * subflow -- the only thing that DOES distinguish
			 * WANs there.
			 */
			w_ptr = bpf_map_lookup_elem(&weight_remote_id, &remote_id);
		}
		if (w_ptr && *w_ptr > 0)
			weight = *w_ptr;

		/* higher weight = more preferred (like ip route weight) */
		linger_time = weight;
		if (linger_time > send_info[backup].linger_time) {
			send_info[backup].ssk = ssk;
			send_info[backup].linger_time = linger_time;
		}
	}
	mptcp_set_timeout(sk);

	/* fall back to best backup when no active subflow is available */
	if (!nr_active)
		send_info[SSK_MODE_ACTIVE].ssk = send_info[SSK_MODE_BACKUP].ssk;

	ssk = send_info[SSK_MODE_ACTIVE].ssk;
	if (!ssk || !bpf_sk_stream_memory_free(ssk))
		return -1;

	subflow = bpf_mptcp_subflow_ctx(ssk);
	if (!subflow)
		return -1;

	burst = min(MPTCP_SEND_BURST_SIZE, mptcp_wnd_end(msk) - msk->snd_nxt);
	ssk = bpf_core_cast(ssk, struct sock);
	wmem = ssk->sk_wmem_queued;
	if (!burst)
		goto out;

	subflow->avg_pacing_rate = div_u64((__u64)subflow->avg_pacing_rate * wmem +
					   ssk->sk_pacing_rate * burst,
					   burst + wmem);
	msk->snd_burst = burst;

out:
	mptcp_subflow_set_scheduled(subflow, true);
	return 0;
}

SEC("struct_ops.s")
int BPF_PROG(bpf_weight_get_retrans, struct mptcp_sock *msk)
{
	struct sock *backup = NULL, *pick = NULL;
	struct mptcp_subflow_context *subflow;
	int min_stale_count = INT_MAX;

	bpf_for_each(mptcp_subflow, subflow, (struct sock *)msk) {
		struct sock *ssk = bpf_mptcp_subflow_tcp_sock(subflow);

		if (!ssk || !mptcp_subflow_active(subflow))
			continue;

		/* still data outstanding at TCP level? skip this */
		if (!tcp_rtx_and_write_queues_empty(ssk)) {
			mptcp_pm_subflow_chk_stale(msk, ssk);
			min_stale_count = min(min_stale_count, subflow->stale_count);
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

	if (pick)
		goto out;
	pick = min_stale_count > 1 ? backup : NULL;

out:
	if (!pick)
		return -1;
	subflow = bpf_mptcp_subflow_ctx(pick);
	if (!subflow)
		return -1;
	mptcp_subflow_set_scheduled(subflow, true);
	return 0;
}

SEC(".struct_ops.link")
struct mptcp_sched_ops weight = {
	.init		= (void *)mptcp_sched_weight_init,
	.release	= (void *)mptcp_sched_weight_release,
	.get_send	= (void *)bpf_weight_get_send,
	.get_retrans	= (void *)bpf_weight_get_retrans,
	.name		= "bpf_weight",
};
