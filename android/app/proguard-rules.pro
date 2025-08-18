# Keep Flutter and plugin classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.camera.** { *; }

# Keep Kotlin metadata
-keepclassmembers class kotlin.Metadata { *; }
-keep class kotlin.Unit { *; }

# Keep Flutter's generated registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Ignore optional Play Core classes used by Flutter deferred components
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitinstall.**

# Keep Flutter deferred components references
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }