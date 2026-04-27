import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/features/recurring/models/recurring_model.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

final recurringRepositoryProvider =
    Provider((ref) => RecurringRepository());

final recurringListProvider = StateNotifierProvider<RecurringListNotifier,
    AsyncValue<List<RecurringModel>>>((ref) {
  return RecurringListNotifier(
    ref.read(recurringRepositoryProvider),
    ref,
  );
});

class RecurringListNotifier
    extends StateNotifier<AsyncValue<List<RecurringModel>>> {
  final RecurringRepository _repo;
  final Ref _ref;

  RecurringListNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getAll();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(RecurringModel rule) async {
    await _repo.insert(rule);
    await refresh();
  }

  Future<void> update(RecurringModel rule) async {
    await _repo.update(rule);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await refresh();
  }

  /// Manually trigger a recurring rule: creates a real transaction and advances next run date
  Future<void> runNow(RecurringModel rule) async {
    final transaction = TransactionModel(
      amount: rule.amount,
      type: rule.type,
      category: rule.category,
      note: rule.title,
      accountId: rule.accountId,
      accountName: rule.accountName,
      date: DateTime.now(),
    );
    await _ref
        .read(transactionListProvider.notifier)
        .addTransaction(transaction);

    final advanced = rule.advance();
    await _repo.update(advanced);
    await refresh();
  }

  Future<void> toggleActive(RecurringModel rule) async {
    await _repo.update(rule.copyWith(isActive: !rule.isActive));
    await refresh();
  }
}

class RecurringRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<RecurringModel>> getAll() async {
    final maps = await _db.queryAll('recurring_transactions',
        orderBy: 'next_run_date ASC');
    return maps.map(RecurringModel.fromMap).toList();
  }

  Future<List<RecurringModel>> getPendingToday() async {
    final all = await getAll();
    return all.where((r) => r.isActive && r.isDueToday).toList();
  }

  Future<void> insert(RecurringModel rule) async {
    await _db.insert('recurring_transactions', rule.toMap());
  }

  Future<void> update(RecurringModel rule) async {
    await _db.update('recurring_transactions', rule.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('recurring_transactions', id);
  }
}
