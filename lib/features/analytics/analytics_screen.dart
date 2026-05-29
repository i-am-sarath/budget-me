import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/features/paywall/paywall_screen.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────
// Range enum
// ─────────────────────────────────────────────

enum _Range {
  week('Week'),
  month('Month'),
  threeMonths('3M'),
  sixMonths('6M'),
  year('Year');

  final String label;
  const _Range(this.label);
}

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Range _range = _Range.month;
  int _touchedPieIndex = -1;
  bool _isExporting = false;

  List<TransactionModel> _filterByRange(List<TransactionModel> all) {
    final now = DateTime.now();
    switch (_range) {
      case _Range.week:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        return all.where((t) => !t.date.isBefore(start)).toList();
      case _Range.month:
        return all
            .where((t) =>
                t.date.year == now.year && t.date.month == now.month)
            .toList();
      case _Range.threeMonths:
        final cutoff = DateTime(now.year, now.month - 2, 1);
        return all.where((t) => !t.date.isBefore(cutoff)).toList();
      case _Range.sixMonths:
        final cutoff = DateTime(now.year, now.month - 5, 1);
        return all.where((t) => !t.date.isBefore(cutoff)).toList();
      case _Range.year:
        final cutoff = DateTime(now.year, now.month - 11, 1);
        return all.where((t) => !t.date.isBefore(cutoff)).toList();
    }
  }

  Future<void> _exportCsv(
      List<TransactionModel> all, CurrencyState currency) async {
    final subscription = ref.read(subscriptionProvider);
    if (!subscription.isPro) {
      await showPaywall(context);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final csv = _buildCsv(all);
      final dir = await getTemporaryDirectory();
      final name =
          'budget_me_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$name');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Budget Me export — $name');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _buildCsv(List<TransactionModel> transactions) {
    final sb = StringBuffer();
    sb.writeln('Date,Type,Category,Note,Payee,Account,Amount');
    for (final t in transactions) {
      String esc(String s) => s.contains(',') ? '"$s"' : s;
      sb.writeln([
        DateFormat('yyyy-MM-dd').format(t.date),
        t.type.label,
        esc(t.category),
        esc(t.note),
        esc(t.payee ?? ''),
        esc(t.accountName ?? ''),
        t.amount.toStringAsFixed(2),
      ].join(','));
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);
    final subscription = ref.watch(subscriptionProvider);
    final tc = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.surface,
      body: txAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          final filtered = _filterByRange(all);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: tc.surface,
                floating: true,
                snap: true,
                elevation: 0,
                titleSpacing: 20,
                title: Row(children: [
                  Text('Analytics',
                      style: GoogleFonts.hankenGrotesk(
                        color: tc.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      )),
                  const Spacer(),
                  _ExportButton(
                    isPro: subscription.isPro,
                    isLoading: _isExporting,
                    onTap: () => _exportCsv(all, currency),
                  ),
                  const SizedBox(width: 8),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Range selector
                    _RangeSelector(
                      selected: _range,
                      onChanged: (r) => setState(() => _range = r),
                    ).animate().fadeIn(duration: 280.ms),
                    const SizedBox(height: 20),

                    // Summary — 2 rows of 3
                    _SummaryGrid(
                            transactions: filtered,
                            allTransactions: all,
                            currency: currency)
                        .animate()
                        .fadeIn(delay: 40.ms),
                    const SizedBox(height: 24),

                    // Daily Spending bar
                    _SectionTitle('Spending', tc),
                    const SizedBox(height: 12),
                    _SpendingBarChart(
                            transactions: filtered,
                            currency: currency,
                            range: _range)
                        .animate()
                        .fadeIn(delay: 80.ms),
                    const SizedBox(height: 24),

                    // Category breakdown
                    _SectionTitle('Spending by Category', tc),
                    const SizedBox(height: 12),
                    _CategoryPie(
                      transactions: filtered,
                      currency: currency,
                      touchedIndex: _touchedPieIndex,
                      onTouch: (i) => setState(() => _touchedPieIndex = i),
                    ).animate().fadeIn(delay: 120.ms),
                    const SizedBox(height: 24),

                    // Income vs Expense trend
                    _SectionTitle('Income vs Expense', tc),
                    const SizedBox(height: 12),
                    _TrendLineChart(
                            transactions: filtered,
                            currency: currency,
                            range: _range)
                        .animate()
                        .fadeIn(delay: 160.ms),
                    const SizedBox(height: 24),

                    // Lend & Borrow
                    _SectionTitle('Lend & Borrow', tc),
                    const SizedBox(height: 12),
                    _LendBorrowSection(
                            transactions: all, currency: currency)
                        .animate()
                        .fadeIn(delay: 200.ms),
                    const SizedBox(height: 28),

                    // Export CTA (always visible, pro-gated)
                    _ExportCta(
                      isPro: subscription.isPro,
                      isLoading: _isExporting,
                      onTap: () => _exportCsv(all, currency),
                    ).animate().fadeIn(delay: 240.ms),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Export button — AppBar
// ─────────────────────────────────────────────

class _ExportButton extends StatelessWidget {
  final bool isPro, isLoading;
  final VoidCallback onTap;
  const _ExportButton(
      {required this.isPro,
      required this.isLoading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tc.primaryContainer,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: tc.primary.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: tc.primary))
            else if (!isPro)
              Icon(Icons.lock_rounded, size: 12, color: tc.primary)
            else
              Icon(Icons.download_rounded, size: 12, color: tc.primary),
            const SizedBox(width: 5),
            Text(
              'Export CSV',
              style: GoogleFonts.hankenGrotesk(
                  color: tc.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Range Selector
// ─────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  final _Range selected;
  final ValueChanged<_Range> onChanged;
  const _RangeSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: _Range.values.map((r) {
          final sel = r == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? tc.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(
                    color: sel ? tc.onPrimary : tc.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
// Summary Grid — 2×3 stat boxes
// ─────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final List<TransactionModel> transactions;
  final List<TransactionModel> allTransactions;
  final CurrencyState currency;

  const _SummaryGrid({
    required this.transactions,
    required this.allTransactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);

    double sum(TransactionType type, [List<TransactionModel>? source]) =>
        (source ?? transactions)
            .where((t) => t.type == type)
            .fold(0.0, (s, t) => s + t.amount);

    final income = sum(TransactionType.income);
    final expense = sum(TransactionType.expense);
    final invested = sum(TransactionType.investment);
    final saved = income - expense;

    // Outstanding lend/borrow from ALL TIME
    final lentOut =
        (sum(TransactionType.lend, allTransactions) -
                sum(TransactionType.lendReturn, allTransactions))
            .clamp(0.0, double.infinity);
    final borrowed =
        (sum(TransactionType.borrow, allTransactions) -
                sum(TransactionType.borrowReturn, allTransactions))
            .clamp(0.0, double.infinity);

    String fmt(double v) => currency.format(v);

    return Column(children: [
      // Row 1
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _StatBox(
              label: 'Income',
              value: fmt(income),
              color: tc.income,
              tc: tc),
          const SizedBox(width: 10),
          _StatBox(
              label: 'Spent',
              value: fmt(expense),
              color: tc.expense,
              tc: tc),
          const SizedBox(width: 10),
          _StatBox(
              label: saved >= 0 ? 'Saved' : 'Overspent',
              value: fmt(saved.abs()),
              color: saved >= 0 ? tc.income : tc.expense,
              tc: tc),
        ]),
      ),
      const SizedBox(height: 10),
      // Row 2
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _StatBox(
              label: 'Invested',
              value: fmt(invested),
              color: tc.investment,
              tc: tc),
          const SizedBox(width: 10),
          _StatBox(
              label: 'Lent Out',
              value: fmt(lentOut),
              color: tc.lend,
              tc: tc,
              sublabel: 'outstanding'),
          const SizedBox(width: 10),
          _StatBox(
              label: 'Borrowed',
              value: fmt(borrowed),
              color: tc.borrow,
              tc: tc,
              sublabel: 'outstanding'),
        ]),
      ),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final AppThemeColors tc;
  final String? sublabel;

  const _StatBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.tc,
      this.sublabel});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
          boxShadow: isLight
              ? [
                  BoxShadow(
                      color: const Color(0x08000000),
                      blurRadius: 6,
                      offset: const Offset(0, 1))
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.hankenGrotesk(
                    color: tc.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(value,
                style: GoogleFonts.hankenGrotesk(
                    color: tc.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (sublabel != null)
              Text(sublabel!,
                  style: GoogleFonts.hankenGrotesk(
                      color: tc.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Title
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final AppThemeColors tc;
  const _SectionTitle(this.title, this.tc);

  @override
  Widget build(BuildContext context) => Text(title,
      style: GoogleFonts.hankenGrotesk(
          color: tc.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700));
}

// ─────────────────────────────────────────────
// Spending Bar Chart — range-adaptive
// ─────────────────────────────────────────────

class _SpendingBarChart extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  final _Range range;

  const _SpendingBarChart(
      {required this.transactions,
      required this.currency,
      required this.range});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final now = DateTime.now();

    // Build buckets depending on range
    late List<double> values;
    late List<String> labels;

    switch (range) {
      case _Range.week:
        // 7 daily buckets — Mon to Sun (last 7 days)
        values = List.filled(7, 0.0);
        labels = List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          return DateFormat('EEE').format(d).substring(0, 2);
        });
        for (final t in transactions) {
          if (t.type != TransactionType.expense) continue;
          final diff = now.difference(t.date).inDays;
          if (diff > 6) continue;
          values[6 - diff] += t.amount;
        }

      case _Range.month:
        // 5 weekly buckets: week 1–4 + partial week 5
        values = List.filled(5, 0.0);
        final firstDay = DateTime(now.year, now.month, 1);
        labels = List.generate(5, (i) => 'Wk ${i + 1}');
        for (final t in transactions) {
          if (t.type != TransactionType.expense) continue;
          if (t.date.month != now.month || t.date.year != now.year) continue;
          final weekIdx =
              ((t.date.day - firstDay.day) ~/ 7).clamp(0, 4);
          values[weekIdx] += t.amount;
        }

      case _Range.threeMonths:
        // 3 monthly buckets
        values = List.filled(3, 0.0);
        labels = List.generate(3, (i) {
          final m = DateTime(now.year, now.month - (2 - i));
          return DateFormat('MMM').format(m);
        });
        for (final t in transactions) {
          if (t.type != TransactionType.expense) continue;
          final monthsAgo = (now.year - t.date.year) * 12 +
              (now.month - t.date.month);
          if (monthsAgo > 2) continue;
          values[2 - monthsAgo] += t.amount;
        }

      case _Range.sixMonths:
        // 6 monthly buckets
        values = List.filled(6, 0.0);
        labels = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - (5 - i));
          return DateFormat('MMM').format(m);
        });
        for (final t in transactions) {
          if (t.type != TransactionType.expense) continue;
          final monthsAgo = (now.year - t.date.year) * 12 +
              (now.month - t.date.month);
          if (monthsAgo > 5) continue;
          values[5 - monthsAgo] += t.amount;
        }

      case _Range.year:
        // 12 monthly buckets
        values = List.filled(12, 0.0);
        labels = List.generate(12, (i) {
          final m = DateTime(now.year, now.month - (11 - i));
          return DateFormat('MMM').format(m);
        });
        for (final t in transactions) {
          if (t.type != TransactionType.expense) continue;
          final monthsAgo = (now.year - t.date.year) * 12 +
              (now.month - t.date.month);
          if (monthsAgo > 11) continue;
          values[11 - monthsAgo] += t.amount;
        }
    }

    final maxY = values.fold(0.0, (m, v) => v > m ? v : m);
    final count = values.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: SizedBox(
        height: 190,
        child: BarChart(BarChartData(
          maxY: maxY == 0 ? 100 : maxY * 1.35,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color: tc.outlineVariant.withOpacity(0.5),
                strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= count) {
                    return const SizedBox.shrink();
                  }
                  // Show every label when ≤7 bars, else every other
                  if (count > 7 && idx % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(labels[idx],
                        style: GoogleFonts.hankenGrotesk(
                            color: tc.onSurfaceVariant,
                            fontSize: 9,
                            fontWeight: FontWeight.w500)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(count, (i) {
            final v = values[i];
            final maxVal = maxY == 0 ? 1.0 : maxY;
            final intensity = (v / maxVal).clamp(0.0, 1.0);
            final barColor = v == 0
                ? tc.outlineVariant
                : intensity < 0.5
                    ? Color.lerp(const Color(0xFF38BDF8),
                        const Color(0xFFFBBF24), intensity * 2)!
                    : Color.lerp(const Color(0xFFFBBF24),
                        const Color(0xFFEF4444), (intensity - 0.5) * 2)!;
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: v,
                gradient: v == 0
                    ? null
                    : LinearGradient(
                        colors: [barColor.withOpacity(0.7), barColor],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                color: v == 0 ? tc.outlineVariant : null,
                width: count <= 7 ? 22 : count <= 12 ? 16 : 10,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ]);
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => tc.surfaceContainerHigh,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                currency.format(rod.toY),
                GoogleFonts.hankenGrotesk(
                    color: tc.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
            ),
          ),
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Category Pie Chart
// ─────────────────────────────────────────────

class _CategoryPie extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _CategoryPie({
    required this.transactions,
    required this.currency,
    required this.touchedIndex,
    required this.onTouch,
  });

  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final catMap = <String, double>{};
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
      }
    }

    if (catMap.isEmpty) {
      return _emptyCard('No expense data for this period', tc);
    }

    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final total = top.fold(0.0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(children: [
        SizedBox(
          height: 200,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 48,
            pieTouchData: PieTouchData(
              touchCallback: (event, resp) {
                if (event is FlTapUpEvent) {
                  onTouch(
                      resp?.touchedSection?.touchedSectionIndex ?? -1);
                }
              },
            ),
            sections: List.generate(top.length, (i) {
              final isTouched = i == touchedIndex;
              final pct =
                  (top[i].value / total * 100).toStringAsFixed(1);
              final col = _colors[i % _colors.length];
              return PieChartSectionData(
                value: top[i].value,
                color: col,
                radius: isTouched ? 76 : 62,
                title: isTouched ? '$pct%' : '',
                titleStyle: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                borderSide: isTouched
                    ? BorderSide(color: col.withOpacity(0.6), width: 3)
                    : const BorderSide(color: Colors.transparent),
              );
            }),
          )),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: List.generate(top.length, (i) {
            final col = _colors[i % _colors.length];
            final pct = total > 0
                ? (top[i].value / total * 100).toStringAsFixed(0)
                : '0';
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: col, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text('${top[i].key}  $pct%  ${currency.format(top[i].value)}',
                  style: GoogleFonts.hankenGrotesk(
                      color: tc.onSurfaceVariant, fontSize: 11)),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _emptyCard(String msg, AppThemeColors tc) => Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Text(msg,
            style: GoogleFonts.hankenGrotesk(
                color: tc.onSurfaceVariant, fontSize: 13)),
      );
}

// ─────────────────────────────────────────────
// Income vs Expense Trend Line Chart
// ─────────────────────────────────────────────

class _TrendLineChart extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  final _Range range;

  const _TrendLineChart(
      {required this.transactions,
      required this.currency,
      required this.range});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final now = DateTime.now();

    late List<double> incomeVals;
    late List<double> expenseVals;
    late List<String> labels;

    switch (range) {
      case _Range.week:
        incomeVals = List.filled(7, 0.0);
        expenseVals = List.filled(7, 0.0);
        labels = List.generate(7, (i) =>
            DateFormat('EEE')
                .format(now.subtract(Duration(days: 6 - i)))
                .substring(0, 2));
        for (final t in transactions) {
          final diff = now.difference(t.date).inDays;
          if (diff > 6) continue;
          final idx = 6 - diff;
          if (t.type == TransactionType.income) incomeVals[idx] += t.amount;
          if (t.type == TransactionType.expense) expenseVals[idx] += t.amount;
        }

      case _Range.month:
        incomeVals = List.filled(5, 0.0);
        expenseVals = List.filled(5, 0.0);
        labels = List.generate(5, (i) => 'W${i + 1}');
        final firstDay = DateTime(now.year, now.month, 1);
        for (final t in transactions) {
          if (t.date.month != now.month || t.date.year != now.year) continue;
          final wk = ((t.date.day - firstDay.day) ~/ 7).clamp(0, 4);
          if (t.type == TransactionType.income) incomeVals[wk] += t.amount;
          if (t.type == TransactionType.expense) expenseVals[wk] += t.amount;
        }

      case _Range.threeMonths:
        incomeVals = List.filled(3, 0.0);
        expenseVals = List.filled(3, 0.0);
        labels = List.generate(
            3,
            (i) => DateFormat('MMM')
                .format(DateTime(now.year, now.month - (2 - i))));
        for (final t in transactions) {
          final mo = (now.year - t.date.year) * 12 +
              (now.month - t.date.month);
          if (mo > 2) continue;
          if (t.type == TransactionType.income) incomeVals[2 - mo] += t.amount;
          if (t.type == TransactionType.expense) expenseVals[2 - mo] += t.amount;
        }

      case _Range.sixMonths:
        incomeVals = List.filled(6, 0.0);
        expenseVals = List.filled(6, 0.0);
        labels = List.generate(
            6,
            (i) => DateFormat('MMM')
                .format(DateTime(now.year, now.month - (5 - i))));
        for (final t in transactions) {
          final mo = (now.year - t.date.year) * 12 +
              (now.month - t.date.month);
          if (mo > 5) continue;
          if (t.type == TransactionType.income) incomeVals[5 - mo] += t.amount;
          if (t.type == TransactionType.expense) expenseVals[5 - mo] += t.amount;
        }

      case _Range.year:
        incomeVals = List.filled(12, 0.0);
        expenseVals = List.filled(12, 0.0);
        labels = List.generate(
            12,
            (i) => DateFormat('MMM')
                .format(DateTime(now.year, now.month - (11 - i))));
        for (final t in transactions) {
          final mo = (now.year - t.date.year) * 12 +
              (now.month - t.date.month);
          if (mo > 11) continue;
          if (t.type == TransactionType.income) incomeVals[11 - mo] += t.amount;
          if (t.type == TransactionType.expense) expenseVals[11 - mo] += t.amount;
        }
    }

    final maxY = [...incomeVals, ...expenseVals]
        .fold(0.0, (m, v) => v > m ? v : m);
    final count = labels.length;

    FlSpot spot(int i, double v) => FlSpot(i.toDouble(), v);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _LegendDot(color: tc.income, label: 'Income', tc: tc),
          const SizedBox(width: 16),
          _LegendDot(color: tc.expense, label: 'Expense', tc: tc),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            minY: 0,
            maxY: maxY == 0 ? 100 : maxY * 1.3,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: tc.outlineVariant.withOpacity(0.5),
                  strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= count) {
                      return const SizedBox.shrink();
                    }
                    if (count > 7 && idx % 2 != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(labels[idx],
                          style: GoogleFonts.hankenGrotesk(
                              color: tc.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w500)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              _buildLine(
                  List.generate(count, (i) => spot(i, incomeVals[i])),
                  tc.income),
              _buildLine(
                  List.generate(count, (i) => spot(i, expenseVals[i])),
                  tc.expense),
            ],
          )),
        ),
      ]),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
            radius: spot.y == 0 ? 0 : 3,
            color: color,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
}

// ─────────────────────────────────────────────
// Lend & Borrow Section
// ─────────────────────────────────────────────

class _LendBorrowSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;

  const _LendBorrowSection(
      {required this.transactions, required this.currency});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);

    double sum(TransactionType t) =>
        transactions.where((tx) => tx.type == t).fold(0.0, (s, tx) => s + tx.amount);

    final lentTotal = sum(TransactionType.lend);
    final lentBack = sum(TransactionType.lendReturn);
    final borrowedTotal = sum(TransactionType.borrow);
    final borrowedBack = sum(TransactionType.borrowReturn);
    final lentOut = (lentTotal - lentBack).clamp(0.0, double.infinity);
    final borrowed = (borrowedTotal - borrowedBack).clamp(0.0, double.infinity);

    final lendBorrowTx = transactions
        .where((t) =>
            t.type == TransactionType.lend ||
            t.type == TransactionType.borrow ||
            t.type == TransactionType.lendReturn ||
            t.type == TransactionType.borrowReturn)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = lendBorrowTx.take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Balance cards
      Row(children: [
        _LendBorrowCard(
          label: 'Lent Out',
          total: lentTotal,
          settled: lentBack,
          outstanding: lentOut,
          color: tc.lend,
          icon: Icons.people_alt_rounded,
          currency: currency,
          tc: tc,
        ),
        const SizedBox(width: 10),
        _LendBorrowCard(
          label: 'Borrowed',
          total: borrowedTotal,
          settled: borrowedBack,
          outstanding: borrowed,
          color: tc.borrow,
          icon: Icons.person_add_alt_1_rounded,
          currency: currency,
          tc: tc,
        ),
      ]),

      if (recent.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: Column(
            children: recent.asMap().entries.map((e) {
              final t = e.value;
              final isLend = t.type == TransactionType.lend ||
                  t.type == TransactionType.lendReturn;
              final color = isLend ? tc.lend : tc.borrow;
              final isReturn = t.type == TransactionType.lendReturn ||
                  t.type == TransactionType.borrowReturn;
              return Column(children: [
                if (e.key > 0)
                  Divider(height: 1, color: tc.outlineVariant),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                          isReturn
                              ? Icons.undo_rounded
                              : isLend
                                  ? Icons.people_alt_rounded
                                  : Icons.person_add_alt_1_rounded,
                          color: color,
                          size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                          t.payee?.isNotEmpty == true
                              ? t.payee!
                              : t.note.isNotEmpty
                                  ? t.note
                                  : t.type.label,
                          style: GoogleFonts.hankenGrotesk(
                              color: tc.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${t.type.label} · ${DateFormat('d MMM y').format(t.date)}',
                          style: GoogleFonts.hankenGrotesk(
                              color: tc.onSurfaceVariant,
                              fontSize: 10),
                        ),
                      ]),
                    ),
                    Text(
                      '${isReturn ? '+' : '−'} ${currency.format(t.amount)}',
                      style: GoogleFonts.hankenGrotesk(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ]);
            }).toList(),
          ),
        ),
      ] else ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: Center(
            child: Text('No lending or borrowing activity',
                style: GoogleFonts.hankenGrotesk(
                    color: tc.onSurfaceVariant, fontSize: 13)),
          ),
        ),
      ],
    ]);
  }
}

