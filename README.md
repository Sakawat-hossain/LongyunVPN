# LongyunVPN

A fast, secure, multi-platform VPN client built on the Clash.Meta (mihomo) core.
LongyunVPN connects to the Longyun subscription service and gives you a clean,
localized interface for managing servers, subscriptions, and traffic.

Author: **Sakawat Hossain** · Licensed under **GNU GPL-3.0** (see [LICENSE](LICENSE)).

## Features

- High-performance proxying powered by the embedded mihomo core
- One-tap subscription purchase and renewal (plans, coupons, traffic reset)
- Account dashboard: plan, expiry, devices, balance, and usage
- Servers page gated on an active subscription, with a Node Status health monitor
- Per-node diagnostics (DNS / TCP / TLS / HTTP) with plain-language fixes
- Fast TCP ping and URL latency testing
- Full localization (English, 简体中文, 日本語, Русский)
- In-app automatic updates from GitHub Releases

## Platforms

- **Windows** — `amd64` / `arm64` installer (`.exe`) and portable `.zip`, with in-app auto-update.
- **Android** — per-ABI APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and a Play `.aab`; application id `com.longyunvpn.app`.
- **macOS** — `arm64` / `amd64` `.dmg`.
- **Linux** — `amd64` `.deb`, `.AppImage`, and `.rpm` (plus `arm64` `.deb`).

Mobile builds update through the app store; desktop builds check GitHub Releases in-app. (iOS is not currently supported.)

## Opening on macOS

The macOS `.dmg` is not signed with an Apple Developer ID or notarized (that
requires a paid Apple Developer account), so on first launch macOS shows
**"LongyunVPN cannot be opened because it is from an unidentified developer."**
This is expected — the app is safe; macOS just can't verify an unsigned build.
To open it:

1. Drag **LongyunVPN** from the DMG into your **Applications** folder.
2. Remove the download quarantine flag, then open the app. In **Terminal**:

   ```bash
   xattr -dr com.apple.quarantine /Applications/LongyunVPN.app
   open /Applications/LongyunVPN.app
   ```

Alternatively, without Terminal: try to open the app once, then go to
**Apple menu → System Settings → Privacy & Security**, scroll down, and click
**"Open Anyway"** next to the LongyunVPN message. You only need to do this once.

## Releasing a new version

The release pipeline is fully automated. To publish an update:

1. Bump the version in [`pubspec.yaml`](pubspec.yaml), e.g. `version: 1.0.2`
   (plain semantic — no build suffix).
2. Commit the change.
3. Create and push a matching tag:

   ```bash
   git tag v1.0.2
   git push origin v1.0.2
   ```

Pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml),
which builds all platforms (Windows, Android, macOS, Linux) in parallel and
publishes a single GitHub Release with every artifact attached. Use semantic
versioning: `v1.0.2` for fixes, `v1.1.0` for features.

## Building locally

Requirements: Flutter 3.41.9 (stable) and Go 1.24+. For Windows also install the
Desktop C++ workload (Visual Studio) and Inno Setup; for Android install the
Android SDK and NDK r28c; for macOS `npm i -g appdmg`; for Linux the apt build
deps (`setup.dart` installs them automatically).

```bash
git clone --recurse-submodules https://github.com/Sakawat-hossain/LongyunVPN.git
cd LongyunVPN
flutter pub get
dart setup.dart windows --env stable -v                # Windows installer + zip
dart setup.dart android --arch arm64 --env stable -v   # Android APK
dart setup.dart macos --env stable -v                  # macOS .dmg
dart setup.dart linux --env stable -v                  # Linux .deb/.AppImage/.rpm
```

Build artifacts are written to the `dist/` directory.

## License & credits

This project is licensed under the GNU General Public License v3.0 and must
remain GPL-3.0. It is built on the open-source [mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo)
core. See [LICENSE](LICENSE) for the full text.
