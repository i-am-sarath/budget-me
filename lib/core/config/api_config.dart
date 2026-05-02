/// Application-wide API & SDK configuration.
///
/// ⚠️ For production builds use --dart-define to override keys.
/// Secret key (sk_...) is for dashboard only — DO NOT embed it.
/// The public API keys below are safe to ship.
class ApiConfig {
  // ─── OpenAI ───────────────────────────────────────────
  static const String openAiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  // ─── RevenueCat PUBLIC Keys ───────────────────────────
  // Note: sk_whcyqZUXynYpTIXMnPSupfyzmtiPv is your SECRET key for the
  // RevenueCat dashboard API — it must NEVER be embedded in the app.
  // You need your PUBLIC Google/Apple keys from:
  //   RevenueCat Dashboard → Project Settings → API Keys → Public
  static const String revenueCatAndroidKey = String.fromEnvironment(
    'RC_ANDROID_KEY',
    defaultValue:
        'goog_whcyqZUXynYpTIXMnPSupfyzmtiPv', // replace with your Android public key
  );

  static const String revenueCatIosKey = String.fromEnvironment(
    'RC_IOS_KEY',
    defaultValue:
        'appl_whcyqZUXynYpTIXMnPSupfyzmtiPv', // replace with your iOS public key
  );

  // ─── RevenueCat Entitlement & Product IDs ─────────────
  static const String entitlementPro = 'pro';
  static const String offeringId = 'default';

  // ─── Product IDs (must match Play Console & App Store Connect) ─
  static const String productMonthly = 'voicelog_pro_monthly';
  static const String productYearly = 'voicelog_pro_yearly';
}
