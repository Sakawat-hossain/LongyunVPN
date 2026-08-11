# Xboard / Xboard-Node compatibility

How LongyunVPN fits together with [Xboard](https://github.com/cedar2025/Xboard)
(the panel) and [Xboard-Node](https://github.com/cedar2025/Xboard-Node) (the
server-side agent), and the one setting that has to be right.

## Who talks to whom

```
LongyunVPN app ──REST──▶ Xboard panel        (/api/v1: login, plans, orders, getSubscribe)
LongyunVPN app ──HTTP──▶ Xboard panel        (subscription download → mihomo YAML)
LongyunVPN core ─proxy──▶ node               (VLESS / Hysteria2 / TUIC / ... )
Xboard-Node    ──WS/REST▶ Xboard panel       (user sync, traffic reporting)
```

The app never speaks to Xboard-Node directly. Xboard-Node runs *on the servers*
(sing-box / xray-core dual kernel) and only syncs with the panel. So client
compatibility with Xboard-Node is purely **protocol** compatibility.

## Protocol coverage

Xboard-Node serves: V2Ray family (VMess/VLESS), Trojan, Shadowsocks,
Hysteria2, TUIC, AnyTLS.

Longyun Core (mihomo / Clash.Meta v0.8.94) supports **all** of them, plus
Reality, ShadowTLS, ECH, WireGuard, OpenVPN, Mieru, SSH, snell and more. There
is no protocol served by Xboard-Node that this client cannot use.

## The setting that matters: subscription format

Xboard decides which subscription *format* to generate from the client's
User-Agent (or an explicit `?flag=`). Two handlers matter:

| Handler | Flags | Emits |
| --- | --- | --- |
| `Clash.php` | `clash` | shadowsocks, vmess, trojan, socks5, http |
| `ClashMeta.php` | `meta`, `verge`, `flclash`, `nekobox`, `clashmetaforandroid` | the above **plus vless, hysteria, hysteria2, tuic, anytls, mieru** |

Xboard matches these flags **longest-first, first match wins**.

This is a real trap. The app used to send `clash-verge`, which contains **both**
`clash` (5 chars) and `verge` (5 chars). Equal length means the winner depended
on iteration order — and if `clash` won, the panel silently dropped every
VLESS/Reality, Hysteria2, TUIC and AnyTLS node from the subscription. The user
sees fewer nodes, or only old protocols, with no error anywhere.

**Fix:** the client now sends `flclash` (see `lib/common/package.dart`). At 7
characters it is matched before the 5-character `clash`, so the Meta format is
guaranteed. The UA override list in Settings was updated for the same reason —
`flclash/...` and `clash.meta/...` are safe, `ClashforWindows/...` is kept only
for panels that gate on it and *will* lose the modern protocols.

If you ever need to force it explicitly, Xboard honours a query parameter that
overrides the UA entirely:

```
https://panel.example.com/api/v1/client/subscribe?token=XXXX&flag=meta
```

## Checklist when adding a node in the panel

- Node protocol is one the client supports (all Xboard-Node protocols are).
- For Hysteria2, leave `up`/`down` unset or below the real line rate — see
  [STABILITY.md](STABILITY.md); wrong values are the main cause of pulsing speed.
- Offer at least one TCP-based node (VLESS+Reality / Trojan) per region, for
  networks that shape or throttle UDP.
- Verify the generated subscription actually contains the new node types: fetch
  the subscribe URL with `curl -H 'User-Agent: flclash/v1.0.0'` and confirm the
  `hysteria2:` / `vless:` / `tuic:` / `anytls:` entries are present.
