// SPDX-License-Identifier: GPL-2.0
/* Copyright (c) 2023, SUSE (get_retrans, from bpf_burst). */
/* Copyright (c) 2026, Yannick Chabanois (Ycarus) for OpenMPTCProuter */

/* BLEST, BLocking ESTimation: S. Ferlin, O. Alay, O. Mehani and R. Boreli,
 * "BLEST: Blocking Estimation-based MPTCP Scheduler for Heterogeneous
 * Networks", IFIP Networking 2016. The decision is the one of
 * mptcp_blest.c in the out-of-tree multipath-tcp.org kernel, OMR's default
 * scheduler on its 4.x and 5.4 kernels.
 *
 * It sends on the lowest-RTT subflow while its congestion window has room.
 * When it has none, data sent on the slower subflow that has room takes the
 * MPTCP send window until it is acked, a slow RTT later. BLEST estimates
 * what the fast subflow would send meanwhile, its window growing as its
 * congestion control lets it, times a margin lambda. If that does not fit
 * in the MPTCP window left beside what the slow subflow has outstanding
 * plus this send, the fast subflow would be blocked by the slow one: it
 * sends nothing and the next ack pushes again (see bpf_ecf).
 *
 * lambda goes from 1.0 to 1.3, starting at 1.2. Once per minimum RTT of
 * the slow subflow, it goes up by 0.04 when the connection retransmitted at
 * MPTCP level since the last update (the slow subflow held data the
 * receiver needed) and down by 0.01 otherwise.
 *
 * Differences from the original, for the 6.x MPTCP stack:
 * - the MPTCP-level retransmission signal is msk->bytes_retrans growing,
 *   where the original read the meta socket's retrans_stamp;
 * - the minimum RTT is the kernel's windowed one (tcp_sock rtt_min) rather
 *   than the lowest smoothed RTT seen by the scheduler;
 * - the slow subflow's linger time is its smoothed RTT: the original's
 *   estimate between its minimum and smoothed RTT was then raised to the
 *   smoothed RTT anyway;
 * - room, burst, the RTO backoff exception and the backup subflows are
 *   bpf_ecf's.
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

/* lambda in thousandths, the original's values */
#define BLEST_LAMBDA_INIT	1200
#define BLEST_LAMBDA_MIN	1000
#define BLEST_LAMBDA_MAX	1300
#define BLEST_LAMBDA_GOOD	10
#define BLEST_LAMBDA_BAD	40

/* initial slow start doubles the window this many RTTs at most */
#define BLEST_MAX_SS_RTTS	16

#define TCP_INFINITE_SSTHRESH	0x7fffffff

#define BLEST_MAX_BYTES		(1ULL << 32)

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

/* The RTT of a subflow without a sample yet, which then ranks behind the
 * others (see bpf_ecf). A variable, not a constant: blest_fill() compares
 * it again, and between two such subflows the verifier would compare two
 * known constants, track them exactly, and never see the walk converge
 * (1M instructions processed). Read from .data, the value is unknown to it.
 */
volatile __u64 blest_unknown_rtt_us = 1000000;

struct mptcp_blest_storage {
	__u64 lambda_stamp;	/* ns */
	__u64 bytes_retrans;	/* msk->bytes_retrans at that time */
	__u32 lambda;		/* thousandths */
};

struct {
	__uint(type, BPF_MAP_TYPE_SK_STORAGE);
	__uint(map_flags, BPF_F_NO_PREALLOC);
	__type(key, int);
	__type(value, struct mptcp_blest_storage);
} mptcp_blest_map SEC(".maps");

/* Only scalars, and the subflow_id rather than a pointer or a position:
 * see struct ecf_path in bpf_ecf for the verifier limits behind that.
 */
