# omr-quota — developer guide

Backend package that enforces monthly data quotas: cuts or throttles one or
more interfaces once their combined vnstat usage crosses a configured limit.
`luci-app-omr-quota` is the UI on top of this; this document only covers the
backend package.

Two kinds of quota, both handled by the same daemon:

- **`interface` section** — one quota for a single interface, based only on
  that interface's own traffic. Section name = the interface name.
- **`global` section** — one quota combining several interfaces' traffic.
  When it's reached, every interface it combines is cut/throttled together.
  The section has a stable UCI name; the `interfaces` option lists what it
  combines and is required (no single interface to fall back to).

## Components

| File | Role |
| --- | --- |
| `files/bin/omr-quota` | Daemon loop: polls vnstat, decides exceeded/not, applies cut or throttle |
| `files/etc/init.d/omr-quota` | procd init script: one daemon instance per configured `interface`/`global` section |
| `files/etc/config/omr-quota` | UCI config (defaults, one `interface` section per WAN plus an example `global` section) |
| `files/etc/uci-defaults/omr-quota` | First-boot: registers the package with `ucitrack` so network reloads restart it |
| `files/usr/libexec/rpcd/quota` | ubus/rpcd plugin (`get_quota`, `set_quota`, `get_status`, `reset_exceeded`) |
| `files/usr/share/rpcd/acl.d/omr-quota.json` | ACL exposing those ubus methods to the LuCI/admin session |

## Config schema (`omr-quota.<section>`)

Validated in `_launch_quota()` / `_launch_global_quota()` in the init script
(split because `interfaces` is absent/optional on `interface` sections but
required on `global` ones):

- `txquota` / `rxquota` / `ttquota` (uinteger, KiB) — TX / RX / combined quota for the month. `0`/unset disables that check.
- `interfaces` (space-separated interface names) — **`global` sections only**,
  required. The interfaces whose vnstat usage is summed *and* which get
  cut/throttled together when the quota is reached. `interface` sections have
  no such option: they always meter and enforce on just themselves.
- `begindate` / `enddate` (date strings accepted by `vnstat -b` and
  `date -d`) — when `begindate` is set, the daemon reads vnstat's total
  traffic since that date instead of the current monthly bucket; `enddate`
  enables daily-budget calculations.
- `method` (`0` default, `1`, or `2`) — optional daily-budget mode once
  `ttquota` usage crosses `percent`: `1` blocks if traffic since the last
  calculation exceeds the per-interval budget, `2` applies a downstream
  `tc` speed limit based on the remaining daily volume.
- `down_interfaces` (space-separated interface names, default: the quota's
  own interfaces — the section itself for `interface` sections, the full
  `interfaces` list for `global` ones) — interfaces shaped by daily-budget
  method `2`.
- `percent` (uinteger, default `80`) and `calculation_interval` (uinteger,
  default `120`) — daily-budget trigger threshold and method `1` recalculation
  cadence.
- `block_lan` (bool, default `0`) — with cut action, also flips
  `firewall.zone_lan.input` to `DROP` while quota enforcement is active. This
  blocks every transparent proxy uniformly without changing proxy UCI state
  or fighting `omr-schedule`; the router itself stays reachable from the LAN
  (LuCI, SSH, DNS, DHCP, ping) through explicit
  `firewall.omr_quota_lan_*` ACCEPT rules, see below.
- `interval` (uinteger, default `30`) — seconds between daemon polls.
- `enabled` (bool, default `0`).
- `exceedance_action` (`cut` default, or `throttle`).
- `throttle_dl` / `throttle_ul` (uinteger, Mbps, default `1`) — used only when `exceedance_action=throttle`.
- `exceedance_scope` (`month_only` default, or `persistent`) — see below.
- `reset_exceeded` (bool) — one-shot trigger, cleared automatically once processed.

`reset_exceeded` is processed (`_reset_baseline_if_requested`: persistent
marker removed, one-shot flag cleared) **before** the `enabled` / quota-value
early returns, so a reset requested on a disabled quota is honoured too --
otherwise the flag stayed set and the persistent marker cut the interface
again the moment the quota was re-enabled, with no way to clear it from the
UI while disabled. (The baseline itself is only recorded by a launched
daemon, so it applies once the quota is enabled again.)

