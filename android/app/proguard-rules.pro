# android/app/proguard-rules.pro
# BellaMusic — ProGuard / R8 Obfuscation Rules
# SECURITY: These rules prevent APK reverse-engineering while keeping
# Flutter runtime and plugin reflection intact.

# ─── Flutter & Dart ───────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ─── Kotlin ───────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# ─── just_audio ───────────────────────────────────────────────────────────────
-keep class com.ryanheise.just_audio.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.ryanheise.**

# ─── flutter_secure_storage ───────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.**

# ─── AndroidX & Jetpack ───────────────────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**
-keep class com.google.** { *; }
-dontwarn com.google.**

# ─── Network (OkHttp / Dart HTTP) ────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**

# ─── Suppress common warnings ─────────────────────────────────────────────────
-dontwarn java.lang.invoke.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ─── SECURITY: Remove all logging in release builds ──────────────────────────
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# ─── Obfuscation settings ─────────────────────────────────────────────────────
# Rename classes/methods aggressively — maximum obfuscation
-repackageclasses 'com.bellamusic.obf'
-allowaccessmodification
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose
