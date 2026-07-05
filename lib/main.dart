import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:money_pi/core/config/api_config.dart';
import 'package:money_pi/core/services/consent_service.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/database/database_helper.dart';
import 'package:money_pi/core/services/backup_service.dart';
import 'package:money_pi/core/services/budget_service.dart';
import 'package:money_pi/core/services/cloud_service.dart';
import 'package:money_pi/core/services/overlay_service.dart';
import 'package:money_pi/core/services/subscription_service.dart';
import 'package:money_pi/core/services/theme_service.dart';
import 'package:money_pi/features/dashboard/dashboard_screen.dart';
import 'package:money_pi/features/onboarding/onboarding_screen.dart';
import 'package:money_pi/features/overlay/overlay_widget.dart';
import 'package:money_pi/features/transactions/providers/voice_log_provider.dart';
import 'package:money_pi/features/transactions/widgets/manual_entry_sheet.dart';
import 'package:money_pi/features/transactions/widgets/voice_capture_sheet.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Group shared between the app and the iOS WidgetKit extension, and the
/// host string used by the home-screen quick-add widget's deep link
/// (`budgetme://voice`).
const String kHomeWidgetAppGroup = 'group.com.budgetme.budgettracker';

/// Global navigator key — needed so the overlay IPC listener can push the
/// quick-entry sheet from anywhere without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global messenger key so background flows (voice auto-save) can show
/// snackbars/undo regardless of which screen is mounted.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Second Flutter entry point — runs inside the system overlay window.
/// Must be top-level and annotated with `vm:entry-point` so tree-shaking
/// doesn't drop it from release builds.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuickLogOverlay());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix "databaseFactory not initialized" on Windows / Linux / macOS
  DatabaseHelper.initForDesktop();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay — transparent, adapts with theme at widget level
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize RevenueCat (graceful failure if key not set)
  try {
    await initRevenueCat();
  } catch (_) {
    // RC key not configured yet — app continues without subscription features
  }

  // Initialize Supabase for cloud groups (no-op if keys aren't configured)
  try {
    await CloudService.init();
  } catch (_) {
    // Cloud sync optional — app continues as a local-only tracker
  }

  // Initialize AdMob (mobile only). Gather UMP consent first so EEA/UK users
  // see the consent form before any ad request (Google ads policy).
  if (Platform.isAndroid || Platform.isIOS) {
    await ConsentService.gatherConsent();
    await MobileAds.instance.initialize();
    // Required on iOS so the app and the WidgetKit extension share storage.
    // Harmless on Android.
    try {
      await HomeWidget.setAppGroupId(kHomeWidgetAppGroup);
    } catch (_) {}
  }

  // Fire-and-forget defensive backup. Rate-limited to once per 24h.
  // The DB remains authoritative; this is JSON insurance against a future
  // bad migration wiping user data.
  unawaited(BackupService.exportAllIfDue());

  // If the user had the always-on overlay enabled previously, bring it back.
  // No-op on iOS / if permission was revoked.
  unawaited(OverlayService.restoreIfEnabled());

  // Initialise crash reporting if a DSN was provided at build time, otherwise
  // run the app directly. Sentry's appRunner installs an error-capturing zone.
  if (ApiConfig.crashReportingEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = ApiConfig.sentryDsn;
        options.tracesSampleRate = 0.2;
        const isRelease = bool.fromEnvironment('dart.vm.product');
        options.debug = !isRelease;
        // Don't ship PII — financial app, keep reports minimal.
        options.sendDefaultPii = false;
      },
      appRunner: () =>
          runApp(const ProviderScope(child: BudgetTrackerApp())),
    );
  } else {
    runApp(const ProviderScope(child: BudgetTrackerApp()));
  }
}

class BudgetTrackerApp extends ConsumerStatefulWidget {
  const BudgetTrackerApp({super.key});

  @override
  ConsumerState<BudgetTrackerApp> createState() => _BudgetTrackerAppState();
}

