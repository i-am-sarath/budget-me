import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:google_fonts/google_fonts.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final bool isSheet;
  const PaywallScreen({super.key, this.isSheet = true});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isAnnual = true;

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final tc = AppThemeColors.of(context);

    final content = SafeArea(
      child: Stack(
        children: [
          // Close
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tc.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded,
                    color: tc.onSurfaceVariant, size: 16),
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tc.onSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.workspace_premium_rounded,
                      color: tc.surface, size: 34),
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                const SizedBox(height: 20),

                Text(
                  'Budget Tracker Pro',
                  style: GoogleFonts.inter(
                    color: tc.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.2),

                const SizedBox(height: 6),

                Text(
                  'Voice-log without limits.\nSync everywhere. Never lose a transaction.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 120.ms),

                const SizedBox(height: 28),

                // Feature list
                ..._features.asMap().entries.map((e) {
                  return _FeatureRow(
                    icon: e.value.$1,
                    label: e.value.$2,
                    sub: e.value.$3,
                  ).animate().fadeIn(delay: (180 + e.key * 55).ms).slideX(begin: -0.08);
                }),

                const SizedBox(height: 28),

                // Plan toggle
                _PlanToggle(
                  isAnnual: _isAnnual,
                  onChanged: (v) => setState(() => _isAnnual = v),
                  sub: sub,
                ).animate().fadeIn(delay: 440.ms).slideY(begin: 0.1),

                const SizedBox(height: 16),

                // CTA
                _PurchaseButton(
                  isAnnual: _isAnnual,
                  sub: sub,
                  onPurchase: () => _handlePurchase(sub),
                ).animate().fadeIn(delay: 480.ms).slideY(begin: 0.1),

                const SizedBox(height: 10),

                TextButton(
                  onPressed:
                      sub.isLoading ? null : () => _handleRestore(sub),
                  child: Text(
                    'Restore purchases',
                    style: GoogleFonts.inter(
                      color: tc.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ).animate().fadeIn(delay: 520.ms),

                Text(
                  'Cancel anytime · Secure payment via Google / Apple',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ).animate().fadeIn(delay: 560.ms),
              ],
            ),
          ),
        ],
      ),
    );

    final bgColor = AppThemeColors.of(context).surface;

    if (widget.isSheet) {
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
              color: AppThemeColors.of(context).outlineVariant, width: 0.5),
        ),
        child: content,
      );
    }
    return Scaffold(backgroundColor: bgColor, body: content);
  }

  Future<void> _handlePurchase(SubscriptionState sub) async {
    // If no packages loaded (RC not configured), show a friendly dialog
    if (!sub.hasOfferings) {
      _showNotConfiguredDialog();
      return;
    }

    final error = _isAnnual
        ? await ref.read(subscriptionProvider.notifier).purchaseAnnual()
        : await ref.read(subscriptionProvider.notifier).purchaseMonthly();

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      final updatedSub = ref.read(subscriptionProvider);
      if (updatedSub.isPro && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to Pro! 🎉')),
        );
      }
    }
  }

  Future<void> _handleRestore(SubscriptionState sub) async {
    if (!sub.hasOfferings) {
      _showNotConfiguredDialog();
      return;
    }
    final error =
        await ref.read(subscriptionProvider.notifier).restorePurchases();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(error ?? 'Purchases restored successfully!')),
    );
    if (error == null && mounted) Navigator.pop(context);
  }

  void _showNotConfiguredDialog() {
    final tc = AppThemeColors.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'In-app purchases',
          style: GoogleFonts.inter(
              color: tc.onSurface, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Store payments are not yet configured for this build. Pro features will be available when the app is published.',
          style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.inter(
                    color: tc.onSurface, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Features
// ─────────────────────────────────────────────

const _features = [
  (Icons.mic_rounded, 'Unlimited voice logs', 'No 1/day limit'),
  (Icons.cloud_sync_rounded, 'Cloud sync', 'Access on any device'),
  (Icons.receipt_long_rounded, 'Full transaction history', 'View & export all records'),
  (Icons.trending_up_rounded, 'Investment tracking', 'Portfolio insights'),
  (Icons.repeat_rounded, 'Unlimited recurring rules', 'DigiGold, SIP and more'),
];

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _FeatureRow({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tc.onSurface, size: 18),
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
                        fontSize: 13)),
                Text(sub,
                    style: GoogleFonts.inter(
                        color: tc.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.check_rounded, color: tc.onSurface, size: 18),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Plan Toggle
// ─────────────────────────────────────────────

class _PlanToggle extends StatelessWidget {
  final bool isAnnual;
  final ValueChanged<bool> onChanged;
  final SubscriptionState sub;

  const _PlanToggle({
    required this.isAnnual,
    required this.onChanged,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          _PlanOption(
            label: 'Monthly',
            price: _price(sub.monthlyPackage, '\$3.99'),
            subLabel: '/month',
            isSelected: !isAnnual,
            onTap: () => onChanged(false),
            badge: null,
            tc: tc,
          ),
          _PlanOption(
            label: 'Annual',
            price: _price(sub.annualPackage, '\$29.99'),
            subLabel: _annualPerMonth(sub.annualPackage).isNotEmpty
                ? '${_annualPerMonth(sub.annualPackage)} · Save 37%'
                : '/year · Save 37%',
            isSelected: isAnnual,
            onTap: () => onChanged(true),
            badge: 'Best Value',
            tc: tc,
          ),
        ],
      ),
    );
  }

  /// Returns the localised price string from the store (e.g. "$3.99", "₹199").
  /// Falls back to a USD/INR hint if RevenueCat hasn't loaded offerings yet.
  String _price(Package? pkg, String usdFallback) {
    if (pkg == null) return usdFallback;
    return pkg.storeProduct.priceString; // always localised by the store
  }

  /// Returns the per-month equivalent for the annual plan.
  String _annualPerMonth(Package? pkg) {
    if (pkg == null) return '';
    final monthly = pkg.storeProduct.price / 12;
    // Replicate the currency symbol from the priceString
    final symbol = pkg.storeProduct.priceString
        .replaceAll(RegExp(r'[\d.,\s]+'), '').trim();
    return '$symbol${monthly.toStringAsFixed(2)}/mo';
  }
}

class _PlanOption extends StatelessWidget {
  final String label;
  final String price;
  final String subLabel;   // e.g. "/month" or "₹12.50/mo · Save 37%"
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;
  final AppThemeColors tc;

  const _PlanOption({
    required this.label,
    required this.price,
    required this.subLabel,
    required this.isSelected,
    required this.onTap,
    required this.badge,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? tc.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tc.surface.withOpacity(0.2)
                        : tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.inter(
                      color: isSelected ? tc.surface : tc.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox(height: 22),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? tc.surface : tc.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: GoogleFonts.inter(
                  color: isSelected ? tc.surface : tc.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isSelected
                      ? tc.surface.withOpacity(0.7)
                      : tc.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Purchase Button
// ─────────────────────────────────────────────

class _PurchaseButton extends StatelessWidget {
  final bool isAnnual;
  final SubscriptionState sub;
  final VoidCallback onPurchase;

  const _PurchaseButton({
    required this.isAnnual,
    required this.sub,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final label = isAnnual ? 'Start Annual Plan' : 'Start Monthly Plan';

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: sub.isLoading ? null : onPurchase,
        child: sub.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: tc.surface,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────

/// Shows the RevenueCat paywall if the user doesn't already have [entitlementPro].
/// Falls back to the custom [PaywallScreen] if the RC paywall isn't configured.
Future<void> showPaywall(BuildContext context) async {
  try {
    await RevenueCatUI.presentPaywallIfNeeded(ApiConfig.entitlementPro);
  } catch (_) {
    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => const PaywallScreen(isSheet: true),
      );
    }
  }
}
