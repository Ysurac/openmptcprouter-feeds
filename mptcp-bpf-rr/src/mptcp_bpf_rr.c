// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2022, SUSE. */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>

char _license[] SEC("license") = "GPL";

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;

/* Bounds the walks for the verifier; same value and reason as bpf_dscp. */
#define MAX_SUBFLOWS	8

struct mptcp_rr_storage {
	struct sock *last_snd;
	__u32 turn;
};

struct {
	__uint(type, BPF_MAP_TYPE_SK_STORAGE);
	__uint(map_flags, BPF_F_NO_PREALLOC);
	__type(key, int);
	__type(value, struct mptcp_rr_storage);
} mptcp_rr_map SEC(".maps");

SEC("struct_ops")
void BPF_PROG(mptcp_sched_rr_init, struct mptcp_sock *msk)
{
	bpf_sk_storage_get(&mptcp_rr_map, msk, 0,
			   BPF_LOCAL_STORAGE_GET_F_CREATE);
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_rr_release, struct mptcp_sock *msk)
{
	bpf_sk_storage_delete(&mptcp_rr_map, msk);
}

static __always_inline bool rr_usable(struct mptcp_subflow_context *subflow,
				      struct sock *ssk)
{
	return ssk && mptcp_subflow_active(subflow) && !subflow->stale &&
	       bpf_sk_stream_memory_free(ssk);
}

/* Round-robin, so nothing here is meant to be sent twice: one subflow is
 * scheduled per call and the turn moves on. The cost came from taking the next
 * subflow in the list whether or not it could carry anything -- one whose send
 * buffer is full because its path is blackholed, one the path manager marked
 * stale, one that has not finished joining. The kernel hands it the dfrag
 * anyway, it never arrives, and MPTCP reinjects it elsewhere. Measured on the
 * sender for a 48.8 MB transfer: 41258 segments out and 0 reinjections for the
 * default scheduler against 86860 out and 6014 reinjections here, i.e. twice
 * the traffic to deliver the same bytes, buying nothing.
 *
 * The turn is a plain counter over the *usable* subflows rather than a position
 * remembered in the subflow list. An earlier attempt keyed it on the list: the
 * previous pick is usually the one whose buffer just filled, so it was absent
 * from the usable set on the next call, the position was lost and the rotation
 * collapsed onto whichever subflow happened to come first -- one WAN took 80%
 * of the traffic and another got 3 KB. A counter has no position to lose, so
 * paths dropping in and out cannot derail it.
 */
SEC("struct_ops")
int BPF_PROG(bpf_rr_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	struct mptcp_rr_storage *ptr;
	__u32 nr = 0, target, idx = 0;
	int seen = 0;

	ptr = bpf_sk_storage_get(&mptcp_rr_map, msk, 0,
				 BPF_LOCAL_STORAGE_GET_F_CREATE);
	if (!ptr)
		return -1;

	/* First walk: how many subflows can take data right now. */
	bpf_for_each(mptcp_subflow, subflow, sk) {
		if (seen >= MAX_SUBFLOWS)
			break;
		seen++;

		if (rr_usable(subflow, mptcp_subflow_tcp_sock(subflow)))
			nr++;
	}

	if (!nr)
		return -1;

	/* Unsigned: BPF has no signed division. */
	target = ptr->turn % nr;

	/* Second walk, scheduling from inside it. Collecting the subflows into
	 * an array first and indexing usable[target] is the obvious shape, but
	 * LLVM folds the lookup back to the modulo result and the verifier then
	 * refuses the access ("math between fp pointer and register with
	 * unbounded min value"); scheduling in place needs no index at all.
	 */
	seen = 0;
	bpf_for_each(mptcp_subflow, subflow, sk) {
		struct sock *ssk;

		if (seen >= MAX_SUBFLOWS)
			break;
		seen++;

		ssk = mptcp_subflow_tcp_sock(subflow);
		if (!rr_usable(subflow, ssk))
			continue;

		if (idx == target) {
			mptcp_subflow_set_scheduled(subflow, true);
			ptr->last_snd = ssk;
			ptr->turn++;
			return 0;
		}
		idx++;
	}

	return -1;
}

SEC(".struct_ops.link")
struct mptcp_sched_ops rr = {
	.init		= (void *)mptcp_sched_rr_init,
	.release	= (void *)mptcp_sched_rr_release,
	.get_send	= (void *)bpf_rr_get_send,
	.name		= "bpf_rr",
};
