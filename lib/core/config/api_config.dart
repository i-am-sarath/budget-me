/// Application-wide API & SDK configuration.
///
/// ⚠️ For production builds use --dart-define to override keys.
/// Secret key (sk_...) is for dashboard only — DO NOT embed it.
/// The public API keys below are safe to ship.
class ApiConfig {
  // ─── Budget Me proxy backend ──────────────────────────
  // OpenAI calls are routed through our Cloudflare Worker so the OpenAI key
  // never ships in the AAB. See backend/ for the worker.
  static const String proxyBaseUrl = String.fromEnvironment('PROXY_BASE_URL');
  static const String proxyClientSecret =
      String.fromEnvironment('PROXY_CLIENT_SECRET');

  // ─── RevenueCat PUBLIC Keys ───────────────────────────
  // Override at build time: --dart-define=RC_ANDROID_KEY=xxx
  static const String revenueCatAndroidKey = String.fromEnvironment(
    'RC_ANDROID_KEY',
    defaultValue: 'test_PZwqjFJDFOucmHwgoHeAyMquzbG',
  );

  static const String revenueCatIosKey = String.fromEnvironment(
    'RC_IOS_KEY',
    defaultValue: 'test_PZwqjFJDFOucmHwgoHeAyMquzbG', // replace with Apple key when submitting to iOS
  );

  // ─── RevenueCat Entitlement & Product IDs ─────────────
  // Verify this matches the entitlement identifier in your RC dashboard.
  static const String entitlementPro = 'pro';
  static const String offeringId = 'default';

  // ─── Product IDs (must match Play Console & App Store Connect) ─
  // Informational only — purchases are driven by RevenueCat package *type*
  // (monthly/annual), not these strings. Kept here as the single source of
  // truth for the store/RC setup. No lifetime: a one-time purchase is an
  // un-repriceable liability against rising AI costs, so Pro is subscription
  // only (monthly + annual, both with a 14-day trial).
  static const String productMonthly = 'budgetme_pro_monthly';
  static const String productYearly  = 'budgetme_pro_annual';

  // ─── AdMob ────────────────────────────────────
  static const String rewardedInterstitialAdUnitId =
      'ca-app-pub-6384260983473792/8085872177';

  // ─── Supabase (cloud groups / shared spending) ────────
  // Override at build time:
  //   --dart-define=SUPABASE_URL=https://xxxx.supabase.co
  //   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
  // The anon key is a PUBLIC key and is safe to ship; Row Level Security
  // in the database is what protects user data. See supabase/README.md.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Google OAuth *web* client ID from the Supabase Google provider config.
  /// Required for native Google sign-in on Android (serverClientId).
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// True when cloud groups are configured for this build. When false the
  /// Groups feature degrades gracefully to a "set up cloud sync" state.
  static bool get cloudGroupsEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // ─── Sentry crash reporting ───────────────────────────
  // Override at build time: --dart-define=SENTRY_DSN=https://...@oXXXX.ingest...
  // When empty, Sentry is not initialised and the app runs normally.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// True when crash reporting is configured for this build.
  static bool get crashReportingEnabled => sentryDsn.isNotEmpty;
}
