import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/features/subscriptions/models/subscription_model.dart';
import 'package:agent_money/features/spaces/repositories/space_repository.dart';

final subscriptionRepositoryProvider =
    Provider((ref) => SubscriptionRepository());

final subscriptionListProvider = StateNotifierProvider<
    SubscriptionListNotifier,
    AsyncValue<List<SubscriptionModel>>>((ref) {
  final spaceId = ref.watch(activeSpaceIdProvider);
  return SubscriptionListNotifier(
      ref.read(subscriptionRepositoryProvider), spaceId);
});

class SubscriptionListNotifier
    extends StateNotifier<AsyncValue<List<SubscriptionModel>>> {
  final SubscriptionRepository _repo;
  final String _spaceId;

  SubscriptionListNotifier(this._repo, this._spaceId)
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

  Future<void> add(SubscriptionModel sub) async {
    await _repo.insert(sub, _spaceId);
    await refresh();
  }

  Future<void> update(SubscriptionModel sub) async {
    await _repo.update(sub);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await refresh();
  }

  /// Mark as paid: advance the next due date
  Future<void> markPaid(SubscriptionModel sub) async {
    final advanced = sub.advanceDueDate();
    await _repo.update(advanced);
    await refresh();
  }
}

class SubscriptionRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<SubscriptionModel>> getAll(String spaceId) async {
    final maps = await _db.queryAll(
      'subscriptions',
      whereClause: 'space_id = ?',
      whereArgs: [spaceId],
      orderBy: 'next_due_date ASC',
    );
    return maps.map(SubscriptionModel.fromMap).toList();
  }

  Future<List<SubscriptionModel>> getDueSoon(String spaceId) async {
    final all = await getAll(spaceId);
    return all.where((s) => s.isActive && s.daysUntilDue <= 7).toList();
  }

  Future<void> insert(SubscriptionModel sub, String spaceId) async {
    await _db.insert('subscriptions', {...sub.toMap(), 'space_id': spaceId});
  }

  Future<void> update(SubscriptionModel sub) async {
    await _db.update('subscriptions', sub.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('subscriptions', id);
  }
}
