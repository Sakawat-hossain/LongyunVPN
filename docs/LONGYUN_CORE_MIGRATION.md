# Migration plan: FlClash + Mihomo → LongyunVPN + Longyun Core

Goal: remove all remaining FlClash branding and ship our own branded core,
**Longyun Core**, built from our Mihomo fork — without breaking existing
installs, features, or any platform.

This plan is phased so each step is independently buildable and testable. The
**user-facing** brand is already LongyunVPN (app name, label, launcher/tray icons,
`applicationId com.longyunvpn.app`); what remains is internal identifiers and the
core binary.

---

## Compatibility invariants (apply to every phase)

These must hold so upgrades don't log users out, drop their config, or break IPC:

1. **Never rename persisted storage keys.** Keep the `shared_preferences` keys
   (`config`, `clash_config`, `version`, …) and the secure-storage key
   `xboardToken` exactly as-is. Renaming them = users logged out / settings lost.
2. **Keep `applicationId = com.longyunvpn.app`** (already correct). The Kotlin
   *namespace* (`com.follow.clash`) is a separate internal thing (Phase 3).
3. **Keep deep-link schemes** `clash://`, `clashmeta://`, `flclash://` for profile
   import compatibility; *add* `longyunvpn://` rather than removing any.
4. **Windows service rename** (Phase 2) must uninstall the old
   `FlClashHelperService` on upgrade, or a dead service lingers.
5. **Installer process-kill lists** must include **both** the old and new binary
   names during the transition release, so an upgrade can replace a running old
   core/helper.
6. **Renaming a binary does not change its SHA256**, so the Windows helper token
   auth (core-hash based) keeps working across the rename.
7. **Do not touch the Go module name** (`core`) or the
   `replace github.com/metacubex/mihomo => ./Clash.Meta` directive.

Run after every phase: `dart run build_runner build --delete-conflicting-outputs`
(if models changed), then the affected platform build, then a smoke test.

---

## Phase 0 — Decisions & prerequisites

- **Names chosen:** desktop core binary `LongyunCore` (was `FlClashCore`); Windows
  helper service `LongyunVPNHelperService` (was `FlClashHelperService`); Kotlin
  package `com.longyunvpn.app` (was `com.follow.clash`).
- **Core fork:** the core is a Git submodule `core/Clash.Meta` →
  `github.com/chen08209/Clash.Meta` (branch `FlClash`). To truly own "Longyun
  Core", fork it (and ideally `plugins/flutter_distributor`, `plugins/tray_manager`)
  under the Longyun org and repoint `.gitmodules` (Phase 6). The Go **wrapper** in
  `core/*.go` is already generically named (module `core`) — no FlClash branding in
  it, so only the built binary name needs changing (Phase 1).

## Phase 1 — Core binary rebrand → `LongyunCore`  ← STARTING NOW

Coordinated rename across all 11 reference sites (desktop binary only; the Android
`.so` is `libclash`, handled separately in Phase 4). Every site must match or the
build won't find/produce the binary:

| File | Reference |
| --- | --- |
| `lib/common/path.dart` | desktop core path |
| `plugins/setup/buildkit/build_tool/lib/src/options.dart` | `coreName` default |
| `plugins/setup/buildkit/build_tool/build_config.yaml` | `core_name` |
| `plugins/setup/buildkit/cmake/buildkit.cmake` | Win + Linux `_output` |
| `plugins/setup/linux/CMakeLists.txt` | install(PROGRAMS …) |
| `plugins/setup/windows/CMakeLists.txt` | bundled_libraries |
| `plugins/setup/macos/setup.podspec` | `output_files` + metadata |
| `macos/Runner.xcodeproj/project.pbxproj` | Copy-Core file ref/phase |
| `windows/packaging/exe/inno_setup.iss` | process-kill list |
| `services/helper/src/service/hub.rs` | comment only |

**Compatibility:** installer kills both `FlClashCore.exe` and `LongyunCore.exe`
during the transition; installer should also delete a leftover `FlClashCore.exe`.
**Validate:** desktop build on each of Windows/macOS/Linux; confirm the core starts
and `path.dart` finds `LongyunCore`.

