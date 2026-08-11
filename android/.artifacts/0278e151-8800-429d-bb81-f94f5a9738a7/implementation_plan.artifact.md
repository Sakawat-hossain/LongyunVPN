# LongyunVPN Android Modernization Plan

Comprehensive review and update of the Android build system, dependencies, and branding for LongyunVPN.

## User Review Required

> [!IMPORTANT]
> **SDK Versions:** I am targeting SDK **35** (Android 15 Stable) instead of **36** (Android 16 Preview) to ensure stability across all dependencies. If you specifically need to test for Android 16, please let me know.
> **Deep Link Change:** Changing the URL scheme from `flclash://` to `longyunvpn://` will break any existing external links or shortcuts using the old scheme.

## Proposed Changes

### Build System & Dependencies

#### [MODIFY] [libs.versions.toml](file:///D:/My GitHub/LongyunVPN/android/gradle/libs.versions.toml)
- Set `targetSdk` and `compileSdk` to `35`.
- Update `coreKtx` to `1.15.0` (stable for SDK 35).
- Update `gson` to `2.12.1`.
- Review other dependencies for stable updates.

#### [MODIFY] [gradle-wrapper.properties](file:///D:/My GitHub/LongyunVPN/android/gradle/wrapper/gradle-wrapper.properties)
- Update Gradle to `8.12`.

#### [MODIFY] [build.gradle.kts (modules)](file:///D:/My GitHub/LongyunVPN/android/service/build.gradle.kts)
- Ensure all modules use `libs.versions` for SDK versions.

---

### Rebranding

#### [MODIFY] [AndroidManifest.xml](file:///D:/My GitHub/LongyunVPN/android/app/src/main/AndroidManifest.xml)
- Change `<data android:scheme="flclash" />` to `<data android:scheme="longyunvpn" />`.

#### [MODIFY] [GlobalState.kt](file:///D:/My GitHub/LongyunVPN/android/common/src/main/java/com/longyunvpn/app/common/GlobalState.kt)
- Change `NOTIFICATION_CHANNEL = "FlClash"` to `NOTIFICATION_CHANNEL = "LongyunVPN"`.

#### [MODIFY] [strings.xml](file:///D:/My GitHub/LongyunVPN/android/common/src/main/res/values/strings.xml)
- Update branding strings if any remain.

---

### Compatibility & Optimization

#### [MODIFY] [AndroidManifest.xml](file:///D:/My GitHub/LongyunVPN/android/app/src/main/AndroidManifest.xml)
- Add `android:extractNativeLibs="true"` or `false` (aligned with 16KB page size best practices).

## Verification Plan

### Automated Tests
- `./gradlew assembleDebug` to verify build success.
- `./gradlew lint` to check for compatibility issues.

### Manual Verification
- Verify the app name in the launcher.
- Verify notification channel name in system settings.
- Test deep link `longyunvpn://` handling.
