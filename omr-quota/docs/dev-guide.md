# omr-quota — developer guide

Backend package that enforces monthly data quotas per WAN interface: cuts or
throttles an interface once its vnstat usage crosses a configured limit.
`luci-app-omr-quota` is the UI on top of this; this document only covers the
backend package.

## Components

| File | Role |
| --- | --- |
| `files/bin/omr-quota` | Daemon loop: polls vnstat, decides exceeded/not, applies cut or throttle |
| `files/etc/init.d/omr-quota` | procd init script: one daemon instance per configured interface |
| `files/etc/config/omr-quota` | UCI config (defaults, one `interface` section per WAN) |
| `files/etc/uci-defaults/omr-quota` | First-boot: registers the package with `ucitrack` so network reloads restart it |
| `files/usr/libexec/rpcd/quota` | ubus/rpcd plugin (`get_quota`, `set_quota`, `get_status`, `reset_exceeded`) |
| `files/usr/share/rpcd/acl.d/omr-quota.json` | ACL exposing those ubus methods to the LuCI/admin session |

## Config schema (`omr-quota.<interface>`)

Validated in `_validate_section()` in the init script:

- `txquota` / `rxquota` / `ttquota` (uinteger, KiB) — TX / RX / combined quota for the month. `0`/unset disables that check.
- `interfaces` (space-separated interface names, default current section) —
  vnstat usage from these interfaces is summed before checking quotas.
- `begindate` / `enddate` (date strings accepted by `vnstat -b` and
  `date -d`) — when `begindate` is set, the daemon reads vnstat's total
  traffic since that date instead of the current monthly bucket; `enddate`
  enables daily-budget calculations.
- `method` (`0` default, `1`, or `2`) — optional daily-budget mode once
  `ttquota` usage crosses `percent`: `1` blocks if traffic since the last
  calculation exceeds the per-interval budget, `2` applies a downstream
  `tc` speed limit based on the remaining daily volume.
- `down_interfaces` (space-separated interface names, default current
  section) — interfaces shaped by daily-budget method `2`.
- `percent` (uinteger, default `80`) and `calculation_interval` (uinteger,
  default `120`) — daily-budget trigger threshold and method `1` recalculation
  cadence.
- `block_lan` (bool, default `0`) — with cut action, also flips
  `firewall.zone_lan.input` to `DROP` and stops `shadowsocks-rust.sss0` while
  quota enforcement is active, restoring both when the quota clears.
- `interval` (uinteger, default `30`) — seconds between daemon polls.
- `enabled` (bool, default `0`).
- `exceedance_action` (`cut` default, or `throttle`).
- `throttle_dl` / `throttle_ul` (uinteger, Mbps, default `1`) — used only when `exceedance_action=throttle`.
- `exceedance_scope` (`month_only` default, or `persistent`) — see below.
- `reset_exceeded` (bool) — one-shot trigger, cleared automatically once processed.

The section name **is** the logical interface name and is passed as `$1` to
the daemon (`files/bin/omr-quota`) and used as `procd_open_instance` per
`config_foreach` in `start_service()`.

## Daemon loop (`files/bin/omr-quota`)

One process per interface, launched by `init.d/omr-quota` with quota values
passed as env vars (`OMR_QUOTA_TX`, `OMR_QUOTA_RX`, `OMR_QUOTA_TT`,
`OMR_QUOTA_INTERVAL`, `OMR_QUOTA_ACTION`, `OMR_QUOTA_THROTTLE_DL/UL`,
`OMR_QUOTA_SCOPE`, `OMR_QUOTA_INTERFACES`, `OMR_QUOTA_DOWN_INTERFACES`,
`OMR_QUOTA_BEGINDATE`, `OMR_QUOTA_ENDDATE`, `OMR_QUOTA_METHOD`,
`OMR_QUOTA_PERCENT`, `OMR_QUOTA_CALCULATION_INTERVAL`,
`OMR_QUOTA_BLOCK_LAN`). Each iteration:

1. Resolve the real L3 device for every interface in `OMR_QUOTA_INTERFACES`
   (defaults to the section interface) via `_get_real_interface`, which
   wraps `ifstatus` and handles both plain interfaces and `@`-prefixed
   logical/dynamic ones (e.g. mwan/multipath aliases). `ifstatus` reports no
   `l3_device` while an interface is administratively down — including when
   *this script* just cut it for quota enforcement — so `_get_real_interface`
   caches the last resolved device name to `<_TSTATE_DIR>/<iface>.realdev`
   and falls back to it when the live lookup comes back empty. Without this
   the next loop reads 0 bytes for a cut interface, sees the quota as no
   longer exceeded, brings it back up, and cuts it again: an infinite
   up/down flap.
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
4. Apply `_apply_throttle` / `_remove_throttle`, or `ifdown`/`ifup`, and log
   the transition once via `logger -t OMR-QUOTA` (edge-triggered on
   `_prev_exceeded`, not every loop). On the cut path, `_block_lan` /
   `_unblock_lan` run alongside `ifdown`/`ifup` when `OMR_QUOTA_BLOCK_LAN=1`.
