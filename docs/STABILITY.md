# Connection stability & speed consistency

Why a tunnel can "work but keep going up and down", what the client already
does about it, and what has to be fixed on the server side.

## Where the problem usually is

The symptom users report — *some* servers are smooth, *others* pulse or stall —
is almost always **per-server**, not per-client. The same app, on the same
network, is stable on a good node. That points at the node's protocol options,
its capacity, or the path to it — not at a client bug.

Ranked by how often they cause it:

1. **Hysteria2 with wrong `up`/`down` bandwidth.** Hysteria2's Brutal congestion
   control *believes* the bandwidth you declare. If the subscription advertises
   more than the server or path can sustain, it oversends, hits loss, backs off,
   and climbs again — textbook "speed pulses up and down". Prefer to **omit**
   `up`/`down` (BBR self-tunes) or set them **below** the real line rate.
2. **UDP throttling.** Hysteria2/TUIC/MASQUE ride QUIC (UDP). Plenty of ISPs
   deprioritise or shape UDP, so those nodes jitter while a TCP node next to
   them is fine. Always offer a TCP fallback (VLESS+Reality, Trojan).
3. **Oversold or distant nodes.** Capacity and peering. No client setting fixes
   an overloaded server.

## What the client already does

These are set by the app for every profile (see `lib/common/task.dart`):

| Setting | Value | Why |
| --- | --- | --- |
| `tcp-concurrent` | `true` | Races A/AAAA + multiple IPs, avoids one dead IP stalling a connect |
| `unified-delay` | `true` | Comparable latency numbers, so failover picks sanely |
| `keep-alive-interval` | 30s | Keeps NAT mappings warm |
| `keep-alive-idle` | 900s | First probe after 15 min idle, so a NAT/CGNAT timeout doesn't silently kill an idle connection (desktop only — the core disables TCP keep-alive on Android for battery) |
| `tun.mtu` | 1400 | 1500 fragments once tunnel overhead is added; fragmentation shows up as stalls, not as a clean failure |
| DNS | fake-ip + DoH (AliDNS / DoH.pub) + `proxy-server-nameserver` | Avoids lookup stalls and DNS leaks/poisoning |
| Group health-check | `interval: 300`, `tolerance: 50` (url-test), `lazy: false` | Subscriptions often omit these, so a dead node keeps being used until something forces a re-test |

All of these only fill in a value the profile didn't set — an explicit setting
from the user or the subscription always wins.

Note the core already health-checks any group that isn't `select`/`relay`; the
defaults above just make sure the checks actually run often enough to fail over.
`select` groups are deliberately left untouched — a manual choice must not be
second-guessed.

## Recommended server-side defaults

These live in the Xboard backend / subscription, not in the app. This is where
speed consistency is actually won.

| Protocol | Recommended |
| --- | --- |
| VLESS | `flow: xtls-rprx-vision` over Reality/TLS, `client-fingerprint: chrome` |
| VMess | `cipher: auto`, `alterId: 0` — prefer VLESS for new nodes |
| Trojan | TLS + `client-fingerprint: chrome` |
| Reality | real `server-name` (SNI), `short-id` set, `chrome` fingerprint |
| Hysteria2 | **omit `up`/`down`**, or set below the real line rate; `obfs: salamander` for China |
| TUIC | v5, `congestion-controller: bbr`, `udp-relay-mode: native`, `reduce-rtt: true` |
| AnyTLS | default padding scheme, `chrome` fingerprint |
| WireGuard | `mtu: 1408` (lower for China), `persistent-keepalive: 25` |
| Shadowsocks | `2022-blake3-aes-128-gcm` over legacy ciphers |
| OpenVPN | GCM ciphers; TCP when reliability matters more than speed |

For censorship-heavy networks (China/Russia) the strongest options in the core
are **VLESS+Reality**, **ShadowTLS v3**, **Hysteria2 with salamander obfs**,
**AnyTLS**, and **Mieru**.

## Diagnosing a specific server

1. Compare it against a known-good node on the same network — if only one is
   bad, it is the node or its options.
2. Check whether it is QUIC/UDP-based; try a TCP node to test for UDP shaping.
3. For Hysteria2, look at the declared `up`/`down` first.
4. Use the in-app **Node Status** page for ping/reachability, and the leak test
   to confirm traffic is actually going through the tunnel.
