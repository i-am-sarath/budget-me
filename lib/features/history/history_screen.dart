import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/dashboard/widgets/transaction_tile.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';
  TransactionType? _filter; // null = all
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);

    final tc = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.surface,
      body: transactionsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTx) {
          // Filter by month
          var filtered = allTx
              .where(
                (t) =>
                    t.date.year == _selectedMonth.year &&
                    t.date.month == _selectedMonth.month,
              )
              .toList();

          // Filter by type
          filtered = _filter == null
              ? filtered
              : filtered.where((t) => t.type == _filter).toList();

          // Filter by search query
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            filtered = filtered
                .where(
                  (t) =>
                      t.category.toLowerCase().contains(q) ||
                      t.note.toLowerCase().contains(q) ||
                      (t.payee?.toLowerCase().contains(q) ?? false),
                )
                .toList();
          }

          // Group by date
          final grouped = _groupByDate(filtered);
          final dates = grouped.keys.toList();

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
                title: Row(
                  children: [
                    Text(
                      'History',
                      style: GoogleFonts.inter(
                        color: tc.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Semantics(
                          label: 'Previous month',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              color: tc.onSurfaceVariant,
                            ),
                            onPressed: () => _changeMonth(-1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Previous month',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM yyyy').format(_selectedMonth),
                          style: GoogleFonts.inter(
                            color: tc.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          label: 'Next month',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: tc.onSurfaceVariant,
                            ),
                            onPressed: () => _changeMonth(1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Next month',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(110),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      children: [
                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: tc.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tc.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            style: GoogleFonts.inter(
                              color: tc.onSurface,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search transactions...',
                              hintStyle: GoogleFonts.inter(
                                color: tc.onSurfaceVariant,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: tc.onSurfaceVariant,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All',
                                isActive: _filter == null,
                                onTap: () => setState(() => _filter = null),
                              ),
                              ...TransactionType.values.map(
                                (t) => _FilterChip(
                                  label: t.label,
                                  isActive: _filter == t,
                                  onTap: () => setState(() => _filter = t),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (dates.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: tc.onSurfaceVariant,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: GoogleFonts.inter(
                            color: tc.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final dateKey = dates[i];
                      final items = grouped[dateKey]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 16),
                            child: Row(
                              children: [
                                Text(
                                  _formatGroupDate(dateKey),
                                  style: GoogleFonts.inter(
                                    color: tc.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: 0.5,
                                    color: tc.outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _groupTotal(items, currency),
                                  style: GoogleFonts.inter(
                                    color: tc.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...items.asMap().entries.map((e) {
                            return TransactionTile(
                              transaction: e.value,
                              currency: currency,
                            ).animate().fadeIn(
                              duration: 300.ms,
                              delay: (e.key * 40).ms,
                            );
                          }),
                        ],
                      );
                    }, childCount: dates.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<TransactionModel>> _groupByDate(
    List<TransactionModel> transactions,
  ) {
    final Map<String, List<TransactionModel>> groups = {};
    for (final t in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(t.date);
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups;
  }

  String _formatGroupDate(String key) {
    final date = DateTime.parse(key);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return DateFormat('MMMM d, yyyy').format(date).toUpperCase();
  }

  String _groupTotal(List<TransactionModel> items, CurrencyState currency) {
    double net = 0;
    for (final t in items) {
      if (t.type == TransactionType.income) net += t.amount;
      if (t.type == TransactionType.expense) net -= t.amount;
    }
    final prefix = net >= 0 ? '+' : '';
    return '$prefix${currency.format(net)}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? tc.onSurface : tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? Colors.transparent : tc.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? tc.surface : tc.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
