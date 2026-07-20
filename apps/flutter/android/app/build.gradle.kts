import java.security.MessageDigest

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.matome.matome_flutter"
    // file_picker (S1 upload, #780) pulls a flutter_plugin_android_lifecycle
    // that requires compileSdk 36; pin it explicitly so the AAR metadata check
    // passes (the Flutter default lagged behind on this toolchain).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.matome.matome_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Pull SQLCipher's Android AAR directly instead of the
    // sqlcipher_flutter_libs Flutter plugin. That plugin intentionally reuses
    // sqlite3_flutter_libs' namespace and cannot coexist with drift_flutter.
    implementation("net.zetetic:sqlcipher-android:4.10.0")
}

val sqlCipherVerification by configurations.creating {
    isCanBeConsumed = false
    isTransitive = false
}

dependencies {
    sqlCipherVerification("net.zetetic:sqlcipher-android:4.10.0")
}

val verifySqlCipherArtifact = tasks.register("verifySqlCipherArtifact") {
    val artifact = sqlCipherVerification.elements
    inputs.files(artifact)
    doLast {
        val aar = artifact.get().single().asFile
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(aar.readBytes())
            .joinToString("") { "%02x".format(it) }
        check(digest == "cc60b1a40d023bec06a1e56740db7172d2516668570140cd9de00ca90f84cd9f") {
            "Unexpected SQLCipher Android AAR SHA-256: $digest"
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(verifySqlCipherArtifact)
}