## Phase 2 — Windows helper service rebrand → `LongyunVPNHelperService`  ✅ DONE (source; build to validate)

Renamed in `constant.dart` (`appHelperService`), `services/helper/src/service/windows.rs`
(`SERVICE_NAME`), build_tool `helperName` (default + `build_config.yaml`), the Windows
CMake bundle, and the Inno installer. **Upgrade compatibility:** a new
`legacyHelperService` constant holds the old name, and `Windows.registerService`
now *always* runs `taskkill` + `sc stop` + `sc delete` on it before creating the new
service, so upgrades don't strand a dead `FlClashHelperService`. The Inno kill-list
carries both old and new helper names during the transition. Original notes below.

Sites: `lib/common/constant.dart` (`appHelperService`), `services/helper/src/service/windows.rs`
(`SERVICE_NAME`), `build_tool` `helperName` (default + `build_config.yaml`),
`plugins/setup/windows/CMakeLists.txt`, `windows/packaging/exe/inno_setup.iss`.
**Compatibility:** on install/upgrade, `sc stop FlClashHelperService && sc delete
FlClashHelperService` before registering the new one (add to the Inno `[Run]`/
`PrepareToInstall`, or the app's service-register path). The exe filename derives
from `appHelperService`, so it stays consistent automatically.
**Validate:** Windows TUN start/stop through the helper; confirm old service gone.

## Phase 3 — Kotlin package `com.follow.clash` → `com.longyunvpn.app`  ✅ DONE (source; Android build to validate)

Executed: moved all 37 `.kt`/`.java` files **and the AIDL tree**
(`android/service/src/main/aidl/…`) from `com/follow/clash` to `com/longyunvpn/app`
across all 4 modules; replaced every `package`/`import`; updated the 4 Gradle
namespaces, `proguard-rules.pro` keep-rules (they referenced the moved model
classes), the `setup` plugin namespace (`plugins/setup/android/` — build harness,
no Kotlin), and the Dart `packageName` (kept equal to Kotlin `Components.PACKAGE_NAME`).
The manifest needed no change (relative `.MainActivity` names follow the namespace;
`${applicationId}` is unchanged). `applicationId` stays `com.longyunvpn.app`, so
**existing users' package id is unchanged** — no reinstall, no data loss.
**Validate:** Android build + launch, per-app proxy list, VPN start/stop, tile.

### Phase 3b — Desktop app identifiers

- **macOS — ✅ DONE.** The *release* bundle id was **already** `com.longyunvpn.app`
  (set in `macos/Runner/Configs/AppInfo.xcconfig`), so there was **no keychain risk**
  to release users. Renamed the debug override (`com.follow.clash.debug` →
  `com.longyunvpn.app.debug`) and the test target (`com.follow.flClash.RunnerTests` →
  `com.longyunvpn.app.RunnerTests`) — debug/test only, not distributed.
- **Linux `APPLICATION_ID` — DEFERRED (verify first).** `linux/CMakeLists.txt` still
  `com.follow.clash`. The Linux binary is `BINARY_NAME = LongyunVPN`, and
  `path_provider` *should* key `~/.local/share/<data>` to the binary name (safe to
  rename the app id) — but `my_application.cc` also calls `g_set_prgname(APPLICATION_ID)`,
  and if path_provider resolves via `g_get_prgname()` instead, renaming would move
  the data dir and **log out / reset existing Linux users**. ⚠️ Confirm on a Linux
  build (check which dir under `~/.local/share` holds the config) **before** renaming.

Original Phase 3 notes below.

~200 references across **4 modules** (`android/{app,common,core,service}`). Move
files, update every `package`/`import`, the 4 Gradle `namespace`s, and keep the
MethodChannel namespace matched on both sides: Kotlin `Components.PACKAGE_NAME`
(`android/common/.../Components.kt`) ↔ Dart `packageName` (`lib/common/constant.dart`).
`Components.PACKAGE_NAME` is also the `ComponentName` class prefix for the tile
intents, so it must equal the new namespace. Details already written in
[`BRANDING_MIGRATION.md`](BRANDING_MIGRATION.md).
**Validate:** Android launch, per-app proxy list, VPN start/stop, quick-settings tile.

## Phase 4 — Android native lib `libclash` → `liblongyuncore`  ✅ DONE (source; Android build to validate)

Renamed `libName` (build_tool default + `build_config.yaml`), the CMake `.so`/`.h`
paths + `target_link_libraries(core longyuncore)`, and the C++ `#include`
(`android/core/src/main/cpp/`). The loader (`System.loadLibrary("core")` → `libcore.so`)
is unaffected; `libcore` now links `liblongyuncore.so` transitively (both ship in
jniLibs). Kept the internal `LIBCLASH` compile flag and the `outputDir: 'libclash'`
build **staging** directory (not shipped; renaming it churns ~6 build-path refs for
no user value). Also swept internal identifiers: isolate names
(`Longyun{Main,Service}Isolate`), the single-instance lock (`LongyunVPN.lock`), the
Android log tag, and build-harness descriptions. **Validate:** Android build loads
`liblongyuncore.so` via FFI (connect + switch node).

Original notes below.

Sites: `build_tool` `libName`/`outputDir`, `android/core/src/main/cpp/CMakeLists.txt`
(`LIB_CLASH_PATH`, header, `LIBCLASH` define), `android/core/src/main/cpp/core.cpp`
(`#ifdef LIBCLASH`, `#include "libclash.h"`). The Go c-shared build emits
`lib<name>.so` + `lib<name>.h`, so the name flows from `libName`. Lower priority —
the `.so` is invisible to users.
**Validate:** Android build loads the renamed `.so` via FFI.

## Phase 5 — Core internal identity (optional, compat-sensitive)

`coreName = 'clash.meta'` (`lib/common/constant.dart`) is the internal mihomo
identity (currently unused in Dart). If the Longyun Core fork changes its reported
name/UA, mirror it here. Leave unless the fork actually rebrands its identity —
changing it can affect config/UA expectations.

## Phase 6 — Submodule re-fork under the Longyun org

Fork `chen08209/Clash.Meta` (and optionally the `flutter_distributor` /
`tray_manager` forks) into the Longyun org, then repoint `.gitmodules` and
`git submodule sync`. This is what makes it genuinely "our" Longyun Core rather
than a rename of someone else's fork. Keep the `replace` directive pointing at the
submodule path.

## Phase 7 — Residual sweep & verification  ✅ SWEEP DONE

A full `grep -rniE 'flclash|follow\.clash'` now returns **only intentional keeps**:
- **Deep-link schemes** `flclash` (Android manifest, `window.dart`, macOS Info.plist) —
  kept for profile-import compatibility.
- **Upgrade-compat** — `legacyHelperService` constant + the Inno transition kill-list.
- **Notification channel id** `"FlClash"` (`GlobalState.kt`) — kept so users' channel
  settings survive; its display name is already "LongyunVPN".
- **`@string/FlClash`** resource key (value is already "LongyunVPN").
- **Desktop app ids** (`linux/CMakeLists.txt`, macOS bundle ids) — Phase 3b.
- **`.gitmodules` `branch = FlClash`** — Phase 6 (submodule fork).
- **`wifi_ssid/LICENSE`** copyright — third-party attribution, must not change.

Still TODO before calling the rebrand complete: **per-platform build + smoke test**
(connect, switch node, profile import, kill switch, leak test, auto-update) on
Windows/macOS/Linux/Android.

`grep -rniE 'flclash|follow\.clash' --include=… .` should return only intentional
compat items (deep-link schemes, transition process-kill entries). Full per-platform
build + smoke test (connect, switch node, profile import, kill switch, leak test,
auto-update).

---

## Rollback

Each phase is a self-contained commit. If a phase's build fails, revert that commit;
earlier phases are independent. Phase 1 is pure renames (no logic change), so its
risk is "build can't find the binary", caught immediately by the platform build.
