# ── Flutter ────────────────────────────────────────────────────────────────
# The Flutter Gradle plugin ships its own keep rules, but keep the embedding
# and any @pragma('vm:entry-point') symbols (e.g. our overlayMain) to be safe.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Play Core / deferred components ─────────────────────────────────────────
# Flutter references these even when not used; suppress missing-class warnings.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Google Mobile Ads (AdMob) + UMP consent ─────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── flutter_overlay_window (second engine entry point) ──────────────────────
-keep class flutter.overlay.window.** { *; }
-dontwarn flutter.overlay.window.**

# ── speech_to_text / record / camera plugins use reflection in spots ────────
-dontwarn com.google.android.gms.**

# ── Keep model classes that are (de)serialised reflectively, if any ─────────
# Riverpod / our own code does not rely on reflection, so nothing else needed.
