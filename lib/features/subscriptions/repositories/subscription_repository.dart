import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/features/subscriptions/models/subscription_model.dart';

final subscriptionRepositoryProvider = Provider(
  (ref) => SubscriptionRepository(),
);

final subscriptionListProvider =
    StateNotifierProvider<
      SubscriptionListNotifier,
      AsyncValue<List<SubscriptionModel>>
    >((ref) {
      return SubscriptionListNotifier(ref.read(subscriptionRepositoryProvider));
    });

class SubscriptionListNotifier
    extends StateNotifier<AsyncValue<List<SubscriptionModel>>> {
  final SubscriptionRepository _repo;

  SubscriptionListNotifier(this._repo) : super(const AsyncValue.loading()) {
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

  Future<void> add(SubscriptionModel sub) async {
    await _repo.insert(sub);
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

  Future<List<SubscriptionModel>> getAll() async {
    final maps = await _db.queryAll(
      'subscriptions',
      orderBy: 'next_due_date ASC',
    );
    return maps.map(SubscriptionModel.fromMap).toList();
  }

  Future<List<SubscriptionModel>> getDueSoon() async {
    final all = await getAll();
    return all.where((s) => s.isActive && s.daysUntilDue <= 7).toList();
  }

  Future<void> insert(SubscriptionModel sub) async {
    await _db.insert('subscriptions', sub.toMap());
  }

  Future<void> update(SubscriptionModel sub) async {
    await _db.update('subscriptions', sub.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('subscriptions', id);
  }
}
