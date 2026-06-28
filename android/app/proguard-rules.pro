# Flutter Engine Proguard Configuration
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# AdMob / Google Play Services
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Prevent R8 from stripping native bridging required for Flutter JNI
-keep class * extends java.lang.annotation.Annotation { *; }

# Suppress warnings for unused optional flutter dependencies
-dontwarn com.google.android.play.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Video Playback intents
-keep class androidx.core.content.FileProvider { *; }

# Firebase Core
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.firebase** { *; }

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.crashlytics.** { *; }
-dontwarn com.crashlytics.**
