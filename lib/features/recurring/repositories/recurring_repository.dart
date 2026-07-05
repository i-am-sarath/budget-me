import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/database/database_helper.dart';
import 'package:money_pi/features/recurring/models/recurring_model.dart';
import 'package:money_pi/features/transactions/models/transaction_model.dart';
import 'package:money_pi/features/transactions/repositories/transaction_repository.dart';
import 'package:money_pi/features/spaces/repositories/space_repository.dart';

final recurringRepositoryProvider =
    Provider((ref) => RecurringRepository());

final recurringListProvider = StateNotifierProvider<RecurringListNotifier,
    AsyncValue<List<RecurringModel>>>((ref) {
  final spaceId = ref.watch(activeSpaceIdProvider);
  return RecurringListNotifier(
    ref.read(recurringRepositoryProvider),
    ref,
    spaceId,
  );
});

class RecurringListNotifier
    extends StateNotifier<AsyncValue<List<RecurringModel>>> {
  final RecurringRepository _repo;
  final Ref _ref;
  final String _spaceId;

  RecurringListNotifier(this._repo, this._ref, this._spaceId)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getAll(_spaceId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(RecurringModel rule) async {
    await _repo.insert(rule, _spaceId);
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

  Future<List<RecurringModel>> getAll(String spaceId) async {
    final maps = await _db.queryAll(
      'recurring_transactions',
      whereClause: 'space_id = ?',
      whereArgs: [spaceId],
      orderBy: 'next_run_date ASC',
    );
    return maps.map(RecurringModel.fromMap).toList();
  }

  Future<List<RecurringModel>> getPendingToday(String spaceId) async {
    final all = await getAll(spaceId);
    return all.where((r) => r.isActive && r.isDueToday).toList();
  }

  Future<void> insert(RecurringModel rule, String spaceId) async {
    await _db.insert('recurring_transactions',
        {...rule.toMap(), 'space_id': spaceId});
  }

  Future<void> update(RecurringModel rule) async {
    await _db.update('recurring_transactions', rule.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('recurring_transactions', id);
  }
}
