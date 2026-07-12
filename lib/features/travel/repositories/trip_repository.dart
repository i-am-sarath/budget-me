import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/features/travel/models/trip_model.dart';

final tripRepositoryProvider = Provider((ref) => TripRepository());

final tripListProvider =
    StateNotifierProvider<TripListNotifier, AsyncValue<List<TripModel>>>((ref) {
  return TripListNotifier(ref.read(tripRepositoryProvider));
});

class TripListNotifier extends StateNotifier<AsyncValue<List<TripModel>>> {
  final TripRepository _repo;

  TripListNotifier(this._repo) : super(const AsyncValue.loading()) {
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

class TripRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<TripModel>> getAll() async {
    final maps = await _db.queryAll('trips', orderBy: 'start_date DESC');
    return maps.map(TripModel.fromMap).toList();
  }

  Future<void> insert(TripModel trip) async {
    await _db.insert('trips', trip.toMap());
  }

  Future<void> update(TripModel trip) async {
    await _db.update('trips', trip.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('trips', id);
  }
}
