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
 *  - dscp_remote_ids: DSCP -> set of MPTCP remote endpoint ids (subflow's
 *                    remote_id). Server-side (VPS): every subflow
 *                    shares the same local IP there, so pinning by
 *                    local IP can't distinguish WANs. remote_id is the
 *                    address id the router assigned to that WAN
 *                    (MP_JOIN/ADD_ADDR), stable across the router's
 *                    WAN IP changing (DHCP renewal, mobile reconnects),
 *                    set via `mptcp-scheduler-dscp.sh set <dscp> id
 *                    <N>...`. A set, as a dual-stack WAN has one id
 *                    per address (its metric for IPv4, +128/+192 for
 *                    IPv6, see the router's multipath script).
 *  - dscp_local_ids: DSCP -> set of local endpoint ids, for the router's
 *                    IPv6 subflows, whose skc_rcv_saddr is 127.0.0.6
 *                    whatever the WAN. Set together with dscp_iface.
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
 * (msk, subflow), same design as bpf_weight_rr's subflow_cw_map)
 * just keeps growing untouched while it's inactive, and it resumes
 * dominating the instant it's active again. Same DSCP_PIN_WEIGHT
 * ratio as an exclusive pin when the pinned subflow is consistently
 * active (it still wins essentially every turn), but degrades
 * gracefully instead of collapsing to zero influence when it isn't.
 */

#include "mptcp_bpf.h"
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_endian.h>
#include "limits.h"

char _license[] SEC("license") = "GPL";

#define MPTCP_SEND_BURST_SIZE	65428
/* Weight ratio between the pinned target and everything else -- large
 * enough that the pinned subflow wins essentially every turn while
 * it's active (999 wins per 1 for a lone competitor), without needing
 * a hard exclusive branch. See the file header comment for why that
 * matters.
 */
#define DSCP_PIN_WEIGHT		1000
#define DSCP_NEUTRAL_WEIGHT	1

#define min(a, b) ((a) < (b) ? (a) : (b))

/* skc_rcv_saddr of every native IPv6 socket (tcp_v6_connect() sets it) */
#define LOOPBACK4_IPV6		bpf_htonl(0x7f000006)

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

/* DSCP (0-63) -> preferred MPTCP remote endpoint ids (subflow->remote_id).
 * Server-side (VPS) equivalent of dscp_iface: every subflow shares the
 * same local IP there, so this keys on the address ids the router
 * assigned to the originating WAN instead, one per address of that WAN.
 * Populated from userspace, e.g. by mptcp-scheduler-dscp.sh set <dscp>
 * id <remote_id>...
 *
 * The ids are a 256-bit set, bit (id & 7) of byte (id >> 3), rather than
 * a count and an array: matching a subflow is then one bounded byte
 * read, with no loop inside the subflow loop to add to the verifier's
 * state space. Renamed from dscp_remote_id, whose value was a single
 * __u8: LIBBPF_PIN_BY_NAME would otherwise fail to reuse a map still
 * pinned with the old value_size after an upgrade.
 */
struct dscp_remote_ids {
	__u8 ids[32];
};

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);
	__type(value, struct dscp_remote_ids);
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} dscp_remote_ids SEC(".maps");

/* DSCP (0-63) -> local endpoint ids, same set layout as dscp_remote_ids.
 * Router-side pins of IPv6 subflows: dscp_iface keys on the local IPv4
 * address and every native IPv6 socket has 127.0.0.6 there, so no IPv6
 * subflow ever matched a pin. Populated by mptcp-scheduler-dscp.sh set
 * <dscp> <interface> with the ids of the WAN's IPv6 endpoints; empty on the
 * VPS. Looked up only for an IPv6 subflow, inside the subflow loop, so it
 * adds no pointer that stays live across the loop.
 */
struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__type(key, __u8);
	__type(value, struct dscp_remote_ids);
	__uint(max_entries, 64);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} dscp_local_ids SEC(".maps");

/* The SWRR state of one subflow. It was keyed by (local_ip, remote_port),
 * which is unique for IPv4 subflows only: local_ip is 127.0.0.6 for every
 * native IPv6 socket and remote_port is the VPS's one port on the router,
 * so all the IPv6 subflows of a connection shared one accumulator, clobbered
 * it within the same get_send call, and the one enumerated last won. The
 * subflow socket itself is unique on either end. (local_ip alone had already
 * collided on the VPS, where every subflow has the same local address.)
 */
