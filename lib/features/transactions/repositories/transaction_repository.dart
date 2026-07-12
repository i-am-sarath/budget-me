import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';

final transactionRepositoryProvider =
    Provider((ref) => TransactionRepository());

final transactionListProvider = StateNotifierProvider<TransactionNotifier,
    AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionNotifier(
    ref.read(transactionRepositoryProvider),
    ref,
  );
});

class TransactionNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionRepository _repository;
  final Ref _ref;

  TransactionNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final transactions = await _repository.getTransactions();
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

      await _repository.addTransaction(tx);

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

  Future<List<TransactionModel>> getTransactions() async {
    final maps = await _dbHelper.queryAll('transactions');
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _dbHelper.insert('transactions', transaction.toMap());
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

  Future<List<TransactionModel>> getByTrip(String tripId) async {
    final maps = await _dbHelper.queryByField(
        'transactions', 'trip_id', tripId);
    return maps.map(TransactionModel.fromMap).toList();
  }
}
