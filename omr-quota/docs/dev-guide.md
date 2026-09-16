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
| `files/usr/libexec/rpcd/quota` | ubus/rpcd plugin (`get_quota`, `set_quota`, `get_status`, `reset_exceeded`) |
| `files/usr/share/rpcd/acl.d/omr-quota.json` | ACL exposing those ubus methods to the LuCI/admin session |

## Config schema (`omr-quota.<section>`)

The package ships `wan1`, `wan2` and the `global1` example. On a platform
whose WANs are not called `wanN` -- provisioned by steer-cloud-init, or
flashed over a config that carries its own layout --
`openmptcprouter/files/etc/uci-defaults/2096-omr-wan-names` renames those
sections onto the WANs the box really has (master first) and, since it can
only hand over as many names as there are sections, **creates one for every
remaining real WAN**: a third link -- a second modem, a wifi uplink -- used
to end up with no section at all and no entry on the quota page, with nothing
saying why. Created sections carry the shipped values with `enabled=0`; an
interface that already has a section is never touched, so re-running the
script (which happens when the package is reinstalled on a live system)
cannot resurrect or enable anything.

Validated in `_launch_quota()` / `_launch_global_quota()` in the init script
(split because `interfaces` is absent/optional on `interface` sections but
required on `global` ones):

- `txquota` / `rxquota` / `ttquota` (uinteger, KiB) — TX / RX / combined quota for the month. `0`/unset disables that check.
- `interfaces` (space-separated interface names) — **`global` sections only**,
  required. The interfaces whose vnstat usage is summed *and* which get
  cut/throttled together when the quota is reached. `interface` sections have
  no such option: they always meter and enforce on just themselves.
