// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2023, SUSE (get_retrans, from bpf_burst). */
/* Copyright (c) 2026, Yannick Chabanois (Ycarus) for OpenMPTCProuter */

/* ECF, Earliest Completion First: Y. Lim, E. M. Nahum, D. Towsley and
 * R. J. Gibbens, "ECF: An MPTCP Path Scheduler to Manage Heterogeneous
 * Paths", ACM CoNEXT 2017. The decision is the one of mptcp_ecf.c in the
 * out-of-tree multipath-tcp.org kernel.
 *
 * With WANs of very different round-trip times (fibre and LTE, or a
 * satellite link), filling the slow path whenever the fast one is
 * cwnd-limited makes the receiver wait for the slow path's segments to
 * deliver in order: the fast path then stalls on the MPTCP receive window.
 * ECF sends on the fastest subflow when its congestion window has room.
 * When it has none, it estimates whether the data still to send would
 * complete sooner by waiting for that subflow than by also using the
 * fastest subflow that has room, and if so sends nothing: the next ack
 * pushes again (__mptcp_check_push() on every DATA_ACK while the MPTCP
 * window is open).
 *
 * Differences from the original, for the 6.x MPTCP stack:
 * - a subflow has room when the segments in flight plus the bytes queued
 *   but not sent yet are below its cwnd: MPTCP hands data to the subflow
 *   queue, which sends it as the cwnd allows, so the queue counts too.
 * - the burst given to a subflow is capped by that room, so the slow path
 *   is never handed more than it can put on the wire right away (the
 *   default scheduler's 64 KB burst would park data behind its cwnd).
 * - a fastest subflow in RTO backoff is not waited for: its RTT is stale
 *   and its cwnd will not open with the next ack. Waiting would hold the
 *   data until the path manager marks it stale, several RTOs later, where
 *   the default scheduler moves on as soon as its queue grows.
 * - backup subflows are used only when no other subflow is active, as in
 *   the default scheduler.
 */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>

char _license[] SEC("license") = "GPL";

extern bool mptcp_subflow_active(struct mptcp_subflow_context *subflow) __ksym;
extern void mptcp_set_timeout(struct sock *sk) __ksym;
extern __u64 mptcp_wnd_end(const struct mptcp_sock *msk) __ksym;
extern bool bpf_sk_stream_memory_free(const struct sock *sk) __ksym;
extern bool bpf_mptcp_subflow_queues_empty(struct sock *sk) __ksym;
extern void mptcp_pm_subflow_chk_stale(const struct mptcp_sock *msk, struct sock *ssk) __ksym;

#define MPTCP_SEND_BURST_SIZE	65428

/* beta = 1/ECF_R_BETA: once ECF waits, the slow subflow must look that
 * much better before it is used again, so the choice does not flap.
 */
#define ECF_R_BETA	4

/* A subflow without an RTT sample yet ranks behind the others. */
#define ECF_UNKNOWN_RTT_US	1000000

/* Keeps the products below in 64 bits: srtt_us >> 3 and mdev_us >> 2 are
 * under 2^30, so with k and the cwnds capped at 2^30 bytes nothing exceeds
 * 2^63.
 */
#define ECF_MAX_BYTES		(1ULL << 30)

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

struct mptcp_ecf_storage {
	__u32 waiting;
};

struct {
	__uint(type, BPF_MAP_TYPE_SK_STORAGE);
	__uint(map_flags, BPF_F_NO_PREALLOC);
	__type(key, int);
	__type(value, struct mptcp_ecf_storage);
} mptcp_ecf_map SEC(".maps");

/* Only scalars: a subflow is remembered by its subflow_id and scheduled by
 * a last walk. Keeping the socket pointers instead, NULL or not for two
 * candidates across the walk, multiplied the verifier states until the
 * program hit the 1M instruction limit. Nor is it a position counted along
 * the list: the verifier tracks such a counter exactly once it is compared
 * after the walk, so the walk never converged ("sequence of 8193 jumps is
 * too complex"). A subflow_id is read from the subflow, unknown to the
 * verifier, and never 0 (the first subflow gets 1).
 */
struct ecf_path {
	__u64 srtt;	/* us */
	__u64 mdev;	/* us */
	__u64 cwnd;	/* bytes */
	__u64 room;	/* bytes the cwnd still lets out */
	__u32 id;	/* subflow_id, 0 if none */
	__u32 backoff;
};

SEC("struct_ops")
void BPF_PROG(mptcp_sched_ecf_init, struct mptcp_sock *msk)
{
	bpf_sk_storage_get(&mptcp_ecf_map, msk, 0,
			   BPF_LOCAL_STORAGE_GET_F_CREATE);
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_ecf_release, struct mptcp_sock *msk)
{
	bpf_sk_storage_delete(&mptcp_ecf_map, msk);
}

static __always_inline bool ecf_backup(struct mptcp_subflow_context *subflow)
{
	return subflow->backup || subflow->request_bkup;
}

