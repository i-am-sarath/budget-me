import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/services/currency_service.dart';
import 'package:money_pi/features/accounts/screens/accounts_screen.dart';
import 'package:money_pi/features/accounts/widgets/transfer_sheet.dart';
import 'package:money_pi/features/accounts/repositories/account_repository.dart';
import 'package:money_pi/features/dashboard/widgets/magic_fab.dart';
import 'package:money_pi/features/dashboard/widgets/transaction_tile.dart';
import 'package:money_pi/features/settings/settings_screen.dart';
import 'package:money_pi/features/transactions/models/transaction_model.dart';
import 'package:money_pi/features/transactions/providers/voice_log_provider.dart';
import 'package:money_pi/features/transactions/repositories/transaction_repository.dart';
import 'package:money_pi/features/transactions/widgets/manual_entry_sheet.dart';
import 'package:money_pi/features/analytics/analytics_screen.dart';
import 'package:intl/intl.dart';
import 'package:money_pi/features/spaces/repositories/space_repository.dart';
import 'package:money_pi/features/spaces/widgets/space_switcher_sheet.dart';
import 'package:money_pi/features/categories/screens/category_budget_screen.dart';
import 'package:money_pi/features/groups/screens/groups_screen.dart';
import 'package:money_pi/features/trips/screens/trips_screen.dart';
import 'package:money_pi/core/services/tour_service.dart';
import 'package:money_pi/features/onboarding/feature_tour.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _navIndex = 0;
  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    // First-run feature tour. We wait for the post-frame callback so the
    // dashboard is fully painted behind the dimmed overlay, and guard with a
    // flag so navigation back to Home never re-triggers it within a session.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
  }

  Future<void> _maybeShowTour() async {
    if (_tourChecked || !mounted) return;
    _tourChecked = true;
    // tourSeenProvider loads from prefs async; give it a beat to settle so we
    // read the real persisted value rather than the safe "seen" default.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final seen = ref.read(tourSeenProvider);
    if (!seen) {
      await showFeatureTour(context);
    }
  }

  final _pages = const [
    _HomeTab(),
    CategoryBudgetScreen(),
    AnalyticsScreen(),
    AccountsScreen(),
    SettingsScreen(),
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
          color: tc.surfaceContainer,
          border: Border(
            top: BorderSide(color: tc.outlineVariant, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
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
                  icon: Icons.donut_large_rounded,
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
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Accounts',
                  isSelected: _navIndex == 3,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 3),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: _navIndex == 4,
                  tc: tc,
                  onTap: () => setState(() => _navIndex = 4),
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
    // Active tab: soft orange wash pill with orange icon + label — the single
    // brand accent, applied identically across all five tabs.
    final pillBg =
        isSelected ? tc.accent.withOpacity(0.12) : Colors.transparent;
    final itemColor =
        isSelected ? tc.accent : tc.onSurfaceVariant.withOpacity(0.6);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppFonts.sans(
                  color: itemColor,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  void _openTransfer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransferSheet(),
    ).then((_) => ref.read(accountProvider.notifier).loadAccounts());
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);
    final voiceProcessing = ref.watch(voiceLogProvider).isProcessing;
    final tc = AppThemeColors.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          backgroundColor: tc.surface,
          floating: true,
          snap: true,
          elevation: 0,
          titleSpacing: 20,
          title: _SpaceHeaderTitle(tc: tc),
          actions: [
            IconButton(
              tooltip: 'Transfer money',
              onPressed: _openTransfer,
              icon: Icon(Icons.swap_horiz_rounded, color: tc.onSurface),
            ),
            IconButton(
              tooltip: 'Trips',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripsScreen()),
              ),
              icon: Icon(Icons.card_travel_rounded, color: tc.onSurface),
            ),
            IconButton(
              tooltip: 'Groups',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroupsScreen()),
              ),
              icon: Icon(Icons.groups_rounded, color: tc.onSurface),
            ),
            const SizedBox(width: 8),
          ],
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ─── Month Navigation ─────────────────────
              _buildMonthNav(tc),
              const SizedBox(height: 12),

              // ─── Filter Chips ──────────────────────────
              _buildFilterChips(tc),
              const SizedBox(height: 14),

              // ─── Voice auto-save in progress ───────────
              if (voiceProcessing) ...[
                _VoiceLoggingRow(tc: tc),
                const SizedBox(height: 10),
              ],

              // ─── Transactions for selected month ───────
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
                  // While a voice log is processing, don't show the empty state
                  // under the shimmer row — it'll fill in a second.
                  if (filtered.isEmpty) {
                    return voiceProcessing
                        ? const SizedBox.shrink()
                        : _EmptyTransactions();
                  }
                  return _DateGroupedList(
                    transactions: filtered,
                    currency: currency,
                    tc: tc,
                    context: context,
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
          style: AppFonts.sans(
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
      (TransactionType.transferOut, 'Transfer'),
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
                style: AppFonts.sans(
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

// ─────────────────────────────────────────────
// Date-grouped transaction list
// ─────────────────────────────────────────────

class _DateGroupedList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  final AppThemeColors tc;
  final BuildContext context;

  const _DateGroupedList({
    required this.transactions,
    required this.currency,
    required this.tc,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    // Group by day key
    final grouped = <String, List<TransactionModel>>{};
    final keyOrder = <String>[];
    for (final tx in transactions) {
      final key = _dayKey(tx.date);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        keyOrder.add(key);
      }
      grouped[key]!.add(tx);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keyOrder.map((key) {
        final group = grouped[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header row
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Row(
                children: [
                  Text(
                    key,
                    style: AppFonts.sans(
                      color: tc.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: tc.outlineVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Transactions with dividers
            ...group.asMap().entries.map((e) {
              final isLast = e.key == group.length - 1;
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ManualEntrySheet(prefill: e.value),
                    ),
                    child: TransactionTile(
                      transaction: e.value,
                      currency: currency,
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      indent: 62,
                      height: 1,
                      color: tc.outlineVariant.withOpacity(0.5),
                    ),
                ],
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  String _dayKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(date);
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
        style: AppFonts.sans(
          color: AppThemeColors.of(context).onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      );
}

/// Shimmer-style row shown at the top of the list while a voice log is being
/// transcribed + parsed in the background (the auto-save flow).
class _VoiceLoggingRow extends StatelessWidget {
  final AppThemeColors tc;
  const _VoiceLoggingRow({required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(tc.onSurface),
              backgroundColor: tc.outlineVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logging your transaction…',
                  style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Transcribing and saving',
                  style: AppFonts.sans(
                    color: tc.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.mic_rounded, color: tc.onSurfaceVariant, size: 18),
        ],
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
            borderRadius: BorderRadius.circular(12),
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
              style: AppFonts.sans(
                color: tc.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hold the mic to speak, or tap Manual to start tracking',
              style: AppFonts.sans(
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
// Space header title — shows active space chip
// ─────────────────────────────────────────────

class _SpaceHeaderTitle extends ConsumerWidget {
  final AppThemeColors tc;
  const _SpaceHeaderTitle({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeSpaceIdProvider);
    final spacesAsync = ref.watch(spaceListProvider);

    final activeSpace = spacesAsync.valueOrNull
        ?.where((s) => s.id == activeId)
        .firstOrNull;

    final isPersonal = activeSpace == null || activeSpace.isPersonal;

    return GestureDetector(
      onTap: () => showSpaceSwitcher(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Brand lockup: open orange-pie mark + navy wordmark.
          Image.asset(
            'assets/brand/logo_mark.png',
            height: 26,
            width: 26,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 8),
          Text(
            'Money Pi',
            style: AppFonts.sans(
              color: tc.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.8,
            ),
          ),
          if (!isPersonal) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Color(activeSpace.colorValue).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(activeSpace.colorValue).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(activeSpace.emoji,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    activeSpace.name,
                    style: AppFonts.sans(
                      color: Color(activeSpace.colorValue),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(activeSpace.colorValue), size: 14),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: tc.onSurfaceVariant.withOpacity(0.5), size: 18),
          ],
        ],
      ),
    );
  }
}
