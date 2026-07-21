// SPDX-License-Identifier: GPL-2.0
/* Based on Burst scheduler */
/* Copyright (c) 2023, SUSE. */
/* Copyright (c) 2026, Yannick Chabanois */
/*
 * DSCP-aware MPTCP scheduler: pins each DSCP class to a chosen WAN
 * interface (identified by its local endpoint IP). Traffic whose DSCP
 * has no pin, or whose pinned interface has no usable subflow, falls
 * back to the first available subflow (active, then backup).
 */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>
#include "limits.h"

char _license[] SEC("license") = "GPL";

#define MPTCP_SEND_BURST_SIZE	65428
#define MAX_SUBFLOWS		8

#define min(a, b) ((a) < (b) ? (a) : (b))

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern void mptcp_set_timeout(struct sock *sk) __ksym;
extern __u64 mptcp_wnd_end(const struct mptcp_sock *msk) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;
extern bool bpf_mptcp_subflow_queues_empty(struct sock *sk) __ksym;
extern void mptcp_pm_subflow_chk_stale(const struct mptcp_sock *msk, struct sock *ssk) __ksym;

/* DSCP (0-63, i.e. tos >> 2) -> preferred WAN local endpoint IP
 * (as stored in skc_rcv_saddr). Populated from userspace, e.g. by
 * mptcp-scheduler-dscp.sh set <dscp> <interface>.
 */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);
	__type(value, __u32);
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} dscp_iface SEC(".maps");

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
void BPF_PROG(mptcp_sched_dscp_init, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_dscp_release, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
int BPF_PROG(bpf_dscp_get_send, struct mptcp_sock *msk)
{
	struct sock *pinned_active = NULL, *pinned_backup = NULL;
	struct sock *fallback_active = NULL, *fallback_backup = NULL;
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	__u32 pace, burst, wmem;
	struct sock *ssk;
	__u32 *desired_ip;
	__u8 dscp;

	dscp = msk->sk.icsk_inet.tos >> 2;
	desired_ip = bpf_map_lookup_elem(&dscp_iface, &dscp);

	bpf_for_each(mptcp_subflow, subflow, sk) {
		__u8 backup = (subflow->backup || subflow->request_bkup) ? 1 : 0;
		__u32 local_ip;
		struct sock *cur;

		cur = mptcp_subflow_tcp_sock(subflow);
		if (!mptcp_subflow_active(subflow))
			continue;

		pace = subflow->avg_pacing_rate;
		if (!pace) {
			subflow->avg_pacing_rate = cur->sk_pacing_rate;
			pace = subflow->avg_pacing_rate;
			if (!pace)
				continue;
		}

		local_ip = cur->__sk_common.skc_rcv_saddr;

		if (desired_ip && *desired_ip == local_ip) {
			if (backup) {
				if (!pinned_backup)
					pinned_backup = cur;
			} else {
				if (!pinned_active)
					pinned_active = cur;
			}
		} else {
			if (backup) {
				if (!fallback_backup)
					fallback_backup = cur;
			} else {
				if (!fallback_active)
					fallback_active = cur;
			}
		}
	}
	mptcp_set_timeout(sk);

	if (pinned_active)
		ssk = pinned_active;
	else if (fallback_active)
		ssk = fallback_active;
	else if (pinned_backup)
		ssk = pinned_backup;
	else
		ssk = fallback_backup;

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
int BPF_PROG(bpf_dscp_get_retrans, struct mptcp_sock *msk)
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
struct mptcp_sched_ops dscp = {
	.init		= (void *)mptcp_sched_dscp_init,
	.release	= (void *)mptcp_sched_dscp_release,
	.get_send	= (void *)bpf_dscp_get_send,
	.get_retrans	= (void *)bpf_dscp_get_retrans,
	.name		= "bpf_dscp",
};
