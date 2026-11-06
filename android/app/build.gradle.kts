plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.puppy_ledger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.puppy_ledger"
        // Match all packaged JNI libraries to Flutter's requested engine ABI(s).
        // Otherwise transitive plugins can add unsupported architectures to the APK.
        ndk {
            abiFilters.clear()
            val requested = (project.findProperty("target-platform") as? String ?: "android-arm64")
                .split(",").mapNotNull {
                    when (it) {
                        "android-arm64" -> "arm64-v8a"
                        "android-arm" -> "armeabi-v7a"
                        "android-x64" -> "x86_64"
                        else -> null
                    }
                }
            abiFilters.addAll(requested)
        }
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

    buildFeatures { resValues = true }

    flavorDimensions += "edition"
    productFlavors {
        create("linepuppy") {
            dimension = "edition"
            applicationIdSuffix = ".linepuppy"
            resValue("string", "app_name", "小狗账本")
        }
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
