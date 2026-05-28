import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/categories/providers/category_provider.dart';
import 'package:agent_money/features/categories/models/category_model.dart';
import 'package:agent_money/features/budget/providers/category_budget_provider.dart';
import 'package:agent_money/features/budget/models/category_budget_model.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthId =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _changeMonth(int offset) =>
      setState(() => _month = DateTime(_month.year, _month.month + offset));

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final categoriesAsync = ref.watch(categoryProvider);
    final budgetsAsync = ref.watch(categoryBudgetProvider(_monthId));
    final txAsync = ref.watch(transactionListProvider);

    // Expenses for selected month
    final monthExpenses = txAsync.valueOrNull
            ?.where((t) =>
                t.type == TransactionType.expense &&
                t.date.year == _month.year &&
                t.date.month == _month.month)
            .toList() ??
        [];

    double totalBudget = 0;
    double totalSpent = 0;
    final budgets = budgetsAsync.valueOrNull ?? [];
    for (final b in budgets) {
      totalBudget += b.limitAmount;
      totalSpent += monthExpenses
          .where((t) => t.category == b.categoryName)
          .fold(0.0, (s, t) => s + t.amount);
    }

    final expenseCats = categoriesAsync.valueOrNull
            ?.where((c) => c.type == 'expense')
            .toList() ??
        [];

    final budgetedCats =
        expenseCats.where((c) => budgets.any((b) => b.categoryName == c.name)).toList();
    final unbdugetedCats =
        expenseCats.where((c) => !budgets.any((b) => b.categoryName == c.name)).toList();

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
              'Budget',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Month navigation
                _buildMonthNav(tc),
                const SizedBox(height: 16),

                // Summary card
                if (budgets.isNotEmpty)
                  _BudgetSummaryCard(
                    totalBudget: totalBudget,
                    totalSpent: totalSpent,
                    currency: currency,
                    tc: tc,
                  ),
                if (budgets.isNotEmpty) const SizedBox(height: 24),

                // Budgeted categories
                if (budgetedCats.isNotEmpty) ...[
                  _SectionLabel('BUDGETED', tc),
                  const SizedBox(height: 10),
                  ...budgetedCats.map((cat) {
                    final budget =
                        budgets.where((b) => b.categoryName == cat.name).firstOrNull;
                    final spent = monthExpenses
                        .where((t) => t.category == cat.name)
                        .fold(0.0, (s, t) => s + t.amount);
                    return _BudgetedCategoryRow(
                      category: cat,
                      budget: budget!,
                      spent: spent,
                      currency: currency,
                      tc: tc,
                      onEdit: () => _showBudgetDialog(cat, budget.limitAmount),
                      onRemove: () => ref
                          .read(categoryBudgetProvider(_monthId).notifier)
                          .removeBudget(budget.id),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Unbudgeted categories
                if (unbdugetedCats.isNotEmpty) ...[
                  _SectionLabel('NOT BUDGETED THIS MONTH', tc),
                  const SizedBox(height: 10),
                  ...unbdugetedCats.map((cat) => _UnbudgetedCategoryRow(
                        category: cat,
                        tc: tc,
                        onSet: () => _showBudgetDialog(cat, null),
                      )),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav(AppThemeColors tc) {
    final isCurrentMonth = _month.year == DateTime.now().year &&
        _month.month == DateTime.now().month;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavArrow(
          icon: Icons.chevron_left_rounded,
          tc: tc,
          onTap: () => _changeMonth(-1),
        ),
        const SizedBox(width: 16),
        Text(
          DateFormat('MMMM yyyy').format(_month),
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 16),
        _NavArrow(
          icon: Icons.chevron_right_rounded,
          tc: tc,
          onTap: isCurrentMonth ? null : () => _changeMonth(1),
          disabled: isCurrentMonth,
        ),
      ],
    );
  }

  void _showBudgetDialog(CategoryModel cat, double? current) {
    final tc = AppThemeColors.of(context);
    final ctrl = TextEditingController(
      text: current != null && current > 0 ? current.toStringAsFixed(0) : '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
              Row(children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(
                  'Set budget for ${cat.name}',
                  style: GoogleFonts.inter(
                    color: tc.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                style: GoogleFonts.inter(
                  color: tc.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.inter(
                      color: tc.onSurfaceVariant, fontSize: 28),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tc.onSurface,
                    foregroundColor: tc.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final val = double.tryParse(ctrl.text) ?? 0;
                    if (val > 0) {
                      ref
                          .read(categoryBudgetProvider(_monthId).notifier)
                          .setBudget(cat.name, val);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Save Budget',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
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
// Budget Summary Card
// ─────────────────────────────────────────────

class _BudgetSummaryCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final CurrencyState currency;
  final AppThemeColors tc;

  const _BudgetSummaryCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.currency,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalBudget > 0
        ? (totalSpent / totalBudget).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (totalBudget - totalSpent).clamp(0.0, double.infinity);
    final isOver = totalSpent > totalBudget;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Budget',
                        style: GoogleFonts.inter(
                            color: tc.onSurfaceVariant, fontSize: 11)),
                    Text(
                      currency.format(totalBudget),
                      style: GoogleFonts.inter(
                        color: tc.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Spent',
                      style: GoogleFonts.inter(
                          color: tc.onSurfaceVariant, fontSize: 11)),
                  Text(
                    currency.format(totalSpent),
                    style: GoogleFonts.inter(
                      color: isOver ? tc.expense : tc.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: tc.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? tc.expense : tc.income,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOver
                ? 'Over budget by ${currency.format(totalSpent - totalBudget)}'
                : '${currency.format(remaining)} remaining',
            style: GoogleFonts.inter(
              color: isOver ? tc.expense : tc.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Budgeted category row
// ─────────────────────────────────────────────

class _BudgetedCategoryRow extends StatelessWidget {
  final CategoryModel category;
  final CategoryBudgetModel budget;
  final double spent;
  final CurrencyState currency;
  final AppThemeColors tc;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _BudgetedCategoryRow({
    required this.category,
    required this.budget,
    required this.spent,
    required this.currency,
    required this.tc,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        budget.limitAmount > 0 ? (spent / budget.limitAmount).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > budget.limitAmount;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOver ? tc.expense.withOpacity(0.4) : tc.outlineVariant,
            width: isOver ? 1 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    style: GoogleFonts.inter(
                      color: tc.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${currency.format(spent)} / ${currency.format(budget.limitAmount)}',
                  style: GoogleFonts.inter(
                    color: isOver ? tc.expense : tc.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(Icons.close_rounded,
                      color: tc.onSurfaceVariant.withOpacity(0.5), size: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: tc.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? tc.expense : tc.income,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Unbudgeted category row
// ─────────────────────────────────────────────

class _UnbudgetedCategoryRow extends StatelessWidget {
  final CategoryModel category;
  final AppThemeColors tc;
  final VoidCallback onSet;

  const _UnbudgetedCategoryRow({
    required this.category,
    required this.tc,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.name,
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: tc.outlineVariant, width: 0.5),
              ),
              child: Text(
                'Set Budget',
                style: GoogleFonts.inter(
                  color: tc.onSurface,
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
// Helpers
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppThemeColors tc;
  const _SectionLabel(this.label, this.tc);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.inter(
          color: tc.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final AppThemeColors tc;
  final VoidCallback? onTap;
  final bool disabled;

  const _NavArrow({
    required this.icon,
    required this.tc,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: disabled
                ? tc.surfaceContainerHigh.withOpacity(0.4)
                : tc.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: disabled
                ? tc.onSurfaceVariant.withOpacity(0.3)
                : tc.onSurfaceVariant,
            size: 18,
          ),
        ),
      );
}
