import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/services/budget_service.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/categories/models/category_model.dart';
import 'package:agent_money/features/categories/repositories/category_repository.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

class CategoryBudgetScreen extends ConsumerWidget {
  const CategoryBudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final categoriesAsync = ref.watch(categoryListProvider);
    final transactionsAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);

    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final daysLeft = daysInMonth - now.day;

    return Scaffold(
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Category Budgets',
          style: AppFonts.sans(
            color: tc.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: IconThemeData(color: tc.onSurface),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          final expenseCategories = categories
              .where((c) => c.transactionType == 'expense')
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          // Compute spent amounts for current month
          final txList = transactionsAsync.valueOrNull ?? [];
          final monthlyExpenses = txList.where((t) =>
              t.type == TransactionType.expense &&
              t.date.year == now.year &&
              t.date.month == now.month);

          final Map<String, double> spentByCategory = {};
          for (final tx in monthlyExpenses) {
            spentByCategory[tx.category] =
                (spentByCategory[tx.category] ?? 0) + tx.amount;
          }

          final totalBudget = expenseCategories.fold<double>(
              0, (sum, c) => sum + c.budgetAmount);
          final totalSpent = spentByCategory.values
              .fold<double>(0, (sum, v) => sum + v);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              // ── Monthly budget limit ───────────────────
              const _MonthlyBudgetCard()
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0),

              const SizedBox(height: 16),

              // ── Hero card ──────────────────────────────
              _HeroCard(
                totalBudget: totalBudget,
                totalSpent: totalSpent,
                currency: currency,
                tc: tc,
                daysLeft: daysLeft,
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              // ── Category cards ─────────────────────────
              ...expenseCategories.asMap().entries.map((entry) {
                final idx = entry.key;
                final cat = entry.value;
                final spent = spentByCategory[cat.name] ?? 0;
                return _CategoryBudgetCard(
                  category: cat,
                  spent: spent,
                  currency: currency,
                  tc: tc,
                  daysLeft: daysLeft,
                  onEditBudget: () => _showEditBudgetSheet(
                      context, ref, cat, currency, tc),
                )
                    .animate(delay: (idx * 50).ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.05, end: 0);
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref, tc),
        backgroundColor: tc.primary,
        foregroundColor: tc.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(
          'Add Category',
          style: AppFonts.sans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Edit Budget Bottom Sheet ─────────────────────────────────────────────

  void _showEditBudgetSheet(
    BuildContext context,
    WidgetRef ref,
    CategoryModel cat,
    CurrencyState currency,
    AppThemeColors tc,
  ) {
    final controller = TextEditingController(
      text: cat.budgetAmount > 0
          ? cat.budgetAmount.toStringAsFixed(0)
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tc.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tc.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: AppFonts.sans(
                          color: tc.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Set monthly budget',
                        style: AppFonts.sans(
                          color: tc.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                style: AppFonts.sans(
                  color: tc.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  prefixText: '${currency.currency.symbol} ',
                  prefixStyle: AppFonts.sans(
                    color: tc.onSurfaceVariant,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  hintText: '0',
                  hintStyle: AppFonts.sans(
                    color: tc.onSurfaceVariant,
                    fontSize: 24,
                  ),
                  filled: true,
                  fillColor: tc.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tc.onSurface,
                        side: BorderSide(color: tc.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.sans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final val = double.tryParse(controller.text) ?? 0;
                        ref
                            .read(categoryListProvider.notifier)
                            .updateBudget(cat.id, val);
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tc.primary,
                        foregroundColor: tc.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Save',
                        style: AppFonts.sans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Add Category Dialog ──────────────────────────────────────────────────

  void _showAddCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    AppThemeColors tc,
  ) {
    final nameController = TextEditingController();
    final emojiController = TextEditingController();
    int selectedColor = 0xFF546E7A;

    const colorOptions = [
      0xFFE65100, // deep orange
      0xFF1565C0, // blue
      0xFF6A1B9A, // purple
      0xFF004D40, // teal
      0xFFC62828, // red
      0xFF37474F, // blue-grey
      0xFF4527A0, // deep purple
      0xFF00838F, // cyan
      0xFF546E7A, // grey-blue
      0xFF2E7D32, // green
      0xFFAD1457, // pink
      0xFFF57F17, // amber
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: tc.surfaceContainer,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'New Category',
            style: AppFonts.sans(
              color: tc.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji field
                TextField(
                  controller: emojiController,
                  style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 24,
                  ),
                  maxLength: 2,
                  decoration: InputDecoration(
                    labelText: 'Emoji',
                    counterText: '',
                    filled: true,
                    fillColor: tc.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Name field
                TextField(
                  controller: nameController,
                  style: AppFonts.sans(color: tc.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Category name',
                    filled: true,
                    fillColor: tc.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Color picker
                Text(
                  'Color',
                  style: AppFonts.sans(
                    color: tc.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((c) {
                    final isSelected = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: 150.ms,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: tc.onSurface,
                                  width: 2.5,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(c).withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: AppFonts.sans(color: tc.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final emoji = emojiController.text.trim();
                if (name.isEmpty) return;

                final newCat = CategoryModel(
                  name: name,
                  emoji: emoji.isEmpty ? '⚙️' : emoji,
                  colorValue: selectedColor,
                  transactionType: 'expense',
                  isCustom: true,
                  sortOrder: 999,
                );
                ref.read(categoryListProvider.notifier).add(newCat);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.primary,
                foregroundColor: tc.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add',
                style: AppFonts.sans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Budget Limit Card
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyBudgetCard extends ConsumerStatefulWidget {
  const _MonthlyBudgetCard();

  @override
  ConsumerState<_MonthlyBudgetCard> createState() => _MonthlyBudgetCardState();
}

class _MonthlyBudgetCardState extends ConsumerState<_MonthlyBudgetCard> {
  final _ctrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(CurrencyState currency) async {
    final val = double.tryParse(_ctrl.text.replaceAll(',', '')) ?? 0;
    await ref.read(budgetProvider.notifier).updateBudget(val);
    if (!mounted) return;
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(val > 0
            ? 'Budget set to ${currency.format(val)}'
            : 'Budget cleared'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final budget = ref.watch(budgetProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, color: tc.primary, size: 18),
              const SizedBox(width: 8),
              Text('MONTHLY BUDGET',
                  style: AppFonts.sans(
                      color: tc.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
              const Spacer(),
              if (!_editing)
                GestureDetector(
                  onTap: () {
                    _ctrl.text = budget.monthlyBudget > 0
                        ? budget.monthlyBudget.toStringAsFixed(0)
                        : '';
                    setState(() => _editing = true);
                  },
                  child: Text(budget.hasBudget ? 'Edit' : 'Set',
                      style: AppFonts.sans(
                          color: tc.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_editing)
            Text(
              budget.hasBudget
                  ? currency.format(budget.monthlyBudget)
                  : 'No budget set',
              style: AppFonts.sans(
                  color: budget.hasBudget ? tc.onSurface : tc.onSurfaceVariant,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5),
            )
          else
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Text(currency.currency.symbol,
                        style: AppFonts.sans(
                            color: tc.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    style: AppFonts.sans(
                        color: tc.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Enter monthly budget',
                      hintStyle: AppFonts.sans(
                          color: tc.onSurfaceVariant, fontSize: 14),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _save(currency),
                  ),
                ),
                GestureDetector(
                  onTap: () => _save(currency),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: tc.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('Save',
                        style: AppFonts.sans(
                            color: tc.onPrimary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final CurrencyState currency;
  final AppThemeColors tc;
  final int daysLeft;

  const _HeroCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.currency,
    required this.tc,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalBudget - totalSpent;
    final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final overBudget = totalBudget > 0 && totalSpent > totalBudget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Budget',
                style: AppFonts.sans(
                  color: tc.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tc.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$daysLeft days left',
                  style: AppFonts.sans(
                    color: tc.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Spent vs Budget row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(totalSpent),
                style: AppFonts.sans(
                  color: overBudget ? tc.expense : tc.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'of ${currency.format(totalBudget)}',
                  style: AppFonts.sans(
                    color: tc.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: tc.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                overBudget ? tc.expense : tc.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                overBudget
                    ? 'Over budget by ${currency.format(totalSpent - totalBudget)}'
                    : '${currency.format(remaining)} remaining',
                style: AppFonts.sans(
                  color: overBudget ? tc.expense : tc.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                totalBudget > 0
                    ? '${(pct * 100).toStringAsFixed(0)}%'
                    : 'No budget set',
                style: AppFonts.sans(
                  color: overBudget
                      ? tc.expense
                      : (pct > 0.9
                          ? tc.expense
                          : (pct > 0.8 ? tc.lend : tc.primary)),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-category card
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBudgetCard extends StatelessWidget {
  final CategoryModel category;
  final double spent;
  final CurrencyState currency;
  final AppThemeColors tc;
  final int daysLeft;
  final VoidCallback onEditBudget;

  const _CategoryBudgetCard({
    required this.category,
    required this.spent,
    required this.currency,
    required this.tc,
    required this.daysLeft,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = category.hasBudget;
    final pct = hasBudget
        ? (spent / category.budgetAmount).clamp(0.0, 1.0)
        : 0.0;
    final overBudget = hasBudget && spent > category.budgetAmount;
    final remaining = category.budgetAmount - spent;

    // Color coding for percentage text
    Color pctColor;
    if (overBudget) {
      pctColor = tc.expense;
    } else if (pct > 0.9) {
      pctColor = tc.expense;
    } else if (pct > 0.8) {
      pctColor = tc.lend;
    } else {
      pctColor = tc.income;
    }

    return GestureDetector(
      onTap: onEditBudget,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji + color dot
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + days left
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: AppFonts.sans(
                          color: tc.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        hasBudget
                            ? '$daysLeft days left'
                            : 'Tap to set budget',
                        style: AppFonts.sans(
                          color: tc.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Spent / budget + pct
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasBudget
                          ? '${currency.format(spent)} / ${currency.format(category.budgetAmount)}'
                          : currency.format(spent),
                      style: AppFonts.sans(
                        color: overBudget ? tc.expense : tc.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasBudget)
                      Text(
                        overBudget
                            ? 'Over!'
                            : '${(pct * 100).toStringAsFixed(0)}%',
                        style: AppFonts.sans(
                          color: pctColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            if (hasBudget) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: tc.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overBudget ? tc.expense : category.color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                overBudget
                    ? 'Over by ${currency.format(spent - category.budgetAmount)}'
                    : '${currency.format(remaining)} remaining',
                style: AppFonts.sans(
                  color: overBudget ? tc.expense : tc.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