`_track_vnstat` makes sure vnstat counts the *device* behind each quota'd
interface (`l3_device`, or `device` for `@` aliases -- vnstat knows
`eth1`/`pppoe-wan`, not `wan1`): it appends the device to
`vnstat.@vnstat[-1].interface` if it isn't listed, commits, and reloads
vnstat once. Interfaces whose device can't be resolved at that moment (down
at boot) are skipped. The previous version appended the *logical* name --
never counted by vnstat -- and, matching the whole space-joined list
instead of one entry, appended it again on every reload as an uncommitted
uci change that any later `uci commit vnstat` would have written out.

For `interface` sections, the section name **is** the logical interface name
and is passed as `$1` (`OMR_QUOTA_INTERFACE`) to the daemon
(`files/bin/omr-quota`). `global` sections have no such identity, so the
init script passes `"global_<uci section id>"` instead — purely a state-file
key, never looked up as a real network interface. Both are launched via
`procd_open_instance` per `config_foreach` in `start_service()`
(`_launch_quota` for `interface`, `_launch_global_quota` for `global`).

## Daemon loop (`files/bin/omr-quota`)

One process per `interface`/`global` section, launched by `init.d/omr-quota`
with quota values passed as env vars (`OMR_QUOTA_TX`, `OMR_QUOTA_RX`,
`OMR_QUOTA_TT`, `OMR_QUOTA_INTERVAL`, `OMR_QUOTA_ACTION`,
`OMR_QUOTA_THROTTLE_DL/UL`, `OMR_QUOTA_SCOPE`, `OMR_QUOTA_INTERFACES`,
`OMR_QUOTA_DOWN_INTERFACES`, `OMR_QUOTA_BEGINDATE`, `OMR_QUOTA_ENDDATE`,
`OMR_QUOTA_METHOD`, `OMR_QUOTA_PERCENT`, `OMR_QUOTA_CALCULATION_INTERVAL`,
`OMR_QUOTA_BLOCK_LAN`). `OMR_QUOTA_INTERFACES` is only ever set by the init
script for `global` sections (to their `interfaces` list); for `interface`
sections it's left unset, so it defaults to `$OMR_QUOTA_INTERFACE` ($1,
the section's own name) everywhere it's read. `target_interfaces` — computed
once per loop as `${OMR_QUOTA_INTERFACES:-$OMR_QUOTA_INTERFACE}` — is
therefore the single list used for *both* metering and enforcement: an
`interface` section's list is just itself, a `global` section's list is every
interface it combines, so exceeding it cuts/throttles all of them together.
Each iteration:

1. Resolve the real L3 device for every interface in `target_interfaces` via
   `_get_real_interface`, which wraps `ifstatus` and handles both plain
   interfaces and `@`-prefixed logical/dynamic ones (e.g. mwan/multipath
   aliases). `ifstatus` reports no `l3_device` while an interface is
   administratively down — including when *this script* just cut it for
   quota enforcement — so `_get_real_interface` caches the last resolved
   device name to `<_TSTATE_DIR>/<iface>.realdev` and falls back to it when
   the live lookup comes back empty. Without this the next loop reads 0
   bytes for a cut interface, sees the quota as no longer exceeded, brings
   it back up, and cuts it again: an infinite up/down flap.
2. `_vnstat_usage` reads rx/tx for each of those devices from
   `vnstat -i <dev> --json` and sums them into `rx`/`tx`/`tt` (KiB). If
   `OMR_QUOTA_BEGINDATE` is set it instead queries
   `vnstat -i <dev> -b <begindate> --json` and reads
   `interfaces[0].traffic.total.*` — cumulative usage since that date
   rather than the current vnstat month bucket. The summed `rx`/`tx` are
   then reduced by the current baseline (see below) before `tt` is derived.
3. Compare `rx`/`tx`/`tt` against the configured quotas to compute
   `exceeded`. `_calculate_budget_limit` additionally derives a daily-budget
   signal (see below) once usage crosses `OMR_QUOTA_PERCENT`: method `1`
   can also set `exceeded=1` ("daily budget" reason); method `2` sets `cb`,
   a `tc` rate applied via `_apply_downstream_limit`/`_remove_downstream_limit`
   independently of `exceeded`.
