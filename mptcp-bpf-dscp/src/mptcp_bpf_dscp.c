// SPDX-License-Identifier: GPL-2.0
/* Based on Burst scheduler */
/* Copyright (c) 2023, SUSE. */
/* Copyright (c) 2026, Yannick Chabanois */
/*
 * DSCP-aware MPTCP scheduler: pins each DSCP class to a chosen WAN
 * subflow, using the same smooth-weighted-round-robin selection as
 * bpf_weight_rr (mptcp-bpf-weight-rr) rather than an exclusive
 * winner-take-all pick.
 *
 * A subflow can be pinned two ways, matched independently (either one
 * is enough to mark it as the pin target for its DSCP class):
 *  - dscp_iface:     DSCP -> local endpoint IP (skc_rcv_saddr/inet_saddr).
 *                    Router-side: each WAN has its own distinct local
 *                    IP, set via `mptcp-scheduler-dscp.sh set <dscp>
 *                    <interface>`.
 *  - dscp_remote_id: DSCP -> MPTCP remote endpoint id (subflow's
 *                    remote_id). Server-side (VPS): every subflow
 *                    shares the same local IP there, so pinning by
 *                    local IP can't distinguish WANs. remote_id is the
 *                    address id the router assigned to that WAN
 *                    (MP_JOIN/ADD_ADDR), stable across the router's
 *                    WAN IP changing (DHCP renewal, mobile reconnects),
 *                    set via `mptcp-scheduler-dscp.sh set <dscp> id
 *                    <N>`.
 *
 * Why weighted instead of exclusive: an earlier version picked the
 * pinned subflow outright whenever mptcp_subflow_active() reported it
 * active that call, and fell all the way back to a generic
 * least-queued pick among every OTHER subflow the moment it didn't --
 * a single missed "active" report meant zero influence from the pin
 * for that call, no matter how heavily it was meant to be preferred.
 * Live A/B testing (bench, 2026-08-07) confirmed this in practice: the
 * exclusive version won its pinned WAN in only ~1/6 real download
 * trials, while bpf_weight_rr's smooth-weighted-round-robin approach
 * -- pinned WAN given a large weight, everyone else a small one, same
 * accumulator algorithm either way -- won 9/10 trials on the identical
 * setup, because a subflow that misses one round doesn't lose the pin
 * permanently: its accumulated weight (dscp_cw_map, keyed by
 * (msk, local_ip), same design as bpf_weight_rr's subflow_cw_map)
 * just keeps growing untouched while it's inactive, and it resumes
 * dominating the instant it's active again. Same DSCP_PIN_WEIGHT
 * ratio as an exclusive pin when the pinned subflow is consistently
 * active (it still wins essentially every turn), but degrades
 * gracefully instead of collapsing to zero influence when it isn't.
 */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>
#include "limits.h"

char _license[] SEC("license") = "GPL";

#define MPTCP_SEND_BURST_SIZE	65428
/* Raised back to 8 to match bpf_weight_rr's MAX_SUBFLOWS, per explicit
 * request (2026-08-12). History: this was previously dropped to 4
 * because at 8 this function's extra branching factor (two
 * independently-nullable pin sources, dscp_iface AND dscp_remote_id,
 * live across both loops -- see the file header comment -- versus
 * weight_rr's single sequential map-lookup-with-fallback) pushed the
 * verifier's state-space exploration over its 1,000,000 instruction
 * budget ("BPF program is too large") on one specific kernel/clang
 * combo at the time. Re-tested live at 8 on the bench (kernel 6.18.39,
 * clang/llvm 21, 2026-08-12): compiles clean and `bpftool struct_ops
 * register` loads it with no verifier error, so that combo no longer
 * reproduces the failure -- whatever changed (newer clang codegen,
 * newer kernel verifier), 8 is confirmed safe to load here. If "BPF
 * program is too large" resurfaces on some other kernel/toolchain,
 * drop back to 4 rather than fighting the verifier further -- see git
 * history for the prior state.
 */
#define MAX_SUBFLOWS		8

/* Weight ratio between the pinned target and everything else -- large
 * enough that the pinned subflow wins essentially every turn while
 * it's active (999 wins per 1 for a lone competitor), without needing
 * a hard exclusive branch. See the file header comment for why that
 * matters.
 */
#define DSCP_PIN_WEIGHT		1000
#define DSCP_NEUTRAL_WEIGHT	1

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

