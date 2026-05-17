import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

bool affectsAccount(TransactionType t) {
  return t == TransactionType.income ||
      t == TransactionType.expense ||
      t == TransactionType.investment ||
      t == TransactionType.lendReturn ||
      t == TransactionType.borrowReturn;
}

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
    final needsAccount = affectsAccount(transaction.type) &&
        (transaction.accountId == null || transaction.accountId!.isEmpty);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: tc.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_sweep_rounded, color: tc.expense, size: 24),
      ),
      onDismissed: (_) {
        ref
            .read(transactionListProvider.notifier)
            .deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                ref
                    .read(transactionListProvider.notifier)
                    .addTransaction(transaction);
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.fromLTRB(16, 14, 16, needsAccount ? 10 : 14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: needsAccount
                ? tc.outlineVariant.withOpacity(0.8)
                : tc.outlineVariant,
            width: needsAccount ? 1.0 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: typeColor, size: 18),
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
                        style: GoogleFonts.inter(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            transaction.category,
                            style: GoogleFonts.inter(
                              color: tc.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          if (transaction.accountName != null &&
                              transaction.accountName!.isNotEmpty) ...[
                            Text(
                              ' · ${transaction.accountName}',
                              style: GoogleFonts.inter(
                                color: tc.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (transaction.payee != null &&
                              transaction.payee!.isNotEmpty) ...[
                            Text(
                              ' · ${transaction.payee}',
                              style: GoogleFonts.inter(
                                color: tc.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Amount + date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$prefix${currency.format(transaction.amount)}',
                      style: GoogleFonts.inter(
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(transaction.date),
                      style: GoogleFonts.inter(
                        color: tc.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Inline account picker — shown when no account is linked
            if (needsAccount) ...[
              const SizedBox(height: 10),
              _InlineAccountPicker(transaction: transaction, tc: tc),
            ],
          ],
        ),
      ),
    );
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
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM').format(date);
  }
}

// ─────────────────────────────────────────────
// Inline account picker (shown for unlinked transactions)
// ─────────────────────────────────────────────

class _InlineAccountPicker extends ConsumerWidget {
  final TransactionModel transaction;
  final AppThemeColors tc;

  const _InlineAccountPicker({
    required this.transaction,
    required this.tc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountProvider).valueOrNull ?? [];
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 10, color: tc.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'LINK ACCOUNT',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: accounts.map((account) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => _linkAccount(context, ref, account),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tc.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                      border:
                          Border.all(color: tc.outlineVariant, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(account.type.icon,
                            size: 11, color: account.type.color),
                        const SizedBox(width: 5),
                        Text(
                          account.name,
                          style: GoogleFonts.inter(
                            color: tc.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _linkAccount(
      BuildContext context, WidgetRef ref, AccountModel account) async {
    HapticFeedback.lightImpact();
    final updated = transaction.copyWith(
      accountId: account.id,
      accountName: account.name,
    );
    await ref
        .read(transactionListProvider.notifier)
        .updateTransaction(transaction, updated);
  }
}
