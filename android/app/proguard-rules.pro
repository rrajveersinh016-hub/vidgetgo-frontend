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

# Hive Database Models and Adapters Protection
-keep class * extends hive.HiveObject { *; }
-keep class * extends hive.TypeAdapter { *; }
-keep class com.loophole.app.data.models.DownloadItem { *; }
-keep class com.loophole.app.data.models.DownloadItemAdapter { *; }
-dontwarn hive.**

# Unity Ads Mediation Adapter
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

# Meta (Facebook) Audience Network Mediation Adapter
-keep class com.facebook.** { *; }
-keep class com.facebook.ads.** { *; }
-dontwarn com.facebook.**
-dontwarn com.facebook.ads.**

# JavascriptInterface preservation (Required for WebView-based ads used by Meta, Unity, and InMobi)
-keepattributes JavascriptInterface
-keep class android.webkit.JavascriptInterface { *; }

# Universal AdMob Mediation Adapter protection
# Prevents AdMob from failing to load mediation adapters by class name reflection in release builds
-keep class com.google.ads.mediation.** { *; }
-keep class com.google.android.gms.ads.mediation.** { *; }

# InMobi SDK & Mediation Rules
-keep class com.inmobi.** { *; }
-dontwarn com.inmobi.**
-dontwarn com.squareup.picasso.**