4. For every interface in `target_interfaces`: apply `_apply_throttle` /
   `_remove_throttle`, or `ifdown`/`ifup`, and log the transition once via
   `logger -t OMR-QUOTA` (edge-triggered on `_prev_exceeded`, not every
   loop). On the cut path, `_block_lan` / `_unblock_lan` run once (not
   per-interface) alongside the `ifdown`/`ifup` loop when
   `OMR_QUOTA_BLOCK_LAN=1`. On the throttle path an interface that is down
   (typically: cut by the previous daemon before the action was switched to
   throttle) is brought up **first** and `_wait_iface_up` waits (bounded,
   10 s) for netifd to report it up before `_apply_throttle` runs -- the
   ifup hotplug runs `mptcp reload <dev>`, which replaces the device's root
   qdisc, so a tbf installed while the interface was still down was wiped a
   second later and the upload ran unshaped until the next poll. (`mptcp`'s
   `_root_qdisc_managed_elsewhere` guard also leaves a `tbf` root alone
   now, so a later `mptcp reload` -- tracker status change, IP change --
   doesn't lift the throttle either.) The loop records what it enforces in
   the markers described below.
5. `sleep "$OMR_QUOTA_INTERVAL"` and repeat — the process never exits on its
   own; procd/`stop` is what tears it down.

`_vnstat_usage` distinguishes a valid zero counter from an unreadable sample
(missing device, failed command, or incomplete JSON). If any member of a quota
has an unreadable sample while a cut/throttle marker or the previous loop says
enforcement is active, the loop preserves that enforcement until a complete
sample proves the quota is no longer exceeded. This prevents a temporary
vnstat failure during modem teardown from being interpreted as a month reset
and triggering an `ifup`.

### Usage baseline / `reset_exceeded` (`_read_baseline`, `OMR_QUOTA_RESET_BASELINE`)

`reset_exceeded` only ever cleared the `persistent`-scope marker file, which
does nothing for `exceedance_scope=month_only`: that scope recomputes
`exceeded` from live vnstat totals every loop, so there was nothing else to
clear and an exceeded month_only quota stayed cut/throttled until vnstat's
own monthly bucket rolled over.

A baseline file `${OMR_QUOTA_STATE_DIR:-/etc/omr-quota/state}/<OMR_QUOTA_INTERFACE>.baseline`
fixes this: it stores `<year-month> <rx0> <tx0>`, and every loop's summed
`rx`/`tx` has `rx0`/`tx0` subtracted (clamped to `0`) before quotas are
checked. `_read_baseline` discards the file (treating it as `0 0`) if its
tag doesn't match the current `date +%Y-%m`, so a real month rollover isn't
permanently masked by a stale baseline.

The baseline is (re)recorded at daemon launch when `OMR_QUOTA_RESET_BASELINE=1`
is passed in the environment: the daemon sums current vnstat usage across
`OMR_QUOTA_INTERFACES` and writes it as the new baseline before entering the
main loop. `init.d/omr-quota` sets that env var whenever
`reset_exceeded=1` is set on the section (in addition to its existing
persistent-marker cleanup), so a single `reset_exceeded` trigger un-exceeds
*both* scopes immediately, regardless of which one is configured.

### Enforcement markers and undo mode (`OMR_QUOTA_UNDO=1`)

The daemon records what it currently enforces under `_TSTATE_DIR`
(`${OMR_QUOTA_THROTTLE_STATE_DIR:-/tmp/omr-quota}`), keyed by its identity
(`$1`), each file listing the interfaces concerned (space separated):

| Marker | Written when | Removed when |
| --- | --- | --- |
| `<id>.cut` | the cut path runs (`target_interfaces`) | the not-exceeded path brings the interfaces up, or a throttle daemon takes over |
| `<id>.throttled` | the throttle path runs (`target_interfaces`) | the not-exceeded path runs `_remove_throttle` |
| `<id>.downstream` | `_apply_downstream_limit` (down interfaces, daily-budget method 2) | `_remove_downstream_limit` |
| `<id>.blocklan` | `_block_lan` actually flips the LAN input to DROP | `_unblock_lan` |

Two consumers besides the daemon itself:

- **`get_status`** (rpcd) reports `cut` / `throttled` from `<id>.cut` /
  `<id>.throttled`.
- **`OMR_QUOTA_UNDO=1 /bin/omr-quota <id>`** runs `_undo_enforcement` and
  exits instead of entering the loop: it removes the tc shapers of the
  interfaces listed in `.throttled` / `.downstream` (device resolved through
  the `<iface>.realdev` cache, since a cut interface has no `l3_device`),
  restores the LAN input if `.blocklan` exists, `ifup`s the interfaces listed
  in `.cut`, deletes the markers and logs
  `Quota enforcement for <id> lifted`. `init.d/omr-quota` calls it from
  `start_service` for every marker whose section is no longer active
  (`_quota_active`: missing, disabled, no quota value, or a `global` section
  without `interfaces`) and from `service_stopped` for every marker on a
  real stop. Without this, disabling or removing a quota whose interface was
  cut left it down for good, and a throttled one stayed shaped: the daemon
  was simply not relaunched and nothing else knew what it had done.

  A `reload` (`reload_service` = stop + start, with `_OMR_QUOTA_RELOADING`
  set so `service_stopped` does nothing) deliberately does **not** undo the
  enforcement of quotas that stay enabled: their daemons are relaunched and
  carry on, so a network or omr-quota config change never causes an
  ifup/ifdown flap of a legitimately cut interface. `restart` (rc.common's
  own stop + start) does lift everything and lets the new daemons re-enforce
  on their first loop.

### Exceedance scope

- `month_only`: `exceeded` is recomputed from current vnstat counters every
  loop, so it clears automatically once vnstat rolls over to a new month.
- `persistent`: once exceeded, a marker file
  `${OMR_QUOTA_STATE_DIR:-/etc/omr-quota/state}/<OMR_QUOTA_INTERFACE>.exceeded` is
  created and short-circuits `exceeded=1` on every subsequent loop
  regardless of vnstat, even across month boundaries. Only removed by
  `reset_exceeded` (UI/ubus) or manual deletion. This is why
  `reset_exceeded` exists as both a UCI option (checked at service start)
  and an rpcd method (checked at runtime).

### Daily budget methods (`_calculate_budget_limit`)

Only active once `ttquota` is set and `enddate` is configured, and only once
usage crosses `percent` (default `80`) of `ttquota`. Given remaining days
`rd` until `enddate` and remaining volume `rv = ttquota - tt`, it derives a
daily volume `dv = rv / rd`:

- `method=1` ("block when the interval budget is exceeded"): every
  `calculation_interval` seconds it recomputes `cv` from `dv` and the
  minutes left in the current day, then resets `last_tt`/`last_calculation`.
  If usage since that checkpoint (`tt - last_tt`) exceeds `cv`, the daemon
  sets `exceeded=1` with reason `"daily budget"` — this feeds into the same
  `exceedance_action` (cut/throttle) as a normal quota breach.
- `method=2` ("limit speed using remaining daily volume"): every loop it
  recomputes a `tc` rate `cb` (kbit/s) from `dv` and the seconds left in the
  day, and applies it via `_apply_downstream_limit` on
  `${OMR_QUOTA_DOWN_INTERFACES:-$target_interfaces}` — independent of
  `exceeded`/`ifdown`, so the interface(s) stay up but shaped.
  `_remove_downstream_limit` clears the `tc` qdisc once method `2` is no
  longer selected or the budget check no longer applies.

Both methods are mutually exclusive per section (`method` is a single
`ListValue`: `0` disabled, `1`, or `2`).

### LAN block on cut (`_block_lan` / `_unblock_lan`)

When `block_lan=1` and `exceedance_action=cut`, bringing the interface down
also sets `firewall.zone_lan.input=DROP` (committed + `firewall reload`), then
restores `ACCEPT` in `_unblock_lan` once the interface is brought back up.
Proxy processes and their UCI enabled/disabled state are deliberately left
unchanged: stopping one backend was incomplete (the others stayed running),
and `omr-schedule/021-proxy` could immediately restore the configured one.
The firewall policy itself blocks every transparent-proxy redirect (ss, xray,
v2ray, hysteria) because each is delivered to the router's own input path.

**The router itself always stays reachable from the LAN.** A bare
`input=DROP` would also cut LuCI, SSH, DNS and DHCP — the admin could no
longer open the quota page to lift the block, and clients would lose their
leases while it lasts. So `_block_lan` creates three named rule sections
alongside the policy flip, which fw4 evaluates in `input_lan` *before* the
zone's policy jump:

| Section | Match | Purpose |
| --- | --- | --- |
| `firewall.omr_quota_lan_tcp` | `src=lan proto=tcp dest_port=<luci> <ssh> 53` | LuCI (uhttpd `listen_http`/`listen_https` ports, default `80 443`), SSH (every `dropbear.*.Port`, default `22`), DNS |
| `firewall.omr_quota_lan_udp` | `src=lan proto=udp dest_port=53 67 547` | DNS, DHCPv4 server, DHCPv6 server |
| `firewall.omr_quota_lan_icmp` | `src=lan proto=icmp` | ping and IPv6 neighbour discovery (fw4 expands `icmp` to `icmp` + `ipv6-icmp`) |

Ports are read live (`_lan_access_tcp_ports` / `_uci_ports`) so a LuCI or
SSH daemon moved to a non-default port stays reachable; each service falls
back to its stock default when its config exposes nothing. `_unblock_lan`
deletes the three sections together with the policy revert. Both functions
key their "already done" check on the policy *and* the presence of
`firewall.omr_quota_lan_tcp`: an `input=DROP` left by an older daemon without
the rules still gets them added, and access rules left behind after someone
restored `input=ACCEPT` by hand are still cleaned up.

Note that DNS resolution keeps working for LAN clients during a block (the
router's resolver answers over whatever uplink remains), and forwarding from
the `lan` zone is not touched: only traffic addressed to the router itself is
dropped.

### Throttle mechanism

`_apply_throttle`/`_remove_throttle` implement bidirectional shaping with
`tc` + an IFB device (`ifb-<dev>` — `/` sanitized to `-`, since MPTCP
sub-interfaces can contain one):

- Egress: `tbf` directly on the real device (upload).
- Ingress: redirected via `u32`/`mirred` to the IFB device, which then has
  its own `tbf` (download) — the standard Linux trick since `tc` cannot
  shape ingress directly.

Throttle state is tracked separately from quota-exceeded state, in
`${OMR_QUOTA_THROTTLE_STATE_DIR:-/tmp/omr-quota}/<OMR_QUOTA_INTERFACE>.throttled`
(tmpfs — intentionally not persisted across reboot, unlike the exceeded
marker; see the markers table above). `<OMR_QUOTA_INTERFACE>` is the daemon
identity passed as `$1` — the interface name for `interface` sections,
`global_<id>` for `global` ones — not necessarily a real network interface.
Only the daemon may delete this marker: it is what makes the not-exceeded
path run `_remove_throttle`. `reset_exceeded` used to delete it, so the
relaunched daemon never tore the shaper down -- the interface silently
stayed at the throttle rate while `get_status` said `throttled=false`.

Both `_PERSIST_DIR` and `_TSTATE_DIR` are overridable via env vars
(`OMR_QUOTA_STATE_DIR`, `OMR_QUOTA_THROTTLE_STATE_DIR`) specifically so the
test suite can point them at a scratch directory instead of the real `/etc`
and `/tmp` paths.

## rpcd plugin (`files/usr/libexec/rpcd/quota`)

Standalone ubus object `quota`, independent from the daemon process — it
reads/writes UCI and the same state files directly rather than talking to
the running daemon. `set_quota` and `reset_exceeded` call
`/etc/init.d/omr-quota reload` after committing, since the daemon only reads
its quota values once at launch (via env vars) and won't notice a live UCI
change otherwise.

`reset_exceeded` no longer clears the persistent marker file directly —
it sets `reset_exceeded=1` in UCI and reloads, delegating to the exact same
`init.d/omr-quota` path the UCI-option trigger uses. It must **not** touch
the daemon's `<id>.throttled` marker (an earlier version did): the
relaunched daemon only removes the tc shaper when it finds that marker and
the quota is no longer exceeded. That path both removes the persistent marker *and*
sets `OMR_QUOTA_RESET_BASELINE=1` for the relaunch, which is what actually
un-exceeds an `exceedance_scope=month_only` quota (see the daemon's usage
baseline section above) — a plain `rm` of the marker file never affected
month_only quotas at all.

`get_status` recomputes `exceeded` from live vnstat data in addition to
checking the persistent marker, so it reflects reality even if the daemon
process for that section isn't running. It also reports `throttled` and
`cut` from the daemon's `<id>.throttled` / `<id>.cut` markers. Its
`_get_real_iface` falls back to the daemon's `<iface>.realdev` cache (then
to netifd's configured `device`) when `ifstatus` has no `l3_device` -- the
normal state of a *cut* interface; without that fallback it read 0 bytes
for a cut interface and reported the very quota it had just enforced as
not exceeded (`rx_kib 0`, `exceeded false`) for as long as it stayed cut. Like the daemon, it uses only the
section's own interface for `interface` sections and sums `interfaces` only
for `global` sections. When `begindate` is set, it queries
`vnstat -i <dev> -b <begindate> --json` / `traffic.total.*` instead of
`traffic.month[-1]`. `_vnstat_month` (in the rpcd plugin) and `_vnstat_usage`
(in the daemon) are separate implementations of the same lookup — keep both
in sync when changing the vnstat query.

Every method resolves a section's type via `_section_type` (`uci -q get
omr-quota.<id>`, returning `interface`/`global`/empty) and derives its
state-file identity via `_state_id` (`<id>` for `interface`,
`global_<id>` for `global`) — this must stay in sync with how
`init.d/omr-quota` names each daemon instance, since `get_status` and
`reset_exceeded` read/write those same files by that name, not by the raw
uci section id. `set_quota` accepts an optional `type` (`interface` default,
or `global`); creating a new `global` section without `interfaces` is
rejected. An existing section's type can't be changed by `set_quota` — the
uci section must be deleted and recreated with the new type.

Input is read as a single JSON blob from stdin (`ubus call` convention) and
picked apart with `jsonfilter`; iface names are sanitized through
`_safe_iface` before being interpolated into file paths / uci keys.

## Manual ubus calls

```
ubus call quota get_quota    '{}'
ubus call quota get_quota    '{"interface":"wan1"}'
ubus call quota set_quota    '{"interface":"wan1","enabled":"1","rxquota":"400000","exceedance_action":"throttle","throttle_dl":"5","throttle_ul":"2","exceedance_scope":"persistent"}'
ubus call quota set_quota    '{"interface":"wan1","ttquota":"500000","method":"2","percent":"80","enddate":"2026-07-31","down_interfaces":"lan"}'
ubus call quota set_quota    '{"interface":"global1","type":"global","interfaces":"wan1 wan2","enabled":"1","ttquota":"900000"}'
ubus call quota get_status   '{"interface":"wan1"}'
ubus call quota reset_exceeded '{"interface":"wan1"}'
```

## Tests

- `tests/run_tests.sh` -- mocked unit tests of the daemon (`test_001_quota.sh`:
  cut/throttle/scope/budget/block_lan/baseline logic;
  `test_002_enforcement_markers.sh`: markers, ifup-before-tbf ordering, undo
  mode). Run locally with bash, no router needed.
- `../tests/cases/88-omr-quota-*.sh` -- bench integration case: drives the
  real rpcd -> init -> daemon -> vnstat/ifdown/tc chain on a router's
  non-master WANs (cut, cut->throttle, iperf3 throughput through the VPS
  server when `iperf.<vps>` is configured, reset, persistent scope, disable
  while cut, global quota, service stop) and restores everything afterwards.
  `sudo ./tests/run.sh <router> --only=88`.
- `../luci-app-omr-quota/tests/test_quota_ui.py` -- Playwright UI test of
  the LuCI page.
