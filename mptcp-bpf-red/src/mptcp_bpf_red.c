// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2022, SUSE. */
/* Copyright (c) 2026, Yannick Chabanois (Ycarus) for OpenMPTCProuter */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>

char _license[] SEC("license") = "GPL";

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;

/* Marking every subflow, as this scheduler did, also marks the ones the
 * kernel cannot usefully send on: a subflow whose send buffer is already
 * full because its path is blackholed, or one the path manager has written
 * off as stale. __subflow_push_pending() hands such a subflow a dfrag
 * anyway and only bails out on the NEXT one, so each push round fed the
 * dead path again. TCP then retransmitted there while MPTCP reinjected the
 * same data on a live path.
 *
 * Measured on a three-WAN bench (48.8 MB through the proxy, 5 subflows, one
 * WAN silently blackholed mid-transfer), against the default scheduler:
 *
 *   default          106% of payload on the wire, 0 duplicate segments
 *   red, unscreened  ~1900%, and a 5s stall the default scheduler did not
 *                    have -- worse failover from the redundant scheduler
 *   red, screened    246-293%, 32893 duplicate segments of 74679 received,
 *                    13 retransmits, no stall
 *
 * So screening does not cost the redundancy: duplicate data still arrives
 * over more than one path (MPTcpExtDuplicateData is flat at zero under the
 * default scheduler), retransmission stays at noise level, and the cost
 * drops from ~19x the payload to ~2.5x, which is what duplicating onto the
 * paths that have room should cost. Screen on the same two conditions
 * __subflow_push_pending() itself uses to stop.
 */
SEC("struct_ops")
void BPF_PROG(mptcp_sched_red_init, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_red_release, struct mptcp_sock *msk)
{
}

/* Bounding the walk keeps the verifier's state search finite: without it the
 * per-subflow branches below explode into "sequence of 8193 jumps is too
 * complex" and the program will not load. Same bound and same reason as
 * bpf_dscp / bpf_weight_rr.
 */
#define MAX_SUBFLOWS	8

SEC("struct_ops")
int BPF_PROG(bpf_red_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	int scheduled = 0;
	int seen = 0;

	bpf_for_each(mptcp_subflow, subflow, sk) {
		struct sock *ssk;
		bool usable;

		if (seen >= MAX_SUBFLOWS)
			break;
		seen++;

		ssk = mptcp_subflow_tcp_sock(subflow);
		if (!ssk)
			continue;

		/* Three conditions, one branch, so the verifier stays cheap:
		 *  - active: join finished and the socket can still send;
		 *  - !stale: the path manager has not written it off after
		 *    stale_loss_cnt losses;
		 *  - memory free: there is room in the send buffer. On a
		 *    blackholed path this is what goes false first, and
		 *    ignoring it is what turned one dead WAN into a
		 *    retransmit storm.
		 */
		usable = mptcp_subflow_active(subflow) &&
			 !subflow->stale &&
			 bpf_sk_stream_memory_free(ssk);
		if (!usable)
			continue;

		mptcp_subflow_set_scheduled(subflow, true);
		scheduled++;
	}

	/* Nothing usable: say so rather than marking a subflow that cannot
	 * take the data, which is what the default scheduler does too
	 * (mptcp_sched_default_get_send returns -EINVAL when it finds none).
	 * __mptcp_push_pending() then breaks out and retries later.
	 */
	if (!scheduled)
		return -1;

	return 0;
}

SEC(".struct_ops.link")
struct mptcp_sched_ops red = {
	.init		= (void *)mptcp_sched_red_init,
	.release	= (void *)mptcp_sched_red_release,
	.get_send	= (void *)bpf_red_get_send,
	.name		= "bpf_red",
};