struct dscp_cw_key {
	__u64 msk;
	__u64 ssk;
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
 * key_size) rather than reusing the old "dscp_cw_map" name. The (msk, ssk)
 * key kept the size of the (msk, local_ip, remote_port) one, so the name
 * stays: an entry left from the old layout can't match a socket address and
 * ages out.
 */
struct {
	__uint(type, BPF_MAP_TYPE_LRU_HASH);
	__type(key, struct dscp_cw_key);
	__type(value, __s32);
	__uint(max_entries, 4096);
	__uint(pinning, LIBBPF_PIN_BY_NAME);
} dscp_cw_map_v2 SEC(".maps");

static __always_inline __u64 div_u64(__u64 dividend, __u32 divisor)
{
	return dividend / divisor;
}

static __always_inline bool remote_id_matches(struct mptcp_subflow_context *subflow,
						const struct dscp_remote_ids *desired)
{
	__u8 id = subflow->remote_id;

	return desired->ids[id >> 3] & (1 << (id & 7));
}

/* Whether the local endpoint id of the IPv6 subflow is pinned to the class
 * dscp. The initial subflow has the address id 0 whatever its endpoint,
 * which the in-kernel path manager keeps in mpc_endpoint_id.
 */
static __always_inline bool local_id_pinned(const struct mptcp_sock *msk,
					    const struct mptcp_subflow_context *subflow,
					    __u8 dscp)
{
	const struct dscp_remote_ids *desired;
	__u8 id = subflow->local_id;

	if (!id)
		id = msk->mpc_endpoint_id;
	desired = bpf_map_lookup_elem(&dscp_local_ids, &dscp);
	return desired && (desired->ids[id >> 3] & (1 << (id & 7)));
}

/* Whether a non-backup subflow is active, even one that cannot take data
 * right now. A walk of its own, run only when the main one found no
 * non-backup subflow to send on: counting them in the main walk multiplied
 * its verifier states past the 1M instruction limit (bpf_weight_rr).
 */
