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

## flutter_gemma / LiteRT-LM (Google AI Edge)
-keep class com.google.ai.edge.** { *; }
-keep class com.google.mediapipe.** { *; }
-keep class com.google.android.mediapipe.** { *; }
-dontwarn com.google.ai.edge.**
-dontwarn com.google.mediapipe.**

## home_widget
-keep class es.antonborri.home_widget.** { *; }

## permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

## pedometer
-keep class io.github.g123k.plugins.** { *; }

## General
-dontwarn io.flutter.**
-dontnote io.flutter.**
