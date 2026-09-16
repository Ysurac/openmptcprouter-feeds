# Monthly Quota — User Guide

`luci-app-omr-quota` caps how much data a WAN interface can use per
calendar month — useful for a metered 4G/5G/satellite link where going
over risks extra charges or a speed cap from the carrier. When the quota
is hit, the interface is either cut off or throttled for the rest of the
month.

It lives under **Network → Quota**, split into two tabs: **Settings**
(configuration, described below) and **Graphs** (live usage bars and
remaining data per interface, refreshed every 15 seconds via the backend's
`get_status` ubus call).

Screenshots were taken on a test router (`v0.64-snapshot`) with two WAN
interfaces already configured (values are just test placeholders).

## Opening the page

```
https://<router-ip>/cgi-bin/luci/admin/network/quota
```

![Monthly Quota — overview](images/01-quota-overview.png)

Each configured interface gets its own block. Use the dropdown +
**Add interface…** at the bottom to add a WAN (only real, non-loopback
interfaces are offered); each block's **Delete** button removes that
interface's quota entirely.

## Fields

| Field | Meaning |
|---|---|
| **Enable** | Turns quota tracking on/off for this interface without deleting its configuration. |
| **TX quota (KiB)** | Upload cap for the month. `0`/blank disables this particular check. |
| **RX quota (KiB)** | Download cap for the month. |
| **TX+RX quota (KiB)** | Combined cap — checked independently of the two above, so you can use any combination (e.g. only a combined cap, or a combined cap *and* a tighter upload-only cap). |
| **Metered interfaces** | Optional list of interfaces whose vnstat usage is summed for this quota. If left empty, only this block's interface is counted. |
| **Downstream limit interfaces** | Optional list of interfaces shaped by the daily-budget speed-limit method. |
| **Begin date / End date** | Optional date range for non-monthly quota periods. Setting a begin date makes usage come from `vnstat -b <date>` totals; the end date is used for daily-budget calculations. |
| **Interval between checks (s)** | How often the traffic counters are polled. |
| **Daily budget method** | Optional extra guard once combined usage passes the threshold: either block when the current interval spends too much of the remaining daily allowance, or rate-limit downstream interfaces based on the remaining daily volume. |
| **Budget threshold (%)** | Percentage of the combined quota after which daily-budget enforcement starts. |
| **Budget calculation interval (s)** | How often the interval budget is recalculated for the blocking daily-budget method. |
| **Block LAN and proxy when cut** | When using the cut action, sets LAN input to `DROP`, uniformly blocking all transparent proxies without changing their service state; LAN input is restored when the quota clears. |
| **Action when quota is reached** | **Cut** — bring the interface down (`ifdown`) for the rest of the month; or **Throttle** — leave it up but rate-limit it. |
| **Enforcement scope** | **This month only** — the cut/throttle clears automatically once the new month's counter starts; or **All future months** — once triggered, the interface stays cut/throttled at every future month rollover until you explicitly reset it below. |

Selecting **Throttle** reveals two more fields; selecting **All future
months** reveals a reset control:

![Monthly Quota — throttle action and persistent scope expanded](images/02-quota-throttle-persistent.png)

| Field | Meaning |
|---|---|
| **Download limit (Mbps)** | Applied via `tc`/`tbf` on an `ifb` device once throttled — the max download speed while over quota. |
| **Upload limit (Mbps)** | Same, for upload. |
| **Reset exceeded state** | Tick and save to lift an exceeded quota now, whichever scope it uses. It clears the persistent "exceeded" flag *and* records usage-so-far as a baseline, so the interface recovers on the next check interval instead of staying cut/throttled until the month rolls over. |

## How accurate is it?

Usage is checked every **Interval** seconds, and what is checked is
`vnstat`'s counter **plus the traffic the kernel has counted since vnstat's
last sample**. That second part matters: `vnstatd` keeps its counters in
memory and only writes them to its database every `SaveInterval` minutes (5
by default), so a quota measured on `vnstat` alone is blind for up to five
minutes — on a fast link (Starlink, fibre) a single speedtest passes several
gigabytes inside that window and the quota is only *seen* as reached long
after it was crossed. Reading the live kernel counters on top brings the
resolution down to the polling interval, so the overshoot is bounded by what
the link can pass in a few seconds rather than in five minutes.

Two consequences worth knowing:

- The figure shown on this page is the same corrected one the daemon
  enforces on, so it can be slightly ahead of what `vnstat` itself reports on
  the command line. They converge at vnstat's next flush.
- It still is not instant. Sizing a quota right at an operator's hard cap is
  never a good idea; leave a margin of whatever the link can pass in a few
  polling intervals. Setting a smaller **Interval** tightens it further, and
  the **Daily budget method** (rate-limit) bounds the overshoot mechanically
  by slowing the link down before the hard limit is reached.

One thing the daemon now fixes on its own: vnstat has to be told which
*devices* to count, and that registration used to happen only when the
service started. An interface that was down at that moment (nothing plugged
in, modem not up yet) was skipped and never registered afterwards, so a quota
on it metered 0 bytes and silently never applied. The daemon now registers the
device the first time it sees vnstat has no data for it, logging
`vnstat was not counting <device>` — once per device, no restart needed.

Should you ever need the reported usage to match `vnstat` exactly, the UCI
option `live_counters` (`uci set omr-quota.<section>.live_counters=0`) goes
back to metering vnstat's database alone, with the five-minute blind window
that implies. It has no field on this page on purpose.

## How enforcement actually works

Each enabled interface runs its own `/bin/omr-quota <interface>` daemon
(started by `/etc/init.d/omr-quota`), polling the counters for that interface
every **Interval** seconds and comparing them against whichever of TX/RX/TX+RX
quotas are set:

- **Cut** just runs `ifdown`/`ifup` on the interface as the quota is
  crossed/not crossed.
- **Throttle** shapes the interface with `tc qdisc ... tbf` — upload
  directly on the WAN device, download via a paired `ifb-<device>`
  interface that egress traffic is redirected through — removing the
  shaping automatically once no longer exceeded.
- With **This month only** scope, "exceeded" is purely derived from the
  current month's counters, so it naturally clears when the month rolls over
  and the counter resets.
- With **All future months** scope, the first time the quota is crossed
  the daemon drops a marker file
  (`/etc/omr-quota/state/<interface>.exceeded`) that forces `exceeded`
  true from then on, independent of the counters — that's what makes it
  survive the monthly counter reset. **Reset exceeded state** deletes that
  marker file; this only actually happens when the `omr-quota` service
  (re)starts, so tick it and then **Save & Apply** (not just save the
  form) for the reset to take effect.
- With **This month only** scope there is no marker to delete: `exceeded` is
  recomputed from the live totals on every poll, so a quota stays enforced
  for as long as those totals are over the limit. **Reset exceeded state**
  is what lifts it early — it records the usage so far as a baseline that is
  subtracted from every later reading, which is why the same tick works for
  both scopes.