/* DSCP (0-63) -> preferred MPTCP remote endpoint id (subflow->remote_id).
 * Server-side (VPS) equivalent of dscp_iface: every subflow shares the
 * same local IP there, so this keys on the address id the router
 * assigned to the originating WAN instead. Populated from userspace,
 * e.g. by mptcp-scheduler-dscp.sh set <dscp> id <remote_id>.
 */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);
	__type(value, __u8);
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} dscp_remote_id SEC(".maps");

/* local_ip alone is NOT a safe per-subflow discriminator here: on the
 * VPS (dscp_remote_id pinning), every subflow shares the SAME local_ip
 * (the VPS has one address; only remote_id differs per router WAN) --
 * confirmed live via bpf_printk-instrumented debug builds + trace_pipe
 * on the VPS (bench, 2026-08-07, see mptcp-dscp-weight-vps-sync-feature
 * memory): with only local_ip in the key, all candidates for a given
 * msk collided onto the SAME dscp_cw_map entry and clobbered each
 * other's accumulator within the same get_send call, so "best_idx"
 * degenerated to whichever subflow bpf_for_each happened to enumerate
 * LAST -- not the one with the highest weight. Confirmed win_pin=1 in
 * only 0/431 sampled real-traffic decisions with local_ip alone, vs.
 * 408/409 once remote_port was added below. remote_port (skc_dport)
 * differs per subflow on the VPS side (each router WAN uses a distinct
 * ephemeral source port) while local_ip differs per subflow on the
 * router side (dscp_iface pinning) -- keying on both together is
 * unique on either end.
 */
struct dscp_cw_key {
	__u64 msk;
	__u32 local_ip;
	__be16 remote_port;
};

/* Per-(connection, WAN) smooth weighted round-robin state -- identical
 * design to bpf_weight_rr's subflow_cw_map (see that file's header
 * comment for the nginx-style algorithm details and why it's kept as
 * one lookup/update per subflow rather than a nested-loop search).
 * LRU so orphaned entries from closed connections age out on their own.
 * Named _v2 (this map was never actually shipped -- see
 * mptcp-dscp-weight-vps-sync-feature memory -- so there's no upgrade
 * path to preserve, but the key layout changed and LIBBPF_PIN_BY_NAME
 * would otherwise fail to reuse a stale pinned map with the old
 * key_size) rather than reusing the old "dscp_cw_map" name.
 */
struct {
	__uint(type, BPF_MAP_TYPE_LRU_HASH);
	__type(key, struct dscp_cw_key);
	__type(value, __s32);
	__uint(max_entries, 4096);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} dscp_cw_map_v2 SEC(".maps");

struct dscp_entry {
	struct sock *ssk;
	__u32 local_ip;
	__be16 remote_port;
	__u32 weight;
	__s32 cw;
	__u8 is_backup;
};

static __always_inline __u64 div_u64(__u64 dividend, __u32 divisor)
{
	return dividend / divisor;
}

