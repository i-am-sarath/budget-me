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

    // Performance optimization: Single pass through transactions
    // rather than repeated .where().fold() chains avoids multiple iterations
    double income = 0;
    double expense = 0;
    double invested = 0;
    double lend = 0;

    for (final t in transactions) {
      if (t.date.month == now.month && t.date.year == now.year) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else if (t.type == TransactionType.expense) {
          expense += t.amount;
        } else if (t.type == TransactionType.investment) {
          invested += t.amount;
        } else if (t.type == TransactionType.lend) {
          lend += t.amount;
        }
      }
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _BentoItem(
            label: 'Spent',
            amount: expense,
            currency: currency,
            accentColor: AppThemeColors.of(context).expense,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _BentoItem(
            label: 'Earned',
            amount: income,
            currency: currency,
            accentColor: AppThemeColors.of(context).income,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _BentoItem(
            label: 'Invested',
            amount: invested,
            currency: currency,
            accentColor: AppThemeColors.of(context).investment,
          ),
        ),
        if (lend > 0) ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _BentoItem(
              label: 'Lent',
              amount: lend.abs(),
              currency: currency,
              accentColor: AppThemeColors.of(context).lend,
              compact: true,
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
  final bool compact;

  const _BentoItem({
    required this.label,
    required this.amount,
    required this.currency,
    required this.accentColor,
    this.compact = false,
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
        children: [
          // Accent dot
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
            compact
                ? _compactFormat(amount, currency)
                : currency.format(amount),
            style: GoogleFonts.inter(
              color: tc.onSurface,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _compactFormat(double value, CurrencyState c) {
    if (value >= 1000000) {
      return '${c.currency.symbol}${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${c.currency.symbol}${(value / 1000).toStringAsFixed(1)}K';
    }
    return c.format(value);
  }
}
