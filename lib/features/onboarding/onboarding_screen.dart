import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/services/budget_service.dart';
import 'package:money_pi/core/services/currency_service.dart';
import 'package:money_pi/features/dashboard/dashboard_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _budgetCtrl = TextEditingController();
  int _page = 0;

  // Country + currency selection
  String _countryCode = 'IN';
  String _countryName = 'India';
  CurrencyInfo _currency =
      const CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee', flag: '🇮🇳');

  static const _countries = [
    ('IN', 'India', 'INR'),
    ('US', 'United States', 'USD'),
    ('GB', 'United Kingdom', 'GBP'),
    ('AE', 'UAE', 'AED'),
    ('SG', 'Singapore', 'SGD'),
    ('AU', 'Australia', 'AUD'),
    ('CA', 'Canada', 'CAD'),
    ('DE', 'Germany', 'EUR'),
    ('FR', 'France', 'EUR'),
    ('JP', 'Japan', 'JPY'),
    ('CN', 'China', 'CNY'),
    ('CH', 'Switzerland', 'CHF'),
    ('MY', 'Malaysia', 'MYR'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;

    await ref.read(budgetProvider.notifier).completeOnboarding(
          budget: budget,
          countryCode: _countryCode,
          countryName: _countryName,
        );

    // Also set the currency
    await ref.read(currencyProvider.notifier).changeCurrency(_currency.code);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? tc.accent : tc.outlineVariant,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(tc: tc),
                  _CountryPage(
                    selected: _countryCode,
                    countries: _countries,
                    onSelect: (code, name, currCode) => setState(() {
                      _countryCode = code;
                      _countryName = name;
                      _currency = SupportedCurrencies.byCode(currCode);
                    }),
                    tc: tc,
                  ),
                  _BudgetPage(
                    controller: _budgetCtrl,
                    currency: _currency,
                    tc: tc,
                  ),
                ],
              ),
            ),

            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _next,
                  // Final step is the most action-forward moment — accent it.
                  style: _page == 2
                      ? ElevatedButton.styleFrom(
                          backgroundColor: tc.accent,
                          foregroundColor: Colors.white,
                        )
                      : null,
                  child: Text(
                    _page == 2 ? "Let's go!" : 'Continue',
                    style: AppFonts.sans(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: Welcome ─────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  final AppThemeColors tc;
  const _WelcomePage({required this.tc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: tc.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                color: tc.accent, size: 44),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 32),

          Text(
            'Budget Tracker',
            textAlign: TextAlign.center,
            style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

          const SizedBox(height: 14),

          Text(
            'Know exactly where your money goes.\nTrack spending, set budgets,\nand build better financial habits.',
            textAlign: TextAlign.center,
            style: AppFonts.sans(
              color: tc.onSurfaceVariant,
              fontSize: 15,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 180.ms),

          const SizedBox(height: 40),

          // Feature chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _FeatureChip('💸 Expense Tracking', tc),
              _FeatureChip('🎯 Monthly Budget', tc),
              _FeatureChip('📊 Analytics', tc),
              _FeatureChip('🔄 Recurring Rules', tc),
              _FeatureChip('🏦 Multi-account', tc),
              _FeatureChip('🎤 Voice Logging', tc),
            ],
          ).animate().fadeIn(delay: 260.ms),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final AppThemeColors tc;
  const _FeatureChip(this.label, this.tc);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Text(label,
            style: AppFonts.sans(
                color: tc.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

// ─── Page 2: Country & Currency ──────────────────────────
class _CountryPage extends StatelessWidget {
  final String selected;
  final List<(String, String, String)> countries;
  final void Function(String code, String name, String currCode) onSelect;
  final AppThemeColors tc;

  const _CountryPage({
    required this.selected,
    required this.countries,
    required this.onSelect,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where are you based?',
                  style: AppFonts.sans(
                      color: tc.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text("We'll set your currency automatically.",
                  style: AppFonts.sans(
                      color: tc.onSurfaceVariant, fontSize: 14)),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: countries.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: tc.outlineVariant),
            itemBuilder: (_, i) {
              final (code, name, currCode) = countries[i];
              final isSelected = code == selected;
              final currency = SupportedCurrencies.byCode(currCode);

              return InkWell(
                onTap: () => onSelect(code, name, currCode),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 14),
                  child: Row(
                    children: [
                      Text(currency.flag,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: AppFonts.sans(
                                    color: tc.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text(
                              '${currency.code} · ${currency.symbol} · ${currency.name}',
                              style: AppFonts.sans(
                                  color: tc.onSurfaceVariant, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? tc.accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? tc.accent : tc.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Page 3: Monthly Budget ───────────────────────────────
class _BudgetPage extends StatelessWidget {
  final TextEditingController controller;
  final CurrencyInfo currency;
  final AppThemeColors tc;

  const _BudgetPage({
    required this.controller,
    required this.currency,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your monthly\nspending limit',
            style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 10),

          Text(
            'How much do you plan to spend each month? You can always change this in Settings.',
            style: AppFonts.sans(
                color: tc.onSurfaceVariant, fontSize: 14, height: 1.5),
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 36),

          // Big amount input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tc.outlineVariant, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(currency.symbol,
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant,
                        fontSize: 28,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: false,
                    style: AppFonts.sans(
                        color: tc.onSurface,
                        fontSize: 36,
                        fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: AppFonts.sans(
                          color: tc.onSurfaceVariant,
                          fontSize: 36,
                          fontWeight: FontWeight.w800),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),

          const SizedBox(height: 20),

          // Quick-set suggestions
          Text('QUICK SET',
              style: AppFonts.sans(
                  color: tc.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestions(currency).map((s) {
              return GestureDetector(
                onTap: () {
                  controller.text = s.replaceAll(',', '');
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: tc.outlineVariant, width: 0.5),
                  ),
                  child: Text('${currency.symbol}$s',
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tc.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.outlineVariant, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: tc.onSurfaceVariant, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can skip this for now. Budget tracking is optional — the app works great without it.',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms),
        ],
      ),
    );
  }

  List<String> _suggestions(CurrencyInfo c) {
    switch (c.code) {
      case 'INR':
        return ['5,000', '10,000', '20,000', '30,000', '50,000'];
      case 'USD':
      case 'CAD':
      case 'AUD':
      case 'SGD':
        return ['500', '1,000', '2,000', '3,000', '5,000'];
      case 'GBP':
        return ['500', '1,000', '1,500', '2,500', '4,000'];
      case 'EUR':
        return ['500', '1,000', '1,500', '2,500', '4,000'];
      case 'AED':
        return ['1,000', '2,000', '5,000', '10,000', '15,000'];
      case 'JPY':
        return ['50,000', '100,000', '200,000', '300,000', '500,000'];
      default:
        return ['1,000', '2,000', '5,000', '10,000', '20,000'];
    }
  }
}
