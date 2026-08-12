# mptcp-bpf-weight-rr

A kernel BPF MPTCP scheduler (`bpf_weight_rr`) that spreads a connection's
traffic across all active subflows in proportion to a per-endpoint weight,
using weighted round-robin — as opposed to always sending on a single
"best" subflow. This is a plain OpenWrt package: no LuCI UI, no init
script, just a compiled `.o` dropped where the MPTCP scheduler
infrastructure picks it up.

## What it does

MPTCP lets you swap the kernel's subflow-selection policy at runtime via
`struct_ops`. This package implements one such policy in
[`src/mptcp_bpf_weight_rr.c`](src/mptcp_bpf_weight_rr.c):

- **`get_send`** (`bpf_weight_rr_get_send`) — on every send opportunity,
  walks the connection's subflows, looks up each one's weight (keyed by
  its local IP) in the `endpoint_weights` map, and picks *which* subflow
  to use next via a **weighted round-robin**: a per-connection counter
  (`conn_counters`, keyed by the `mptcp_sock` pointer) is taken modulo the
  sum of weights of the eligible subflows, then walked against each
  subflow's cumulative weight range to find the owner of that slot. The
  counter increments every call, so over many sends each subflow gets a
  share of traffic proportional to its weight — e.g. weights 150/50 (3:1)
  land roughly 3 out of every 4 sends on the heavier subflow, not just
  "usually" but by explicit slot arithmetic. Backup subflows are only
  considered when no active subflow exists.
- **`get_retrans`** (`bpf_weight_rr_get_retrans`) — picks a subflow to
  carry a retransmission: prefers any active, non-backup subflow with no
  outstanding TCP-level data; falls back to a backup subflow once the
  active ones have been retried enough times (tracked via
  `mptcp_pm_subflow_chk_stale`).
- Unweighted endpoints default to weight `100` (neutral).

### vs. `mptcp-bpf-weight` (non-RR)

The sibling `mptcp-bpf-weight` package (`bpf_weight`) is derived from the
upstream *burst* scheduler and uses the weight as a **linger/preference**
value — it consistently favors one subflow (the "best" one per its
internal heuristic) rather than splitting traffic proportionally. This
package (`bpf_weight_rr`) is the one that actually *distributes* traffic
according to the weight ratio across multiple subflows simultaneously. Pick
`bpf_weight_rr` when you want, say, a 3:1 fiber/LTE split with both links
carrying real traffic concurrently; pick `bpf_weight` when you want a
single preferred link with automatic failover-like behavior.

## BPF maps

Both declared with `LIBBPF_PIN_BY_NAME`, so they show up under
`/sys/fs/bpf/<name>` once the program is loaded:

| Map | Key | Value | Purpose |
|---|---|---|---|
| `endpoint_weights` | local IP (`skc_rcv_saddr`, as a raw `__u32`) | weight (`__u32`, higher = more traffic) | Per-WAN weight table. **Shared with `mptcp-bpf-weight`** — both packages declare a map of the same name and pinning, so they read/write the same pinned table at `/sys/fs/bpf/endpoint_weights`. Switching between the two schedulers keeps the same configured weights. |
| `conn_counters` | `mptcp_sock` pointer (`__u64`) | round counter (`__u32`) | Per-connection round-robin position; cleared in `release` when the MPTCP connection ends. |

## Managing weights

Weights are set with `mptcp-weight-manager`'s
`/usr/sbin/mptcp-scheduler-weight.sh` (a separate package — install it
alongside this one):

```sh
mptcp-scheduler-weight.sh show              # all interfaces
mptcp-scheduler-weight.sh show wan1         # one interface
mptcp-scheduler-weight.sh set wan1 150      # higher = more traffic
```

The script resolves an interface name to its MPTCP endpoint IP (via
`ip mptcp endpoint show`), then reads/writes `endpoint_weights` through
`bpftool map ... key hex ... value hex ...`. Note the key/value encoding:
the script computes the IP as a plain 32-bit integer in **host byte
order** (`(o4*256^3)+(o3*256^2)+(o2*256)+o1` — i.e. treating the first
dotted-quad octet as the least-significant byte) and then serializes that
integer as **little-endian** hex for `bpftool`. This matches how the BPF
program reads `skc_rcv_saddr` as a raw `__u32` on a little-endian target,
but it means the pinned map's key bytes do *not* read as the IP in its
normal dotted-quad byte order if you inspect the map by hand — use the
manager script's `show`, not a raw `bpftool map dump`, to avoid
miscomputing weights.

### Automatic weight sync has a gap for this scheduler

`mptcp-weight-manager` also ships a post-tracking hook,
[`040-multipath-weight`](../mptcp-weight-manager/files/usr/share/omr/post-tracking.d/040-multipath-weight),
that's meant to push each interface's `network.<if>.multipath_weight` UCI
value (set from the wizard/MPTCP settings page's **Weight** field) into
the BPF map automatically after every tracker run. As of this writing that
hook's scheduler check only matches
`mptcp_bpf_weight.o` / `mptcp_bpf_burstweight.o` / `bpf_weight` /
`bpf_burstweight` — **`bpf_weight_rr` / `mptcp_bpf_weight_rr.o` is not in
that list**, so selecting this scheduler does not currently get its
weights auto-synced from UCI on tracker events. Until that list is
extended, set weights for this scheduler manually with
`mptcp-scheduler-weight.sh set <iface> <weight>` (which is exactly what
this package's own test suite does — see below).

## Selecting the scheduler

```sh
uci set network.globals.mptcp_scheduler='bpf_weight_rr'
uci commit network
/etc/init.d/mptcp restart
```

`luci-app-mptcp`'s MPTCP settings page auto-discovers any `.o` dropped
into `/usr/share/bpf/scheduler/` (this package installs
`mptcp_bpf_weight_rr.o` there) and lists it in the **Multipath TCP
scheduler** dropdown — no separate LuCI wiring needed for this package
itself. Confirm it's actually active in the kernel via:

```sh
cat /proc/sys/net/mptcp/scheduler
bpftool struct_ops list | grep weight_rr
```

## Build

Standard OpenWrt kernel-BPF package: `PKG_BUILD_DEPENDS` on the BPF
toolchain, built with `bpf_mptcp.mk`'s `CompileBPF` against the kernel's
vendored MPTCP BPF headers (`vmlinux.h`, `mptcp_bpf.h`,
`bpf_experimental.h` in `src/`), and installs only the compiled
`mptcp_bpf_weight_rr.o` — there's no init script or config file, it's
purely a scheduler object file that `network`/`mptcp` init and LuCI
reference by path/name. Requires a non-5.4 kernel
(`DEPENDS:=... @!LINUX_5_4`) since it needs modern MPTCP BPF struct_ops
support.

## Testing

Exercised end-to-end by the repo's bench test suite:
[`tests/omr-test.sh`](../tests/omr-test.sh) section **4e** and
[`tests/omr-test-weight.sh`](../tests/omr-test-weight.sh) (scheduler
registration, pinned-map read/write, equal-weight distribution across
parallel connections, and an extreme 250:10 weight differential). Those
tests are also the concrete reference for the "higher weight = more
traffic" semantics and for driving `mptcp-scheduler-weight.sh` directly
rather than relying on the post-tracking hook.
