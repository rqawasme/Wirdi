import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured out of band, through `android/key.properties`,
// which is gitignored along with the keystore it points at. CI writes both from
// repository secrets before building. When the file is absent — a fresh clone, a
// fork, a pull request from someone without access to the secrets — the release
// build falls back to the debug keys so that `flutter build apk --release` still
// works locally. The release workflow reads the same file to decide whether the
// APK it produces is distributable, so an unsigned build is labelled rather than
// silently published as if it were signed.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

// A key.properties written by hand and missing a line would otherwise fail deep
// inside the signing task, with a message that does not name what is missing.
fun keystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: throw GradleException(
            "android/key.properties has no '$name'. It needs storeFile, " +
                "storePassword, keyAlias and keyPassword — see docs/RELEASING.md.",
        )

android {
    namespace = "app.wirdi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.wirdi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                // An absolute path: Gradle resolves a relative one against
                // this module's directory, android/app, rather than against
                // key.properties, which is rarely what was meant.
                storeFile = file(keystoreProperty("storeFile"))
                storePassword = keystoreProperty("storePassword")
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Debug keys, so a local `flutter build apk --release` works
                // without a keystore. Not distributable: Play rejects it, and
                // the debug key is a well-known one anybody can re-sign with.
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // Named rather than relied on transitively. AndroidManifest.xml references
    // androidx.core.content.FileProvider by class name and MainActivity.kt
    // imports it, so a Flutter embedding that stopped pulling androidx.core in
    // would fail at install time on a device rather than at build time here.
    implementation("androidx.core:core:1.15.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
