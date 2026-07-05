import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_pi/core/database/database_helper.dart';
import 'package:money_pi/features/spaces/models/space_model.dart';

// ─────────────────────────────────────────────
// Active Space — persisted in SharedPreferences
// ─────────────────────────────────────────────

class ActiveSpaceNotifier extends StateNotifier<String> {
  ActiveSpaceNotifier() : super(SpaceModel.personalId) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('active_space_id') ?? SpaceModel.personalId;
    if (mounted) state = id;
  }

  Future<void> switchTo(String spaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_space_id', spaceId);
    state = spaceId;
  }
}

final activeSpaceIdProvider =
    StateNotifierProvider<ActiveSpaceNotifier, String>(
  (ref) => ActiveSpaceNotifier(),
);

// ─────────────────────────────────────────────
// Space List
// ─────────────────────────────────────────────

class SpaceRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<SpaceModel>> getAll() async {
    final rows = await _db.queryAll('spaces', orderBy: 'created_at ASC');
    return rows.map(SpaceModel.fromMap).toList();
  }

  Future<void> insert(SpaceModel space) async {
    await _db.insert('spaces', space.toMap());
  }

  Future<void> update(SpaceModel space) async {
    await _db.update('spaces', space.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('spaces', id);
  }
}

class SpaceListNotifier extends StateNotifier<AsyncValue<List<SpaceModel>>> {
  final SpaceRepository _repo = SpaceRepository();

  SpaceListNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getAll();
      // Always ensure the personal space is present
      if (!list.any((s) => s.id == SpaceModel.personalId)) {
        await _repo.insert(SpaceModel.defaultPersonal);
        final updated = await _repo.getAll();
        state = AsyncValue.data(updated);
      } else {
        state = AsyncValue.data(list);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(SpaceModel space) async {
    await _repo.insert(space);
    await refresh();
  }

  Future<void> update(SpaceModel space) async {
    await _repo.update(space);
    await refresh();
  }

  Future<void> delete(String id) async {
    if (id == SpaceModel.personalId) return;
    await _repo.delete(id);
    await refresh();
  }
}

final spaceListProvider =
    StateNotifierProvider<SpaceListNotifier, AsyncValue<List<SpaceModel>>>(
  (ref) => SpaceListNotifier(),
);
