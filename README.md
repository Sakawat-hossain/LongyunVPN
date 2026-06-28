# LongyunVPN

A fast, secure, multi-platform VPN client built on the Clash.Meta (mihomo) core.
LongyunVPN connects to the Longyun subscription service and gives you a clean,
localized interface for managing servers, subscriptions, and traffic.

> LongyunVPN is a derivative of [FlClash](https://github.com/chen08209/FlClash)
> and the [mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo) core, and is
> distributed under the **GNU GPL-3.0** license (see [LICENSE](LICENSE)).

## Features

- High-performance proxying powered by the embedded mihomo core
- One-tap subscription purchase and renewal (plans, coupons, traffic reset)
- Account dashboard: plan, expiry, devices, balance, and usage
- Per-node diagnostics (DNS / TCP / TLS / HTTP) with plain-language fixes
- Fast TCP ping and URL latency testing
- Full localization (English, 简体中文, 日本語, Русский)
- In-app automatic updates from GitHub Releases

## Releasing a new version

The release pipeline is fully automated. To publish an update:

1. Bump the version in [`pubspec.yaml`](pubspec.yaml), e.g. `version: 1.0.1+2`.
2. Commit the change.
3. Create and push a matching tag:

   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

Pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml),
which builds the Windows installer and publishes a GitHub Release with the
`.exe` attached. Installed apps detect the new release and offer a one-click
update. Use semantic versioning: `v1.0.1` for fixes, `v1.1.0` for features.

## Building locally

Requirements: Flutter 3.41.9 (stable), Go 1.24.0, and the Windows build tools
(Visual Studio with the Desktop C++ workload, plus Inno Setup for the installer).

```bash
git clone --recurse-submodules https://github.com/Sakawat-hossain/LongyunVPN.git
cd LongyunVPN
flutter pub get
dart setup.dart windows --env stable -v
```

The installer is written to the `dist/` directory.

## License

This project is licensed under the GNU General Public License v3.0. Because it is
a derivative of GPL-3.0 software (FlClash and mihomo), it must remain GPL-3.0.
See [LICENSE](LICENSE) for the full text.
