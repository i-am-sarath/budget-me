import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _touchedPieIndex = -1;
  // 0=30d, 1=3m, 2=6m
  int _rangeSel = 0;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);
    final tc = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.surface,
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                title: Text('Analytics',
                    style: GoogleFonts.inter(
                      color: tc.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    )),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Range selector
                    _RangeSelector(
                      selected: _rangeSel,
                      onChanged: (v) => setState(() => _rangeSel = v),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 20),

                    // Summary row
                    _SummaryRow(transactions: filtered, currency: currency)
                        .animate().fadeIn(delay: 60.ms),
                    const SizedBox(height: 24),

                    // Bar chart
                    _SectionTitle('Daily Spending', tc),
                    const SizedBox(height: 12),
                    _BarChartCard(transactions: filtered, currency: currency)
                        .animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 24),

                    // Category breakdown
                    _SectionTitle('Spending by Category', tc),
                    const SizedBox(height: 12),
                    _PieSection(
                      transactions: filtered,
                      currency: currency,
                      touchedIndex: _touchedPieIndex,
                      onTouch: (i) => setState(() => _touchedPieIndex = i),
                    ).animate().fadeIn(delay: 140.ms),
                    const SizedBox(height: 24),

                    // Income vs Expense trend
                    _SectionTitle('Income vs Expense', tc),
                    const SizedBox(height: 12),
                    _LineChartCard(transactions: filtered, currency: currency)
                        .animate().fadeIn(delay: 180.ms),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TransactionModel> _filterByRange(List<TransactionModel> all) {
    final now = DateTime.now();
    final days = [30, 90, 180][_rangeSel];
    final cutoff = now.subtract(Duration(days: days));
    return all.where((t) => t.date.isAfter(cutoff)).toList();
  }
}

