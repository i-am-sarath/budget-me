import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/budget_service.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/theme_service.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/paywall/paywall_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final subscription = ref.watch(subscriptionProvider);
    final themeMode = ref.watch(themeProvider);
    final tc = AppThemeColors.of(context);
    final budget = ref.watch(budgetProvider);

    return Scaffold(
      backgroundColor: tc.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: tc.surface,
            floating: true,
            snap: true,
            elevation: 0,
            titleSpacing: 20,
            title: Text(
              'Settings',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Subscription card
                _SubscriptionCard(subscription: subscription)
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.12, end: 0),
                const SizedBox(height: 28),

                // Appearance
                _SectionLabel('APPEARANCE'),
                const SizedBox(height: 10),
                _ThemeCard(themeMode: themeMode)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 50.ms),
                const SizedBox(height: 28),

                // Budget
                _SectionLabel('MONTHLY BUDGET'),
                const SizedBox(height: 10),
                _BudgetSettingsCard(budget: budget)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 80.ms),
                const SizedBox(height: 28),

                // Currency
                _SectionLabel('CURRENCY'),
                const SizedBox(height: 10),
                _CurrencySection(currency: currency)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 100.ms),
                const SizedBox(height: 28),

                // Voice usage
                _SectionLabel('VOICE'),
                const SizedBox(height: 10),
                _VoiceCard(subscription: subscription)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 150.ms),
                const SizedBox(height: 28),

                // About
                _SectionLabel('ABOUT'),
                const SizedBox(height: 10),
                _AboutCard()
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 200.ms),
                const SizedBox(height: 28),

                // Subscription management
                _SectionLabel('SUBSCRIPTION'),
                const SizedBox(height: 10),
                _SubscriptionManagementCard(subscription: subscription)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 220.ms),
                const SizedBox(height: 28),

                // Danger zone
                _SectionLabel('DANGER ZONE'),
                const SizedBox(height: 10),
                _ResetDataCard()
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 260.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.inter(
          color: AppThemeColors.of(context).onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

// ─────────────────────────────────────────────
// Subscription Card
// ─────────────────────────────────────────────

class _SubscriptionCard extends ConsumerWidget {
  final SubscriptionState subscription;
  const _SubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = subscription.isPro;
    final tc = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPro ? tc.onSurface : tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPro ? Colors.transparent : tc.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPro
                  ? tc.surface.withOpacity(0.15)
                  : tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPro
                  ? Icons.verified_rounded
                  : Icons.workspace_premium_outlined,
              color: isPro ? tc.surface : tc.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro ? 'Budget Me Pro' : 'Free Plan',
                  style: GoogleFonts.inter(
                    color: isPro ? tc.surface : tc.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isPro
                      ? 'Unlimited · Cloud sync active'
                      : '${SubscriptionState.freeVoiceLogLimit} voice logs/month · Local only',
                  style: GoogleFonts.inter(
                    color: isPro
                        ? tc.surface.withOpacity(0.6)
                        : tc.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isPro)
            GestureDetector(
              onTap: () => showPaywall(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tc.onSurface,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Upgrade',
                  style: GoogleFonts.inter(
                    color: tc.surface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Theme Card
// ─────────────────────────────────────────────

class _ThemeCard extends ConsumerWidget {
  final ThemeMode themeMode;
  const _ThemeCard({required this.themeMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final modes = [
      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: modes.map((m) {
          final isSelected = themeMode == m.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setMode(m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? tc.onSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      m.$3,
                      color: isSelected ? tc.surface : tc.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.$2,
                      style: GoogleFonts.inter(
                        color: isSelected ? tc.surface : tc.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Currency Section
// ─────────────────────────────────────────────

class _CurrencySection extends ConsumerWidget {
  final CurrencyState currency;
  const _CurrencySection({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: Row(
            children: [
              Text(currency.currency.flag,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currency.currency.name,
                        style: GoogleFonts.inter(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                    Text(currency.currency.code,
                        style: GoogleFonts.inter(
                          color: tc.onSurfaceVariant,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              Text(
                currency.currency.symbol,
                style: GoogleFonts.inter(
                  color: tc.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SupportedCurrencies.all.map((c) {
            final isSelected = c.code == currency.currency.code;
            return GestureDetector(
              onTap: () async {
                await ref
                    .read(currencyProvider.notifier)
                    .changeCurrency(c.code);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? tc.onSurface : tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : tc.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.flag, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      c.code,
                      style: GoogleFonts.inter(
                        color: isSelected ? tc.surface : tc.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (currency.lastUpdated != null) ...[
          const SizedBox(height: 8),
          Text(
            'Rates updated ${_fmtDate(currency.lastUpdated!)}',
            style: GoogleFonts.inter(
              color: tc.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────
// Voice Card
// ─────────────────────────────────────────────

class _VoiceCard extends StatelessWidget {
  final SubscriptionState subscription;
  const _VoiceCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final isPro = subscription.isPro;
    final used = subscription.voiceLogsUsedThisMonth;
    final max = SubscriptionState.freeVoiceLogLimit;
    final progress = isPro ? 1.0 : (max > 0 ? (used / max).clamp(0.0, 1.0) : 0.0);
    final tc = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded, color: tc.onSurface, size: 18),
              const SizedBox(width: 8),
              Text(
                isPro
                    ? 'Unlimited voice logs'
                    : 'This month: $used / $max',
                style: GoogleFonts.inter(
                  color: tc.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (!isPro) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: tc.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? tc.expense : tc.onSurface,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subscription.canUseVoice
                  ? '${subscription.voiceLogsRemaining} voice logs remaining this month'
                  : 'Limit reached. Resets next month.',
              style: GoogleFonts.inter(
                color: subscription.canUseVoice
                    ? tc.onSurfaceVariant
                    : tc.expense,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// About Card
// ─────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          _AboutRow(label: 'Version', value: '1.0.0'),
          Divider(height: 1, color: tc.outlineVariant),
          _AboutRow(
            label: 'Privacy Policy',
            hasArrow: true,
            onTap: () => launchUrl(
              Uri.parse('https://i-am-sarath.github.io/budget-me/privacy'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          Divider(height: 1, color: tc.outlineVariant),
          _AboutRow(
            label: 'Terms of Service',
            hasArrow: true,
            onTap: () => launchUrl(
              Uri.parse('https://i-am-sarath.github.io/budget-me/terms'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool hasArrow;
  final VoidCallback? onTap;

  const _AboutRow({
    required this.label,
    this.value,
    this.hasArrow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: tc.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (value != null)
            Text(
              value!,
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          else if (hasArrow)
            Icon(Icons.chevron_right_rounded,
                color: tc.onSurfaceVariant, size: 18),
        ],
      ),
    ));
  }
}

// ─────────────────────────────────────────────
// Budget Settings Card
// ─────────────────────────────────────────────

class _BudgetSettingsCard extends ConsumerStatefulWidget {
  final BudgetState budget;
  const _BudgetSettingsCard({required this.budget});

  @override
  ConsumerState<_BudgetSettingsCard> createState() =>
      _BudgetSettingsCardState();
}

class _BudgetSettingsCardState extends ConsumerState<_BudgetSettingsCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.budget.monthlyBudget > 0
          ? widget.budget.monthlyBudget.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.budget.hasBudget
                ? 'Current limit: ${currency.format(widget.budget.monthlyBudget)}'
                : 'No budget set yet',
            style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(currency.currency.symbol,
                      style: GoogleFonts.inter(
                          color: tc.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                      color: tc.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Enter monthly budget',
                    hintStyle: GoogleFonts.inter(
                        color: tc.onSurfaceVariant, fontSize: 14),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final val = double.tryParse(_ctrl.text) ?? 0;
                  await ref.read(budgetProvider.notifier).updateBudget(val);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val > 0
                            ? 'Budget set to ${currency.format(val)}'
                            : 'Budget cleared'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: tc.onSurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Save',
                      style: GoogleFonts.inter(
                          color: tc.surface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Subscription Management Card
// ─────────────────────────────────────────────

class _SubscriptionManagementCard extends ConsumerWidget {
  final SubscriptionState subscription;
  const _SubscriptionManagementCard({required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          // Restore Purchases
          _SettingsTile(
            icon: Icons.restore_rounded,
            label: 'Restore Purchases',
            sub: 'Already subscribed on another device?',
            tc: tc,
            onTap: () async {
              try {
                final info = await Purchases.restorePurchases();
                final isPro = info.entitlements.active
                    .containsKey(ApiConfig.entitlementPro);
                ref.invalidate(subscriptionProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isPro
                        ? '✓ Pro restored! Welcome back.'
                        : 'No active subscription found.'),
                  ));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restore failed. Try again.')),
                  );
                }
              }
            },
          ),

          Divider(height: 1, color: tc.outlineVariant),

          // Upgrade / Manage
          if (subscription.isPro)
            _SettingsTile(
              icon: Icons.manage_accounts_rounded,
              label: 'Manage Subscription',
              sub: 'Cancel, change plan, or get help',
              tc: tc,
              onTap: () async {
                try {
                  await RevenueCatUI.presentCustomerCenter();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('To cancel, open Play Store → Subscriptions.'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
            )
          else
            _SettingsTile(
              icon: Icons.workspace_premium_rounded,
              label: 'Upgrade to Pro',
              sub: 'Unlock voice logs, charts & more',
              tc: tc,
              onTap: () => showPaywall(context),
            ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final AppThemeColors tc;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tc.onSurface, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            color: tc.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(sub,
                        style: GoogleFonts.inter(
                            color: tc.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: tc.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────
// Reset All Data Card
// ─────────────────────────────────────────────

class _ResetDataCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.expense.withOpacity(0.3), width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _confirmReset(context, ref, tc),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tc.expense.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete_forever_rounded,
                    color: tc.expense, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset All Data',
                        style: GoogleFonts.inter(
                            color: tc.expense,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text('Delete all transactions, accounts & recurring rules',
                        style: GoogleFonts.inter(
                            color: tc.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: tc.expense.withOpacity(0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(
      BuildContext context, WidgetRef ref, AppThemeColors tc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerHigh,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset all data?',
          style: GoogleFonts.inter(
              color: tc.onSurface, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete all your transactions, accounts, and recurring rules. This cannot be undone.',
          style: GoogleFonts.inter(
              color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: tc.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tc.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _doReset(context, ref);
            },
            child: Text('Reset Everything',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _doReset(BuildContext context, WidgetRef ref) async {
    try {
      await DatabaseHelper().clearAllData();

      // Clear voice log usage counter
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('voice_logs_month');
      await prefs.remove('voice_logs_month_id');

      // Refresh all providers so UI updates immediately
      ref.invalidate(transactionListProvider);
      ref.invalidate(accountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset failed: $e')),
        );
      }
    }
  }
}
