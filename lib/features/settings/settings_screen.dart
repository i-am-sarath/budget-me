import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:money_pi/core/config/api_config.dart';
import 'package:money_pi/core/database/database_helper.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/services/currency_service.dart';
import 'package:money_pi/core/services/overlay_service.dart';
import 'package:money_pi/core/services/sheets_sync_service.dart';
import 'package:money_pi/core/services/subscription_service.dart';
import 'package:money_pi/core/services/theme_service.dart';
import 'package:money_pi/features/accounts/repositories/account_repository.dart';
import 'package:money_pi/features/transactions/repositories/transaction_repository.dart';
import 'package:money_pi/features/paywall/paywall_screen.dart';
import 'package:money_pi/features/auth/widgets/account_sheet.dart';
import 'package:money_pi/core/services/auth_service.dart';
import 'package:money_pi/features/groups/providers/groups_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final subscription = ref.watch(subscriptionProvider);
    final themeMode = ref.watch(themeProvider);
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
              style: AppFonts.sans(
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

                // Account (sign in / sign up / log out)
                _SectionLabel('ACCOUNT'),
                const SizedBox(height: 10),
                const _AuthCard()
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 30.ms),
                const SizedBox(height: 28),

                // Appearance
                _SectionLabel('APPEARANCE'),
                const SizedBox(height: 10),
                _ThemeCard(themeMode: themeMode)
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 50.ms),
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

                // Always-on quick-log overlay (Android only)
                if (OverlayService.isSupported) ...[
                  _SectionLabel('QUICK LOG'),
                  const SizedBox(height: 10),
                  _OverlayToggleCard()
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 170.ms),
                  const SizedBox(height: 28),
                ],

                // Google Sheets one-way sync (opt-in, privacy-first)
                _SectionLabel('GOOGLE SHEETS'),
                const SizedBox(height: 10),
                _SheetsSyncCard()
                    .animate()
                    .fadeIn(duration: 350.ms, delay: 185.ms),
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

                // Account (cloud sign-in) — only when cloud sync is configured.
                if (ref.watch(cloudEnabledProvider)) ...[
                  _SectionLabel('ACCOUNT'),
                  const SizedBox(height: 10),
                  _AccountCard()
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 240.ms),
                  const SizedBox(height: 28),
                ],

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
        style: AppFonts.sans(
          color: AppThemeColors.of(context).onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

// ─────────────────────────────────────────────
// Account Card (sign in / sign up / log out)
// ─────────────────────────────────────────────

class _AuthCard extends ConsumerWidget {
  const _AuthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final account = ref.watch(authProvider);

    if (account.signedIn) {
      final name = account.displayName;
      final email = account.email ?? '';
      final initial =
          (name.isNotEmpty ? name.characters.first : '?').toUpperCase();
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: AppFonts.sans(
                    color: tc.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sans(
                        color: tc.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sans(
                          color: tc.onSurfaceVariant, fontSize: 12),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _confirmLogout(context, ref),
              style: TextButton.styleFrom(foregroundColor: tc.error),
              child: Text('Log out',
                  style: AppFonts.sans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    // Signed out → invite to sign in / sign up.
    return GestureDetector(
      onTap: () => requireAccount(
        context,
        ref,
        reason: 'Sign in to sync across devices, log by voice, and connect '
            'Google Sheets.',
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_outline_rounded,
                  color: tc.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign in or sign up',
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text('For voice logging, Sheets & multi-device sync',
                      style: AppFonts.sans(
                          color: tc.onSurfaceVariant, fontSize: 12)),
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final tc = AppThemeColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log out?',
            style:
                AppFonts.sans(color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
          'You can keep using manual entry, but voice, Sheets sync and '
          'multi-device sync will be turned off until you sign back in.',
          style: AppFonts.sans(
              color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AppFonts.sans(color: tc.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: tc.error),
            child: Text('Log out',
                style: AppFonts.sans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }
}

// ─────────────────────────────────────────────
// Google Sheets sync Card
// ─────────────────────────────────────────────

class _SheetsSyncCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final sync = ref.watch(sheetsSyncProvider);
    const sheetsGreen = Color(0xFF188038);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
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
                  color: sheetsGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: sheetsGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sync.connected ? 'Connected' : 'Sync to Google Sheets',
                      style: AppFonts.sans(
                        color: tc.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sync.connected
                          ? (sync.email ?? 'Your sheet is up to date')
                          : 'Mirror every transaction to your own sheet',
                      style: AppFonts.sans(
                        color: tc.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Private by design — we can only see the one sheet we create for you, '
            'nothing else in your Drive.',
            style: AppFonts.sans(
              color: tc.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (sync.connected) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sync.url == null
                        ? null
                        : () => launchUrl(Uri.parse(sync.url!),
                            mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text('Open sheet',
                        style: AppFonts.sans(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: tc.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: sync.isBusy
                        ? null
                        : () => ref.read(sheetsSyncProvider.notifier).disconnect(),
                    child: Text('Disconnect',
                        style: AppFonts.sans(
                            color: tc.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sync.isBusy
                    ? null
                    : () async {
                        // Sheets sync requires a signed-in account…
                        final hasAccount = await requireAccount(
                          context,
                          ref,
                          reason:
                              'Sign in to connect Google Sheets and auto-sync your transactions.',
                        );
                        if (!hasAccount || !context.mounted) return;
                        // …and is a Pro feature (with a 14-day trial). Send
                        // non-Pro users to the paywall first.
                        if (!ref.read(subscriptionProvider).isPro) {
                          await showPaywall(context);
                          if (!context.mounted ||
                              !ref.read(subscriptionProvider).isPro) {
                            return;
                          }
                        }
                        final err = await ref
                            .read(sheetsSyncProvider.notifier)
                            .connect();
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err)),
                          );
                        }
                      },
                icon: sync.isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  sync.isBusy ? 'Connecting…' : 'Connect Google Sheets',
                  style: AppFonts.sans(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tc.onSurface,
                  foregroundColor: tc.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  isPro ? 'Money Pi Pro' : 'Free Plan',
                  style: AppFonts.sans(
                    color: isPro ? tc.surface : tc.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isPro
                      ? 'Unlimited voice logs · All features unlocked'
                      : '${SubscriptionState.freeVoiceLogLimit} voice logs/month',
                  style: AppFonts.sans(
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
                  style: AppFonts.sans(
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
                      style: AppFonts.sans(
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
                        style: AppFonts.sans(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                    Text(currency.currency.code,
                        style: AppFonts.sans(
                          color: tc.onSurfaceVariant,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              Text(
                currency.currency.symbol,
                style: AppFonts.sans(
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
                      style: AppFonts.sans(
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
            style: AppFonts.sans(
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
                style: AppFonts.sans(
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
              style: AppFonts.sans(
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
            style: AppFonts.sans(
              color: tc.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (value != null)
            Text(
              value!,
              style: AppFonts.sans(
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
                        style: AppFonts.sans(
                            color: tc.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(sub,
                        style: AppFonts.sans(
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
                        style: AppFonts.sans(
                            color: tc.expense,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text('Delete all transactions, accounts & recurring rules',
                        style: AppFonts.sans(
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
          style: AppFonts.sans(
              color: tc.onSurface, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete all your transactions, accounts, and recurring rules. This cannot be undone.',
          style: AppFonts.sans(
              color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppFonts.sans(color: tc.onSurfaceVariant)),
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
                style: AppFonts.sans(fontWeight: FontWeight.w700)),
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

// ─────────────────────────────────────────────
// Always-on overlay toggle (Android only)
// ─────────────────────────────────────────────

class _OverlayToggleCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final enabled = ref.watch(overlayEnabledProvider);

    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outline, width: 1.0),
      ),
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
              child: Icon(Icons.bubble_chart_rounded,
                  color: tc.onSurface, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Floating quick-log bubble',
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    'Show a draggable button over other apps for instant logging',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              onChanged: (v) => _toggle(context, ref, v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool target) async {
    final notifier = ref.read(overlayEnabledProvider.notifier);
    if (target) {
      final err = await notifier.turnOn();
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    } else {
      await notifier.turnOff();
    }
  }
}

// ─────────────────────────────────────────────
// Account Card (cloud sign-in / sign-out / delete account)
// ─────────────────────────────────────────────

class _AccountCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final auth = ref.watch(cloudAuthProvider);

    if (!auth.isSignedIn) {
      return Container(
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: _SettingsTile(
          icon: Icons.login_rounded,
          label: 'Sign in',
          sub: 'Sign in to share spending with groups',
          tc: tc,
          onTap: () => ref.read(cloudAuthProvider.notifier).signIn(),
        ),
      );
    }

    final email = auth.user?.email ?? 'Signed in';

    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          // Signed-in identity
          Padding(
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
                  child: Icon(Icons.person_rounded, color: tc.onSurface, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in',
                          style: AppFonts.sans(
                              color: tc.onSurfaceVariant, fontSize: 11)),
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.sans(
                              color: tc.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tc.outlineVariant),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            sub: 'Sign out on this device',
            tc: tc,
            onTap: () => ref.read(cloudAuthProvider.notifier).signOut(),
          ),
          Divider(height: 1, color: tc.outlineVariant),
          // Delete account — required by Google Play account-deletion policy.
          InkWell(
            onTap: () => _confirmDelete(context, ref, tc),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tc.expense.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_off_rounded,
                        color: tc.expense, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delete Account',
                            style: AppFonts.sans(
                                color: tc.expense,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text('Permanently delete your account & cloud data',
                            style: AppFonts.sans(
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
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppThemeColors tc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete your account?',
            style:
                AppFonts.sans(color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
          'This permanently deletes your account and all your shared group data '
          'from the cloud. Groups you created will be removed for everyone. '
          'This cannot be undone.\n\nYour on-device transactions stay on this '
          'phone — use "Reset All Data" to remove those too.',
          style:
              AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: AppFonts.sans(color: tc.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tc.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _doDelete(context, ref);
            },
            child: Text('Delete Account',
                style: AppFonts.sans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cloudAuthProvider.notifier).deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account has been deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}
