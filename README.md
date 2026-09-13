# LongyunVPN

A fast, secure, multi-platform VPN client built on the Clash.Meta (mihomo) core.
LongyunVPN connects to the Longyun subscription service and gives you a clean,
localized interface for managing servers, subscriptions, and traffic.

[![Latest release](https://img.shields.io/github/v/release/Sakawat-hossain/LongyunVPN?style=flat-square&color=1f6feb&label=latest)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Sakawat-hossain/LongyunVPN/total?style=flat-square&color=2ea043)](https://github.com/Sakawat-hossain/LongyunVPN/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-777?style=flat-square)](#download)

Author: **Sakawat Hossain** · Licensed under **GNU GPL-3.0** (see [LICENSE](LICENSE)).

## Features

- High-performance proxying powered by the embedded mihomo core
- One-tap subscription purchase and renewal (plans, coupons, traffic reset)
- Account dashboard: plan, expiry, devices, balance, and usage
- Servers page gated on an active subscription, with a Node Status health monitor
- Per-node diagnostics (DNS / TCP / TLS / HTTP) with plain-language fixes
- Fast TCP ping and URL latency testing
- Full localization (English, 简体中文, 日本語, Русский)
- In-app update checks against GitHub Releases

## Download

> Every button below opens the **[latest release](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest)**.
> Download the file named in the **File** column for your device.
> Not sure which one? Each table says exactly who it is for.

### 🤖 Android

<sub>Requires **Android 7.0 (Nougat)** or newer.</sub>

| Download | File | Choose this if |
| :--- | :--- | :--- |
| [![APK arm64-v8a](https://img.shields.io/badge/APK-arm64--v8a-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `LongyunVPN-arm64-v8a.apk` | **Almost everyone — start here.** Every 64-bit ARM phone and tablet: Snapdragon, MediaTek Dimensity/Helio, Samsung Exynos, Google Tensor. That is essentially every device sold since 2015. |
| [![APK armeabi-v7a](https://img.shields.io/badge/APK-armeabi--v7a-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `LongyunVPN-armeabi-v7a.apk` | Older **32-bit ARM** devices only — budget and legacy handsets that refuse the arm64 build. If arm64 installs, use arm64: it is faster. |
| [![APK x86_64](https://img.shields.io/badge/APK-x86__64-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `LongyunVPN-x86_64.apk` | Android running on **Intel/AMD**: emulators (Android Studio, BlueStacks, Waydroid), Chromebooks running Android apps, and x86 tablets. |

<sub>💡 The in-app updater detects your device's ABI and offers the matching APK automatically — it will never hand you the wrong one.</sub>

### 🪟 Windows

<sub>Requires **Windows 10 or 11** (x64), or **Windows 11 on ARM** (ARM64).</sub>

| Download | File | Choose this if |
| :--- | :--- | :--- |
| [![Setup x64](https://img.shields.io/badge/Setup-x64-0078D4?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-windows-amd64-setup.exe` | **The normal choice.** Any desktop or laptop with an Intel or AMD processor. Installs properly, adds a Start-menu entry, and updates install themselves from inside the app. |
| [![Portable x64](https://img.shields.io/badge/Portable-x64-4C8EDA?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-windows-amd64.zip` | Same app, **no installer** — unzip and run. For USB sticks, or PCs where you cannot install software. You update it by downloading the new zip yourself. |
| [![Setup ARM64](https://img.shields.io/badge/Setup-ARM64-0078D4?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-windows-arm64-setup.exe` | **Windows on ARM** machines: Copilot+ PCs with Snapdragon X Elite/Plus, Surface Pro X and ARM Surface Pro 9/11, and Windows 11 ARM in a VM on an Apple Silicon Mac (Parallels, UTM). |
| [![Portable ARM64](https://img.shields.io/badge/Portable-ARM64-4C8EDA?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-windows-arm64.zip` | The ARM64 build without an installer. |

<sub>💡 An ARM64 PC <em>can</em> run the x64 build through emulation, but the native ARM64 build is faster and lighter on battery.</sub>

### 🍎 macOS

<sub>Requires **macOS 11 Big Sur** or newer.</sub>

| Download | File | Choose this if |
| :--- | :--- | :--- |
| [![DMG Apple Silicon](https://img.shields.io/badge/DMG-Apple%20Silicon-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-macos-arm64.dmg` | **Any Mac from late 2020 onward** — M1, M2, M3, M4, including every Pro / Max / Ultra variant. |
| [![DMG Intel x64](https://img.shields.io/badge/DMG-Intel%20x64-555555?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-macos-amd64.dmg` | **Intel Macs** — roughly 2006 through 2020, plus the 2020 Intel models sold alongside the first M1s. |

**Which Mac do I have?** Apple menu → **About This Mac**. If it says **Chip: Apple M1/M2/M3/M4**, take Apple Silicon. If it says **Processor: … Intel …**, take Intel x64.

<sub>⚠️ The macOS build is not signed with an Apple Developer ID — see <a href="#opening-on-macos">Opening on macOS</a> below before first launch. macOS updates open the releases page rather than installing in place.</sub>

### 🐧 Linux

<sub>**x86_64 (amd64) only.** There is no Linux ARM build yet — Flutter does not publish a Linux arm64 SDK that CI can install.</sub>

| Download | File | Choose this if |
| :--- | :--- | :--- |
| [![AppImage](https://img.shields.io/badge/AppImage-x64-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-linux-amd64.AppImage` | **Any distribution**, no install and no root: `chmod +x` it and run. It is also the **only Linux build that can update itself** from inside the app. |
| [![DEB](https://img.shields.io/badge/DEB-x64-A81D33?style=for-the-badge&logo=debian&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-linux-amd64.deb` | **Debian-family** distributions: Debian, Ubuntu, Linux Mint, Pop!\_OS, elementary OS, Zorin. |
| [![RPM](https://img.shields.io/badge/RPM-x64-EE0000?style=for-the-badge&logo=redhat&logoColor=white)](https://github.com/Sakawat-hossain/LongyunVPN/releases/latest) | `…-linux-amd64.rpm` | **RPM-family** distributions: Fedora, RHEL, CentOS, Rocky, AlmaLinux, openSUSE. |

<sub>💡 `.deb` and `.rpm` installs are owned by your package manager, so the app sends you to the releases page instead of replacing itself.</sub>

### Verifying your download

Every release ships a `SHA256SUMS` file covering all artifacts:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

### How updates reach you

| Platform | Update behaviour |
| :--- | :--- |
| Windows | Downloads and runs the matching installer for you |
| Android | Downloads and installs the APK matching your device's ABI |
| Linux (AppImage) | Replaces the running image in place |
| Linux (deb / rpm) | Opens the releases page — use your package manager |
| macOS | Opens the releases page — install the new DMG manually |

There is no app-store distribution; every platform checks GitHub Releases.

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

1. Bump the version in [`pubspec.yaml`](pubspec.yaml), e.g. `version: 1.4.9`
   (plain semantic — no build suffix).
2. Commit the change.
3. Create and push a matching tag:

   ```bash
   git tag v1.4.9
   git push origin v1.4.9
   ```

Pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml),
which builds all platforms (Windows, Android, macOS, Linux) in parallel and
publishes a single GitHub Release with every artifact attached. Use semantic
versioning: `v1.4.9` for fixes, `v1.5.0` for features.

## Building locally

Requirements: Flutter 3.44.9 (stable) and Go 1.26.5. For Windows also install the
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