class _BudgetTrackerAppState extends ConsumerState<BudgetTrackerApp>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _overlaySub;
  static const String _pendingLogsKey = 'pending_voice_logs';
  bool _draining = false;

  @override
  void initState() {
    super.initState();
    // Listen for events from the overlay bubble (separate Flutter engine):
    //   - {'type': 'voice_log', 'path': <m4a>}   → run transcribe + parse
    //   - {'type': 'mic_permission_needed'}      → prompt for mic
    //   - 'open_quick_entry' (legacy)             → manual entry sheet
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      _overlaySub = OverlayService.events.listen(_handleOverlayEvent);
      // Drain any recordings the bubble captured while the app was killed.
      // ignore: discarded_futures
      _drainPendingVoiceLogs();
    }

    // Home-screen quick-add widget: tapping it deep-links to budgetme://voice.
    if (Platform.isAndroid || Platform.isIOS) {
      _initHomeWidgetLaunch();
    }
  }

  StreamSubscription<Uri?>? _widgetSub;

  /// Handle launches that originate from the home-screen widget — both a cold
  /// start (app was not running) and a warm tap (app already alive).
  void _initHomeWidgetLaunch() {
    // Warm taps arrive on this stream.
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    // Cold start: the launch URI is available once after startup.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        _handleWidgetUri(uri);
      } catch (_) {}
    });
  }

  bool _handlingWidgetLaunch = false;

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    // budgetme://voice  (host == 'voice')
    if (uri.host != 'voice' && uri.path != '/voice') return;
    // ignore: discarded_futures
    _openVoiceWhenReady();
  }

  /// Open the voice recorder, waiting for the app to be ready first.
  ///
  /// On a cold start (the common case for a widget tap — the app wasn't
  /// running) the deep link arrives before the navigator/dashboard is mounted.
  /// Showing the sheet then either targets a null context or lands on the
  /// splash and gets torn down when the [AnimatedSwitcher] swaps in the
  /// dashboard. So we poll briefly until both a navigator context exists and
  /// onboarding is complete, then show it.
  Future<void> _openVoiceWhenReady() async {
    if (_handlingWidgetLaunch) return;
    _handlingWidgetLaunch = true;
    try {
      for (var i = 0; i < 50; i++) {
        if (!mounted) return;
        final ctx = rootNavigatorKey.currentContext;
        final ready = ctx != null && ref.read(budgetProvider).onboardingDone;
        if (ready) {
          // ctx is freshly read from the global navigator key on this line.
          // ignore: use_build_context_synchronously
          await showVoiceCapture(ctx);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _handlingWidgetLaunch = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground — pick up anything the bubble queued while
    // the app was backgrounded or killed.
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      // ignore: discarded_futures
      _drainPendingVoiceLogs();
    }
  }

  /// Process a single overlay recording and remove it from the persisted queue.
  Future<void> _processOverlayLog(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final list = prefs.getStringList(_pendingLogsKey) ?? <String>[];
      if (list.remove(path)) {
        await prefs.setStringList(_pendingLogsKey, list);
      }
    } catch (_) {/* the file check below still gates processing */}
    final file = File(path);
    if (!await file.exists() || !mounted) return;
    await ref.read(voiceLogProvider.notifier).processAndSave(file);
  }

  /// Drain recordings the overlay bubble captured while the app process was not
  /// alive to receive the live IPC. Waits until the app is ready, then runs
  /// each through the normal voice auto-save pipeline. Files are deleted by the
  /// pipeline, so a path whose file is already gone is simply skipped.
  Future<void> _drainPendingVoiceLogs() async {
    if (_draining) return;
    _draining = true;
    try {
      for (var i = 0; i < 50; i++) {
        if (!mounted) return;
        final ready = rootNavigatorKey.currentContext != null &&
            ref.read(budgetProvider).onboardingDone;
        if (ready) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final pending = prefs.getStringList(_pendingLogsKey) ?? <String>[];
      if (pending.isEmpty) return;
      await prefs.remove(_pendingLogsKey);
      for (final path in pending) {
        if (!mounted) return;
        final file = File(path);
        if (!await file.exists()) continue;
        await ref.read(voiceLogProvider.notifier).processAndSave(file);
      }
    } catch (_) {
      // Best-effort — anything left will be retried on the next resume.
    } finally {
      _draining = false;
    }
  }

  void _handleOverlayEvent(dynamic event) {
    final nav = rootNavigatorKey.currentState;
    final ctx = nav?.context;
    if (ctx == null) return;

    // Legacy tap event from older overlay builds — keep so existing installs
    // still open the manual sheet on a plain tap.
    if (event == 'open_quick_entry') {
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ManualEntrySheet(),
      );
      return;
    }

    if (event is Map) {
      final type = event['type'];
      if (type == 'voice_log') {
        final path = event['path'];
        if (path is! String || path.isEmpty) return;
        // Process via the same background auto-save flow as the in-app mic
        // (shimmer row + Undo), and clear it from the persisted queue so the
        // startup/resume drain never processes it twice.
        // ignore: discarded_futures
        _processOverlayLog(path);
        return;
      }
      if (type == 'mic_permission_needed') {
        // Trigger the in-app mic permission prompt while we have a real
        // Activity context. The overlay isolate can't prompt itself.
        // Fire-and-forget — the result surfaces on the user's next tap.
        AudioRecorder().hasPermission();
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Microphone access is needed for voice logging.'),
          ),
        );
        return;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlaySub?.cancel();
    _widgetSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Money Pi',
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: _Bootstrapper(),
    );
  }
}

/// Decides whether to show onboarding or the main app.
/// Waits for the budget provider to load from SharedPreferences first.
class _Bootstrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetProvider);

    // Budget provider initialises async — show a blank splash while loading
    // We detect "not yet loaded" by checking if the state equals the default
    // AND onboardingDone is false (default). Once loaded, onboardingDone will
    // reflect the persisted value.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: budget.onboardingDone
          ? const DashboardScreen(key: ValueKey('dashboard'))
          : _LoadingOrOnboarding(key: const ValueKey('onboard')),
    );
  }
}

class _LoadingOrOnboarding extends ConsumerWidget {
  const _LoadingOrOnboarding({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    // Brief shimmer splash, then show onboarding
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 600)),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // Splash screen
          return Scaffold(
            backgroundColor: tc.surface,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: tc.onSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded,
                        color: tc.surface, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('Money Pi',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )),
                ],
              ),
            ),
          );
        }
        return const OnboardingScreen();
      },
    );
  }
}