static __always_inline bool remote_id_matches(struct mptcp_subflow_context *subflow,
						__u8 desired_id)
{
	return desired_id == subflow->remote_id;
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
	struct dscp_entry entries[MAX_SUBFLOWS] = {};
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	int nr_active = 0, nr_total = 0;
	__u64 msk_key = (__u64)(unsigned long)msk;
	__u32 total_weight = 0;
	__u32 pace, burst, wmem;
	struct sock *ssk = NULL;
	int best_idx = -1;
	__u32 *desired_ip;
	__u8 *desired_remote_id;
	__u8 use_backup;
	__u8 dscp, tos;
	int i;

	tos = BPF_CORE_READ(msk, sk.icsk_inet.tos);
	dscp = tos >> 2;
	desired_ip = bpf_map_lookup_elem(&dscp_iface, &dscp);
	desired_remote_id = bpf_map_lookup_elem(&dscp_remote_id, &dscp);

	bpf_for_each(mptcp_subflow, subflow, sk) {
		__u8 is_backup = (subflow->backup || subflow->request_bkup) ? 1 : 0;
		__u32 local_ip, weight;
		bool is_pin_target;
		struct sock *cur;

		if (nr_total >= MAX_SUBFLOWS)
			break;

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

		/* Direct member access on this trusted pointer, like
		 * bpf_weight_rr_get_send's identical local_ip read -- NOT
		 * BPF_CORE_READ()/local_ip_matches() (which does its own,
		 * separate BPF_CORE_READ of the same field plus an extra,
		 * redundant inet_saddr fallback check once
		 * mptcp_subflow_active() has already confirmed this subflow
		 * is established). This alone wasn't sufficient, though --
		 * see MAX_SUBFLOWS' comment for the rest of the fix.
		 */
		local_ip = cur->__sk_common.skc_rcv_saddr;
		is_pin_target = (desired_ip && local_ip == *desired_ip) ||
				(desired_remote_id && remote_id_matches(subflow, *desired_remote_id));
		weight = is_pin_target ? DSCP_PIN_WEIGHT : DSCP_NEUTRAL_WEIGHT;

		entries[nr_total].ssk = cur;
		entries[nr_total].local_ip = local_ip;
		entries[nr_total].remote_port = cur->__sk_common.skc_dport;
		entries[nr_total].weight = weight;
		entries[nr_total].is_backup = is_backup;
		nr_total++;
		if (!is_backup)
			nr_active++;
	}

	mptcp_set_timeout(sk);

	if (nr_total == 0)
		return -1;

	/* Prefer active subflows; fall back to backup if none active --
	 * same convention as bpf_weight_rr.
	 */
	use_backup = (nr_active == 0) ? 1 : 0;

	/* Smooth weighted round-robin (nginx-style), identical algorithm to
	 * bpf_weight_rr_get_send: every candidate's current-weight
	 * (persisted in dscp_cw_map_v2, keyed by (msk, local_ip,
	 * remote_port)) is bumped by its own weight and written back in
	 * this same pass, while total_weight accumulates alongside it;
	 * the winner isn't known
	 * until the pass finishes, so its debit (cw -= total_weight) is
	 * applied as a single extra map update right after the loop rather
	 * than in a second pass over all candidates -- see
	 * mptcp_bpf_weight_rr.c's identical comment for why a second full
	 * loop blew up the BPF verifier's state space.
	 *
	 * With DSCP_PIN_WEIGHT >> DSCP_NEUTRAL_WEIGHT, the pinned subflow
	 * wins essentially every turn while it's active (this reproduces
	 * the old exclusive pin's behavior in the common case) -- but if it
	 * drops out of "active" for a stretch, its accumulated cw simply
	 * stops growing rather than being lost, and the OTHER subflows'
	 * cw keeps accumulating on their own weight in the meantime. The
	 * instant the pinned subflow is active again, it resumes winning
	 * immediately: no separate "have_pin"/exclusive-branch state to
	 * fall out of sync, and no permanent loss of preference from one
	 * missed round.
	 */
	for (i = 0; i < MAX_SUBFLOWS; i++) {
		struct dscp_cw_key key = {};
		__s32 *cw_ptr, cw;

		if (i >= nr_total)
			break;
		if (entries[i].is_backup != use_backup)
			continue;

		total_weight += entries[i].weight;

		key.msk = msk_key;
		key.local_ip = entries[i].local_ip;
		key.remote_port = entries[i].remote_port;
		cw_ptr = bpf_map_lookup_elem(&dscp_cw_map_v2, &key);
		cw = cw_ptr ? *cw_ptr : 0;
		cw += (__s32)entries[i].weight;
		entries[i].cw = cw;
		bpf_map_update_elem(&dscp_cw_map_v2, &key, &cw, BPF_ANY);

		/* best_idx < 0 alone only proves a lower bound; without an explicit
		 * upper bound too, the verifier can't prove entries[best_idx] below
		 * stays inside the array once best_idx has been spilled to the
		 * stack and reloaded ("invalid unbounded variable-offset read from
		 * stack") -- confirmed live on this kernel/clang combo even though
		 * best_idx is only ever assigned values in [0, MAX_SUBFLOWS) by
		 * this same loop. bpf_weight_rr_get_send has the identical
		 * best_idx pattern without this extra check and loads fine today,
		 * but that's apparently down to incidental register allocation
		 * from having less code ahead of it, not a guarantee -- add the
		 * explicit bound here rather than rely on that.
		 */
		if (best_idx < 0 || best_idx >= MAX_SUBFLOWS || cw > entries[best_idx].cw)
			best_idx = i;
	}

	if (!total_weight)
		return -1;

	if (best_idx >= 0 && best_idx < MAX_SUBFLOWS) {
		struct dscp_cw_key key = {};
		__s32 cw = entries[best_idx].cw - (__s32)total_weight;

		key.msk = msk_key;
		key.local_ip = entries[best_idx].local_ip;
		key.remote_port = entries[best_idx].remote_port;
		bpf_map_update_elem(&dscp_cw_map_v2, &key, &cw, BPF_ANY);

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
