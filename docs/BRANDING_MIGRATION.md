# FlClash → LongyunVPN internal branding migration

The **user-facing** branding is already LongyunVPN (app name, label, launcher/tray
icons, `applicationId = com.longyunvpn.app`). What remains are **internal code
identifiers** that no user ever sees. This document tracks them.

## Already done (safe, Dart-only — shipped)

These have no native coupling and were renamed directly:

- IPC socket / pipe names — `constant.dart`: `LongyunSocket_*` (was `FlClashSocket_*`),
  `LongyunCore_*` pipe (was `FlClashCore_*`). Random-suffixed, passed as the
  transport address, not matched anywhere else.
- `LongyunHttpOverrides` class (was `FlClashHttpOverrides`) — `common/http.dart`
  plus its two references in `request.dart` and `main.dart`.

## Not done — build-coupled, do these ONLY on a machine that can build & run

There are ~200 references to `com.follow.clash` across **four Android modules**
(`app`, `common`, `core`, `service`) and a few cross-language couplings. These
**must be changed together and validated with a real build** — a single missed
import fails the Android build, and a mismatched channel/service name silently
breaks IPC at runtime. Do not attempt these blind.

### A. Kotlin package `com.follow.clash` → e.g. `com.longyunvpn.app`

This one string is simultaneously the Kotlin package, the Gradle namespace, the
MethodChannel namespace, and the ComponentName class prefix. All must move in lockstep:

1. Move every `.kt` file from `.../com/follow/clash/**` to the new package path in
   all four modules under `android/`.
2. Update every `package com.follow.clash…` declaration and matching `import`.
3. Update the four Gradle namespaces:
   - `android/app/build.gradle.kts:26` → `com.longyunvpn.app`
   - `android/common/build.gradle.kts:9` → `com.longyunvpn.app.common`
   - `android/core/build.gradle.kts:9` → `com.longyunvpn.app.core`
   - `android/service/build.gradle.kts:10` → `com.longyunvpn.app.service`
4. `AndroidManifest.xml` component names use relative `.MainActivity` form, so they
   follow the namespace automatically — but verify after the move.
5. **MethodChannel namespace (must match on both sides):**
   - Kotlin `Components.PACKAGE_NAME` — `android/common/.../common/Components.kt:6`
   - Dart `packageName` — `lib/common/constant.dart:19`
   These two strings must stay equal (they name the `…/app`, `…/tile` channels and
   the `ComponentName` class prefix for the quick-settings tile intents). They do
   **not** need to equal the `applicationId`, only each other.
6. Rebuild the Android app and verify: launch, per-app proxy list (AppPlugin
   channel), the VPN service start/stop, and the quick-settings tile.

> Because this is purely a cosmetic internal namespace that users never see and it
> carries real breakage risk, it's reasonable to **leave it as `com.follow.clash`**
> indefinitely. Prioritize it low.

### B. Windows helper service name `FlClashHelperService` → `LongyunVPNHelperService` — ✅ DONE (Phase 2)

Completed as Phase 2 of [`LONGYUN_CORE_MIGRATION.md`](LONGYUN_CORE_MIGRATION.md).
`Windows.registerService` now always stops+deletes the legacy service
(`legacyHelperService` constant) on (re)register, so upgrades don't strand a dead
service. Original notes retained below.

Three places must match, and there's an upgrade caveat:

- Dart `appHelperService` — `lib/common/constant.dart:15`
- Rust `SERVICE_NAME` — `services/helper/src/service/windows.rs:19`
- build_tool `helperName` default — `plugins/setup/buildkit/build_tool/lib/src/options.dart:40`
  (or override via `helper_name:` in a root `build_config.yaml`)

The Dart side also derives the helper exe filename from `appHelperService`
(`path.dart:51`), so keep all four in sync. **Caveat:** users who already installed
the old service keep a registered `FlClashHelperService` after upgrade; the new app
registers `LongyunVPNHelperService` and the old one is orphaned (harmless but
untidy). If you rename, add a one-time uninstall of the old service name.

### C. Go core binary name `FlClashCore` → `LongyunCore` — ✅ DONE (Phase 1)

Completed as Phase 1 of [`LONGYUN_CORE_MIGRATION.md`](LONGYUN_CORE_MIGRATION.md)
(the master plan — see it for the full phased rebrand). Original notes retained below.

- Dart `FlClashCore` literal — `lib/common/path.dart:47`
- build_tool `coreName` default — `options.dart:36` (or `core_name:` in
  `build_config.yaml`)

Keep both in sync and rebuild every platform (the core is produced by the platform
build hooks).

### D. Deep-link schemes — KEEP, do not remove

`clash://`, `clashmeta://`, `flclash://` (registered in `common/window.dart` and
`AndroidManifest.xml`) are how subscription/profile links import into the app. The
`clash` scheme in particular is a Clash-ecosystem convention. **Removing them is a
feature regression, not branding cleanup.** If desired, *add* a `longyunvpn://`
scheme alongside them rather than removing the existing ones.

## Suggested priority

Low. None of this is user-visible. Do B and C opportunistically if you're already
touching the build; treat A as optional cosmetic cleanup for a quiet release where
you can fully regression-test Android.
