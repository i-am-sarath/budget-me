import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/subscriptions/models/subscription_model.dart';
import 'package:agent_money/features/subscriptions/repositories/subscription_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(subscriptionListProvider);
    final currency = ref.watch(currencyProvider);
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
              'Subscriptions',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add_rounded, color: tc.onSurface),
                tooltip: 'Add subscription',
                onPressed: () => _showAddSheet(context, ref),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: subsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  SliverFillRemaining(child: Center(child: Text('Error: $e'))),
              data: (subs) {
                if (subs.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(
                      onAdd: () => _showAddSheet(context, ref),
                    ),
                  );
                }

                final active = subs.where((s) => s.isActive).toList();
                final totalMonthly = _calcMonthlyTotal(active);

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // Monthly total card
                    _TotalCard(
                      monthlyTotal: totalMonthly,
                      currency: currency,
                      count: active.length,
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15),
                    const SizedBox(height: 24),

                    // Due soon section
                    if (active.any((s) => s.isDueSoon || s.isOverdue)) ...[
                      _SectionLabel(label: 'DUE SOON', color: tc.expense),
                      const SizedBox(height: 10),
                      ...active
                          .where((s) => s.isDueSoon || s.isOverdue)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (e) =>
                                _SubTile(
                                      sub: e.value,
                                      currency: currency,
                                      onMarkPaid: () => ref
                                          .read(
                                            subscriptionListProvider.notifier,
                                          )
                                          .markPaid(e.value),
                                      onDelete: () => ref
                                          .read(
                                            subscriptionListProvider.notifier,
                                          )
                                          .delete(e.value.id),
                                    )
                                    .animate()
                                    .fadeIn(delay: (e.key * 60).ms)
                                    .slideX(begin: -0.05),
                          ),
                      const SizedBox(height: 20),
                    ],

                    // All subscriptions
                    _SectionLabel(
                      label: 'ALL SUBSCRIPTIONS',
                      color: tc.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    ...active.asMap().entries.map(
                      (e) => _SubTile(
                        sub: e.value,
                        currency: currency,
                        onMarkPaid: () => ref
                            .read(subscriptionListProvider.notifier)
                            .markPaid(e.value),
                        onDelete: () => ref
                            .read(subscriptionListProvider.notifier)
                            .delete(e.value.id),
                      ).animate().fadeIn(delay: (e.key * 50).ms),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppThemeColors.of(context).onSurface,
        foregroundColor: AppThemeColors.of(context).surface,
        elevation: 0,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  double _calcMonthlyTotal(List<SubscriptionModel> subs) {
    double total = 0;
    for (final s in subs) {
      switch (s.billingCycle) {
        case BillingCycle.daily:
          total += s.amount * 30;
        case BillingCycle.weekly:
          total += s.amount * 4.33;
        case BillingCycle.monthly:
          total += s.amount;
        case BillingCycle.quarterly:
          total += s.amount / 3;
        case BillingCycle.yearly:
          total += s.amount / 12;
      }
    }
    return total;
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _AddSubscriptionSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Total Card
// ─────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double monthlyTotal;
  final CurrencyState currency;
  final int count;

  const _TotalCard({
    required this.monthlyTotal,
    required this.currency,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tc.onSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly spend',
            style: GoogleFonts.inter(
              color: tc.surface.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currency.format(monthlyTotal),
            style: GoogleFonts.inter(
              color: tc.surface,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count active subscription${count != 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              color: tc.surface.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Subscription Tile
// ─────────────────────────────────────────────

class _SubTile extends StatelessWidget {
  final SubscriptionModel sub;
  final CurrencyState currency;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  const _SubTile({
    required this.sub,
    required this.currency,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final daysLeft = sub.daysUntilDue;
    final urgencyColor = sub.isOverdue
        ? tc.expense
        : sub.isDueToday
        ? tc.lend
        : sub.isDueSoon
        ? tc.lend
        : tc.onSurfaceVariant;

    return Dismissible(
      key: Key(sub.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: tc.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_sweep_rounded, color: tc.expense, size: 26),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(sub.category.icon, color: tc.onSurface, size: 20),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    style: GoogleFonts.inter(
                      color: tc.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${sub.billingCycle.label} · ${sub.category.label}',
                    style: GoogleFonts.inter(
                      color: tc.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Amount + due
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(sub.amount),
                  style: GoogleFonts.inter(
                    color: tc.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onMarkPaid();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      sub.isOverdue
                          ? 'Overdue'
                          : sub.isDueToday
                          ? 'Pay today'
                          : 'Due in ${daysLeft}d',
                      style: GoogleFonts.inter(
                        color: urgencyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: GoogleFonts.inter(
      color: color,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: tc.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.subscriptions_outlined,
            color: tc.onSurfaceVariant,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No subscriptions yet',
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track Netflix, Hotstar, electricity bills\nand all your recurring payments.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: tc.onSurfaceVariant,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: tc.onSurface,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Add subscription',
              style: GoogleFonts.inter(
                color: tc.surface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Add Subscription Sheet
// ─────────────────────────────────────────────

class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  SubscriptionCategory _category = SubscriptionCategory.ott;
  BillingCycle _cycle = BillingCycle.monthly;
  DateTime _nextDue = DateTime.now().add(const Duration(days: 30));

  static const _presets = [
    ('Netflix', SubscriptionCategory.ott, 649.0),
    ('Hotstar', SubscriptionCategory.ott, 299.0),
    ('Spotify', SubscriptionCategory.music, 119.0),
    ('Amazon Prime', SubscriptionCategory.ott, 299.0),
    ('YouTube Premium', SubscriptionCategory.ott, 189.0),
    ('Electricity', SubscriptionCategory.utility, 0.0),
    ('Internet', SubscriptionCategory.utility, 0.0),
    ('Gym', SubscriptionCategory.gym, 0.0),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      return;
    }
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final sub = SubscriptionModel(
      name: _nameCtrl.text.trim(),
      category: _category,
      amount: amount,
      billingCycle: _cycle,
      nextDueDate: _nextDue,
      notes: _notesCtrl.text.trim(),
    );
    ref.read(subscriptionListProvider.notifier).add(sub);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: bottomPad + 32,
      ),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Subscription',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Quick presets
            Text(
              'Quick add',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((p) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _nameCtrl.text = p.$1;
                        _category = p.$2;
                        if (p.$3 > 0) _amountCtrl.text = p.$3.toString();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tc.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: tc.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        p.$1,
                        style: GoogleFonts.inter(
                          color: tc.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(
                  Icons.label_outline_rounded,
                  color: tc.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(
                  Icons.currency_rupee,
                  color: tc.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            Text(
              'Category',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SubscriptionCategory.values.map((cat) {
                final selected = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? tc.onSurface : tc.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat.icon,
                          size: 13,
                          color: selected ? tc.surface : tc.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          cat.label,
                          style: GoogleFonts.inter(
                            color: selected ? tc.surface : tc.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Billing cycle
            Text(
              'Billing cycle',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: BillingCycle.values.map((c) {
                final selected = c == _cycle;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _cycle = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? tc.onSurface
                            : tc.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: selected ? tc.surface : tc.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Next due date
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDue,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (picked != null) setState(() => _nextDue = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tc.outlineVariant, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: tc.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Next due: ${DateFormat('d MMM yyyy').format(_nextDue)}',
                      style: GoogleFonts.inter(
                        color: tc.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(
                  'Save Subscription',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