// ─── Range Selector ─────────────────────────────────────
class _RangeSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _RangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final labels = ['30 Days', '3 Months', '6 Months'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final sel = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? tc.onSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: sel ? tc.surface : tc.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  const _SummaryRow({required this.transactions, required this.currency});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final saved = income - expense;

    return Row(
      children: [
        _StatBox(label: 'Income', value: currency.format(income),
            color: tc.income, tc: tc),
        const SizedBox(width: 10),
        _StatBox(label: 'Spent', value: currency.format(expense),
            color: tc.expense, tc: tc),
        const SizedBox(width: 10),
        _StatBox(label: 'Saved', value: currency.format(saved.abs()),
            color: saved >= 0 ? tc.income : tc.expense, tc: tc),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final AppThemeColors tc;
  const _StatBox({required this.label, required this.value,
      required this.color, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.inter(color: tc.onSurfaceVariant,
                    fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(value,
                style: GoogleFonts.inter(color: tc.onSurface,
                    fontSize: 13, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final AppThemeColors tc;
  const _SectionTitle(this.title, this.tc);

  @override
  Widget build(BuildContext context) => Text(title,
      style: GoogleFonts.inter(
          color: tc.onSurface, fontSize: 15, fontWeight: FontWeight.w700));
}

// ─── Bar Chart ────────────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;

  // Cache DateFormat for performance
  static final _dateFormat = DateFormat('d/M');

  const _BarChartCard({required this.transactions, required this.currency});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    // Group expenses by day (last 14 days)
    final now = DateTime.now();
    final dailyData = <int, double>{};
    for (var i = 13; i >= 0; i--) {
      dailyData[i] = 0.0;
    }
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        final diff = now.difference(t.date).inDays;
        if (diff <= 13) dailyData[diff] = (dailyData[diff] ?? 0) + t.amount;
      }
    }
    final maxY = dailyData.values.fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY == 0 ? 100 : maxY * 1.3,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: tc.outlineVariant.withOpacity(0.5), strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (val, _) {
                    final daysAgo = 13 - val.toInt();
                    if (daysAgo % 4 != 0) return const SizedBox.shrink();
                    final date = now.subtract(Duration(days: daysAgo));
                    return Text(_dateFormat.format(date),
                        style: GoogleFonts.inter(
                            color: tc.onSurfaceVariant, fontSize: 9));
                  },
                ),
              ),
            ),
            barGroups: List.generate(14, (i) {
              final daysAgo = 13 - i;
              final value = dailyData[daysAgo] ?? 0;
              final maxVal = maxY == 0 ? 1.0 : maxY;
              final intensity = (value / maxVal).clamp(0.0, 1.0);
              // Gradient from sky-blue (low) → amber (mid) → red (high)
              final barColor = value == 0
                  ? tc.outlineVariant
                  : intensity < 0.5
                      ? Color.lerp(const Color(0xFF38BDF8), const Color(0xFFFBBF24), intensity * 2)!
                      : Color.lerp(const Color(0xFFFBBF24), const Color(0xFFEF4444), (intensity - 0.5) * 2)!;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: value,
                    gradient: value == 0
                        ? null
                        : LinearGradient(
                            colors: [barColor.withOpacity(0.7), barColor],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                    color: value == 0 ? tc.outlineVariant : null,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  ),
                ],
              );
            }),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => tc.surfaceContainerHigh,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  currency.format(rod.toY),
                  GoogleFonts.inter(color: tc.onSurface,
                      fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pie Chart ────────────────────────────────────────────
class _PieSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _PieSection({
    required this.transactions,
    required this.currency,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final expenses = transactions.where((t) => t.type == TransactionType.expense);
    final catMap = <String, double>{};
    for (final t in expenses) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    if (catMap.isEmpty) {
      return _emptyCard('No expense data yet', tc);
    }

    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final total = top.fold(0.0, (s, e) => s + e.value);

    // Vibrant category palette
    const categoryColors = [
      Color(0xFF6366F1), // indigo
      Color(0xFFF59E0B), // amber
      Color(0xFF10B981), // emerald
      Color(0xFFEF4444), // red
      Color(0xFF8B5CF6), // violet
      Color(0xFF06B6D4), // cyan
    ];
    final greys = categoryColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 48,
                pieTouchData: PieTouchData(
                  touchCallback: (event, resp) {
                    if (event is FlTapUpEvent) {
                      onTouch(resp?.touchedSection?.touchedSectionIndex ?? -1);
                    }
                  },
                ),
                sections: List.generate(top.length, (i) {
                  final isTouched = i == touchedIndex;
                  final pct = (top[i].value / total * 100).toStringAsFixed(1);
                  final col = greys[i % greys.length];
                  return PieChartSectionData(
                    value: top[i].value,
                    color: col,
                    radius: isTouched ? 74 : 62,
                    title: isTouched ? '$pct%' : '',
                    titleStyle: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    borderSide: isTouched
                        ? BorderSide(color: col.withOpacity(0.6), width: 3)
                        : const BorderSide(color: Colors.transparent),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(top.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: greys[i % greys.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${top[i].key} · ${currency.format(top[i].value)}',
                    style: GoogleFonts.inter(
                        color: tc.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String msg, AppThemeColors tc) => Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Text(msg,
            style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13)),
      );
}

// ─── Line Chart ───────────────────────────────────────────
class _LineChartCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;

  // Cache DateFormat for performance
  static final _dateFormat = DateFormat('d/M');

  const _LineChartCard({required this.transactions, required this.currency});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    // Group by week
    final now = DateTime.now();
    const weeks = 8;
    final incomeW = List<double>.filled(weeks, 0);
    final expenseW = List<double>.filled(weeks, 0);

    for (final t in transactions) {
      final weeksAgo = now.difference(t.date).inDays ~/ 7;
      if (weeksAgo >= weeks) continue;
      final idx = weeks - 1 - weeksAgo;
      if (t.type == TransactionType.income) incomeW[idx] += t.amount;
      if (t.type == TransactionType.expense) expenseW[idx] += t.amount;
    }

    final maxY = [...incomeW, ...expenseW].fold(0.0, (m, v) => v > m ? v : m);

    FlSpot spot(int i, double v) => FlSpot(i.toDouble(), v);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    color: tc.outlineVariant.withOpacity(0.5), strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (val, _) {
                      final weeksAgo = weeks - 1 - val.toInt();
                      if (weeksAgo % 2 != 0) return const SizedBox.shrink();
                      final date = now.subtract(Duration(days: weeksAgo * 7));
                      return Text(_dateFormat.format(date),
                          style: GoogleFonts.inter(
                              color: tc.onSurfaceVariant, fontSize: 9));
                    },
                  ),
                ),
              ),
              lineBarsData: [
                _line(List.generate(weeks, (i) => spot(i, incomeW[i])),
                    tc.income),
                _line(List.generate(weeks, (i) => spot(i, expenseW[i])),
                    tc.expense),
              ],
            )),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) =>
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final AppThemeColors tc;
  const _LegendDot({required this.color, required this.label, required this.tc});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(
              color: tc.onSurfaceVariant, fontSize: 11)),
        ],
      );
}
