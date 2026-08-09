# LongyunVPN — project status & roadmap

One living checklist for what's done, what to finish for v1.1.6, and what to
improve next. Tick items as you go.

## ✅ Verified done
- **Rebrand** FlClash → LongyunVPN and Mihomo → **Longyun Core** (core binary
  `LongyunCore`, native lib `liblongyuncore`, Windows service
  `LongyunVPNHelperService`, Android namespace `com.longyunvpn.app`).
- **Core migrated** to `Sakawat-hossain/Longyun-Core` — and it **compiles**
  (built the desktop core with Go, all deps resolved).
- **Core security backports (2026-08-10)** — pointer bumped `bfb281c8 → b937c8ba`
  (fast-forward on `Longyun-Core/main`). Cherry-picked 6 upstream memory-safety
  fixes from chen08209 v0.8.94 onto our base **without** a dep/API bump: socks4
  unbounded alloc (DoS), vision TLS OOB read, trojan panic on oversized UDP
  length, quic-sniffer single-packet OOB crash, exchangeQUIC context, dns
  variable capture. Branding intact; core + full Windows app rebuilt clean.
  *Deliberately NOT taken* (stability): full v0.8.94 bump (removes
  `updater.Update*WithPath` our wrapper calls → build break), v0.8.95 (divergent
  protocol rewrites), doq OOB fix (complex read-path conflict), dispatcher-nil
  fix (needs dep bump).
- **All 7 deps on your forks**, pinned to exact commits, reachable
  (core, tray_manager, flutter_distributor + window_manager, re-editor,
  flutter_js, yaml_writer). No `chen08209` refs left in code.
- **History clean of Claude** across all branches + tags + files.
- **v1.1.6 tagged + pushed** (`main` = `origin/main` = tag `ff249f5`).
- **Security/features shipped in the branch:** Windows helper auth, Linux
  `pkexec`, update SHA256 verification, leak test, kill switch, split tunnel.
- **CI + release both run `build_runner`** so codegen isn't a build blocker.

## 🔴 Release-critical — to finish v1.1.6
- [ ] **Android signing** — generate `longyunvpn-upload.jks` (you) + set the 4
      GitHub secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`,
      `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`). See `docs/ANDROID_SIGNING.md`.
- [ ] **Re-run the release** after secrets exist (re-run the Android job, or
      re-push the tag) so the signed APKs build.
- [ ] **Watch the v1.1.6 release run** — confirm Windows / macOS / Linux / Android
      all build **and publish**. Paste any red job log and fix on a branch, then re-tag.
- [ ] **Commit regenerated codegen** — run `dart run build_runner build
      --delete-conflicting-outputs` locally and commit the `*.freezed.dart` /
      `*.g.dart` (pipelines regenerate them, but a raw `git clone` won't build without this).
- [ ] **macOS/Windows code signing** (the original "unidentified developer" /
      SmartScreen issue) — needs a paid Apple Developer ID + notarization and an
      Authenticode cert. Until then the install warning stands (README documents the workaround).

## 🟠 Validate on your machine (needs flutter/dart/cargo/java — not available in the agent env)
- [x] **Debug run Windows** — `flutter build windows --debug` + `flutter run -d windows`
      both succeed; app launches, first frame renders, Dart VM service up, no
      crash and no runtime exceptions in the console. (2026-08-10)
- [ ] **Debug run Android** per `docs/VALIDATION.md`.
- [ ] **Upgrade test** — install v1.1.6 over an existing v1.1.5: login/profiles
      preserved, old `FlClashHelperService` removed on Windows.
- [x] Confirm the migrated core loads at runtime — **desktop `LongyunCore` starts
      and stays resident** (verified on Windows: `LongyunCore.exe` alongside
      `LongyunVPN.exe`). Android `liblongyuncore.so` still to verify. (2026-08-10)

## 🟡 Security & audit backlog
- [ ] **`badCertificateCallback => true`** in `LongyunHttpOverrides` — accepts all
      TLS certs for proxied app requests; tighten.
- [ ] **macOS/Linux helper redesign** — replace setuid-root core with a
      launchd/systemd daemon (`docs/HELPER_REDESIGN.md`).
- [ ] **`QUERY_ALL_PACKAGES`** — Play-policy-sensitive; justify or switch to the
      user-selected-apps API.
- [x] Anti-censorship backup domains — **skipped** (no backup domain).

## 🟢 Branding loose ends (optional, low priority)
- [ ] Replace `core/Clash.Meta/Meta.png` (Mihomo logo) with the Longyun logo.
- [ ] Linux `APPLICATION_ID` (`com.follow.clash`) — rename after a Linux build
      confirms the data-dir keying (risk: could reset Linux users' data).
- [ ] Dart package name `fl_clash` — invisible internal id; large rename; leave unless wanted.
- [ ] Notification-channel id `"FlClash"` — leave (renaming resets users' notification prefs).

## ⚪ Maintenance / hygiene
- [ ] **Keep the 7 forks in sync** — set up Dependabot or periodic upstream pulls
      (do it after v1.1.6 ships; bump one dep at a time, build-test each).
- [ ] Add a short README to each fork ("Longyun fork of X, pinned for LongyunVPN").
- [ ] Enable branch protection on `main` + Dependabot alerts on all repos.
- [ ] Keep `docs/` (VALIDATION, ANDROID_SIGNING, migration guides) current.

## Compatibility invariants (never break these)
- Don't rename persisted keys (`config`, `clash_config`, secure-storage
  `xboardToken`) or `applicationId com.longyunvpn.app` — existing users would lose
  login/data.
- Keep the Go module path `github.com/metacubex/mihomo` + `metacubex/*` deps
  (functional, not branding) and protocol client ids.
- Keep third-party licenses/copyright (mihomo GPL, leanflutter, etc.) intact.