class _LendBorrowCard extends StatelessWidget {
  final String label;
  final double total, settled, outstanding;
  final Color color;
  final IconData icon;
  final CurrencyState currency;
  final AppThemeColors tc;

  const _LendBorrowCard({
    required this.label,
    required this.total,
    required this.settled,
    required this.outstanding,
    required this.color,
    required this.icon,
    required this.currency,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    final settledPct =
        total > 0 ? (settled / total).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.hankenGrotesk(
                      color: tc.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ]),
            const SizedBox(height: 8),
            Text(
              currency.format(outstanding),
              style: GoogleFonts.hankenGrotesk(
                  color: outstanding > 0 ? color : tc.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
            Text('outstanding',
                style: GoogleFonts.hankenGrotesk(
                    color: tc.onSurfaceVariant.withOpacity(0.6),
                    fontSize: 9)),
            if (total > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: settledPct,
                  minHeight: 4,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(settledPct * 100).toStringAsFixed(0)}% settled',
                style: GoogleFonts.hankenGrotesk(
                    color: tc.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Export CTA card (bottom of page)
// ─────────────────────────────────────────────

class _ExportCta extends StatelessWidget {
  final bool isPro, isLoading;
  final VoidCallback onTap;
  const _ExportCta(
      {required this.isPro,
      required this.isLoading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isPro ? tc.primary.withOpacity(0.08) : tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPro
                ? tc.primary.withOpacity(0.3)
                : tc.outlineVariant,
            width: isPro ? 1 : 0.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPro
                  ? tc.primary.withOpacity(0.15)
                  : tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: tc.primary)))
                : Icon(
                    isPro
                        ? Icons.download_rounded
                        : Icons.lock_rounded,
                    color: isPro ? tc.primary : tc.onSurfaceVariant,
                    size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Text(
                  'Export to CSV',
                  style: GoogleFonts.hankenGrotesk(
                      color: tc.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                if (!isPro) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: tc.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('PRO',
                        style: GoogleFonts.hankenGrotesk(
                            color: tc.onPrimary,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                isPro
                    ? 'Download all transactions as a spreadsheet'
                    : 'Upgrade to Pro to export your data',
                style: GoogleFonts.hankenGrotesk(
                    color: tc.onSurfaceVariant, fontSize: 11),
              ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: tc.onSurfaceVariant, size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Legend dot helper
// ─────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final AppThemeColors tc;
  const _LegendDot(
      {required this.color, required this.label, required this.tc});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.hankenGrotesk(
                  color: tc.onSurfaceVariant, fontSize: 11)),
        ],
      );
}
