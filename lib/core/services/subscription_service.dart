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
  final int voiceLogsUsedThisMonth;
  final DateTime? lastVoiceLogDate;
  final bool isLoading;
  final Package? monthlyPackage;
  final Package? annualPackage;
  final Package? lifetimePackage;
  final CustomerInfo? customerInfo;

  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.voiceLogsUsedThisMonth = 0,
    this.lastVoiceLogDate,
    this.isLoading = false,
    this.monthlyPackage,
    this.annualPackage,
    this.lifetimePackage,
    this.customerInfo,
  });

  bool get isPro => tier == SubscriptionTier.pro;

  /// Free users get 100 voice logs per month.
  static const int freeVoiceLogLimit = 100;

  bool get canUseVoice => isPro || voiceLogsUsedThisMonth < freeVoiceLogLimit;

  int get voiceLogsRemaining => isPro ? -1 : (freeVoiceLogLimit - voiceLogsUsedThisMonth).clamp(0, freeVoiceLogLimit); // -1 = unlimited sentinel

  bool get hasCloudSync => false;

  bool get hasOfferings => monthlyPackage != null || annualPackage != null || lifetimePackage != null;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    int? voiceLogsUsedThisMonth,
    DateTime? lastVoiceLogDate,
    bool? isLoading,
    Package? monthlyPackage,
    Package? annualPackage,
    Package? lifetimePackage,
    CustomerInfo? customerInfo,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      voiceLogsUsedThisMonth: voiceLogsUsedThisMonth ?? this.voiceLogsUsedThisMonth,
      lastVoiceLogDate: lastVoiceLogDate ?? this.lastVoiceLogDate,
      isLoading: isLoading ?? this.isLoading,
      monthlyPackage: monthlyPackage ?? this.monthlyPackage,
      annualPackage: annualPackage ?? this.annualPackage,
      lifetimePackage: lifetimePackage ?? this.lifetimePackage,
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
  static const _voiceCountKey = 'voice_logs_month';
  static const _voiceMonthKey = 'voice_logs_month_id';

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
    final now = DateTime.now();
    final currentMonthId = '${now.year}-${now.month}';
    final storedMonthId = prefs.getString(_voiceMonthKey);

    int count = 0;
    if (storedMonthId == currentMonthId) {
      count = prefs.getInt(_voiceCountKey) ?? 0;
    }

    state = state.copyWith(
      voiceLogsUsedThisMonth: count,
      lastVoiceLogDate: DateTime.tryParse(storedMonthId ?? ''),
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
      Package? lifetime;

      for (final pkg in current.availablePackages) {
        if (pkg.packageType == PackageType.monthly) monthly = pkg;
        if (pkg.packageType == PackageType.annual) annual = pkg;
        if (pkg.packageType == PackageType.lifetime) lifetime = pkg;
      }

      state = state.copyWith(
        monthlyPackage: monthly,
        annualPackage: annual,
        lifetimePackage: lifetime,
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

  Future<String?> purchaseLifetime() async {
    final pkg = state.lifetimePackage;
    if (pkg == null) return 'Lifetime plan not available';
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
    final currentMonthId = '${now.year}-${now.month}';
    final storedMonthId = prefs.getString(_voiceMonthKey);

    int newCount;
    if (storedMonthId == currentMonthId) {
      newCount = state.voiceLogsUsedThisMonth + 1;
    } else {
      newCount = 1; // new month, reset
    }

    await prefs.setInt(_voiceCountKey, newCount);
    await prefs.setString(_voiceMonthKey, currentMonthId);

    state = state.copyWith(
      voiceLogsUsedThisMonth: newCount,
      lastVoiceLogDate: now,
    );
  }

  Future<void> addBonusVoiceLogs(int count) async {
    if (state.isPro) return;
    final prefs = await SharedPreferences.getInstance();
    final newCount = (state.voiceLogsUsedThisMonth - count).clamp(0, SubscriptionState.freeVoiceLogLimit);
    await prefs.setInt(_voiceCountKey, newCount);
    state = state.copyWith(voiceLogsUsedThisMonth: newCount);
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