- `begindate` / `enddate` (`YYYY-MM-DD`; `begindate` goes to `vnstat -b`,
  `enddate` to `date -d`, which on busybox means a plain date and not
  "tomorrow" or "+1 week") — when `begindate` is set, the daemon meters the
  traffic recorded since that date instead of the current monthly bucket;
  `enddate` enables daily-budget calculations. See the daemon loop below for
  why that window comes from vnstat's *daily* buckets.
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
- `live_counters` (bool, default `1`) — add the kernel's live byte counters
  on top of vnstat's last sample when metering, so a quota is noticed within
  one poll instead of within vnstat's `SaveInterval`. Advanced escape hatch;
  see [Live kernel counters](#live-kernel-counters-_live_delta-_interface_usage)
  for what setting it to `0` gives back.
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
   `vnstat -i <dev> --json` (`interfaces[0].traffic.month[-1].*`) and sums
   them into `rx`/`tx`/`tt` (KiB). If `OMR_QUOTA_BEGINDATE` is set it
   instead queries `vnstat -i <dev> --json d -b <begindate>` and sums the
   `interfaces[0].traffic.day[*].*` entries the query returns.

   The obvious `vnstat -i <dev> -b <begindate> --json` + `traffic.total`
   does **not** work, and used to be what both readers did: `-b` only bounds
   vnstat's list output, while `traffic.total` is the interface's whole
   recorded history. The date was therefore silently ignored and a
   `begindate` quota metered every byte vnstat had ever seen for the device —
   harmless on a database created this month, but a WAN cut on day one for
   anyone whose vnstat history is older than the billing cycle. Measured on
   the bench: `-b` with the first of the month, with yesterday and with a
   future day all returned `694221137`, while the day-bucket sums for the
   same three dates were `694221137`, `411937225` and `0`. vnstat keeps a
   limited daily history (`DailyDays`, 30 by default), so a `begindate`
   older than that meters from the oldest day still in the database.

   `_interface_usage` then adds the *live* kernel delta on top of that
   sample (see below) — vnstat's database is up to five minutes stale — and
   the summed `rx`/`tx` are reduced by the current baseline before `tt` is
   derived. When the sample is unusable while the device did resolve,
   `_vnstat_register` repairs vnstat's tracking of it (see below).
3. Compare `rx`/`tx`/`tt` against the configured quotas to compute
   `exceeded`. `_calculate_budget_limit` additionally derives a daily-budget
   signal (see below) once usage crosses `OMR_QUOTA_PERCENT`: method `1`
   can also set `exceeded=1` ("daily budget" reason); method `2` sets `cb`,
   a `tc` rate applied via `_apply_downstream_limit`/`_remove_downstream_limit`
   independently of `exceeded`.
4. For every interface in `target_interfaces`: apply `_apply_throttle` /
   `_remove_throttle`, or `ifdown`, and log the transition once via
   `logger -t OMR-QUOTA` (edge-triggered on `_prev_exceeded`, not every
   loop). On the cut path, `_block_lan` / `_unblock_lan` run once (not
   per-interface) alongside the `ifdown` loop when
   `OMR_QUOTA_BLOCK_LAN=1`. The recovery direction is *not* driven by
   `target_interfaces`: it raises the interfaces listed in `<id>.ifdown`, the
   ones this daemon actually took down (see the marker table below). On the throttle path an interface that is down
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

### Live kernel counters (`_live_delta`, `_interface_usage`)

vnstat is the metering *reference* — it survives reboots, knows about months
and is what the whole package is configured against — but it is **not live**.
`vnstatd` keeps its counters in memory and only writes them to its database
every `SaveInterval` **minutes**, 5 by default, and OpenWrt ships the stock
`/etc/vnstat.conf` with every interval commented out, so that default is what
runs (`UpdateInterval 20`, `SaveInterval 5`; the database lands in
`/var/lib/vnstat`, i.e. tmpfs, with OMR's 2-hourly `vnstat_backup` cron for
persistence). `vnstat --json` is therefore up to five minutes behind reality.

A quota checked against that alone is blind for exactly that long. On a fast
WAN a single speedtest passes gigabytes inside one save window and is metered
in one lump at the next flush, long after the quota was crossed — the field
report this was written against is a Starlink WAN overshooting its quota by
42% before the cut, the whole overshoot being one speedtest that vnstat had
not written down yet.

So `_interface_usage` meters `vnstat_sample + kernel_delta_since_that_sample`,
the delta coming from `/sys/class/net/<dev>/statistics/{rx,tx}_bytes`
(`OMR_QUOTA_SYSFS_DIR` overrides the root for the unit tests). `_live_delta`
keeps one state file per **quota and device** in the runtime dir —
`live.<id>.<dev>`, `<id>` being the daemon identity (the interface name, or
`global_<section>`):

```
<valid until> <vnstat rx> <vnstat tx> <anchor rx> <anchor tx> <last rx> <last tx>
```

every field in KiB except the first, a `/proc/uptime` deadline. Each poll:

- **No usable state** (first poll, or expired) → anchor on the current
  reading, contribute nothing this round.
- **vnstat sample unchanged** → anchor untouched, delta is
  `kernel_now - anchor`.
- **vnstat sample changed** (vnstatd has flushed) → re-anchor on the
  *previous poll's* kernel reading, not the current one. The traffic between
  that poll and the flush is then counted twice — at most one poll interval of
  it, erring on the side of cutting slightly early; anchoring on the current
  reading instead would lose that same window entirely. The error never
  accumulates: vnstat's value is absolute and the anchor resets at every flush.
- **Kernel counter below the anchor** (device recreated by ifup, a modem
  reconnect, a driver reload) → re-anchor on it. Without this every later
  delta is negative and masks real usage until the counter catches up.

The deadline is `3 × interval`, at least 60 s. Past it the state is thrown
away: a daemon coming back after a real gap (service stopped, quota disabled
for a while) would otherwise re-anchor on a reading from before the gap, while
vnstat has had all that time to record the same traffic itself — counting it
twice.

The `<id>` in the file name is not decoration. "Has the sample changed" is the
only flush signal there is, and two quotas metering one device do not
necessarily read the same sample: a section with a `begindate` sums daily
buckets from that date, one without reads the month bucket. While they shared a
single `live.<dev>`, each poll saw a "changed" sample, re-anchored on the
*other* daemon's last reading and returned one poll interval of traffic instead
of everything since the flush — the very blindness the correction exists to
remove. `test_004` case 079b interleaves two such quotas over one device and
fails the moment the state is shared again.

The delta is only added when the vnstat sample is complete (see above): with no
reference to add it to, a delta measures nothing. An interface whose device is
gone — notably one this daemon has cut — has no readable counters, the delta is
`0 0` and metering is exactly what it was before this existed.

Net effect: enforcement resolution goes from `SaveInterval` (5 min) down to the
poll `interval`, without touching vnstat's own configuration. Verified live on
a router: 20 MiB pushed at once, `get_status` moved `5222 → 25936 KiB` within
8 s while vnstat's month counter and its database mtime did not move at all;
forcing a flush right after left the reported usage at `25948 KiB` instead of
jumping to ~46700, i.e. no double count across the flush boundary.

`live_counters=0` (`OMR_QUOTA_LIVE_COUNTERS`) restores the old vnstat-only
metering, for anyone who needs the reported figure to match `vnstat` exactly.

### vnstat self-repair (`_vnstat_register`)

`_track_vnstat` in the init registers a quota's device with vnstat at service
start, but only one netifd can resolve **right then**. A WAN that is down at
that moment — nothing plugged into the port, modem not up yet, DHCP not
finished — is skipped, and nothing ever comes back to it: the procd trigger is
`procd_add_reload_trigger omr-quota network`, i.e. a change of the network
*config*, not of interface state, and the package ships no hotplug script.

Found on a router whose WAN port had nothing plugged in when the image first
booted (`eth1`: `NO-CARRIER`, `rx_bytes` 0). Its uci list held the two modems
and never `eth1`, `1970-omr-vnstat` is gated on `openmptcprouter.latest_versions`
being empty (so it is dead after the first boot) and reads `network.wan1.device`
which does not exist on a platform with renamed WANs, and
`2096-omr-wan-names` fills the vnstat list **only when it is empty**. So
`vnstat -i eth1 --json` answered `Error: No interface matching "eth1" found in
database` for good: a quota enabled on that WAN would read an incomplete sample
every poll, meter 0 bytes, and silently never apply — with nothing in the UI
saying so.

So the daemon repairs it itself. When `_interface_usage` gets an **unusable
sample for a device it did resolve**, `_vnstat_register` adds that device to
`vnstat.@vnstat[-1].interface`, commits, and reloads vnstat (which runs
`vnstat --add --force -i <dev>` for every listed device and signals vnstatd).
Four guards:

- **The device must exist right now** (`_kernel_counters` succeeds). A device
  name outlives the device itself — `_get_real_interface` keeps serving the
  cached one while the interface is cut — and registering a phantom name would
  leave a dead entry in vnstat's database.
- **vnstat itself is the authority**, not the uci list: `vnstat --dbiflist`
  decides. A device can sit in the list and be missing from the database, or
  be counted without being listed. A device vnstat *does* know but has no
  bucket for yet (the state right after any registration, until vnstatd's next
  flush) needs no repair and must not consume the attempt.
- **Once per device per boot**, the marker being a *directory* under the tmpfs
  runtime dir (`vnstatadd.<dev>`), created with `mkdir` — atomic, so two
  daemons metering the same device (an interface quota and a global one) cannot
  both add it. Retrying every poll would churn uci and restart vnstatd forever
  when the registration does not help.
- **A `vnstat.@vnstat[-1]` section must exist** to add to.

`OMR_QUOTA_VNSTAT_AUTOADD=0` disables it. No uci option: a quota metering
nothing is never what anyone configured.

Reproducing it by hand on a router, on any up interface with a quota (this is
the live verification, since the bench case deliberately does not touch
vnstat's database — removing a device drops its history):

```sh
uci -q del_list vnstat.@vnstat[-1].interface=<dev>; uci -q commit vnstat
/etc/init.d/vnstat reload; vnstat --remove -i <dev> --force
rm -rf /tmp/omr-quota/vnstatadd.<dev>
# within one poll interval:
#   OMR-QUOTA: vnstat was not counting <dev>: registering it so the quota on <iface> can be metered
#   vnstatd: Monitoring (3): ... <dev> ...
```

Measured on a router: break at 11:29:04, repair logged at 11:29:06, vnstatd
monitoring it again at 11:29:20, and still exactly one log line and one list
entry three poll intervals later.

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
is passed in the environment: the daemon sums current usage across
`OMR_QUOTA_INTERFACES` — through `_interface_usage`, i.e. the same
vnstat-plus-live-delta measure the main loop compares against, or the baseline
would be systematically smaller than the readings it is subtracted from — and
writes it as the new baseline before entering the main loop. `init.d/omr-quota` sets that env var whenever
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
| `<id>.ifdown` | the cut path actually calls `ifdown` on an interface (cumulative across polls) | the same places as `<id>.cut` |
| `<id>.throttled` | the throttle path runs (`target_interfaces`) | the not-exceeded path runs `_remove_throttle` |
| `<id>.downstream` | `_apply_downstream_limit` (down interfaces, daily-budget method 2) | `_remove_downstream_limit` |
| `<id>.blocklan` | `_block_lan` actually flips the LAN input to DROP | `_unblock_lan` |

`<id>.cut` and `<id>.ifdown` look redundant and are not. `<id>.cut` is the
cross-package one: 002-error reads its *contents* so that every interface a
quota cut covers — the members of a global quota included — is recognised as
an administrative decision rather than a connectivity failure. `<id>.ifdown`
is the narrower record of what the daemon itself took down, and it is the only
thing it will ever raise again. They differ whenever an interface a quota
covers was already down when the quota was crossed: it belongs in `.cut` (do
not "recover" it) but not in `.ifdown` (it was not ours to take down, so it is
not ours to put back). Raising the whole `.cut` list instead meant an
interface the admin had just brought down came back up on the very next poll —
at the shipped `interval` of 2s, a fight the admin cannot win. A recovery that
finds a `<id>.cut` with no `<id>.ifdown` beside it treats it as a marker from a
daemon older than the split and raises the whole list once, so a router
upgraded mid-cut does not keep its WAN down for good.

The directory is resolved as
`${OMR_QUOTA_RUNTIME_DIR:-${OMR_QUOTA_THROTTLE_STATE_DIR:-/tmp/omr-quota}}`
in both the daemon and the init. Two names because the two sides of the
interface grew apart: omr-quota only ever read
`OMR_QUOTA_THROTTLE_STATE_DIR` (the older name, and the one its unit tests
pass), while the omr-tracker consumer below resolves the same directory as
`OMR_QUOTA_RUNTIME_DIR`. The defaults matched, so nothing was broken in
production, but a directory only one side of a contract can relocate is a
latent bug: point omr-quota elsewhere and the guard keeps reading
`/tmp/omr-quota`. `OMR_QUOTA_RUNTIME_DIR` therefore wins when both are set,
with the older name kept as an alias so existing callers and tests are
unaffected.

**The `.cut` markers are a cross-package interface, not a private detail.**
`omr-tracker`'s `post-tracking.d/002-error` reads them (its
`_omr_quota_cut_active`) so that an interface omr-quota has deliberately
`ifdown`ed is not mistaken for a connectivity failure: without it the
tracker's recovery paths would re-enable the ModemManager modem and `ifup`
the interface, fighting the quota daemon every cycle. It matches a
per-interface quota by marker *basename* (`<iface>.cut`) and a global quota
by marker *contents* (the interface list), which is exactly how the daemon
writes them — so the file name, the content format and the directory name
must all stay stable, or that guard silently stops working. `tests/cases/88`
checks the contract from the other side by running that function against
markers a real daemon has just written.

Two details a consumer has to get right. The marker directory does not exist
until a daemon first enforces something, so iterating the glob has to
tolerate no match — the guard's `for marker in <dir>/*.cut; do [ -f
"$marker" ] || continue` idiom does, but it would break under `nullglob` or
`set -u`. And a consumer sourced into omr-tracker's post-tracking shell
inherits that package's `uci()` wrapper function (it flushes a cache, then
passes through to the real binary), so anything reading UCI there goes
through it rather than straight to `/sbin/uci`.

Two consumers besides the daemon itself:

- **`get_status`** (rpcd) reports `cut` / `throttled` from `<id>.cut` /
  `<id>.throttled`.
- **`OMR_QUOTA_UNDO=1 /bin/omr-quota <id>`** runs `_undo_enforcement` and
  exits instead of entering the loop: it removes the tc shapers of the
  interfaces listed in `.throttled` / `.downstream` (device resolved through
  the `<iface>.realdev` cache, since a cut interface has no `l3_device`),
  restores the LAN input if `.blocklan` exists, `ifup`s the interfaces listed
  in `.ifdown` (falling back to `.cut` when only that older marker is
  present), deletes the markers and logs
  `Quota enforcement for <id> lifted`. Without this, disabling or removing a
  quota whose interface was cut left it down for good, and a throttled one
  stayed shaped: the daemon was simply not relaunched and nothing else knew
  what it had done.

  `init.d/omr-quota` drives it from two places: `_undo_orphaned_enforcement`
  at the end of `start_service`, for every marker identity the walk it just
  did did *not* launch a daemon for, and `service_stopped`, for every marker
  identity there is, on a real stop.

  The orphan sweep compares marker identities (`_marker_ids`) against
  `$_ACTIVE_IDS`, which `_launch_quota` / `_launch_global_quota` append to
  as they open each procd instance — i.e. against the single `config_load`
  snapshot `start_service` is already working from. It deliberately does
  **not** re-ask uci about each marker: `set_quota` / `reset_exceeded` run
  `uci commit omr-quota` and *then* trigger this very reload, and while that
  commit is in flight `uci -q get omr-quota.<section>` comes back empty, so
  a sweep that treated "cannot read" as "not configured" lifted the
  enforcement of quotas that were still enabled (seen on the bench: two
  enforced WANs released at once while the rpcd plugin answered "interface
  not found" for the same section). For the same reason the sweep skips
  itself entirely, with a log line, when the walk saw no section at all
  (`_SECTIONS_SEEN` is 0) while `/etc/config/omr-quota` is not empty: that
  combination means unreadable, not unconfigured.

  `_TSTATE_DIR`, the persistent state dir, the daemon path and the config
  file path are all overridable in the init too (`OMR_QUOTA_RUNTIME_DIR` or
  its legacy alias `OMR_QUOTA_THROTTLE_STATE_DIR`, `OMR_QUOTA_STATE_DIR`,
  `OMR_QUOTA_BIN`, `OMR_QUOTA_CONFIG_FILE`) so
  `tests/test_003_init_orphan_sweep.sh` can drive the sweep against a scratch
  directory and a fake daemon.

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

  **`calculation_interval` must be longer than `interval`.** The growth
  comparison happens after the checkpoint is (re)set, so a
  `calculation_interval` at or below the poll interval moves the checkpoint
  to the current usage on every iteration, `tt - last_tt` is always 0, and
  method 1 can never fire. That was silent until it was measured on the
  bench (`calculation_interval=1`, `interval=5`: two 150 KB bursts against a
  2 KiB budget, no cut in five minutes), so the daemon now clamps the value
  to `2 × interval` and logs the substitution once. Usage is still only
  ever compared against a *closed* window, which is why a budget cut lasts
  until the next checkpoint and then releases: method 1 blocks for the
  remainder of each window rather than latching.
- `method=2` ("limit speed using remaining daily volume"): every loop it
  recomputes a `tc` rate `cb` (kbit/s) from `dv` and the seconds left in the
  day, and applies it via `_apply_downstream_limit` on
  `${OMR_QUOTA_DOWN_INTERFACES:-$target_interfaces}` — independent of
  `exceeded`/`ifdown`, so the interface(s) stay up but shaped.
  `_remove_downstream_limit` clears the shaping once method `2` is no longer
  selected or the budget check no longer applies.

  The rate caps **both directions** (`_shape_device`, the same egress-tbf +
  ingress-to-IFB mechanism the throttle action uses). It used to install the
  egress tbf only, which on a WAN device limits upload and leaves download —
  the direction a volume budget is actually spent on — completely untouched.
  Measured on the bench under a derived 2 Mbit/s limit: upload 1897 kbit/s,
  download 20003 kbit/s. After the fix, 1542 and 1955 kbit/s.

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

`_apply_throttle`/`_remove_throttle` are thin wrappers over `_shape_device`/
`_unshape_device`, which implement bidirectional shaping with `tc` + an IFB
device (`ifb-<dev>` — `/` sanitized to `-`, since MPTCP sub-interfaces can
contain one). The daily-budget speed limit uses the same pair:

- Egress: `tbf` directly on the real device (upload).
- Ingress: redirected via `u32`/`mirred` to the IFB device, which then has
  its own `tbf` (download) — the standard Linux trick since `tc` cannot
  shape ingress directly.

### SQM hand-off (`_sqm_manages`)

SQM (`/usr/lib/sqm`, cake or htb+fq_codel) owns the root qdisc of the devices
it shapes, and `_shape_device` replaces it. A device SQM manages is therefore
handed over explicitly: `_shape_device` runs `/usr/lib/sqm/run.sh stop <dev>`
before installing the tbf, and `_unshape_device` runs
`/usr/lib/sqm/run.sh start <dev>` afterwards, logging both. Without the
hand-back the user's shaper was silently gone once a quota cleared while
SQM's state file still claimed it was running — the same failure mode as
issue #4329, where mptcp's `fq` default wiped cake. Without the take-over,
SQM's state file stayed behind and any `sqm reload` would drop cake back on
top of the quota's tbf.

`_sqm_manages` detects it the same way mptcp's guard does: a live
`<state dir>/<dev>.state`, or an enabled `sqm` section whose `interface` is
that device. `OMR_QUOTA_SQM_RUN` and `OMR_QUOTA_SQM_STATE_DIR` override the
paths for the unit tests. Verified live on the bench: cake at 5 Mbit/s →
tbf at 2 Mbit/s when the throttle engaged (state file gone) → cake at
5 Mbit/s again when the quota was disabled (state file back).

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
change otherwise. They have to call it explicitly: a bare `uci commit` does
not emit the `config.change` event procd's reload triggers listen for (only
LuCI's apply and `/sbin/reload_config` do), which is also why a test that
restores the config by committing without reloading leaves the daemon
enforcing settings the config no longer holds.

The package used to ship an `etc/uci-defaults/omr-quota` that registered
itself with `ucitrack`. That is the pre-procd way of tying a config change to
a service restart, OMR images ship no `/etc/config/ucitrack` at all (so the
registration failed silently), and `service_triggers` already declares
`procd_add_reload_trigger omr-quota network` — which is what actually reloads
the service. The file was removed rather than repaired.

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

`get_status` applies the same live-counter correction as the daemon, through a
**read-only** twin of `_live_delta`: the daemon owns the `live.<id>.<dev>`
state,
the plugin only consumes it (and ignores it when it is missing or expired), so
the page shows the number the quota is actually enforced on rather than one up
to five minutes old. Keep the two in sync, like `_vnstat_month` and
`_vnstat_usage`.

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
for `global` sections. When `begindate` is set, it sums
`vnstat -i <dev> --json d -b <begindate>` day buckets instead of reading
`traffic.month[-1]`, for the reason given in the daemon loop above.
`_vnstat_month` (in the rpcd plugin) and `_vnstat_usage`
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

- `tests/run_tests.sh` -- mocked unit tests, run locally with bash, no router
  needed: `test_001_quota.sh` (daemon cut/throttle/scope/budget/block_lan/
  baseline logic), `test_002_enforcement_markers.sh` (markers,
  ifup-before-tbf ordering, undo mode), `test_003_init_orphan_sweep.sh`
  (init: what the orphan sweep lifts and what it must not, reload vs stop,
  the `reset_exceeded` one-shot, vnstat device tracking).
- `../tests/cases/88-omr-quota-*.sh` -- bench integration case: drives the
  real rpcd -> init -> daemon -> vnstat/ifdown/tc/firewall chain on a
  router's non-master WANs, in thirteen phases: rpcd input validation, cut,
  the omr-tracker quota-cut guard reading the markers the daemon just wrote,
  vnstat tracking hygiene, cut -> throttle, goodput through the VPS iperf3
  server (when `iperf.<vps>` is configured), `reset_exceeded`, persistent
  scope, disable while cut, re-enable plus reset on a disabled quota, a
  global quota over two WANs, `block_lan` with the router-access rules, and
  a real service stop. It restores the package, the firewall and the
  interfaces afterwards, and asserts that it did.
  `sudo ./tests/run.sh <router> --only=88`.

  It measures goodput with **UDP**: OMR forces MPTCP on router-originated
  connections, so a TCP socket bound to one WAN's address still gains
  subflows on the other WANs and measures the aggregate instead of the
  throttled link. UDP has no subflows and tracks the tbf rate closely
  (live: 8.9 -> 3.0 Mbit/s down, 3.3 -> 1.1 Mbit/s up across a 3/1 Mbit/s
  throttle). The case also disables any other enabled quota section for its
  duration -- one left enabled cuts its own WAN and can flip
  `firewall.zone_lan.input` to DROP while the case runs.

  Phase 1b is about the live-counter correction: that the daemon keeps a
  well-formed, unexpired `live.<id>.<dev>` state, that `get_status` really reports
  vnstat's sample plus the kernel delta (recomputed on the router from the
  same inputs), that fresh traffic shows up within one poll interval while
  vnstat's database has not been rewritten at all, and that forcing a flush
  (`SIGHUP` to vnstatd, what `/etc/init.d/vnstat reload` sends) does not make
  the usage jump -- the double count the re-anchoring rule exists to avoid.
  It runs with a quota value that can never be reached, so it enforces
  nothing.

  Two more things the case deliberately does not do. It never waits for fresh
  traffic to reach a quota: vnstat serves only what its database holds and
  vnstatd flushes on `SaveInterval` (5 minutes by default), so a quota
  measured against a freshly reset baseline stays un-exceeded for minutes
  after real traffic has flowed -- "exceeded" is driven by the month's
  already accumulated usage, and the baseline file is deleted when that
  usage needs to count again. And it never asserts on before/after
  `logread` match counts: the ring buffer holds about ten minutes here, so a
  rotation loses the "before" line and makes an added line read as "no
  change". It writes its own marker line into the log and greps only what
  follows it, skipping the check if the marker itself has rotated away.

  Because `block_lan` closes the LAN the suite itself drives the router
  over, that phase first arms a detached watchdog on the router which
  restores `firewall.zone_lan.input=ACCEPT` and deletes the three access
  rules if it is not cancelled within 180 seconds.
- `../tests/cases/89-omr-quota-every-uci-option.sh` -- bench case walking the
  *option schema* rather than the lifecycle: the rpcd round trip of all
  seventeen options, a quota of `0` meaning "no quota", `txquota` and
  `ttquota` enforced on their own counters, the `begindate` window (the
  regression test for the `traffic.total` bug above), `method=2` with
  `percent` / `enddate` / `down_interfaces`, `method=1`'s daily-budget block
  (which lowers vnstat's `SaveInterval` for its duration, since it is the
  one check that needs usage to actually grow), the procd environment the
  init hands the daemon for every option, live `throttle_dl` / `throttle_ul`
  changes, `interval`, the ubus/ACL surface, and the SQM hand-off (it enables
  SQM on the test WAN itself, then puts it back).
  `sudo ./tests/run.sh <router> --only=89`.
- `tests/test_004_live_counters.sh` -- the live kernel-counter correction:
  anchoring, the re-anchor on a vnstat flush, counter resets, expired state,
  `live_counters=0`, an incomplete vnstat sample, a global quota summing every
  member's delta, and the baseline recording the corrected usage. The mock
  environment has its own empty `/sys/class/net` (`MOCK_SYSFS_DIR`), so a test
  that says nothing about kernel counters gets none -- rather than silently
  reading a real device of the build host that shares the mock's name.
  It also covers `_vnstat_register`: a device vnstat does not know gets added,
  committed and vnstat reloaded exactly once; one vnstat already counts is left
  alone; a device that is not there, a usable sample, and a missing
  `vnstat.@vnstat[-1]` section register nothing.
- `../luci-app-omr-quota/tests/test_quota_ui.py` -- Playwright UI test of
  the LuCI page.
