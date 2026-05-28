import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/services/theme_service.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/accounts/screens/accounts_screen.dart';
import 'package:agent_money/core/providers/voice_processing_provider.dart';
import 'package:agent_money/features/dashboard/widgets/magic_fab.dart';
import 'package:agent_money/features/dashboard/widgets/transaction_tile.dart';
import 'package:agent_money/features/recurring/screens/recurring_screen.dart';
import 'package:agent_money/features/settings/settings_screen.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/transactions/widgets/manual_entry_sheet.dart';
import 'package:agent_money/features/analytics/analytics_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:agent_money/features/accounts/widgets/add_account_sheet.dart';
import 'package:agent_money/core/services/balance_visibility_service.dart';
import 'package:agent_money/core/providers/overlay_event_provider.dart';
import 'package:agent_money/features/overlay/overlay_queue_service.dart';
import 'package:agent_money/features/budget/screens/budget_screen.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _navIndex = 0;

  final _pages = const [
    _HomeTab(),
    BudgetScreen(),
    AnalyticsScreen(),
    AccountsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.surface,
      body: IndexedStack(
        index: _navIndex,
        children: _pages,
      ),
      floatingActionButton: _navIndex == 0 ? const MagicFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: tc.outlineVariant, width: 0.5),
          ),
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
                  icon: Icons.pie_chart_rounded,
                  label: 'Budget',
                  isSelected: _navIndex == 1,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 1),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  isSelected: _navIndex == 2,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 2),
                ),
                _NavItem(
                  icon: Icons.account_balance_rounded,
                  label: 'Accounts',
                  isSelected: _navIndex == 3,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 3),
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
                color: isSelected ? tc.onSurface : tc.onSurfaceVariant.withOpacity(0.6),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? tc.onSurface : tc.onSurfaceVariant.withOpacity(0.6),
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
// Home Tab — stateful for month nav + filter
// ─────────────────────────────────────────────

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  TransactionType? _filter;

  @override
  void initState() {
    super.initState();
    // Drain any transactions the overlay saved while the app was closed.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _processOverlayQueue());
  }

  Future<void> _processOverlayQueue() async {
    try {
      final txs = await OverlayQueueService.dequeueAll();
      for (final tx in txs) {
        await ref.read(transactionListProvider.notifier).addTransaction(tx);
      }
    } catch (_) {}
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

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
              icon: Icons.repeat_rounded,
              label: 'Recurring Payments',
              tc: tc,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RecurringScreen()));
              },
            ),
            _MoreMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              tc: tc,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountProvider);
    final themeMode = ref.watch(themeProvider);
    final tc = AppThemeColors.of(context);

    // Refresh when the overlay saves transactions while the app is in the foreground.
    ref.listen(overlayEventProvider, (_, next) {
      next.whenData((_) => _processOverlayQueue());
    });

    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
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
            Consumer(
              builder: (_, ref, __) {
                final isHidden = ref.watch(balanceVisibilityProvider);
                return IconButton(
                  onPressed: () =>
                      ref.read(balanceVisibilityProvider.notifier).toggle(),
                  icon: Icon(
                    isHidden
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: tc.onSurface,
                    size: 20,
                  ),
                );
              },
            ),
            IconButton(
              onPressed: () => ref.read(themeProvider.notifier).toggle(),
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: tc.onSurface,
                size: 20,
              ),
            ),
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
              // ─── Accounts Strip ────────────────────────
              accountsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (accounts) {
                  if (accounts.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: accounts.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            if (i == accounts.length) {
                              return _AddAccountMiniCard();
                            }
                            return _AccountMiniCard(
                              account: accounts[i],
                              currency: currency,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),

              // ─── Month Navigation ─────────────────────
              _buildMonthNav(tc),
              const SizedBox(height: 14),

              // ─── Month Stats Bar ───────────────────────
              transactionsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (txs) {
                  final monthTxs = txs
                      .where((t) =>
                          t.date.year == _selectedMonth.year &&
                          t.date.month == _selectedMonth.month)
                      .toList();
                  return _MonthStatsBar(
                    transactions: monthTxs,
                    currency: currency,
                    tc: tc,
                  );
                },
              ),
              const SizedBox(height: 14),

              // ─── Filter Chips ──────────────────────────
              _buildFilterChips(tc),
              const SizedBox(height: 10),

              // ─── Voice processing card ─────────────────
              Consumer(
                builder: (_, ref, __) {
                  final vp = ref.watch(voiceProcessingProvider);
                  if (vp.isIdle) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VoiceProcessingCard(state: vp),
                  );
                },
              ),

              // ─── Date-grouped Transactions ─────────────
              transactionsAsync.when(
                loading: () => const _TransactionsSkeleton(),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: TextStyle(
                          color: AppThemeColors.of(context).expense)),
                ),
                data: (txs) {
                  var filtered = txs
                      .where((t) =>
                          t.date.year == _selectedMonth.year &&
                          t.date.month == _selectedMonth.month)
                      .toList();
                  if (_filter != null) {
                    filtered =
                        filtered.where((t) => t.type == _filter).toList();
                  }
                  if (filtered.isEmpty) return _EmptyTransactions();
                  final groups = _groupByDate(filtered);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: groups.entries.expand((entry) {
                      return <Widget>[
                        _DateGroupHeader(label: entry.key),
                        const SizedBox(height: 6),
                        ...entry.value.asMap().entries.map((e) {
                          return GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  ManualEntrySheet(prefill: e.value),
                            ),
                            child: TransactionTile(
                              transaction: e.value,
                              currency: currency,
                            )
                                .animate()
                                .fadeIn(
                                    duration: 300.ms,
                                    delay: (e.key * 30).ms),
                          );
                        }),
                        const SizedBox(height: 4),
                      ];
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

  Widget _buildMonthNav(AppThemeColors tc) {
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;
    return Row(
      children: [
        _SectionHeader(label: 'LOGS'),
        const Spacer(),
        GestureDetector(
          onTap: () => _changeMonth(-1),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_left_rounded,
                color: tc.onSurfaceVariant, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          DateFormat('MMM yyyy').format(_selectedMonth),
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: isCurrentMonth ? null : () => _changeMonth(1),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCurrentMonth
                  ? tc.surfaceContainerHigh.withOpacity(0.4)
                  : tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_right_rounded,
                color: isCurrentMonth
                    ? tc.onSurfaceVariant.withOpacity(0.3)
                    : tc.onSurfaceVariant,
                size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(AppThemeColors tc) {
    final filters = <(TransactionType?, String)>[
      (null, 'All'),
      (TransactionType.income, 'Income'),
      (TransactionType.expense, 'Expense'),
      (TransactionType.investment, 'Invest'),
      (TransactionType.lend, 'Lent'),
      (TransactionType.lendReturn, 'Got Back'),
      (TransactionType.borrow, 'Borrowed'),
      (TransactionType.borrowReturn, 'Repaid'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _filter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? tc.onSurface : tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive ? Colors.transparent : tc.outlineVariant,
                  width: 0.5,
                ),
              ),
              child: Text(
                f.$2,
                style: GoogleFonts.inter(
                  color: isActive ? tc.surface : tc.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
      trailing:
          Icon(Icons.chevron_right_rounded, color: tc.onSurfaceVariant, size: 20),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────
// Account Mini Cards
// ─────────────────────────────────────────────

class _AccountMiniCard extends ConsumerWidget {
  final AccountModel account;
  final CurrencyState currency;

  const _AccountMiniCard({required this.account, required this.currency});

  bool get _isLiability =>
      account.type == AccountType.loan ||
      account.type == AccountType.creditCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final isHidden = ref.watch(balanceVisibilityProvider);
    final balanceColor = _isLiability ? tc.expense : tc.onSurface;
    final displayBalance = account.balance.abs();

    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isLiability
              ? tc.expense.withOpacity(0.3)
              : tc.outlineVariant,
          width: _isLiability ? 1 : 0.5,
        ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  isHidden
                      ? '• • •'
                      : _isLiability
                          ? '−${currency.format(displayBalance)}'
                          : currency.format(displayBalance),
                  key: ValueKey(isHidden),
                  style: GoogleFonts.inter(
                    color: balanceColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_isLiability)
                Text(
                  'owed',
                  style: GoogleFonts.inter(
                    color: tc.expense.withOpacity(0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
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
              child: Icon(Icons.receipt_long_outlined,
                  color: tc.onSurfaceVariant, size: 30),
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
// Month Stats Bar (expense / income / total)
// ─────────────────────────────────────────────

class _MonthStatsBar extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  final AppThemeColors tc;

  const _MonthStatsBar({
    required this.transactions,
    required this.currency,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    final expense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final total = income - expense;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tc.outlineVariant, width: 0.5),
          bottom: BorderSide(color: tc.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _StatCol(label: 'EXPENSE', amount: expense, color: tc.expense,
              currency: currency, tc: tc),
          Container(width: 0.5, height: 32, color: tc.outlineVariant),
          _StatCol(label: 'INCOME', amount: income, color: tc.income,
              currency: currency, tc: tc),
          Container(width: 0.5, height: 32, color: tc.outlineVariant),
          _StatCol(
            label: 'TOTAL',
            amount: total.abs(),
            color: total >= 0 ? tc.income : tc.expense,
            currency: currency,
            tc: tc,
            prefix: total < 0 ? '−' : null,
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final CurrencyState currency;
  final AppThemeColors tc;
  final String? prefix;

  const _StatCol({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
    required this.tc,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                  color: tc.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                )),
            const SizedBox(height: 4),
            Text(
              '${prefix ?? ''}${currency.format(amount)}',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}


// ─────────────────────────────────────────────
// Date-group helpers
// ─────────────────────────────────────────────

Map<String, List<TransactionModel>> _groupByDate(
    List<TransactionModel> txs) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final Map<String, List<TransactionModel>> groups = {};
  for (final tx in txs) {
    final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
    final diff = today.difference(d).inDays;
    final key = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : DateFormat('EEE, d MMM').format(tx.date);
    (groups[key] ??= []).add(tx);
  }
  return groups;
}

class _DateGroupHeader extends StatelessWidget {
  final String label;
  const _DateGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: tc.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Voice processing card — shown at the top of the transaction list
// while the AI is working, then briefly shows confirmation.
// ─────────────────────────────────────────────

class _VoiceProcessingCard extends ConsumerWidget {
  final VoiceProcessingState state;
  const _VoiceProcessingCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: state.isProcessing
          ? _processingView(tc)
          : state.isSaved
              ? _savedView(tc)
              : state.isError
                  ? _errorView(tc, ref)
                  : const SizedBox.shrink(),
    );
  }

  Widget _processingView(AppThemeColors tc) {
    return Container(
      key: const ValueKey('processing'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(tc.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: 130,
                  decoration: BoxDecoration(
                    color: tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.statusMessage,
                  style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                height: 11,
                width: 52,
                decoration: BoxDecoration(
                  color: tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 9,
                width: 32,
                decoration: BoxDecoration(
                  color: tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _savedView(AppThemeColors tc) {
    return Container(
      key: const ValueKey('saved'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF22C55E).withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF22C55E), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              state.statusMessage,
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(AppThemeColors tc, WidgetRef ref) {
    return Container(
      key: const ValueKey('error'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.4), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Processing failed',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                ref.read(voiceProcessingProvider.notifier).dismiss(),
            child: Icon(Icons.close_rounded,
                color: tc.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(voiceProcessingProvider.notifier).retry(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
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
