import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

class TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;
  final CurrencyState currency;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final (typeColor, prefix, icon) = _typeStyle(transaction.type, tc);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: tc.errorContainer,
        child: Icon(Icons.delete_sweep_rounded, color: tc.expense, size: 24),
      ),
      onDismissed: (_) {
        ref
            .read(transactionListProvider.notifier)
            .deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => ref
                  .read(transactionListProvider.notifier)
                  .addTransaction(transaction),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.outline, width: 1.0),
        ),
        child: Row(
          children: [
            // 48px circle icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 14),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note.isNotEmpty
                        ? transaction.note
                        : transaction.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sans(
                      color: tc.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sans(
                      color: tc.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount right-aligned, color-coded
            Text(
              '$prefix${currency.format(transaction.amount)}',
              style: AppFonts.sans(
                color: typeColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    parts.add(transaction.category);
    if (transaction.accountName != null && transaction.accountName!.isNotEmpty) {
      parts.add(transaction.accountName!);
    }
    if (transaction.payee != null && transaction.payee!.isNotEmpty) {
      parts.add(transaction.payee!);
    }
    return parts.join(' · ');
  }

  (Color, String, IconData) _typeStyle(
      TransactionType type, AppThemeColors tc) {
    switch (type) {
      case TransactionType.expense:
        return (tc.expense, '−', Icons.arrow_upward_rounded);
      case TransactionType.income:
        return (tc.income, '+', Icons.arrow_downward_rounded);
      case TransactionType.investment:
        return (tc.investment, '→', Icons.trending_up_rounded);
      case TransactionType.lend:
        return (tc.lend, '↗', Icons.people_alt_rounded);
      case TransactionType.borrow:
        return (tc.borrow, '↙', Icons.person_add_alt_1_rounded);
      case TransactionType.lendReturn:
        return (tc.income, '←', Icons.undo_rounded);
      case TransactionType.borrowReturn:
        return (tc.expense, '→', Icons.redo_rounded);
      case TransactionType.transferOut:
        return (tc.investment, '⇄', Icons.swap_horiz_rounded);
      case TransactionType.transferIn:
        return (tc.investment, '⇄', Icons.swap_horiz_rounded);
    }
  }

}

