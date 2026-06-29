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

- **Windows** — installer (`LongyunVPN-Setup.exe`) with in-app auto-update.
- **Android** — APK (`LongyunVPN.apk`, application id `com.longyunvpn.app`).

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
which builds the Windows installer and the Android APK and publishes a GitHub
Release with both attached. Use semantic versioning: `v1.0.2` for fixes,
`v1.1.0` for features.

## Building locally

Requirements: Flutter 3.41.9 (stable) and Go 1.24+. For Windows also install the
Desktop C++ workload (Visual Studio) and Inno Setup; for Android install the
Android SDK and NDK r28c.

```bash
git clone --recurse-submodules https://github.com/Sakawat-hossain/LongyunVPN.git
cd LongyunVPN
flutter pub get
dart setup.dart windows --env stable -v          # Windows installer
dart setup.dart android --arch arm64 --env stable -v   # Android APK
```

Build artifacts are written to the `dist/` directory.

## License & credits

This project is licensed under the GNU General Public License v3.0 and must
remain GPL-3.0. It is built on the open-source [mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo)
core. See [LICENSE](LICENSE) for the full text.
