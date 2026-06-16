plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.uzita"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.uzita"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    // Real phones are ARM only. Drop the x86_64 (emulator-only) native libs,
    // including the prebuilt ones inside the Neshan/Carto AARs, to shrink the
    // universal APK. Combine with `--target-platform android-arm,android-arm64`
    // to also drop the Flutter engine's x86_64 library.
    packaging {
        jniLibs {
            excludes += listOf("lib/x86_64/**")
        }
    }

    signingConfigs {
        getByName("debug") {
            // MIUI / older Android reject v2-only APKs with "package appears to
            // be invalid". Keep the legacy JAR (v1) signature alongside v2/v3.
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Neshan MapView + Carto JNI break when R8 strips SDK classes.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Configure splits based on Flutter's -Psplit-per-abi property
    val isSplitPerAbiRequested = project.hasProperty("split-per-abi")
    splits {
        abi {
            isEnable = isSplitPerAbiRequested
            reset()
            include("armeabi-v7a", "arm64-v8a")
            // When building with --split-per-abi, do NOT create a universal APK to avoid plugin NPE
            // When building without the flag, create only a universal APK
            isUniversalApk = !isSplitPerAbiRequested
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(files("libs/mobile-sdk-1.0.3.aar"))
    implementation(files("libs/services-sdk-1.0.0.aar"))
    implementation(files("libs/common-sdk-0.0.3.aar"))
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.android.gms:play-services-gcm:17.0.0")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.0")
}
