import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/categories/screens/categories_screen.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/theme_service.dart';
import 'package:agent_money/core/services/voice_language_service.dart';
import 'package:agent_money/core/providers/overlay_settings_provider.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/overlay/overlay_permission_service.dart';
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
    final voiceLang = ref.watch(voiceLanguageProvider);
    final tc = AppThemeColors.of(context);

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

                // Categories
                _SectionLabel('CATEGORIES'),
                const SizedBox(height: 10),
                _CategoriesCard()
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

                // Voice usage + language
                _SectionLabel('VOICE'),
                const SizedBox(height: 10),
                _VoiceCard(subscription: subscription)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 150.ms),
                const SizedBox(height: 10),
                _VoiceLanguageCard(currentCode: voiceLang)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 165.ms),
                const SizedBox(height: 28),

                // Floating overlay button (Android only)
                if (Platform.isAndroid) ...[
                  _SectionLabel('FLOATING BUTTON'),
                  const SizedBox(height: 10),
                  const _OverlayMicCard()
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 170.ms),
                ],
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
                      ? 'Unlimited voice AI logging'
                      : '${SubscriptionState.freeVoiceLogLimit} voice logs/month',
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
// Voice Language Card
// ─────────────────────────────────────────────

class _VoiceLanguageCard extends ConsumerWidget {
  final String currentCode;
  const _VoiceLanguageCard({required this.currentCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final current = voiceLanguageOptions
        .firstWhere((o) => o.$1 == currentCode,
            orElse: () => voiceLanguageOptions.first);

    return GestureDetector(
      onTap: () => _showPicker(context, ref, tc),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Text(current.$3, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice language',
                    style: GoogleFonts.inter(
                      color: tc.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    current.$2,
                    style: GoogleFonts.inter(
                      color: tc.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
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

  void _showPicker(
      BuildContext context, WidgetRef ref, AppThemeColors tc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Voice Language',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Helps Whisper transcribe accurately',
              style: GoogleFonts.inter(
                  color: tc.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...voiceLanguageOptions.map((opt) {
              final isSelected = opt.$1 == currentCode;
              return GestureDetector(
                onTap: () {
                  ref
                      .read(voiceLanguageProvider.notifier)
                      .setLanguage(opt.$1);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tc.onSurface
                        : tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(opt.$3,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Text(
                        opt.$2,
                        style: GoogleFonts.inter(
                          color:
                              isSelected ? tc.surface : tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        Icon(Icons.check_rounded,
                            color: tc.surface, size: 18),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
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
          _AboutRow(label: 'Privacy Policy', hasArrow: true),
          Divider(height: 1, color: tc.outlineVariant),
          _AboutRow(label: 'Terms of Service', hasArrow: true),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool hasArrow;

  const _AboutRow({
    required this.label,
    this.value,
    this.hasArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Padding(
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
    );
  }
}

// ─────────────────────────────────────────────
// Categories Card
// ─────────────────────────────────────────────

class _CategoriesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: _SettingsTile(
        icon: Icons.category_outlined,
        label: 'Manage Categories',
        sub: 'Add, edit or delete expense, income and investment categories',
        tc: tc,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CategoriesScreen()),
        ),
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
// Floating Overlay Mic Card (Android)
// ─────────────────────────────────────────────

class _OverlayMicCard extends ConsumerStatefulWidget {
  const _OverlayMicCard();

  @override
  ConsumerState<_OverlayMicCard> createState() => _OverlayMicCardState();
}

class _OverlayMicCardState extends ConsumerState<_OverlayMicCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoEnableIfPermitted();
  }

  Future<void> _autoEnableIfPermitted() async {
    if (!Platform.isAndroid) return;
    final isEnabled = ref.read(overlaySettingsProvider);
    if (isEnabled) return;
    final hasOverlay = await OverlayPermissionService.hasOverlayPermission();
    final hasMic = await OverlayPermissionService.hasMicPermission();
    if (hasOverlay && hasMic && mounted) {
      await ref.read(overlaySettingsProvider.notifier).enable();
    }
  }

  Future<void> _onToggle(bool value) async {
    if (value) {
      final hasOverlay = await OverlayPermissionService.hasOverlayPermission();
      if (!hasOverlay) {
        _showOverlayPermissionDialog();
        return;
      }
      final hasMic = await OverlayPermissionService.hasMicPermission();
      if (!hasMic) {
        final granted = await OverlayPermissionService.requestMicPermission();
        if (!granted) return;
      }
      await ref.read(overlaySettingsProvider.notifier).enable();
    } else {
      await ref.read(overlaySettingsProvider.notifier).disable();
    }
  }

  void _showOverlayPermissionDialog() {
    final tc = AppThemeColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Overlay Permission',
          style: GoogleFonts.inter(
              color: tc.onSurface, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Budget Me needs "Display over other apps" permission to show the floating mic button on top of other apps.\n\nTap "Open Settings", enable the permission, then return here.',
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
              backgroundColor: tc.onSurface,
              foregroundColor: tc.surface,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await OverlayPermissionService.requestOverlayPermission();
            },
            child: Text('Open Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(overlaySettingsProvider);
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? tc.onSurface
                      : tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: isEnabled ? tc.surface : tc.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Floating mic button',
                      style: GoogleFonts.inter(
                        color: tc.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Hold to record from any screen',
                      style: GoogleFonts.inter(
                        color: tc.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: _onToggle,
                activeColor: tc.onSurface,
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: tc.onSurfaceVariant, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account balances update when you next open Budget Me.',
                      style: GoogleFonts.inter(
                        color: tc.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
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
