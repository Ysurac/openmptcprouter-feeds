// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2022, SUSE. */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>

char _license[] SEC("license") = "GPL";

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;

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

SEC(".struct_ops.link")
struct mptcp_sched_ops first = {
	.init		= (void *)mptcp_sched_first_init,
	.release	= (void *)mptcp_sched_first_release,
	.get_send	= (void *)bpf_first_get_send,
	.name		= "bpf_first",
};
