import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_pi/core/database/database_helper.dart';
import 'package:money_pi/features/trips/models/trip_model.dart';
import 'package:money_pi/features/transactions/models/transaction_model.dart';
import 'package:money_pi/features/transactions/repositories/transaction_repository.dart';

class TripRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<TripModel>> getAll() async {
    final rows = await _db.queryAll(
      'trips',
      orderBy: 'is_active DESC, created_at DESC',
    );
    return rows.map(TripModel.fromMap).toList();
  }

  Future<void> insert(TripModel trip) async =>
      _db.insert('trips', trip.toMap());

  Future<void> update(TripModel trip) async =>
      _db.update('trips', trip.toMap());

  Future<void> delete(String id) async => _db.delete('trips', id);

  /// All transactions tagged to [tripId], newest first (across every space —
  /// a trip's spending is the same money regardless of which space you logged
  /// it in).
  Future<List<TransactionModel>> transactionsForTrip(String tripId) async {
    final db = await _db.database;
    final rows = await db.query(
      'transactions',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'date DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }
}

// ─────────────────────────────────────────────
// Trip list
// ─────────────────────────────────────────────

class TripListNotifier extends StateNotifier<AsyncValue<List<TripModel>>> {
  final TripRepository _repo = TripRepository();

  TripListNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      state = AsyncValue.data(await _repo.getAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(TripModel trip) async {
    await _repo.insert(trip);
    await refresh();
  }

  Future<void> update(TripModel trip) async {
    await _repo.update(trip);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await refresh();
  }
}

final tripRepositoryProvider = Provider((ref) => TripRepository());

final tripListProvider =
    StateNotifierProvider<TripListNotifier, AsyncValue<List<TripModel>>>(
  (ref) => TripListNotifier(),
);

// ─────────────────────────────────────────────
// Active trip — new expenses are auto-tagged to it
// ─────────────────────────────────────────────

class ActiveTripNotifier extends StateNotifier<String?> {
  ActiveTripNotifier() : super(null) {
    _load();
  }

  static const _key = 'active_trip_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (mounted) state = (id != null && id.isNotEmpty) ? id : null;
  }

  Future<void> setActive(String? tripId) async {
    final prefs = await SharedPreferences.getInstance();
    if (tripId == null || tripId.isEmpty) {
      await prefs.remove(_key);
      state = null;
    } else {
      await prefs.setString(_key, tripId);
      state = tripId;
    }
  }
}

final activeTripIdProvider =
    StateNotifierProvider<ActiveTripNotifier, String?>(
  (ref) => ActiveTripNotifier(),
);

/// All transactions tagged to [tripId], live with the transaction list.
final tripTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, tripId) async {
  ref.watch(transactionListProvider);
  return ref.read(tripRepositoryProvider).transactionsForTrip(tripId);
});

/// Total amount spent (expenses) tagged to [tripId]. Refetched whenever the
/// transaction list changes so trip totals stay live.
final tripSpentProvider =
    FutureProvider.family<double, String>((ref, tripId) async {
  final txs = await ref.watch(tripTransactionsProvider(tripId).future);
  return txs
      .where((t) => t.type == TransactionType.expense)
      .fold<double>(0, (sum, t) => sum + t.amount);
});
