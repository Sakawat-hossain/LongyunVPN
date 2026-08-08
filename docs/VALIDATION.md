# v1.1.6 validation checklist

Run this end-to-end on a machine with the toolchain (Flutter 3.41.9, Go 1.26+,
Rust, Android SDK/NDK). Nothing here was build-tested in the environment the
changes were authored in, so treat the first green build as the real sign-off.
Check every box before merging `rebrand/v1.1.6` → `main` and tagging `v1.1.6`.

## 0. Prerequisites

```bash
cd LongyunVPN
git checkout rebrand/v1.1.6
git submodule update --init --recursive        # pulls Longyun-Core, tray_manager, flutter_distributor forks
flutter pub get                                 # resolves the 4 forked git deps
dart run build_runner build --delete-conflicting-outputs   # regenerates freezed/riverpod/drift/json
flutter analyze                                 # must be clean
flutter test                                    # root tests
flutter test plugins/proxy/test/proxy_test.dart
```
- [ ] `flutter pub get` resolves `window_manager` / `re_editor` / `flutter_js` /
      `yaml_writer` from **github.com/Sakawat-hossain/…** (check `pubspec.lock`).
- [ ] `build_runner` succeeds (it regenerates the code for the new
      `Tun.strictRoute` and `SplitTunnelProps` model fields — commit the
      regenerated `*.freezed.dart` / `*.g.dart`).
- [ ] `flutter analyze` clean, `flutter test` green.

## 1. Dependency / fork resolution
- [ ] `git submodule status` shows: `core/Clash.Meta` @ `bfb281c8` (Longyun-Core),
      `plugins/tray_manager` @ `6163dc8`, `plugins/flutter_distributor` @ `cdeeef2d`
      — all from `Sakawat-hossain/*`.
- [ ] `grep -rn chen08209 .gitmodules pubspec.yaml pubspec.lock` → **no matches**.

## 2. Longyun Core builds
- [ ] **Windows:** `dart setup.dart windows --env stable -v` → produces
      `LongyunCore.exe` + `LongyunVPNHelperService.exe` in `dist/`.
- [ ] **Android:** `dart setup.dart android --arch arm64 --env stable -v` → the
      APK contains `liblongyuncore.so` (unzip → `lib/arm64-v8a/`).
- [ ] **macOS:** `dart setup.dart macos --env stable -v` → `LongyunCore` in the bundle.
- [ ] **Linux:** `dart setup.dart linux --env stable -v` → `LongyunCore` in the bundle.
- [ ] Core reports itself as **"Longyun Core"** (constant `MihomoName`).

## 3. Runtime smoke test (each platform you ship)
- [ ] App launches; log in to the account (token still in keychain — see §5).
- [ ] Connect; switch nodes; Quick Connect works.
- [ ] Subscription/servers page loads; buy/renew flow reaches the payment step.
- [ ] Traffic + delay tests update.

## 4. New features
- [ ] **Kill switch** (desktop, Tools → Settings): toggling it sets TUN
      `strict-route`; with it on, traffic can't leak outside the tunnel.
- [ ] **Split tunnel** (desktop, Tools): exclude/include a process; confirm that
      process is routed accordingly (`find-process-mode` active).
- [ ] **Leak test** (Tools): shows exit IP vs real IP and IPv6 exposure; verdict
      is "Protected" when connected.
- [ ] **Windows helper security:** with the app running, a request to
      `http://127.0.0.1:47890/stop` **without** the `Authorization` token is
      rejected (401); the app's own start/stop still works.

## 5. Upgrade-path compatibility (install v1.1.6 OVER an existing v1.1.5)
- [ ] Existing user stays **logged in** (secure-storage `xboardToken` preserved —
      `applicationId`/bundle-id/keychain unchanged).
- [ ] Profiles, settings, and rules survive the upgrade.
- [ ] **Windows:** old `FlClashHelperService` is removed and
      `LongyunVPNHelperService` registered → `sc query FlClashHelperService`
      returns "does not exist"; `sc query LongyunVPNHelperService` is running.
- [ ] Deep-link import (`clash://…`) still works.

## 6. Signing / release (before tagging)
- [ ] Android keystore secrets set (see `docs/ANDROID_SIGNING.md`); release APK is
      release-signed (not the debug `.dev` id).
- [ ] (If available) macOS Developer ID + notarization, Windows Authenticode.
- [ ] Push tag `v1.1.6` → `release.yml` builds all platforms green.

## 7. Sign-off
- [ ] All of the above pass → merge `rebrand/v1.1.6` → `main`, tag `v1.1.6`.

---
If anything fails, capture the exact output and we fix it on `rebrand/v1.1.6`
before merging — do **not** tag from a red build.
