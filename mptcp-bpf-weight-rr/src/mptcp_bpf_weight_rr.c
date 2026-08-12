// SPDX-License-Identifier: GPL-2.0
/* Based on Burst scheduler */
/* Copyright (c) 2023, SUSE. */
/* Copyright (c) 2025-2026, Yannick Chabanois */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_helpers.h>
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

struct subflow_entry {
	struct sock *ssk;
	__u32 local_ip;
	__be16 remote_port;
	__u32 weight;
	__s32 cw;      /* bumped current-weight for this round (SWRR) */
	__u8 is_backup;
};

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u32);   /* local IP as stored in skc_rcv_saddr */
	__type(value, __u32); /* weight: higher = more traffic (e.g. 80 for SAT, 20 for LTE) */
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} endpoint_weights SEC(".maps");

/* Server/VPS-side counterpart of endpoint_weights: every subflow shares
 * the same local IP there, so a local-IP-keyed weight can't distinguish
 * WANs. Keys on the MPTCP remote endpoint id instead (the address id the
 * router assigned to the originating WAN, stable across the router's WAN
 * IP changing) -- same map shape/purpose as mptcp_bpf_dscp's
 * dscp_remote_id, set via mptcp-scheduler-weight.sh set id <N> <weight>.
 * Shared (same pinned name) with mptcp_bpf_weight.c's identical map.
 */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);    /* subflow->remote_id */
	__type(value, __u32); /* weight, same semantics as endpoint_weights */
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} weight_remote_id SEC(".maps");

/* local_ip alone is NOT a safe per-subflow discriminator here: on the
 * VPS (weight_remote_id pinning), every subflow shares the SAME
 * local_ip (the VPS has one address; only remote_id differs per router
 * WAN) -- confirmed live via bpf_printk-instrumented debug builds +
 * trace_pipe on the VPS (bench, 2026-08-07, see
 * mptcp-dscp-weight-vps-sync-feature memory): with only local_ip in the
 * key, all candidates for a given msk collided onto the SAME
 * subflow_cw_map entry and clobbered each other's accumulator within
 * the same get_send call, so "best_idx" degenerated to whichever
 * subflow bpf_for_each happened to enumerate LAST -- not the one with
 * the highest weight. This is almost certainly the real explanation for
 * this scheduler's own documented long-download anomaly (one of two
 * 200MB runs reversed ~1.77:1 against the pinned target) previously
 * attributed to kernel-level primary-subflow race timing -- that
 * explanation was based on router-side-only bpf_printk tracing (see
 * weight-rr-scheduler-bias-open-question memory), which never exercises
 * this VPS-side remote_id path at all, so it never could have caught
 * this. remote_port (skc_dport) differs per subflow on the VPS side
 * (each router WAN uses a distinct ephemeral source port) while
 * local_ip differs per subflow on the router side (endpoint_weights
 * pinning) -- keying on both together is unique on either end.
 */
struct cw_key {
	__u64 msk;
	__u32 local_ip;
	__be16 remote_port;
};

/* Per-(connection, WAN) smooth weighted round-robin state (nginx-style:
 * every call bumps each candidate's current-weight by its configured
 * weight, picks the highest, then debits total_weight from the winner).
 * Replaces an older "counter % total_weight, contiguous cumulative range"
 * scheme that assigned each endpoint one long unbroken burst of turns
 * (e.g. 150 consecutive picks for a weight=150 WAN, then 50 for
 * weight=50) rather than interleaving them — under real send-buffer
 * backpressure the WAN with the long burst was far more likely to hit
 * bpf_sk_stream_memory_free()==false mid-burst and waste
 * already-allocated turns, collapsing the intended 3:1 delivered-packet
 * ratio to ~1:1 or worse. Confirmed via bpf_printk trace + a 200MB bench
 * transfer.
 *
 * Keyed directly by (msk, local_ip) rather than a per-connection
 * fixed-size slot array: an earlier version searched a small
 * per-connection array for the matching local_ip, which needed nested
 * loops that made the BPF verifier's state space explode (rejected with
 * "BPF program is too large. Processed 1000001 insn"). A single
 * lookup/update per subflow avoids that entirely. LRU so orphaned
 * entries (closed connections skip the release hook path here) age out
 * instead of needing explicit cleanup.
 *
 * Named _v2: the key layout changed (see struct cw_key's comment above)
 * and LIBBPF_PIN_BY_NAME would otherwise fail to reuse a stale pinned
 * map with the old key_size; this map was never actually shipped, so
 * there's no upgrade path to preserve.
 */
struct {
	__uint(type, BPF_MAP_TYPE_LRU_HASH);
	__type(key, struct cw_key);
	__type(value, __s32);
	__uint(max_entries, 4096);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} subflow_cw_map_v2 SEC(".maps");

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
void BPF_PROG(mptcp_sched_weight_rr_init, struct mptcp_sock *msk)
{
}

SEC("struct_ops")
void BPF_PROG(mptcp_sched_weight_rr_release, struct mptcp_sock *msk)
{
	/* subflow_cw_map_v2 is an LRU hash keyed by (msk, local_ip,
	 * remote_port); entries for a closed connection simply age out,
	 * no explicit cleanup needed here.
	 */
}

