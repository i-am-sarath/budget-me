import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/theme_service.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/accounts/screens/accounts_screen.dart';
import 'package:agent_money/features/dashboard/widgets/magic_fab.dart';
import 'package:agent_money/features/dashboard/widgets/summary_card.dart';
import 'package:agent_money/features/dashboard/widgets/transaction_tile.dart';
import 'package:agent_money/features/history/history_screen.dart';
import 'package:agent_money/features/recurring/screens/recurring_screen.dart';
import 'package:agent_money/features/settings/settings_screen.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/analytics/analytics_screen.dart';
import 'package:agent_money/core/services/budget_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:agent_money/features/accounts/widgets/add_account_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _navIndex = 0;

  final _pages = const [_HomeTab(), AnalyticsScreen(), AccountsScreen()];

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.surface,
      body: IndexedStack(index: _navIndex, children: _pages),
      floatingActionButton: _navIndex == 0 ? const MagicFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          border: Border(top: BorderSide(color: tc.outlineVariant, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _navIndex == 0,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 0),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  isSelected: _navIndex == 1,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 1),
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Accounts',
                  isSelected: _navIndex == 2,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom Nav Item
// ─────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final AppThemeColors tc;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? tc.onSurface.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? tc.onSurface
                    : tc.onSurfaceVariant.withOpacity(0.6),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected
                    ? tc.onSurface
                    : tc.onSurfaceVariant.withOpacity(0.6),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Home Tab
