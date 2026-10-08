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

/* Bounds the walk for the verifier; same value and reason as bpf_dscp. */
#define MAX_SUBFLOWS	8

SEC("struct_ops")
void BPF_PROG(mptcp_sched_bkup_init, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_bkup_release, struct mptcp_sock *msk)
{
}

/* The first subflow that is not a backup, and a backup one only when no
 * other subflow is active, as the default scheduler does.
 *
 * request_bkup is our own backup flag (the endpoint's backup flag, or an
 * MP_PRIO we sent) and backup is the peer's (its MP_JOIN or MP_PRIO). This
 * scheduler skipped a subflow only when both were set, which they rarely are:
 * a router WAN flagged as backup has only request_bkup set, so it carried
 * traffic like the others, and the same WAN seen from the VPS has only backup.
 * And with no other subflow left, it scheduled nothing at all, so the
 * transfer stopped instead of moving to the backup subflow.
 *
 * A non-backup subflow whose send buffer is full is waited for (-1), not
 * replaced by a backup one: a backup path is often metered or slow.
 */
SEC("struct_ops")
int BPF_PROG(bpf_bkup_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	struct sock *backup = NULL, *pick = NULL;
	int nr_active = 0;
	int seen = 0;

	/* the MPTCP retransmission timer follows the subflows' own timers
	 * (see get_retrans below)
	 */
	mptcp_set_timeout(sk);

	bpf_for_each(mptcp_subflow, subflow, sk) {
		struct sock *ssk;
		bool usable;

		if (seen >= MAX_SUBFLOWS)
			break;
		seen++;

		ssk = mptcp_subflow_tcp_sock(subflow);
		if (!ssk || !mptcp_subflow_active(subflow))
			continue;

		usable = bpf_sk_stream_memory_free(ssk);
		if (subflow->backup || subflow->request_bkup) {
			if (usable && !backup)
				backup = ssk;
			continue;
		}

		nr_active++;
		if (usable) {
			pick = ssk;
			break;
		}
	}

	if (!pick && !nr_active)
		pick = backup;
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

/* MPTCP-level retransmissions: the default scheduler's choice
 * (mptcp_subflow_get_retrans()), as in bpf_first, bpf_rr and bpf_red. With
 * no get_retrans the kernel asks get_send, which picks the subflow already
 * holding the data, and without mptcp_set_timeout() above the timer stays at
 * TCP_RTO_MIN, so the oldest data was sent again every 200 ms on the same path.
 */
SEC("struct_ops.s")
int BPF_PROG(bpf_bkup_get_retrans, struct mptcp_sock *msk)
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
struct mptcp_sched_ops bkup = {
	.init		= (void *)mptcp_sched_bkup_init,
	.release	= (void *)mptcp_sched_bkup_release,
	.get_send	= (void *)bpf_bkup_get_send,
	.get_retrans	= (void *)bpf_bkup_get_retrans,
	.name		= "bpf_bkup",
};
