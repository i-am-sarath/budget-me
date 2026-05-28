import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:app_links/app_links.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/services/notification_service.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/core/services/budget_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/theme_service.dart';
import 'package:agent_money/core/providers/overlay_event_provider.dart';
import 'package:agent_money/core/providers/quick_log_provider.dart';
import 'package:agent_money/features/dashboard/dashboard_screen.dart';
import 'package:agent_money/features/onboarding/onboarding_screen.dart';
import 'package:agent_money/features/overlay/overlay_entry_point.dart'; // registers vm:entry-point

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

  // Cache Pro status for the overlay isolate and wire the shareData listener
  if (Platform.isAndroid) {
    try {
      final info = await Purchases.getCustomerInfo();
      final isPro =
          info.entitlements.active.containsKey(ApiConfig.entitlementPro);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('overlay_is_pro', isPro);
    } catch (_) {}

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && data['event'] == 'overlay_saved') {
        addOverlayEvent(Map<String, dynamic>.from(data as Map));
      }
    });
  }

  // Handle budgetme://quicklog deep links (iOS home screen widget)
  if (Platform.isIOS || Platform.isAndroid) {
    AppLinks().uriLinkStream.listen((uri) {
      if (uri.host == 'quicklog') triggerQuickLog();
    });
  }

  // Initialize AdMob (mobile only)
  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
  }

  // Initialize notifications
  if (Platform.isAndroid || Platform.isIOS) {
    await NotificationService.init();
  }

  runApp(const ProviderScope(child: BudgetTrackerApp()));
}

class BudgetTrackerApp extends ConsumerWidget {
  const BudgetTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Budget Me',
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
