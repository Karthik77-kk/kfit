## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Keep shared_preferences
-keep class com.google.android.gms.** { *; }

## Prevent stripping of notification classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }

## General
-dontwarn io.flutter.**
