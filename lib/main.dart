import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/core/services/backup_service.dart';
import 'package:agent_money/core/services/budget_service.dart';
import 'package:agent_money/core/services/overlay_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/theme_service.dart';
import 'package:agent_money/features/dashboard/dashboard_screen.dart';
import 'package:agent_money/features/onboarding/onboarding_screen.dart';
import 'package:agent_money/features/overlay/overlay_widget.dart';
import 'package:agent_money/features/transactions/widgets/manual_entry_sheet.dart';

/// Global navigator key — needed so the overlay IPC listener can push the
/// quick-entry sheet from anywhere without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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

  // Initialize AdMob (mobile only)
  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
  }

  // Fire-and-forget defensive backup. Rate-limited to once per 24h.
  // The DB remains authoritative; this is JSON insurance against a future
  // bad migration wiping user data.
  unawaited(BackupService.exportAllIfDue());

  // If the user had the always-on overlay enabled previously, bring it back.
  // No-op on iOS / if permission was revoked.
  unawaited(OverlayService.restoreIfEnabled());

  runApp(const ProviderScope(child: BudgetTrackerApp()));
}

class BudgetTrackerApp extends ConsumerStatefulWidget {
  const BudgetTrackerApp({super.key});

  @override
  ConsumerState<BudgetTrackerApp> createState() => _BudgetTrackerAppState();
}

class _BudgetTrackerAppState extends ConsumerState<BudgetTrackerApp> {
  StreamSubscription<dynamic>? _overlaySub;

  @override
  void initState() {
    super.initState();
    // Listen for overlay-bubble taps. The overlay (separate Flutter engine)
    // sends 'open_quick_entry' on tap; we react by pushing the manual entry
    // sheet over the current screen if the navigator is mounted.
    if (Platform.isAndroid) {
      _overlaySub = OverlayService.events.listen((event) {
        if (event != 'open_quick_entry') return;
        final nav = rootNavigatorKey.currentState;
        final ctx = nav?.context;
        if (ctx == null) return;
        showModalBottomSheet(
          // ignore: use_build_context_synchronously
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const ManualEntrySheet(),
        );
      });
    }
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Budget Me',
      navigatorKey: rootNavigatorKey,
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
                  Text('Budget Me',
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
