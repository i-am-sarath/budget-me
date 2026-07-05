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
  static const String productMonthly  = 'monthly';
  static const String productYearly   = 'yearly';
  static const String productLifetime = 'lifetime';

  // ─── AdMob ────────────────────────────────────
  static const String rewardedInterstitialAdUnitId =
      'ca-app-pub-6384260983473792/8085872177';

  // ─── Backup (Google Drive) ────────────────────
  // OAuth web client ID for server-side/offline access during Google Sign-In.
  // Override at build time: --dart-define=GOOGLE_DRIVE_SERVER_CLIENT_ID=xxx
  static const String googleDriveServerClientId = String.fromEnvironment(
    'GOOGLE_DRIVE_SERVER_CLIENT_ID',
  );

  static const String driveBackupFolderName = 'Budget Me Backups';

  static const int maxBackupsRetained = 10;
}
