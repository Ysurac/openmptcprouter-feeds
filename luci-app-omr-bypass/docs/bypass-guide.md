# OMR-Bypass — User Guide

`luci-app-omr-bypass` lets you route specific traffic *around* the normal
MPTCP/VPN bonding — straight out a chosen WAN, out the VPS's VPN, or just
DSCP-marked in place — instead of through the default aggregated path.
Typical uses: keep a streaming service off a metered link, force a
latency-sensitive app onto one specific WAN, or send everything from one
device out a dedicated interface.

It has two tabs under **Services → OMR-Bypass**: **Bypass Rules** (this
package's own view) and **DPI Flows** (contributed by the separate
`luci-app-ndpid` package, wired in here because DPI-based rules depend on
it).

Screenshots were taken on a test router (`v0.64-snapshot`) with no bypass
rules configured yet, so the grids show their empty state; the **Add**
modal for each rule type was opened (without saving) to capture its
fields.

## Bypass Rules

```
https://<router-ip>/cgi-bin/luci/admin/services/omr-bypass/rules
```

![Bypass Rules — Global settings plus all rule tables, empty](images/00-rules-grid.png)

The page requires **OpenMPTCProuter's own DNS resolver** to be used by
clients (stated right under the page title) — domain-based rules only work
because OMR's DNS is what returns the matched IP in the first place, tying
it to the right rule.

Above the rule tables, a small **Global settings** box, then 9
independent rule tables, each matching traffic a different way. All of
the rule tables share a common tail of options — **Output interfaces**,
**DSCP marking**, **Note** — described once below, then only
each section's distinguishing fields are called out.

### Global settings

![Global settings — default](images/00a-global-settings.png)

One field, **Bypassed domains IP refresh**: domain-based rules (the
**Domains** table below) work by resolving each domain to an IP and
firewall/DNS-matching on that IP, so OMR periodically re-resolves them in
case the IP changed — which can force a firewall/DNS restart and briefly
interrupt existing connections if it did. This setting picks *when* that
periodic refresh runs: a specific hour (default **02:00**) or **Every
hour**, for domains that change IP more often than once a day.

**Common fields** (present in every rule type):

| Field | Meaning |
|---|---|
| **Enabled** | Toggle the rule on/off without deleting it. |
| **VPN on server** *(where present)* | Route matched traffic over the VPN configured on the VPS instead of a local WAN interface. |
| **Output interfaces** | Which WAN sends this traffic, as an ordered list (see below). Entries: `Default` (MPTCP master), a specific WAN, or **None** to block it outright. Leave the list empty for no routing change (DSCP marking only). |
| **DSCP marking** | Optional DSCP class to stamp on matched traffic (CS0–CS7, AF11–AF43, EF, LE) — usable on its own, without changing the route. |
| **Note** | Free-text reminder of why the rule exists. |

