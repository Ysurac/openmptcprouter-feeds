// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2022, SUSE. */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>

char _license[] SEC("license") = "GPL";

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;
extern bool bpf_mptcp_subflow_queues_empty(struct sock *sk) __ksym;
extern void mptcp_pm_subflow_chk_stale(const struct mptcp_sock *msk, struct sock *ssk) __ksym;
extern void mptcp_set_timeout(struct sock *sk) __ksym;

/* Bounds the fallback walk for the verifier; same value and reason as bpf_dscp. */
#define MAX_SUBFLOWS	16

SEC("struct_ops")
void BPF_PROG(mptcp_sched_first_init, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_first_release, struct mptcp_sock *msk)
{
}

static __always_inline bool first_usable(struct mptcp_subflow_context *subflow,
					 struct sock *ssk)
{
	return ssk && mptcp_subflow_active(subflow) && !subflow->stale &&
	       bpf_sk_stream_memory_free(ssk);
}

/* Still "first": msk->first is used whenever it can carry data, so the
 * scheduler keeps its single-path character. It just no longer insists on a
 * subflow that cannot. Scheduling the initial subflow unconditionally meant
 * that when its WAN was blackholed the kernel kept handing it every dfrag, and
 * the transfer stopped for as long as TCP took to give up: measured as a 24 s
 * application-visible stall with 110228 duplicate segments and 3.6x the payload
 * on the wire, where the default scheduler had no stall at all. Falling back to
 * the first subflow that is usable turns that into an ordinary failover.
 */
SEC("struct_ops")
int BPF_PROG(bpf_first_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	struct sock *pick = NULL;
	int seen = 0;

	/* the MPTCP retransmission timer follows the subflows' own timers
	 * (see get_retrans below)
	 */
	mptcp_set_timeout(sk);

	subflow = bpf_mptcp_subflow_ctx(msk->first);
	if (subflow && first_usable(subflow, mptcp_subflow_tcp_sock(subflow))) {
		mptcp_subflow_set_scheduled(subflow, true);
		return 0;
	}

	bpf_for_each(mptcp_subflow, subflow, sk) {
		struct sock *ssk;

		if (seen >= MAX_SUBFLOWS)
			break;
		seen++;

		ssk = mptcp_subflow_tcp_sock(subflow);
		if (!first_usable(subflow, ssk))
			continue;

		pick = ssk;
		break;
	}

	if (!pick)
		return -1;

	subflow = bpf_mptcp_subflow_ctx(pick);
	if (!subflow)
		return -1;

	mptcp_subflow_set_scheduled(subflow, true);
	return 0;
}

static __always_inline bool tcp_rtx_and_write_queues_empty(struct sock *sk)
{
	const struct tcp_sock *tp = bpf_skc_to_tcp_sock(sk);

	return bpf_mptcp_subflow_queues_empty(sk) &&
	       (!tp || tp->write_seq == tp->snd_nxt);
}

/* MPTCP-level retransmissions, when the MPTCP retransmission timer fires.
 * The timer runs for msk->timer_ival, which only mptcp_set_timeout()
 * updates: the default scheduler and bpf_burst call it on every pick, and
 * __subflow_push_pending() only while msk->snd_burst is positive, which only
 * they set. Without it the timer stays at TCP_RTO_MIN, 200 ms, whatever the
 * subflows' round-trip times. With no get_retrans either, the kernel asks
 * get_send (mptcp_sched_get_retrans()), which picks a subflow that can take
 * new data, usually the one already holding the data to retransmit: every
 * 200 ms one more copy of the oldest data went out behind the first one, on
 * the same path.
 *
 * get_send now calls mptcp_set_timeout(), and this is the default
 * scheduler's choice (mptcp_subflow_get_retrans()), as in bpf_burst: a
 * subflow with nothing outstanding at TCP level, and a backup one only when
 * no subflow makes progress.
 */
SEC("struct_ops.s")
int BPF_PROG(bpf_first_get_retrans, struct mptcp_sock *msk)
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
struct mptcp_sched_ops first = {
	.init		= (void *)mptcp_sched_first_init,
	.release	= (void *)mptcp_sched_first_release,
	.get_send	= (void *)bpf_first_get_send,
	.get_retrans	= (void *)bpf_first_get_retrans,
	.name		= "bpf_first",
};
