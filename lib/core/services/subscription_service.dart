import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_money/core/config/api_config.dart';

// ─────────────────────────────────────────────
// Subscription Tiers
// ─────────────────────────────────────────────

enum SubscriptionTier { free, pro }

// ─────────────────────────────────────────────
// Subscription State
// ─────────────────────────────────────────────

class SubscriptionState {
  final SubscriptionTier tier;
  final int voiceLogsUsedToday;
  final DateTime? lastVoiceLogDate;
  final bool isLoading;
  final Package? monthlyPackage;
  final Package? annualPackage;
  final CustomerInfo? customerInfo;

  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.voiceLogsUsedToday = 0,
    this.lastVoiceLogDate,
    this.isLoading = false,
    this.monthlyPackage,
    this.annualPackage,
    this.customerInfo,
  });

  bool get isPro => tier == SubscriptionTier.pro;

  /// Voice logging is a Pro-only feature.
  /// Free users see 0 voice logs — the mic button shows the paywall.
  static const int freeVoiceLogLimit = 0;

  bool get canUseVoice => isPro;

  int get voiceLogsRemainingToday => isPro ? -1 : 0; // -1 = unlimited sentinel

  bool get hasCloudSync => isPro;

  bool get hasOfferings => monthlyPackage != null || annualPackage != null;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    int? voiceLogsUsedToday,
    DateTime? lastVoiceLogDate,
    bool? isLoading,
    Package? monthlyPackage,
    Package? annualPackage,
    CustomerInfo? customerInfo,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      voiceLogsUsedToday: voiceLogsUsedToday ?? this.voiceLogsUsedToday,
      lastVoiceLogDate: lastVoiceLogDate ?? this.lastVoiceLogDate,
      isLoading: isLoading ?? this.isLoading,
      monthlyPackage: monthlyPackage ?? this.monthlyPackage,
      annualPackage: annualPackage ?? this.annualPackage,
      customerInfo: customerInfo ?? this.customerInfo,
    );
  }
}

// ─────────────────────────────────────────────
// RevenueCat Initializer (call once from main)
// ─────────────────────────────────────────────

Future<void> initRevenueCat() async {
  // Debug logging only in debug mode
  const bool isRelease = bool.fromEnvironment('dart.vm.product');
  await Purchases.setLogLevel(isRelease ? LogLevel.error : LogLevel.debug);

  final apiKey = Platform.isAndroid
      ? ApiConfig.revenueCatAndroidKey
      : ApiConfig.revenueCatIosKey;

  final config = PurchasesConfiguration(apiKey);
  await Purchases.configure(config);
}

// ─────────────────────────────────────────────
// Subscription Notifier
// ─────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  static const _voiceCountKey = 'voice_logs_today';
  static const _voiceDateKey = 'voice_logs_date';

  SubscriptionNotifier() : super(const SubscriptionState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    // Load local voice usage tracking
    await _loadVoiceUsage();

    // Fetch current subscription status from RevenueCat
    await refreshSubscriptionStatus();

    // Load available offerings (paywall data)
    await _loadOfferings();

    // Listen for real-time subscription changes
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadVoiceUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final dateTimestamp = prefs.getInt(_voiceDateKey);
    final lastDate = dateTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(dateTimestamp)
        : null;

    int count = 0;
    if (lastDate != null) {
      final now = DateTime.now();
      final isSameDay = lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day;
      if (isSameDay) count = prefs.getInt(_voiceCountKey) ?? 0;
    }

    state = state.copyWith(
      voiceLogsUsedToday: count,
      lastVoiceLogDate: lastDate,
    );
  }

  /// Sync subscription tier from RevenueCat entitlements
  Future<void> refreshSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _applyCustomerInfo(customerInfo);
    } catch (e) {
      // Silently fall back to free tier if RC unavailable
      state = state.copyWith(tier: SubscriptionTier.free);
    }
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final isPro = info.entitlements.active.containsKey(ApiConfig.entitlementPro);
    state = state.copyWith(
      tier: isPro ? SubscriptionTier.pro : SubscriptionTier.free,
      customerInfo: info,
    );
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _applyCustomerInfo(info);
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return;

      Package? monthly;
      Package? annual;

      for (final pkg in current.availablePackages) {
        if (pkg.packageType == PackageType.monthly) monthly = pkg;
        if (pkg.packageType == PackageType.annual) annual = pkg;
      }

      state = state.copyWith(
        monthlyPackage: monthly,
        annualPackage: annual,
      );
    } catch (_) {
      // Offerings not critical — paywall will show "Contact support"
    }
  }

  // ─────────────────────────────────────────────
  // Purchase Actions
  // ─────────────────────────────────────────────

  /// Returns null on success, or an error message string on failure.
  Future<String?> purchaseMonthly() async {
    final pkg = state.monthlyPackage;
    if (pkg == null) return 'Monthly plan not available';
    return _purchase(pkg);
  }

  Future<String?> purchaseAnnual() async {
    final pkg = state.annualPackage;
    if (pkg == null) return 'Annual plan not available';
    return _purchase(pkg);
  }

  Future<String?> _purchase(Package package) async {
    state = state.copyWith(isLoading: true);
    try {
      final info = await Purchases.purchasePackage(package);
      _applyCustomerInfo(info);
      state = state.copyWith(isLoading: false);
      return null; // success
    } on PurchasesErrorCode catch (e) {
      state = state.copyWith(isLoading: false);
      if (e == PurchasesErrorCode.purchaseCancelledError) return null; // user cancelled
      return e.name;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return 'Purchase failed: $e';
    }
  }

  Future<String?> restorePurchases() async {
    state = state.copyWith(isLoading: true);
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      state = state.copyWith(isLoading: false);
      final isPro = info.entitlements.active.containsKey(ApiConfig.entitlementPro);
      return isPro ? null : 'No active subscription found';
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return 'Restore failed: $e';
    }
  }

  // ─────────────────────────────────────────────
  // Voice Usage Tracking
  // ─────────────────────────────────────────────

  Future<void> recordVoiceLogUsed() async {
    if (state.isPro) return; // don't track for pro users
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final lastDate = state.lastVoiceLogDate;
    int newCount = 1;
    if (lastDate != null) {
      final isSameDay = lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day;
      newCount = isSameDay ? state.voiceLogsUsedToday + 1 : 1;
    }

    await prefs.setInt(_voiceCountKey, newCount);
    await prefs.setInt(_voiceDateKey, now.millisecondsSinceEpoch);

    state = state.copyWith(
      voiceLogsUsedToday: newCount,
      lastVoiceLogDate: now,
    );
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    super.dispose();
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);