/* Fills fast with the active subflow of the lowest RTT and avail with the
 * one of the lowest RTT among those that can take data now, both among the
 * backup or the non-backup subflows. Returns whether one of those is
 * active.
 */
static __always_inline bool ecf_walk(struct sock *sk, bool backup,
				    struct ecf_path *fast,
				    struct ecf_path *avail)
{
	struct mptcp_subflow_context *subflow;
	bool found = false;

	__builtin_memset(fast, 0, sizeof(*fast));
	__builtin_memset(avail, 0, sizeof(*avail));
	fast->srtt = -1;
	avail->srtt = -1;

	bpf_for_each(mptcp_subflow, subflow, sk) {
		const struct tcp_sock *tp;
		__u64 srtt, cwnd, used;
		__u32 mss, in_flight;
		struct sock *ssk;

		if (ecf_backup(subflow) != backup ||
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

		/* srtt_us is 8 times the smoothed RTT */
		srtt = tp->srtt_us >> 3;
		if (!srtt)
			srtt = ECF_UNKNOWN_RTT_US;
		cwnd = (__u64)tp->snd_cwnd * mss;
		/* tcp_packets_in_flight(), then what waits in the queue */
		in_flight = tp->packets_out - (tp->sacked_out + tp->lost_out) +
			    tp->retrans_out;
		used = (__u64)in_flight * mss + (__u32)(tp->write_seq - tp->snd_nxt);

		if (srtt < fast->srtt) {
			fast->srtt = srtt;
			/* mdev_us is 4 times the RTT mean deviation */
			fast->mdev = tp->mdev_us >> 2;
			fast->cwnd = cwnd;
			fast->id = subflow->subflow_id;
			fast->backoff = tp->inet_conn.icsk_backoff;
		}
		if (used + mss <= cwnd && srtt < avail->srtt &&
		    bpf_sk_stream_memory_free(ssk)) {
			avail->srtt = srtt;
			avail->mdev = tp->mdev_us >> 2;
			avail->cwnd = cwnd;
			avail->room = cwnd - used;
			avail->id = subflow->subflow_id;
		}
	}

	return found;
}

SEC("struct_ops")
int BPF_PROG(bpf_ecf_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	__u64 k, delta, cwnd_f, cwnd_s, wnd_end;
	struct mptcp_ecf_storage *ptr;
	struct ecf_path fast, avail;
	bool backup = false;

	/* the MPTCP retransmission timer follows the subflows' own timers
	 * (see get_retrans below)
	 */
	mptcp_set_timeout(sk);

	ptr = bpf_sk_storage_get(&mptcp_ecf_map, msk, 0,
				 BPF_LOCAL_STORAGE_GET_F_CREATE);
	if (!ptr)
		return -1;

	if (!ecf_walk(sk, false, &fast, &avail)) {
		backup = true;
		if (!ecf_walk(sk, true, &fast, &avail))
			return -1;
	}

	/* every cwnd is full: the next ack pushes again */
	if (!avail.id)
		return -1;

	if (avail.id == fast.id || fast.backoff)
		goto send;

	/* The fastest subflow is cwnd-limited, avail is the fastest one with
	 * room. With k bytes left to send, waiting for the fastest subflow
	 * takes (1 + k / cwnd_f) * rtt_f; sending on avail takes at least
	 * rtt_s, plus the RTT deviation delta as a margin.
	 */
	k = min(msk->write_seq - msk->snd_nxt, ECF_MAX_BYTES);
	cwnd_f = min(fast.cwnd, ECF_MAX_BYTES);
	cwnd_s = min(avail.cwnd, ECF_MAX_BYTES);
	delta = max(fast.mdev, avail.mdev);

	if (ECF_R_BETA * fast.srtt * (k + cwnd_f) <
	    (ECF_R_BETA + ptr->waiting) * cwnd_f * (avail.srtt + delta)) {
		/* Waiting is quicker for the whole transfer. It is chosen only
		 * if what avail would carry also takes longer there than the
		 * fastest subflow needs to free its cwnd and deliver it,
		 * 2 * rtt_f + delta: otherwise avail helps and is used.
		 */
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
		if (ecf_backup(subflow) != backup ||
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

/* MPTCP-level retransmissions: the default scheduler's choice
 * (mptcp_subflow_get_retrans()), as in bpf_burst and bpf_rr, see bpf_rr for
 * why get_send calls mptcp_set_timeout(). A subflow with nothing
 * outstanding at TCP level, and a backup one only when no subflow makes
 * progress.
 */
SEC("struct_ops.s")
int BPF_PROG(bpf_ecf_get_retrans, struct mptcp_sock *msk)
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
struct mptcp_sched_ops ecf = {
	.init		= (void *)mptcp_sched_ecf_init,
	.release	= (void *)mptcp_sched_ecf_release,
	.get_send	= (void *)bpf_ecf_get_send,
	.get_retrans	= (void *)bpf_ecf_get_retrans,
	.name		= "bpf_ecf",
};
