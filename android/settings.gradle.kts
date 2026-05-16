pluginManagement {
    val offlineRepo = file("offline-maven-repo")
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
            ?: error("flutter.sdk not set in local.properties")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        if (offlineRepo.exists()) {
            maven(url = offlineRepo.toURI())
        }
        // Mirrors first (Iran / restricted networks); then upstream fallbacks.
        maven(url = "https://maven.myket.ir")
        maven(url = "https://maven.tarazerp.ir")
        maven(url = "https://maven.aliyun.com/repository/google")
        maven(url = "https://maven.aliyun.com/repository/gradle-plugin")
        maven(url = "https://maven.aliyun.com/repository/public")
        // Avoid gradlePluginPortal(): it still resolves artifacts via plugins-artifacts.gradle.org.
        google()
        mavenCentral()
    }

    resolutionStrategy {
        eachPlugin {
            when (requested.id.id) {
                "com.android.application",
                "com.android.library" ->
                    useModule("com.android.tools.build:gradle:${requested.version}")

                "org.jetbrains.kotlin.android" ->
                    useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")

                "org.jetbrains.kotlin.jvm" ->
                    useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")

                "org.gradle.kotlin.kotlin-dsl" ->
                    useModule("org.gradle.kotlin:gradle-kotlin-dsl-plugins:${requested.version}")
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")