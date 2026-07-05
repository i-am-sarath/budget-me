import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/database/database_helper.dart';
import 'package:money_pi/core/services/sheets_sync_service.dart';
import 'package:money_pi/features/transactions/models/transaction_model.dart';
import 'package:money_pi/features/accounts/models/account_model.dart';
import 'package:money_pi/features/accounts/repositories/account_repository.dart';
import 'package:money_pi/features/spaces/repositories/space_repository.dart';

final transactionRepositoryProvider =
    Provider((ref) => TransactionRepository());

final transactionListProvider = StateNotifierProvider<TransactionNotifier,
    AsyncValue<List<TransactionModel>>>((ref) {
  final spaceId = ref.watch(activeSpaceIdProvider);
  return TransactionNotifier(
    ref.read(transactionRepositoryProvider),
    ref,
    spaceId,
  );
});

class TransactionNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionRepository _repository;
  final Ref _ref;
  final String _spaceId;

  TransactionNotifier(this._repository, this._ref, this._spaceId)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final transactions = await _repository.getTransactions(_spaceId);
      state = AsyncValue.data(transactions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      var tx = transaction;

      // Voice flow returns a free-form account_name (e.g. "SBI"). Resolve it to
      // a real account by fuzzy-matching, so the balance update below kicks in.
      if ((tx.accountId == null || tx.accountId!.isEmpty) &&
          tx.accountName != null &&
          tx.accountName!.isNotEmpty) {
        final accounts = _ref.read(accountProvider).valueOrNull ?? [];
        final matched = matchAccountByName(tx.accountName!, accounts);
        if (matched != null) {
          tx = tx.copyWith(accountId: matched.id, accountName: matched.name);
        }
      }

      await _repository.addTransaction(tx, _spaceId);

      // One-way mirror to the user's Google Sheet (no-op unless connected).
      // Fire-and-forget: never let a sync hiccup affect the local save.
      // ignore: discarded_futures
      SheetsSyncService.instance.appendTransaction(tx);

      // Adjust linked account balance
      if (tx.accountId != null && tx.accountId!.isNotEmpty) {
        await _ref
            .read(accountProvider.notifier)
            .adjustBalance(tx.accountId!, tx.balanceDelta);
      }

      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Move money between two accounts as one atomic operation.
  ///
  /// Both legs are written and *both* balances are adjusted before a single
  /// refresh, and any failure is rethrown so the caller can surface it (the
  /// generic [addTransaction] swallows errors into provider state, which made
  /// transfers fail silently and leave balances untouched).
  Future<void> transfer({
    required AccountModel from,
    required AccountModel to,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    if (amount <= 0) throw ArgumentError('Transfer amount must be positive');
    if (from.id == to.id) {
      throw ArgumentError('Source and destination must differ');
    }

    final displayNote = note.trim().isNotEmpty ? note.trim() : 'Transfer';
    // Repaying a loan / credit card → the credit leg reduces the liability.
    final isLoanRepayment = to.type.isLiability;

    final debit = TransactionModel(
      amount: amount,
      type: TransactionType.transferOut,
      category: isLoanRepayment ? 'Loan Repayment' : 'Transfer',
      note: '$displayNote → ${to.name}',
      accountId: from.id,
      accountName: from.name,
      date: date,
    );
    final credit = TransactionModel(
      amount: amount,
      type: isLoanRepayment
          ? TransactionType.borrowReturn
          : TransactionType.transferIn,
      category: isLoanRepayment ? 'Loan Repayment' : 'Transfer',
      note: '$displayNote ← ${from.name}',
      accountId: to.id,
      accountName: to.name,
      date: date,
    );

    // Persist both legs first…
    await _repository.addTransaction(debit, _spaceId);
    await _repository.addTransaction(credit, _spaceId);

    // …then adjust both balances (deduct from source, add to destination).
    final accounts = _ref.read(accountProvider.notifier);
    await accounts.adjustBalance(from.id, debit.balanceDelta);
    await accounts.adjustBalance(to.id, credit.balanceDelta);

    // Mirror to Google Sheets (no-op unless connected).
    // ignore: discarded_futures
    SheetsSyncService.instance.appendTransaction(debit);
    // ignore: discarded_futures
    SheetsSyncService.instance.appendTransaction(credit);

    await refresh();
  }

  Future<void> deleteTransaction(String id) async {
    try {
      // Reverse the balance effect before deleting
      final current = state.valueOrNull ?? [];
      final tx = current.where((t) => t.id == id).firstOrNull;
      if (tx != null &&
          tx.accountId != null &&
          tx.accountId!.isNotEmpty) {
        await _ref
            .read(accountProvider.notifier)
            .adjustBalance(tx.accountId!, -tx.balanceDelta);
      }

      await _repository.deleteTransaction(id);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAll(List<TransactionModel> transactions) async {
    for (final t in transactions) {
      await addTransaction(t);
    }
  }

  Future<void> updateTransaction(TransactionModel oldTx, TransactionModel newTx) async {
    try {
      // Reverse old balance effect
      if (oldTx.accountId != null && oldTx.accountId!.isNotEmpty) {
        await _ref
            .read(accountProvider.notifier)
            .adjustBalance(oldTx.accountId!, -oldTx.balanceDelta);
      }

      // Apply new balance effect
      if (newTx.accountId != null && newTx.accountId!.isNotEmpty) {
        await _ref
            .read(accountProvider.notifier)
            .adjustBalance(newTx.accountId!, newTx.balanceDelta);
      }

      await _repository.updateTransaction(newTx);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<TransactionModel>> getTransactions(String spaceId) async {
    final maps = await _dbHelper.queryAll(
      'transactions',
      whereClause: 'space_id = ?',
      whereArgs: [spaceId],
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<void> addTransaction(TransactionModel transaction, String spaceId) async {
    await _dbHelper.insert('transactions', {
      ...transaction.toMap(),
      'space_id': spaceId,
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _dbHelper.delete('transactions', id);
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _dbHelper.update('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getByAccount(String accountId) async {
    final maps = await _dbHelper.queryByField(
        'transactions', 'account_id', accountId);
    return maps.map(TransactionModel.fromMap).toList();
  }
}
