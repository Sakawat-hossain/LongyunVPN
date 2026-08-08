# Android release signing

Tagged releases (`git push origin vX.Y.Z`) build a **release-signed** APK. The CI
job [`release.yml`](../.github/workflows/release.yml) now **fails fast** if the
signing secret is missing, so you can never accidentally publish a debug-signed
build (a debug build uses the `com.longyunvpn.app.dev` application id and cannot
update a device that has a real install).

You only do this setup **once**. After that every tagged release is signed
automatically.

## 1. Create an upload keystore

Run locally (needs the JDK's `keytool`, bundled with Android Studio / Flutter):

```bash
keytool -genkey -v \
  -keystore longyunvpn-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias longyunvpn
```

It will prompt for a **store password**, a **key password** (you can use the same
value), and a name/organization. **Keep this file and both passwords safe and
backed up** — if you lose them you cannot ship an update that existing users can
install over their current version.

> If you plan to distribute through Google Play, enable **Play App Signing** and
> treat this key as the *upload* key. Play then manages the final app-signing key,
> and a lost upload key can be reset by Google. For GitHub-only APK distribution,
> this key **is** the app signing key — losing it is unrecoverable.

## 2. Add the four repository secrets

Base64-encode the keystore and add it plus the three passwords/alias as GitHub
Actions secrets. With the [GitHub CLI](https://cli.github.com/):

```bash
# from the folder containing longyunvpn-upload.jks
gh secret set ANDROID_KEYSTORE_BASE64 --repo Sakawat-hossain/LongyunVPN < <(base64 -w0 longyunvpn-upload.jks)
gh secret set ANDROID_STORE_PASSWORD  --repo Sakawat-hossain/LongyunVPN --body 'your-store-password'
gh secret set ANDROID_KEY_ALIAS       --repo Sakawat-hossain/LongyunVPN --body 'longyunvpn'
gh secret set ANDROID_KEY_PASSWORD    --repo Sakawat-hossain/LongyunVPN --body 'your-key-password'
```

(On macOS `base64` has no `-w0`; use `base64 longyunvpn-upload.jks | tr -d '\n'`.)

Or add them in the browser under **Settings → Secrets and variables → Actions →
New repository secret**.

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of `longyunvpn-upload.jks` |
| `ANDROID_STORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | `longyunvpn` (whatever `-alias` you used) |
| `ANDROID_KEY_PASSWORD` | the key password |

## 3. Release

```bash
git tag v1.1.6
git push origin v1.1.6
```

The workflow decodes the keystore, writes it to `android/app/keystore.jks` and the
passwords to `android/local.properties`, and Gradle's `release` build type signs
with it (see [`android/app/build.gradle.kts`](../android/app/build.gradle.kts)).

## Local release builds

The same mechanism works locally — create `android/local.properties` with:

```properties
storePassword=your-store-password
keyAlias=longyunvpn
keyPassword=your-key-password
```

and place the keystore at `android/app/keystore.jks`. Without these, a **local**
`dart setup.dart android` still builds a debug-signed `.dev` APK for convenience;
only the CI **release** path requires the real key.

## Verify a build is correctly signed

```bash
# prints the signing certificate; should NOT be the Android debug cert
$ANDROID_SDK_ROOT/build-tools/<version>/apksigner verify --print-certs dist/LongyunVPN-arm64-v8a.apk
```

The debug certificate has `CN=Android Debug`; a correctly signed release shows the
subject you entered in step 1.