struct blest_path {
	__u64 srtt;	/* us */
	__u64 rtt_min;	/* us */
	__u64 room;	/* bytes the cwnd still lets out */
	__u64 out;	/* bytes sent or queued and not acked yet */
	__u32 mss;
	__u32 cwnd;	/* segments */
	__u32 ssthresh;
	__u32 id;	/* subflow_id, 0 if none */
	__u32 backoff;
};

static __always_inline struct mptcp_blest_storage *
blest_storage(struct mptcp_sock *msk)
{
	struct mptcp_blest_storage *ptr;

	ptr = bpf_sk_storage_get(&mptcp_blest_map, msk, 0,
				 BPF_LOCAL_STORAGE_GET_F_CREATE);
	if (ptr && !ptr->lambda) {
		ptr->lambda = BLEST_LAMBDA_INIT;
		ptr->lambda_stamp = bpf_ktime_get_ns();
		ptr->bytes_retrans = msk->bytes_retrans;
	}
	return ptr;
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_blest_init, struct mptcp_sock *msk)
{
	blest_storage(msk);
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_blest_release, struct mptcp_sock *msk)
{
	bpf_sk_storage_delete(&mptcp_blest_map, msk);
}

static __always_inline bool blest_backup(struct mptcp_subflow_context *subflow)
{
	return subflow->backup || subflow->request_bkup;
}

static __always_inline void blest_fill(struct blest_path *p,
				       const struct tcp_sock *tp,
				       struct mptcp_subflow_context *subflow,
				       __u64 srtt, __u32 mss)
{
	__u64 rtt_min = tp->rtt_min.s[0].v;

	p->srtt = srtt;
	p->rtt_min = rtt_min && rtt_min < srtt ? rtt_min : srtt;
	p->out = (__u32)(tp->write_seq - tp->snd_una);
	p->mss = mss;
	p->cwnd = tp->snd_cwnd;
	p->ssthresh = tp->snd_ssthresh;
	p->id = subflow->subflow_id;
	p->backoff = tp->inet_conn.icsk_backoff;
}

/* Fills fast with the active subflow of the lowest RTT and avail with the
 * one of the lowest RTT among those that can take data now, both among the
 * backup or the non-backup subflows. Returns whether one of those is
 * active.
 */
static __always_inline bool blest_walk(struct sock *sk, bool backup,
				      struct blest_path *fast,
				      struct blest_path *avail)
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

		if (blest_backup(subflow) != backup ||
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
			srtt = blest_unknown_rtt_us;
		cwnd = (__u64)tp->snd_cwnd * mss;
		/* tcp_packets_in_flight(), then what waits in the queue */
		in_flight = tp->packets_out - (tp->sacked_out + tp->lost_out) +
			    tp->retrans_out;
		used = (__u64)in_flight * mss + (__u32)(tp->write_seq - tp->snd_nxt);

		if (srtt < fast->srtt)
			blest_fill(fast, tp, subflow, srtt, mss);
		if (used + mss <= cwnd && srtt < avail->srtt &&
		    bpf_sk_stream_memory_free(ssk)) {
			blest_fill(avail, tp, subflow, srtt, mss);
			avail->room = cwnd - used;
		}
	}

	return found;
}

/* Once per minimum RTT of the slow subflow: up when the connection
 * retransmitted at MPTCP level meanwhile, down otherwise.
 */
static __always_inline void blest_update_lambda(struct mptcp_sock *msk,
						struct mptcp_blest_storage *ptr,
						const struct blest_path *slow)
{
	__u64 now = bpf_ktime_get_ns();
	__u64 retrans = msk->bytes_retrans;
	__u32 lambda = ptr->lambda;

	if (now - ptr->lambda_stamp < slow->rtt_min * 1000)
		return;

	if (retrans != ptr->bytes_retrans)
		lambda = min(lambda + BLEST_LAMBDA_BAD, BLEST_LAMBDA_MAX);
	else if (lambda > BLEST_LAMBDA_MIN + BLEST_LAMBDA_GOOD)
		lambda -= BLEST_LAMBDA_GOOD;
	else
		lambda = BLEST_LAMBDA_MIN;

	ptr->lambda = lambda;
	ptr->lambda_stamp = now;
	ptr->bytes_retrans = retrans;
}

