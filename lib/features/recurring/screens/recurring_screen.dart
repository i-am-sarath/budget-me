import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/recurring/models/recurring_model.dart';
import 'package:agent_money/features/recurring/repositories/recurring_repository.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(recurringListProvider);
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
              'Recurring',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              Semantics(
                label: 'Add recurring transaction',
                button: true,
                child: IconButton(
                  tooltip: 'Add recurring transaction',
                  icon: Icon(Icons.add_rounded, color: tc.onSurface),
                  onPressed: () => _showAddSheet(context, ref),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: listAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  SliverFillRemaining(child: Center(child: Text('Error: $e'))),
              data: (rules) {
                if (rules.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(
                      onAdd: () => _showAddSheet(context, ref),
                    ),
                  );
                }

                final due = rules
                    .where((r) => r.isActive && r.isDueToday)
                    .toList();
                final active = rules
                    .where((r) => r.isActive && !r.isDueToday)
                    .toList();
                final paused = rules.where((r) => !r.isActive).toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // Due today
                    if (due.isNotEmpty) ...[
                      _SectionLabel(label: 'RUN TODAY', color: tc.income),
                      const SizedBox(height: 10),
                      ...due.asMap().entries.map(
                        (e) =>
                            _RecurringTile(
                                  rule: e.value,
                                  currency: currency,
                                  isDue: true,
                                  onRunNow: () =>
                                      _runNow(context, ref, e.value),
                                  onToggle: () => ref
                                      .read(recurringListProvider.notifier)
                                      .toggleActive(e.value),
                                  onDelete: () => ref
                                      .read(recurringListProvider.notifier)
                                      .delete(e.value.id),
                                  onEdit: () => _showAddSheet(
                                    context,
                                    ref,
                                    existing: e.value,
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: (e.key * 60).ms)
                                .slideY(begin: 0.1),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Upcoming
                    if (active.isNotEmpty) ...[
                      _SectionLabel(
                        label: 'UPCOMING',
                        color: tc.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      ...active.asMap().entries.map(
                        (e) => _RecurringTile(
                          rule: e.value,
                          currency: currency,
                          isDue: false,
                          onRunNow: () => _runNow(context, ref, e.value),
                          onToggle: () => ref
                              .read(recurringListProvider.notifier)
                              .toggleActive(e.value),
                          onDelete: () => ref
                              .read(recurringListProvider.notifier)
                              .delete(e.value.id),
                          onEdit: () =>
                              _showAddSheet(context, ref, existing: e.value),
                        ).animate().fadeIn(delay: (e.key * 50).ms),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Paused
                    if (paused.isNotEmpty) ...[
                      _SectionLabel(
                        label: 'PAUSED',
                        color: tc.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      ...paused.asMap().entries.map(
                        (e) => _RecurringTile(
                          rule: e.value,
                          currency: currency,
                          isDue: false,
                          onRunNow: () => _runNow(context, ref, e.value),
                          onToggle: () => ref
                              .read(recurringListProvider.notifier)
                              .toggleActive(e.value),
                          onDelete: () => ref
                              .read(recurringListProvider.notifier)
                              .delete(e.value.id),
                          onEdit: () =>
                              _showAddSheet(context, ref, existing: e.value),
                        ),
                      ),
                    ],
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

  Future<void> _runNow(
    BuildContext context,
    WidgetRef ref,
    RecurringModel rule,
  ) async {
    HapticFeedback.mediumImpact();
    await ref.read(recurringListProvider.notifier).runNow(rule);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${rule.title} — transaction added ✓')),
      );
    }
  }

  void _showAddSheet(
    BuildContext context,
    WidgetRef ref, {
    RecurringModel? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _AddRecurringSheet(existing: existing),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Recurring Tile
// ─────────────────────────────────────────────

class _RecurringTile extends StatelessWidget {
  final RecurringModel rule;
  final CurrencyState currency;
  final bool isDue;
  final VoidCallback onRunNow;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RecurringTile({
    required this.rule,
    required this.currency,
    required this.isDue,
    required this.onRunNow,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final typeColor = _typeColor(rule.type, tc);

    return Dismissible(
      key: Key(rule.id),
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
          color: rule.isActive
              ? tc.surfaceContainerLow
              : tc.surfaceContainerLow.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: isDue
              ? Border.all(color: tc.income.withOpacity(0.3), width: 1)
              : Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            // Type badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _typeIcon(rule.type),
                color: rule.isActive ? typeColor : tc.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.title,
                    style: GoogleFonts.inter(
                      color: rule.isActive ? tc.onSurface : tc.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${rule.frequency.label} · ${rule.type.label}',
                    style: GoogleFonts.inter(
                      color: tc.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Next: ${DateFormat('d MMM').format(rule.nextRunDate)}',
                    style: GoogleFonts.inter(
                      color: isDue ? tc.income : tc.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: isDue ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(rule.amount),
                  style: GoogleFonts.inter(
                    color: rule.isActive ? typeColor : tc.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (isDue)
                      GestureDetector(
                        onTap: onRunNow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tc.income.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Run',
                            style: GoogleFonts.inter(
                              color: tc.income,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onEdit,
                      child: Icon(
                        Icons.edit_outlined,
                        color: tc.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onToggle,
                      child: Icon(
                        rule.isActive
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        color: tc.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(TransactionType type, AppThemeColors tc) {
    switch (type) {
      case TransactionType.expense:
        return tc.expense;
      case TransactionType.income:
        return tc.income;
      case TransactionType.investment:
        return tc.investment;
      case TransactionType.lend:
        return tc.lend;
      case TransactionType.borrow:
        return tc.borrow;
      case TransactionType.lendReturn:
        return tc.income;
      case TransactionType.borrowReturn:
        return tc.expense;
    }
  }

  IconData _typeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.investment:
        return Icons.trending_up_rounded;
      case TransactionType.lend:
        return Icons.people_alt_rounded;
      case TransactionType.borrow:
        return Icons.person_add_alt_1_rounded;
      case TransactionType.lendReturn:
        return Icons.undo_rounded;
      case TransactionType.borrowReturn:
        return Icons.redo_rounded;
    }
  }
}

// ─────────────────────────────────────────────
// Section label
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
            Icons.repeat_rounded,
            color: tc.onSurfaceVariant,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No recurring rules',
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up DigiGold daily buys, SIP investments,\nsalary income, or any repeating transaction.',
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
              'Add recurring rule',
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
// Add Recurring Sheet
// ─────────────────────────────────────────────

class _AddRecurringSheet extends ConsumerStatefulWidget {
  final RecurringModel? existing;
  const _AddRecurringSheet({this.existing});

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _category = 'General';
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _startDate = DateTime.now();

  bool get _isEditing => widget.existing != null;

  static const _presets = [
    (
      'DigiGold',
      TransactionType.investment,
      'Investment',
      RecurringFrequency.daily,
      100.0,
    ),
    (
      'SIP',
      TransactionType.investment,
      'Investment',
      RecurringFrequency.monthly,
      5000.0,
    ),
    (
      'Salary',
      TransactionType.income,
      'Salary',
      RecurringFrequency.monthly,
      0.0,
    ),
    ('Rent', TransactionType.expense, 'Rent', RecurringFrequency.monthly, 0.0),
    (
      'Grocery',
      TransactionType.expense,
      'Food',
      RecurringFrequency.weekly,
      0.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toString();
      _type = e.type;
      _category = e.category;
      _frequency = e.frequency;
      _startDate = e.startDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      return;
    }
    final amount = double.tryParse(_amountCtrl.text) ?? 0;

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        title: _titleCtrl.text.trim(),
        amount: amount,
        type: _type,
        category: _category,
        frequency: _frequency,
        startDate: _startDate,
      );
      ref.read(recurringListProvider.notifier).update(updated);
    } else {
      final rule = RecurringModel(
        title: _titleCtrl.text.trim(),
        amount: amount,
        type: _type,
        category: _category,
        frequency: _frequency,
        startDate: _startDate,
        nextRunDate: _startDate,
      );
      ref.read(recurringListProvider.notifier).add(rule);
    }
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
              _isEditing ? 'Edit Recurring Rule' : 'Add Recurring Rule',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Presets
            Text(
              'Quick add',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((p) {
                  return GestureDetector(
                    onTap: () => setState(() {
                      _titleCtrl.text = p.$1;
                      _type = p.$2;
                      _category = p.$3;
                      _frequency = p.$4;
                      if (p.$5 > 0) _amountCtrl.text = p.$5.toString();
                    }),
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

            // Title
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(
                  Icons.repeat_rounded,
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
                  Icons.attach_money_rounded,
                  color: tc.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Transaction type
            Text(
              'Type',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: TransactionType.values.map((t) {
                  final sel = t == _type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? tc.onSurface : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: sel ? tc.surface : tc.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Frequency
            Text(
              'Frequency',
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
              children: RecurringFrequency.values.map((f) {
                final sel = f == _frequency;
                return GestureDetector(
                  onTap: () => setState(() => _frequency = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? tc.onSurface : tc.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      f.label,
                      style: GoogleFonts.inter(
                        color: sel ? tc.surface : tc.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Start date
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _startDate = picked);
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
                      'Start: ${DateFormat('d MMM yyyy').format(_startDate)}',
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

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(
                  _isEditing ? 'Update Rule' : 'Save Rule',
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
