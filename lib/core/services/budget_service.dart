import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Budget State
// ─────────────────────────────────────────────

class BudgetState {
  final double monthlyBudget;
  final String countryCode;   // e.g. "IN"
  final String countryName;   // e.g. "India"
  final bool onboardingDone;

  const BudgetState({
    this.monthlyBudget = 0,
    this.countryCode = 'IN',
    this.countryName = 'India',
    this.onboardingDone = false,
  });

  bool get hasBudget => monthlyBudget > 0;

  /// percentage spent: 0.0–1.0+  (can exceed 1 if over budget)
  double spentFraction(double spent) =>
      monthlyBudget > 0 ? spent / monthlyBudget : 0;

  double remaining(double spent) => monthlyBudget - spent;

  BudgetState copyWith({
    double? monthlyBudget,
    String? countryCode,
    String? countryName,
    bool? onboardingDone,
  }) =>
      BudgetState(
        monthlyBudget: monthlyBudget ?? this.monthlyBudget,
        countryCode: countryCode ?? this.countryCode,
        countryName: countryName ?? this.countryName,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );
}

// ─────────────────────────────────────────────
// Budget Notifier
// ─────────────────────────────────────────────

class BudgetNotifier extends StateNotifier<BudgetState> {
  static const _budgetKey = 'monthly_budget';
  static const _countryCodeKey = 'country_code';
  static const _countryNameKey = 'country_name';
  static const _onboardingKey = 'onboarding_done';

  BudgetNotifier() : super(const BudgetState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = BudgetState(
      monthlyBudget: prefs.getDouble(_budgetKey) ?? 0,
      countryCode: prefs.getString(_countryCodeKey) ?? 'IN',
      countryName: prefs.getString(_countryNameKey) ?? 'India',
      onboardingDone: prefs.getBool(_onboardingKey) ?? false,
    );
  }

  Future<void> completeOnboarding({
    required double budget,
    required String countryCode,
    required String countryName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, budget);
    await prefs.setString(_countryCodeKey, countryCode);
    await prefs.setString(_countryNameKey, countryName);
    await prefs.setBool(_onboardingKey, true);
    state = BudgetState(
      monthlyBudget: budget,
      countryCode: countryCode,
      countryName: countryName,
      onboardingDone: true,
    );
  }

  Future<void> updateBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, budget);
    state = state.copyWith(monthlyBudget: budget);
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, false);
    state = state.copyWith(onboardingDone: false);
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────

final budgetProvider = StateNotifierProvider<BudgetNotifier, BudgetState>(
  (ref) => BudgetNotifier(),
);