static __always_inline bool has_active_nonbackup(struct sock *sk)
{
	struct mptcp_subflow_context *subflow;
	bool found = false;

	bpf_for_each(mptcp_subflow, subflow, sk) {
		if (subflow->backup || subflow->request_bkup)
			continue;
		if (mptcp_subflow_active(subflow)) {
			found = true;
			break;
		}
	}

	return found;
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

/* Whether the subflow carries the class dscp: its local IPv4 address is
 * the one pinned in dscp_iface, its remote id one of dscp_remote_ids (on the
 * VPS), or, for an IPv6 subflow, its local id one of dscp_local_ids.
 *
 * The local address is a direct member access on this trusted pointer, like
 * bpf_weight_rr_get_send's identical local_ip read -- NOT BPF_CORE_READ()
 * (a separate read of the same field plus a redundant inet_saddr fallback,
 * once mptcp_subflow_active() has confirmed the subflow is established).
 */
static __always_inline bool dscp_pinned(const struct mptcp_sock *msk,
					struct mptcp_subflow_context *subflow,
					struct sock *cur, __u8 dscp,
					const __u32 *desired_ip,
					const struct dscp_remote_ids *desired_remote_ids)
{
	__u32 local_ip = cur->__sk_common.skc_rcv_saddr;

	if ((desired_ip && local_ip == *desired_ip) ||
	    (desired_remote_ids && remote_id_matches(subflow, desired_remote_ids)))
		return true;
	return local_ip == LOOPBACK4_IPV6 && local_id_pinned(msk, subflow, dscp);
}

/* Whether the subflow is one the round is between: one that can take data
 * right now, as in bpf_weight_rr (f2abf1d5): a winner whose send buffer was
 * full was debited its turn and then dropped by the check after the round,
 * so the round produced nothing. The pin target is kept when it is merely
 * full: the round then waits for it (-1) instead of moving its class to
 * another WAN whenever it is saturated. A stale one is screened like the
 * others, so a class still fails over off a dead path. Its pacing rate is
 * filled in when it has none yet.
 */
static __always_inline bool dscp_candidate(struct mptcp_subflow_context *subflow,
					   struct sock *cur, bool is_pin_target)
{
	if (mptcp_subflow_stale(subflow) ||
	    (!is_pin_target && !bpf_sk_stream_memory_free(cur)))
		return false;
	if (!subflow->avg_pacing_rate) {
		subflow->avg_pacing_rate = cur->sk_pacing_rate;
		if (!subflow->avg_pacing_rate)
			return false;
	}
	return true;
}

SEC("struct_ops")
int BPF_PROG(bpf_dscp_get_send, struct mptcp_sock *msk)
{
	struct mptcp_subflow_context *subflow;
	struct sock *sk = (struct sock *)msk;
	bool has_active = false, has_backup = false;
	__u64 msk_key = (__u64)(unsigned long)msk;
	struct sock *ssk = NULL, *best = NULL;
	struct dscp_remote_ids *desired_remote_ids;
	__u32 total_weight = 0;
	__u32 burst, wmem;
	__u32 *desired_ip;
	__s32 best_cw = 0;
	__u8 use_backup;
	__u8 dscp, tos;

	tos = BPF_CORE_READ(msk, sk.icsk_inet.tos);
	dscp = tos >> 2;
	desired_ip = bpf_map_lookup_elem(&dscp_iface, &dscp);
	desired_remote_ids = bpf_map_lookup_elem(&dscp_remote_ids, &dscp);

	/* Both walks below carry flags, pointers and values the verifier
	 * doesn't track exactly, so it sees the same states at every turn and
	 * stops, however many subflows there are. The candidates used to be
	 * gathered into an array walked by index, which it checked one index
	 * at a time: past its 1M instruction limit at 16 subflows (and once
	 * already at 8, on an older kernel and clang).
	 *
	 * First walk: whether the round is between the active subflows or,
	 * none being a candidate, the backup ones.
	 */
	bpf_for_each(mptcp_subflow, subflow, sk) {
		struct sock *cur = mptcp_subflow_tcp_sock(subflow);

		if (!mptcp_subflow_active(subflow))
			continue;
		if (!dscp_candidate(subflow, cur,
				    dscp_pinned(msk, subflow, cur, dscp, desired_ip,
						desired_remote_ids)))
			continue;
		if (!subflow->backup && !subflow->request_bkup) {
			has_active = true;
			break;
		}
		has_backup = true;
	}

	mptcp_set_timeout(sk);

	if (!has_active && !has_backup)
		return -1;

	/* Prefer active subflows; fall back to backup if none active --
	 * same convention as bpf_weight_rr. Only then: the screen above also
	 * drops active subflows that are merely full, and the kernel's
	 * mptcp_subflow_get_send() waits for those rather than loading the
	 * backup WAN with every saturating upload.
	 */
	use_backup = has_active ? 0 : 1;
	if (use_backup && has_active_nonbackup(sk))
		return -1;

	/* Second walk, smooth weighted round-robin (nginx-style), identical
	 * algorithm to bpf_weight_rr_get_send: every candidate's
	 * current-weight (persisted in dscp_cw_map_v2, keyed by (msk, ssk)) is
	 * bumped by its own weight and written back in this same pass, while
	 * total_weight accumulates alongside it; the winner isn't known until
	 * the pass finishes, so its debit (cw -= total_weight) is applied as a
	 * single extra map update right after the walk.
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
	bpf_for_each(mptcp_subflow, subflow, sk) {
		__u8 is_backup = (subflow->backup || subflow->request_bkup) ? 1 : 0;
		struct dscp_cw_key key = {};
		struct sock *cur;
		bool is_pin_target;
		__s32 *cw_ptr, cw;
		__u32 weight;

		if (is_backup != use_backup || !mptcp_subflow_active(subflow))
			continue;
		cur = mptcp_subflow_tcp_sock(subflow);
		is_pin_target = dscp_pinned(msk, subflow, cur, dscp, desired_ip,
					    desired_remote_ids);
		if (!dscp_candidate(subflow, cur, is_pin_target))
			continue;

		weight = is_pin_target ? DSCP_PIN_WEIGHT : DSCP_NEUTRAL_WEIGHT;
		total_weight += weight;

		key.msk = msk_key;
		key.ssk = (__u64)(unsigned long)cur;
		cw_ptr = bpf_map_lookup_elem(&dscp_cw_map_v2, &key);
		cw = cw_ptr ? *cw_ptr : 0;
		cw += (__s32)weight;
		bpf_map_update_elem(&dscp_cw_map_v2, &key, &cw, BPF_ANY);

		if (!best || cw > best_cw) {
			best = cur;
			best_cw = cw;
		}
	}

	/* Every weight is at least 1, so a winner means total_weight > 0.
	 * Testing total_weight itself would have the verifier track its exact
	 * value through the walk: the weights are constants here.
	 */
	if (!best)
		return -1;

	{
		struct dscp_cw_key key = {};
		__s32 cw = best_cw - (__s32)total_weight;

		key.msk = msk_key;
		key.ssk = (__u64)(unsigned long)best;
		bpf_map_update_elem(&dscp_cw_map_v2, &key, &cw, BPF_ANY);
	}

	ssk = best;
	if (!bpf_sk_stream_memory_free(ssk))
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
