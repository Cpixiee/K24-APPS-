# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Ignore missing play core split install references in Flutter deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Workmanager rules
-keep class dev.beamer.workmanager.** { *; }
-keep class androidx.work.** { *; }

# Flutter Local Notifications rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# SharedPreferences rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