**Output interfaces, in order.** The first interface of the list that is
up is used. When OMR-Tracker reports it down, the next one takes over.
Once it is reported up again (after the tracker's "tries up" count),
traffic goes back to it. The grid shows the list and, for a list of more
than one entry, the one in use right now: `wan2 → wan3 → Default (now:
wan3)`.

* When no listed interface is up, the traffic is **blocked**, which is what
  a single interface that is down always did. Put **Default** last to fall
  back on the MPTCP master instead.
* **None** ends the list: listed first, the rule blocks the traffic. Listed
  after WANs, it makes the "blocked when all are down" explicit.
* A rule with a single interface behaves exactly as before.
* When a rule switches interface, the connections it had opened through
  the previous one are dropped so clients reconnect right away. Each switch
  is logged (`logread | grep "Output WAN list"`).
* The former **Failback** field is gone: an existing failback interface was
  moved to the end of the rule's list on upgrade.

### Domains

![Domains — add rule](images/01-domains-modal.png)

Matches by destination domain name. Adds **Restrict to address family**
(IPv4/IPv6/both) and **protocol** (all/tcp/udp) beyond the common set, plus
**Disable AAAA IPv6 DNS** to make the router ignore IPv6 answers for this
domain and force IPv4-only resolution — useful when a service's IPv6 path
is worse than its IPv4 one.

### IPs and Networks

![IPs and Networks — add rule](images/02-ips-modal.png)

Matches a destination IP or CIDR network directly — for services you'd
rather target by address than by domain (or that don't have a stable
domain name at all).

### Ports destination / Ports source

![Ports destination — add rule](images/03-dest-port-modal.png)

Match by destination port (pictured) or source port — nearly identical
forms, just **port** + **protocol** (tcp/udp/icmp) as the match, no
domain/IP involved. Destination-port rules are the way to steer a specific
*service* (e.g. a game server port) regardless of which domain/IP serves
it; source-port rules instead target traffic *generated* by a specific
local port (e.g. a device or daemon that always sends from a fixed port).

### MAC-Address

![MAC-Address — add rule](images/05-mac-modal.png)

Matches by client device MAC — the dropdown is populated live from LuCI's
host-hints (DHCP leases/ARP table), showing each known device's name next
to its MAC; empty here since no LAN clients were attached during capture.
Use this to route *everything* a specific device sends, regardless of
destination.

### Source lan IP address or network

![Source LAN IP — add rule](images/06-lan-ip-modal.png)

Same idea as MAC-Address but matched by the client's LAN-side IP/subnet
instead — useful for a whole VLAN or IP range rather than one device.

### Source interface policies

Sends *everything* that enters the router on a local interface (a guest
network, a VLAN, a second LAN port...) out through one chosen WAN,
directly, with its own failover order. Unlike the rules above, it has a
list of WANs instead of a single **Output interface**:

* **Source interface** — the local interface(s) the policy applies to.
* **Output WANs** — an ordered list. The first WAN that is up is used.
  When OMR-Tracker reports it down, the next one takes over. Once the
  preferred WAN is reported up again (after the tracker's own "tries up"
  count), traffic goes back to it.
* **When all WANs are down** — *Default OpenMPTCProuter path* lets the
  traffic use the normal aggregated path through the server. *Block
  traffic* drops it instead, so the interface never uses anything but the
  listed WANs.
* **IPv6** — *Default* leaves IPv6 on the normal path. *Same WAN as IPv4*
  routes it through the selected WAN too. Only use that when the WAN
  itself gives this interface routable IPv6 addresses: addresses from the
  server's prefix cannot leave through a WAN. *Block IPv6* drops it.
* **Current output** — the WAN the policy uses right now, or the fallback
  in use.

Traffic to the router itself and to the other local networks is not
affected. A destination rule (domain, IP, port, ASN, protocol) still
wins over the policy, so you can still send one service elsewhere. When
the policy switches WANs, connections opened through the previous one
are dropped so clients reconnect through the new one right away. Every
switch is logged (`logread | grep "Source interface policy"`).

The source interface's firewall zone must be allowed to forward to the
`wan` zone, as for any other direct bypass.

### ASN

![ASN — add rule](images/07-asn-modal.png)

Matches destinations announced by a given Autonomous System Number —
handy for bypassing an entire provider (e.g. a CDN or cloud provider's ASN)
without tracking their individual IP ranges by hand.

### Protocols and services

![Protocols and services — add rule](images/08-dpis-modal.png)

Matches by application protocol/service as identified by **nDPI** deep
packet inspection — the **Protocol/Service** dropdown is populated from
`/usr/share/omr-bypass/omr-bypass-proto.json` plus whatever's active in
`/proc/net/xt_ndpi/proto` and `host_proto`. Adds **Restrict to address
family**, **Transport protocol**, **Disable AAAA IPv6 DNS**, and — when
nDPI support is detected on the router — **Enable ndpi** to actually turn
on packet inspection for this rule (vs. matching only by the DNS-derived
hostname the other rule types use).

### Protocol categories

![Protocol categories — add rule](images/09-categories-modal.png)

Same nDPI-backed matching as above, but bypasses an entire **Category**
at once (e.g. *Chat*, *Streaming*, *Social*) instead of picking individual
protocols — the categories are pulled from the same proto JSON file, so
whatever the router lists as a category shows up here automatically.

## Bypass rules and port forwarding

A bypass rule decides where a connection *your side* opens goes out. It
never applies to the reply traffic of a connection someone opened *from
outside* through a port forward, even when that connection is on a
bypassed port:

* **A port forward relayed by your VPS** (a port forward with the VPN as
  its source zone, which is what OMR pushes to the server) arrives over
  the tunnel, so its answers go back over the tunnel. That stays true with
  a bypass rule on the same port — otherwise the answer would leave a WAN
  still carrying the tunnel's address and the remote end would never see
  it. Note WireGuard makes this easy to run into: it sends from its own
  `ListenPort`, so with both ends on the same port a *destination* port
  rule matches the answers too.
* **A port forward reached directly on a WAN address** (a port forward
  whose source zone is `wan`, for a WAN that is reachable from outside)
  answers through the WAN it came in on, whichever interface the default
  route or a bypass rule would otherwise pick.

So if what you want is a service behind the router reachable *without*
going through the VPS at all — a WireGuard endpoint, say — add the port
forward with **wan** as its source zone and have the remote peer connect
to that WAN's own public address. A bypass rule for the same port only
covers the connections your side starts.

## DPI Flows

```
https://<router-ip>/cgi-bin/luci/admin/services/omr-bypass/flows
```

![DPI Flows — nDPId not running](images/10-dpi-flows.png)

A live (5s-refresh) table of nDPI-identified flows: application, carrier,
category, L4 protocol, source/destination, packet count, and state — lets
you confirm DPI is actually classifying the traffic you expect before
relying on it in a **Protocols and services** or **Protocol categories**
rule.

This page belongs to `luci-app-ndpid`, not this package — but
`luci-app-omr-bypass`'s own menu wires it in as a second tab since the two
are meant to be used together. It needs `ndpid`/`ndpisrvd` actually
running to show anything; on this bench both show **stopped** and the
table is empty, because nothing currently triggers them. In practice OMR
starts them automatically as soon as at least one enabled **Protocols and
services** or **Protocol categories** rule exists — there's no separate
manual start step, just add a DPI-based bypass rule and this page should
populate.
