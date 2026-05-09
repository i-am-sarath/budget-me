import 'package:flutter/material.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:google_fonts/google_fonts.dart';

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

    double expense = 0.0, income = 0.0, invested = 0.0;
    double totalLent = 0.0, totalLentReturned = 0.0;
    double totalBorrowed = 0.0, totalBorrowReturned = 0.0;

    // Single-pass optimization: Instead of iterating the transactions list multiple times
    // with .where().fold(), calculate all totals in a single pass.
    // This reduces O(N * 7) traversals down to O(N).
    for (final t in transactions) {
      final isThisMonth = t.date.month == now.month && t.date.year == now.year;

      if (isThisMonth) {
        if (t.type == TransactionType.expense) {
          expense += t.amount;
        }
        if (t.type == TransactionType.income) {
          income += t.amount;
        }
        if (t.type == TransactionType.investment) {
          invested += t.amount;
        }
      }

      if (t.type == TransactionType.lend) {
        totalLent += t.amount;
      }
      if (t.type == TransactionType.lendReturn) {
        totalLentReturned += t.amount;
      }
      if (t.type == TransactionType.borrow) {
        totalBorrowed += t.amount;
      }
      if (t.type == TransactionType.borrowReturn) {
        totalBorrowReturned += t.amount;
      }
    }

    final outstandingLent = (totalLent - totalLentReturned).clamp(
      0.0,
      double.infinity,
    );
    final outstandingBorrowed = (totalBorrowed - totalBorrowReturned).clamp(
      0.0,
      double.infinity,
    );

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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
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
            style: GoogleFonts.inter(
              color: tc.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _compactFormat(amount, currency),
            style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