SEC("struct_ops")
int BPF_PROG(bpf_weight_rr_get_send, struct mptcp_sock *msk)
{
	struct subflow_entry entries[MAX_SUBFLOWS] = {};
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	int nr_active = 0, nr_total = 0;
	__u64 msk_key = (__u64)(unsigned long)msk;
	__u32 total_weight = 0;
	__u32 pace, burst, wmem;
	struct sock *ssk = NULL;
	int best_idx = -1;
	__u8 use_backup;
	int i;

	bpf_for_each(mptcp_subflow, subflow, sk) {
		__u8 is_backup = (subflow->backup || subflow->request_bkup) ? 1 : 0;
		__u32 local_ip, weight;
		__u32 *w_ptr;

		if (nr_total >= MAX_SUBFLOWS)
			break;

		ssk = mptcp_subflow_tcp_sock(subflow);
		if (!mptcp_subflow_active(subflow))
			continue;

		pace = subflow->avg_pacing_rate;
		if (!pace) {
			subflow->avg_pacing_rate = ssk->sk_pacing_rate;
			pace = subflow->avg_pacing_rate;
			if (!pace)
				continue;
		}

		local_ip = ssk->__sk_common.skc_rcv_saddr;
		weight = 100;
		w_ptr = bpf_map_lookup_elem(&endpoint_weights, &local_ip);
		if (!w_ptr) {
			__u8 remote_id = subflow->remote_id;

			/* See mptcp_bpf_weight.c's identical fallback for
			 * why: router-side this is a no-op (remote_id there
			 * identifies the VPS's one address, not a WAN);
			 * VPS-side it's the only key that DOES distinguish
			 * WANs, since endpoint_weights always misses there.
			 */
			w_ptr = bpf_map_lookup_elem(&weight_remote_id, &remote_id);
		}
		if (w_ptr && *w_ptr > 0)
			weight = *w_ptr;

		entries[nr_total].ssk = ssk;
		entries[nr_total].local_ip = local_ip;
		entries[nr_total].remote_port = ssk->__sk_common.skc_dport;
		entries[nr_total].weight = weight;
		entries[nr_total].is_backup = is_backup;
		nr_total++;
		if (!is_backup)
			nr_active++;
	}

	mptcp_set_timeout(sk);

	if (nr_total == 0)
		return -1;

	/* Prefer active subflows; fall back to backup if none active */
	use_backup = (nr_active == 0) ? 1 : 0;

	/* Smooth weighted round-robin (nginx-style): every candidate's
	 * current-weight (persisted in subflow_cw_map_v2, keyed by
	 * (msk, local_ip, remote_port)) is bumped by its own weight and
	 * written back in this same pass, while total_weight accumulates
	 * alongside it; the winner isn't known until the pass finishes, so
	 * its debit
	 * (cw -= total_weight) is applied as a single extra map update right
	 * after the loop rather than in a second pass over all candidates —
	 * a second full loop (tried first) plus this one made the BPF
	 * verifier's state space explode ("BPF program is too large.
	 * Processed 1000001 insn"); one pass here keeps it at parity with
	 * the original single-pass scheme.
	 *
	 * This interleaves picks turn-by-turn (e.g. 150:50 settles into a
	 * steady ...,A,A,A,B,A,A,A,B,... pattern) instead of handing one
	 * endpoint one long unbroken burst (the old "counter % total_weight,
	 * contiguous cumulative range" scheme) — so a temporary
	 * bpf_sk_stream_memory_free() failure on the heavy endpoint costs it
	 * one turn, not the whole remainder of its burst.
	 */
	for (i = 0; i < MAX_SUBFLOWS; i++) {
		struct cw_key key = {};
		__s32 *cw_ptr, cw;

		if (i >= nr_total)
			break;
		if (entries[i].is_backup != use_backup)
			continue;

		total_weight += entries[i].weight;

		key.msk = msk_key;
		key.local_ip = entries[i].local_ip;
		key.remote_port = entries[i].remote_port;
		cw_ptr = bpf_map_lookup_elem(&subflow_cw_map_v2, &key);
		cw = cw_ptr ? *cw_ptr : 0;
		cw += (__s32)entries[i].weight;
		entries[i].cw = cw;
		bpf_map_update_elem(&subflow_cw_map_v2, &key, &cw, BPF_ANY);

		if (best_idx < 0 || cw > entries[best_idx].cw)
			best_idx = i;
	}

	if (!total_weight)
		return -1;

	if (best_idx >= 0) {
		struct cw_key key = {};
		__s32 cw = entries[best_idx].cw - (__s32)total_weight;

		key.msk = msk_key;
		key.local_ip = entries[best_idx].local_ip;
		key.remote_port = entries[best_idx].remote_port;
		bpf_map_update_elem(&subflow_cw_map_v2, &key, &cw, BPF_ANY);

		ssk = entries[best_idx].ssk;
	}

	/* Safety fallback: pick first available in set */
	if (!ssk) {
		for (i = 0; i < MAX_SUBFLOWS; i++) {
			if (i >= nr_total)
				break;
			if (entries[i].is_backup == use_backup) {
				ssk = entries[i].ssk;
				break;
			}
		}
	}

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
int BPF_PROG(bpf_weight_rr_get_retrans, struct mptcp_sock *msk)
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
struct mptcp_sched_ops weight_rr = {
	.init		= (void *)mptcp_sched_weight_rr_init,
	.release	= (void *)mptcp_sched_weight_rr_release,
	.get_send	= (void *)bpf_weight_rr_get_send,
	.get_retrans	= (void *)bpf_weight_rr_get_retrans,
	.name		= "bpf_weight_rr",
};