/* The bytes the fast subflow sends in time_us, assuming Reno: its window
 * doubles each RTT in initial slow start, grows by a segment each RTT
 * otherwise. Its RTT for that is between its minimum and its smoothed one.
 */
static __always_inline __u64 blest_fast_bytes(const struct blest_path *fast,
					      __u64 time_us, __u32 lambda)
{
	__u64 rtt = (fast->rtt_min + fast->srtt) / 2;
	__u64 rtts, packets, cwnd = fast->cwnd;

	rtts = rtt ? time_us / rtt + 1 : 1;
	if (fast->ssthresh >= TCP_INFINITE_SSTHRESH) {
		rtts = min(rtts, BLEST_MAX_SS_RTTS);
		packets = cwnd * ((1ULL << rtts) - 1);
	} else {
		rtts = min(rtts, 1 << 16);
		cwnd = max(cwnd, (__u64)fast->ssthresh + 1);
		packets = (cwnd + (rtts - 1) / 2) * rtts;
	}
	/* cwnd is under 2^31 and packets under 2^47: capped before the
	 * products below leave 64 bits
	 */
	packets = min(packets, BLEST_MAX_BYTES);

	return min(packets * fast->mss, BLEST_MAX_BYTES) * lambda / 1000;
}

SEC("struct_ops")
int BPF_PROG(bpf_blest_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	struct mptcp_blest_storage *ptr;
	struct blest_path fast, avail;
	__u64 wnd_end, wnd, burst, slow_bytes;
	bool backup = false;

	mptcp_set_timeout(sk);

	ptr = blest_storage(msk);
	if (!ptr)
		return -1;

	if (!blest_walk(sk, false, &fast, &avail)) {
		backup = true;
		if (!blest_walk(sk, true, &fast, &avail))
			return -1;
	}

	/* every cwnd is full: the next ack pushes again */
	if (!avail.id)
		return -1;

	/* A closed MPTCP window still schedules a subflow, without a burst,
	 * as the default scheduler does: that is where the zero window probe
	 * goes.
	 */
	wnd_end = mptcp_wnd_end(msk);
	burst = 0;
	if (wnd_end > msk->snd_nxt)
		burst = min(min(avail.room, MPTCP_SEND_BURST_SIZE),
			    wnd_end - msk->snd_nxt);

	if (avail.id == fast.id || fast.backoff || !burst)
		goto send;

	/* The fastest subflow is cwnd-limited, avail is slower. What avail
	 * has outstanding plus this burst stays in the MPTCP send window for
	 * avail's RTT; the fast subflow must fit what it sends meanwhile in
	 * the rest of the window, or it would be blocked.
	 */
	blest_update_lambda(msk, ptr, &avail);
	wnd = wnd_end - msk->snd_una;
	slow_bytes = avail.out + burst;
	if (blest_fast_bytes(&fast, avail.srtt, ptr->lambda) >
	    (slow_bytes < wnd ? wnd - slow_bytes : 0))
		return -1;

send:
	bpf_for_each(mptcp_subflow, subflow, sk) {
		if (subflow->subflow_id != avail.id)
			continue;
		if (blest_backup(subflow) != backup ||
		    !mptcp_subflow_active(subflow))
			return -1;

		if (burst)
			msk->snd_burst = burst;
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
 * bpf_ecf.
 */
SEC("struct_ops.s")
int BPF_PROG(bpf_blest_get_retrans, struct mptcp_sock *msk)
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
struct mptcp_sched_ops blest = {
	.init		= (void *)mptcp_sched_blest_init,
	.release	= (void *)mptcp_sched_blest_release,
	.get_send	= (void *)bpf_blest_get_send,
	.get_retrans	= (void *)bpf_blest_get_retrans,
	.name		= "bpf_blest",
};
