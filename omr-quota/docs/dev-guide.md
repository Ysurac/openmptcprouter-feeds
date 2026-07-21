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
`OMR_QUOTA_SCOPE`). Each iteration:

1. Resolve the real L3 device via `ifstatus` (handles both plain interfaces
   and `@`-prefixed logical/dynamic ones, e.g. mwan/multipath aliases).
2. Read this month's rx/tx from `vnstat -i <dev> --json`
   (`interfaces[0].traffic.month[-1]`), converted from bits to KiB.
3. Compare against the configured quotas to compute `exceeded`.
4. Apply `_apply_throttle` / `_remove_throttle`, or `ifdown`/`ifup`, and log
   the transition once via `logger -t OMR-QUOTA` (edge-triggered on
   `_prev_exceeded`, not every loop).
5. `sleep "$OMR_QUOTA_INTERVAL"` and repeat — the process never exits on its
   own; procd/`stop` is what tears it down.

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

`get_status` recomputes `exceeded` from live vnstat data in addition to
checking the persistent marker, so it reflects reality even if the daemon
process for that interface isn't running.

Input is read as a single JSON blob from stdin (`ubus call` convention) and
picked apart with `jsonfilter`; iface names are sanitized through
`_safe_iface` before being interpolated into file paths / uci keys.

## Manual ubus calls

```
ubus call omr-quota get_quota    '{}'
ubus call omr-quota get_quota    '{"interface":"wan1"}'
ubus call omr-quota set_quota    '{"interface":"wan1","enabled":"1","rxquota":"400000","exceedance_action":"throttle","throttle_dl":"5","throttle_ul":"2","exceedance_scope":"persistent"}'
ubus call omr-quota get_status   '{"interface":"wan1"}'
ubus call omr-quota reset_exceeded '{"interface":"wan1"}'
```