// ─────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  void _showMoreMenu(BuildContext context, AppThemeColors tc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tc.outlineVariant,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 20),
            _MoreMenuItem(
              icon: Icons.history_rounded,
              label: 'Transaction History',
              tc: tc,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            _MoreMenuItem(
              icon: Icons.repeat_rounded,
              label: 'Recurring Payments',
              tc: tc,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecurringScreen()),
                );
              },
            ),
            _MoreMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              tc: tc,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);
    final sub = ref.watch(subscriptionProvider);
    final accountsAsync = ref.watch(accountProvider);
    final themeMode = ref.watch(themeProvider);
    final tc = AppThemeColors.of(context);
    final budget = ref.watch(budgetProvider);

    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // App Bar
        SliverAppBar(
          backgroundColor: tc.surface,
          floating: true,
          snap: true,
          elevation: 0,
          titleSpacing: 20,
          title: Text(
            'Budget Me',
            style: GoogleFonts.inter(
              color: tc.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.8,
            ),
          ),
          actions: [
            // Theme toggle
            IconButton(
              onPressed: () => ref.read(themeProvider.notifier).toggle(),
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: tc.onSurface,
                size: 20,
              ),
            ),
            // More menu
            IconButton(
              onPressed: () => _showMoreMenu(context, tc),
              icon: Icon(Icons.more_horiz_rounded, color: tc.onSurface),
            ),
            const SizedBox(width: 8),
          ],
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ─── Balance Hero ──────────────────────────
              transactionsAsync.when(
                loading: () => const _BalanceSkeleton(),
                error: (e, _) => const SizedBox(),
                data: (txs) => _BalanceHero(
                  transactions: txs,
                  currency: currency,
                  sub: sub,
                ),
              ),
              const SizedBox(height: 16),

              // ─── Quick Stats (Summary) ─────────────────
              transactionsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (txs) => SummaryCard(
                  transactions: txs,
                  currency: currency,
                ).animate().fadeIn(delay: 200.ms),
              ),
              const SizedBox(height: 16),

              // ─── Budget Progress ───────────────────────
              transactionsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (txs) {
                  if (!budget.hasBudget) return const SizedBox();
                  final now = DateTime.now();
                  final spent = txs
                      .where(
                        (t) =>
                            t.type == TransactionType.expense &&
                            t.date.month == now.month &&
                            t.date.year == now.year,
                      )
                      .fold(0.0, (s, t) => s + t.amount);
                  return _BudgetCard(
                    budget: budget,
                    spent: spent,
                    currency: currency,
                  ).animate().fadeIn(delay: 400.ms);
                },
              ),

              const SizedBox(height: 24),

              // ─── Accounts Strip ────────────────────────
              accountsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (accounts) {
                  if (accounts.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(label: 'ACCOUNTS'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: accounts.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (ctx, i) {
                            if (i == accounts.length)
                              return _AddAccountMiniCard();
                            return _AccountMiniCard(
                              account: accounts[i],
                              currency: currency,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // ─── Recent Transactions ──────────────────
              _SectionHeader(label: 'RECENT LOGS'),
              const SizedBox(height: 12),

              transactionsAsync.when(
                loading: () => const _TransactionsSkeleton(),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(color: AppThemeColors.of(context).expense),
                  ),
                ),
                data: (txs) {
                  final recent = txs.take(6).toList();
                  if (recent.isEmpty) return _EmptyTransactions();
                  return Column(
                    children: recent.asMap().entries.map((e) {
                      return TransactionTile(
                            transaction: e.value,
                            currency: currency,
                          )
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (e.key * 50).ms)
                          .slideY(begin: 0.1, end: 0);
                    }).toList(),
                  );
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppThemeColors tc;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: tc.onSurface, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: tc.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: tc.onSurfaceVariant,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────
// Balance Hero
// ─────────────────────────────────────────────

class _BalanceHero extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  final SubscriptionState sub;

  const _BalanceHero({
    required this.transactions,
    required this.currency,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    double income = 0;
    double expense = 0;
    double invested = 0;

    // ⚡ Bolt: Single pass aggregation instead of multiple lazy where().fold() chains
    for (final t in transactions) {
      if (t.date.month == now.month && t.date.year == now.year) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else if (t.type == TransactionType.expense) {
          expense += t.amount;
        } else if (t.type == TransactionType.investment) {
          invested += t.amount;
        }
      }
    }

    final balance = income - expense - invested;

    final tc = AppThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tc.onSurface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: tc.onSurface.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(now).toUpperCase(),
            style: GoogleFonts.inter(
              color: tc.surface.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 6),
          Text(
                currency.format(balance),
                style: GoogleFonts.inter(
                  color: tc.surface,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              )
              .animate()
              .fadeIn(duration: 500.ms, delay: 100.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 20),
          Row(
            children: [
              _MiniStat(
                label: 'Income',
                value: currency.format(income),
                color: tc.income,
                surface: tc.surface,
              ),
              const Spacer(),
              _MiniStat(
                label: 'Spent',
                value: currency.format(expense),
                color: tc.expense,
                surface: tc.surface,
              ),
              const Spacer(),
              _MiniStat(
                label: 'Savings',
                value: currency.format(balance > 0 ? balance : 0),
                color: tc.primaryContainer,
                surface: tc.surface,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color surface;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: surface.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Account Mini Cards
// ─────────────────────────────────────────────

class _AccountMiniCard extends StatelessWidget {
  final AccountModel account;
  final CurrencyState currency;

  const _AccountMiniCard({required this.account, required this.currency});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(account.displayIcon, color: account.type.color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            currency.format(account.balance),
            style: GoogleFonts.inter(
              color: tc.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAccountMiniCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddAccountSheet(),
      ),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: tc.outlineVariant,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: tc.onSurfaceVariant, size: 24),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Utils
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: GoogleFonts.inter(
      color: AppThemeColors.of(context).onSurfaceVariant,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppThemeColors.of(context).surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

class _TransactionsSkeleton extends StatelessWidget {
  const _TransactionsSkeleton();

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 72,
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: tc.onSurfaceVariant,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No logs yet',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the mic or manual to start tracking',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Budget Progress Card
// ─────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetState budget;
  final double spent;
  final CurrencyState currency;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final fraction = (spent / budget.monthlyBudget).clamp(0.0, 1.0);
    final isOver = spent > budget.monthlyBudget;
    final remaining = budget.monthlyBudget - spent;
    final daysInMonth = DateUtils.getDaysInMonth(
      DateTime.now().year,
      DateTime.now().month,
    );
    final dayOfMonth = DateTime.now().day;
    final expectedFraction = dayOfMonth / daysInMonth;
    final isOnTrack = fraction <= expectedFraction + 0.05;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOver ? tc.expense.withOpacity(0.3) : tc.outlineVariant,
          width: isOver ? 1.5 : 0.5,
        ),
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
                    Text(
                      'MONTHLY BUDGET',
                      style: GoogleFonts.inter(
                        color: tc.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(budget.monthlyBudget),
                      style: GoogleFonts.inter(
                        color: tc.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOver
                      ? tc.expense.withOpacity(0.12)
                      : isOnTrack
                      ? tc.income.withOpacity(0.12)
                      : tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isOver
                      ? '⚠ Over budget'
                      : isOnTrack
                      ? '✓ On track'
                      : 'Watch out',
                  style: GoogleFonts.inter(
                    color: isOver
                        ? tc.expense
                        : isOnTrack
                        ? tc.income
                        : tc.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: tc.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? tc.expense : tc.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${currency.format(spent)}',
                style: GoogleFonts.inter(
                  color: tc.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                isOver
                    ? 'Over by ${currency.format(-remaining)}'
                    : '${currency.format(remaining)} left',
                style: GoogleFonts.inter(
                  color: isOver ? tc.expense : tc.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: isOver ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