5. `sleep "$OMR_QUOTA_INTERVAL"` and repeat — the process never exits on its
   own; procd/`stop` is what tears it down.

### Usage baseline / `reset_exceeded` (`_read_baseline`, `OMR_QUOTA_RESET_BASELINE`)

`reset_exceeded` only ever cleared the `persistent`-scope marker file, which
does nothing for `exceedance_scope=month_only`: that scope recomputes
`exceeded` from live vnstat totals every loop, so there was nothing else to
clear and an exceeded month_only quota stayed cut/throttled until vnstat's
own monthly bucket rolled over.

A baseline file `${OMR_QUOTA_STATE_DIR:-/etc/omr-quota/state}/<interface>.baseline`
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

### Exceedance scope

- `month_only`: `exceeded` is recomputed from current vnstat counters every
  loop, so it clears automatically once vnstat rolls over to a new month.
- `persistent`: once exceeded, a marker file
  `${OMR_QUOTA_STATE_DIR:-/etc/omr-quota/state}/<interface>.exceeded` is
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
  day, and applies it via `_apply_downstream_limit` on `down_interfaces`
  (default: the section interface) — independent of `exceeded`/`ifdown`, so
  the interface stays up but shaped. `_remove_downstream_limit` clears the
  `tc` qdisc once method `2` is no longer selected or the budget check no
  longer applies.

Both methods are mutually exclusive per section (`method` is a single
`ListValue`: `0` disabled, `1`, or `2`).

### LAN block on cut (`_block_lan` / `_unblock_lan`)

When `block_lan=1` and `exceedance_action=cut`, bringing the interface down
also sets `firewall.zone_lan.input=DROP` (committed + `firewall reload`) and
stops `shadowsocks-rust` if `shadowsocks-rust.sss0` is currently set to
`ss_rules`, disabling that section so it doesn't restart on its own. Both are
reverted (`ACCEPT` / re-enable + start) in `_unblock_lan` once the interface
is brought back up. This is meant to stop LAN clients from silently falling
back to another route (e.g. a second WAN or the proxy) once the quota'd
interface is cut.

### Throttle mechanism

`_apply_throttle`/`_remove_throttle` implement bidirectional shaping with
`tc` + an IFB device (`ifb-<dev>` — `/` sanitized to `-`, since MPTCP
sub-interfaces can contain one):

- Egress: `tbf` directly on the real device (upload).
- Ingress: redirected via `u32`/`mirred` to the IFB device, which then has
  its own `tbf` (download) — the standard Linux trick since `tc` cannot
  shape ingress directly.

Throttle state is tracked separately from quota-exceeded state, in
`${OMR_QUOTA_THROTTLE_STATE_DIR:-/tmp/omr-quota}/<interface>.throttled`
(tmpfs — intentionally not persisted across reboot, unlike the exceeded
marker).

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
it clears the throttle-state file, sets `reset_exceeded=1` in UCI, and
reloads, delegating to the exact same `init.d/omr-quota` path the
UCI-option trigger uses. That path both removes the persistent marker *and*
sets `OMR_QUOTA_RESET_BASELINE=1` for the relaunch, which is what actually
un-exceeds an `exceedance_scope=month_only` quota (see the daemon's usage
baseline section above) — a plain `rm` of the marker file never affected
month_only quotas at all.

`get_status` recomputes `exceeded` from live vnstat data in addition to
checking the persistent marker, so it reflects reality even if the daemon
process for that interface isn't running. Like the daemon, it sums usage
across `interfaces` (default: the section interface) and, when `begindate`
is set, queries `vnstat -i <dev> -b <begindate> --json` /
`traffic.total.*` instead of `traffic.month[-1]`. `_vnstat_month` (in the
rpcd plugin) and `_vnstat_usage` (in the daemon) are separate implementations
of the same lookup — keep both in sync when changing the vnstat query.

Input is read as a single JSON blob from stdin (`ubus call` convention) and
picked apart with `jsonfilter`; iface names are sanitized through
`_safe_iface` before being interpolated into file paths / uci keys.

## Manual ubus calls

```
ubus call omr-quota get_quota    '{}'
ubus call omr-quota get_quota    '{"interface":"wan1"}'
ubus call omr-quota set_quota    '{"interface":"wan1","enabled":"1","rxquota":"400000","exceedance_action":"throttle","throttle_dl":"5","throttle_ul":"2","exceedance_scope":"persistent"}'
ubus call omr-quota set_quota    '{"interface":"wan1","ttquota":"500000","method":"2","percent":"80","enddate":"2026-07-31","down_interfaces":"lan"}'
ubus call omr-quota get_status   '{"interface":"wan1"}'
ubus call omr-quota reset_exceeded '{"interface":"wan1"}'
```
