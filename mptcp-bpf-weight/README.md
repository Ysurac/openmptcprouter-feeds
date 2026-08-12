# mptcp-bpf-weight

A kernel BPF MPTCP scheduler (`bpf_weight`) that always sends on the
single active subflow with the **highest configured weight** — a static,
admin-set preference rather than a dynamic "fastest link wins" heuristic.
Like its siblings, this is a plain OpenWrt package: no LuCI UI, no init
script, just a compiled `.o` dropped where the MPTCP scheduler
infrastructure picks it up.

## What it does

[`src/mptcp_bpf_weight.c`](src/mptcp_bpf_weight.c) is explicitly forked
from the upstream in-kernel *burst* scheduler (see the file header) and
keeps its burst/pacing mechanics, but replaces burst's dynamic
"least-lingering-time" subflow choice with a static, configured weight:

- **`get_send`** (`bpf_weight_get_send`) — walks every subflow, looks up
  each one's weight (keyed by its local IP) in the `endpoint_weights` map,
  and keeps the single subflow with the highest weight seen so far —
  tracked separately for active and backup subflows via a 2-slot
  `send_info[SSK_MODE_ACTIVE/BACKUP]` array indexed by the subflow's
  backup flag. The comparison is strict (`>`), so on a tie the
  first-encountered subflow at that weight keeps the slot. Backup mode is
  only used when there are zero active subflows. **This is winner-take-all
  by weight, every single call** — there is no rotation and no
  proportional split; the highest-weight active subflow carries 100% of
  the traffic until its weight changes or it goes inactive. (The
  `linger_time` variable name and the burst-size/pacing-rate bookkeeping
  below it are inherited from the upstream burst scheduler this was
  forked from; here `linger_time` is just set equal to the weight, not an
  actual estimated queue-drain time.)
- **`get_retrans`** (`bpf_weight_get_retrans`) — identical to
  `mptcp-bpf-weight-rr`'s: prefers any active, non-backup subflow with no
  outstanding TCP-level data, falling back to a backup subflow once the
  active ones are confirmed stale via `mptcp_pm_subflow_chk_stale`.
- Unweighted endpoints default to weight `100` (neutral); the source
  comment is explicit: *"higher weight = more preferred (like ip route
  weight)"*.

### vs. `mptcp-bpf-weight-rr`

The sibling `mptcp-bpf-weight-rr` package (`bpf_weight_rr`) reuses the
same map and the same "higher = more traffic" convention, but actually
**distributes** traffic across all active subflows in proportion to their
weight (weighted round-robin via a per-connection counter), rather than
pinning everything to one link. Pick `bpf_weight` (this package) when you
want a single preferred link with automatic failover to the next-best one
if it drops out; pick `bpf_weight_rr` when you want multiple links
carrying traffic concurrently in a fixed ratio.

## BPF maps

| Map | Key | Value | Purpose |
|---|---|---|---|
| `endpoint_weights` | local IP (`skc_rcv_saddr`, raw `__u32`) | weight (`__u32`, higher = more preferred) | Per-WAN weight table, pinned at `/sys/fs/bpf/endpoint_weights`. **Shared with `mptcp-bpf-weight-rr`** — both packages declare a map of the same name/pinning, so switching between the two schedulers keeps the same configured weights. |

Unlike `mptcp-bpf-weight-rr`, this scheduler needs no per-connection state
(`init`/`release` are no-ops) since there's nothing to round-robin — the
decision only depends on the current weight table.

## Managing weights

Weights are set with `mptcp-weight-manager`'s
`/usr/sbin/mptcp-scheduler-weight.sh` (a separate package — install it
alongside this one):

```sh
mptcp-scheduler-weight.sh show              # all interfaces
mptcp-scheduler-weight.sh show wan1         # one interface
mptcp-scheduler-weight.sh set wan1 150      # higher = more preferred
```

The script resolves an interface to its MPTCP endpoint IP (via
`ip mptcp endpoint show`) and reads/writes `endpoint_weights` through
`bpftool map ... key hex ... value hex ...`. It computes the IP as a
32-bit integer in **host byte order**
(`(o4*256^3)+(o3*256^2)+(o2*256)+o1`) and serializes it as
**little-endian** hex for `bpftool` — matching how the BPF program reads
`skc_rcv_saddr` as a raw `__u32` on a little-endian target. Use the
manager script's `show`, not a raw `bpftool map dump`, if you need to
inspect the map by hand — the pinned key bytes don't read as the IP's
normal dotted-quad order.

This scheduler *is* covered by `mptcp-weight-manager`'s automatic
post-tracking hook,
[`040-multipath-weight`](../mptcp-weight-manager/files/usr/share/omr/post-tracking.d/040-multipath-weight):
its scheduler-name check matches both `mptcp_bpf_weight.o` and
`bpf_weight`, so each interface's `network.<if>.multipath_weight` UCI
value (the wizard/MPTCP settings page's **Weight** field) gets pushed into
this map automatically after tracker runs. (The sibling `bpf_weight_rr` is
*not* in that hook's match list — see `mptcp-bpf-weight-rr`'s own README
if you're using that scheduler instead.)

## Selecting the scheduler

```sh
uci set network.globals.mptcp_scheduler='bpf_weight'
uci commit network
/etc/init.d/mptcp restart
```

`luci-app-mptcp`'s MPTCP settings page auto-discovers any `.o` dropped
into `/usr/share/bpf/scheduler/` (this package installs
`mptcp_bpf_weight.o` there) and lists it in the **Multipath TCP
scheduler** dropdown. Confirm it's active in the kernel via:

```sh
cat /proc/sys/net/mptcp/scheduler
bpftool struct_ops list | grep -w bpf_weight
```

## Build

Standard OpenWrt kernel-BPF package: built with `bpf_mptcp.mk`'s
`CompileBPF` against the kernel's vendored MPTCP BPF headers
(`vmlinux.h`, `mptcp_bpf.h`, `bpf_experimental.h` in `src/`), installing
only the compiled `mptcp_bpf_weight.o` — no init script or config file.
Requires a non-5.4 kernel (`DEPENDS:=... @!LINUX_5_4`) for MPTCP BPF
struct_ops support.

## Testing, and a discrepancy worth knowing about

[`tests/omr-test.sh`](../tests/omr-test.sh) section **4d** exercises this
scheduler end-to-end (registers it, sets weights, drives real downloads
through it, compares TX packet deltas per WAN). Its own inline comments
and pass/fail assertions state the *opposite* preference direction from
what the C source implements: the test sets `WAN1=50` expecting it to be
preferred ("lower = preferred") and `WAN2=200` expecting it to be
avoided, and treats `WAN1` carrying more traffic as the passing outcome.
The source (`weight = ...; if (linger_time > send_info[backup].linger_time)`,
plus its own inline comment "higher weight = more preferred") and the
`luci-app-mptcp` **Weight** field's help text ("A weight >100 make it
more attractive, a weight <100 make it less attractive") both agree the
scheduler favors the *higher*-weighted subflow — so on real hardware this
test's traffic-direction assertion should actually hit its `fail` branch
("non-preferred WAN2 (weight=200) sent more TX"), not the `pass` one its
comments describe. If you're validating this scheduler yourself, trust the
"higher weight wins" behavior documented above (source + LuCI agree) over
that test section's comments, and treat section 4d's current pass/fail
framing as due for a fix.
