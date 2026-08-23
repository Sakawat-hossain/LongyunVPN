import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// The published application id, shared by the Firebase config check below and
// the android block further down.
val applicationIdBase = "com.longyunvpn.app"

// Firebase is wired up only when google-services.json can actually serve this
// application id.
//
// Two ways it can fall short, and both have to leave a working build behind:
// the file may be absent entirely (a fresh clone, or a fork that wants no
// telemetry), or it may be a config for some other package. Either way the
// google-services plugin would fail the build outright — "No matching client
// found" — so it is applied only once the id is confirmed present, and the
// check reads the package names straight out of the json rather than trusting
// that the right file was dropped in. When Firebase is off, Android falls back
// to the on-device CrashLog exactly as Windows and Linux do.
//
// The crashlytics plugin earns its place: release is minified, so without its
// mapping-file upload every production stack trace would arrive obfuscated.
val googleServicesFile = file("google-services.json")
val googleServicesPackages: Set<String> = if (googleServicesFile.exists()) {
    Regex("\"package_name\"\\s*:\\s*\"([^\"]+)\"")
        .findAll(googleServicesFile.readText())
        .map { it.groupValues[1] }
        .toSet()
} else {
    emptySet()
}
if (googleServicesPackages.contains(applicationIdBase)) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else if (googleServicesFile.exists()) {
    logger.warn(
        "Firebase disabled for Android: google-services.json has no client for " +
            "$applicationIdBase (it lists " +
            googleServicesPackages.joinToString().ifEmpty { "nothing" } +
            "). Register that application id in the Firebase console and " +
            "re-download the file to enable crash reporting."
    )
} else {
    logger.lifecycle("Firebase disabled for Android: google-services.json not found.")
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val mStoreFile: File = file("keystore.jks")
val mStorePassword: String? = localProperties.getProperty("storePassword")
val mKeyAlias: String? = localProperties.getProperty("keyAlias")
val mKeyPassword: String? = localProperties.getProperty("keyPassword")
val isRelease =
    mStoreFile.exists() && mStorePassword != null && mKeyAlias != null && mKeyPassword != null


android {
    namespace = "com.longyunvpn.app"
    compileSdk = libs.versions.compileSdk.get().toInt()
    ndkVersion = libs.versions.ndkVersion.get()



    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Published application id (what the store / device sees). After the
        // com.follow.clash → com.longyunvpn.app migration the Kotlin namespace
        // matches this id.
        applicationId = applicationIdBase
        minSdk = flutter.minSdkVersion
        targetSdk = libs.versions.targetSdk.get().toInt()
        // LongyunVPN ships a plain semantic version (e.g. 1.0.1) with no Flutter
        // build suffix, matching the desktop build. Keep versionName identical
        // and derive a monotonic Android versionCode from it (1.0.1 -> 10001).
        versionName = flutter.versionName
        versionCode = flutter.versionName.split(".").let { parts ->
            (parts.getOrNull(0)?.toIntOrNull() ?: 1) * 10000 +
                (parts.getOrNull(1)?.toIntOrNull() ?: 0) * 100 +
                (parts.getOrNull(2)?.toIntOrNull() ?: 0)
        }
    }

    signingConfigs {
        if (isRelease) {
            create("release") {
                storeFile = mStoreFile
                storePassword = mStorePassword
                keyAlias = mKeyAlias
                keyPassword = mKeyPassword
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        // Every variant publishes under the one application id. There is no
        // ".dev" suffix any more: one name, everywhere.
        //
        // The trade-off, worth knowing before you hit it: debug and unsigned
        // builds are debug-signed while releases are key-signed, and Android
        // refuses to update a package with a different signature. Swapping
        // between a locally-built app and an installed release now needs an
        // uninstall first, where the suffixed ids used to let both sit side by
        // side.
        debug {
            isMinifyEnabled = false
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            if (isRelease) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}


dependencies {
    implementation(project(":service"))
    implementation(project(":common"))
    implementation(libs.core.splashscreen)
    implementation(libs.gson)
    implementation(libs.smali.dexlib2) {
        exclude(group = "com.google.guava", module = "guava")
    }
}