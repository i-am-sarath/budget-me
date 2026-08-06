import 'package:flutter/material.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/services/currency_service.dart';
import 'package:money_pi/features/transactions/models/transaction_model.dart';

class SummaryCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final CurrencyState currency;

  const SummaryCard({
    super.key,
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = transactions.where(
        (t) => t.date.month == now.month && t.date.year == now.year);
    final expense = thisMonth
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final income = thisMonth
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final invested = thisMonth
        .where((t) => t.type == TransactionType.investment)
        .fold(0.0, (s, t) => s + t.amount);

    // Outstanding lent/borrowed — all-time running totals
    final totalLent = transactions
        .where((t) => t.type == TransactionType.lend)
        .fold(0.0, (s, t) => s + t.amount);
    final totalLentReturned = transactions
        .where((t) => t.type == TransactionType.lendReturn)
        .fold(0.0, (s, t) => s + t.amount);
    final outstandingLent =
        (totalLent - totalLentReturned).clamp(0.0, double.infinity);

    final totalBorrowed = transactions
        .where((t) => t.type == TransactionType.borrow)
        .fold(0.0, (s, t) => s + t.amount);
    final totalBorrowReturned = transactions
        .where((t) => t.type == TransactionType.borrowReturn)
        .fold(0.0, (s, t) => s + t.amount);
    final outstandingBorrowed =
        (totalBorrowed - totalBorrowReturned).clamp(0.0, double.infinity);

    final showLendBorrow = outstandingLent > 0 || outstandingBorrowed > 0;
    final tc = AppThemeColors.of(context);

    return Column(
      children: [
        // Row 1 — always visible: Spent | Earned | Invested
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BentoItem(
                  label: 'Spent',
                  amount: expense,
                  currency: currency,
                  accentColor: tc.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoItem(
                  label: 'Earned',
                  amount: income,
                  currency: currency,
                  accentColor: tc.income,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoItem(
                  label: 'Invested',
                  amount: invested,
                  currency: currency,
                  accentColor: tc.investment,
                ),
              ),
            ],
          ),
        ),

        // Row 2 — Lent | Borrowed | (spacer for alignment)
        if (showLendBorrow) ...[
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BentoItem(
                    label: 'Lent Out',
                    amount: outstandingLent,
                    currency: currency,
                    accentColor: tc.lend,
                    sublabel: 'outstanding',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BentoItem(
                    label: 'Borrowed',
                    amount: outstandingBorrowed,
                    currency: currency,
                    accentColor: tc.borrow,
                    sublabel: 'outstanding',
                  ),
                ),
                // Third column spacer keeps same item width as row above
                const SizedBox(width: 10),
                Expanded(child: const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BentoItem extends StatelessWidget {
  final String label;
  final double amount;
  final CurrencyState currency;
  final Color accentColor;
  final String? sublabel;

  const _BentoItem({
    required this.label,
    required this.amount,
    required this.currency,
    required this.accentColor,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outline, width: 1.0),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: const Color(0x0A000000),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
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
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppFonts.sans(
              color: tc.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _compactFormat(amount, currency),
            style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: AppFonts.sans(
                color: tc.onSurfaceVariant.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _compactFormat(double value, CurrencyState c) {
    if (value >= 1000000) {
      return '${c.currency.symbol}${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 100000) {
      return '${c.currency.symbol}${(value / 1000).toStringAsFixed(0)}K';
    } else if (value >= 10000) {
      return '${c.currency.symbol}${(value / 1000).toStringAsFixed(1)}K';
    }
    return c.format(value);
  }
}
