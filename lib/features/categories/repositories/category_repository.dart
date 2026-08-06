import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/features/categories/models/category_model.dart';
import 'package:agent_money/features/spaces/repositories/space_repository.dart';

class CategoryRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<CategoryModel>> getAll(String spaceId) async {
    final rows = await _db.queryAll(
      'categories',
      whereClause: 'space_id = ?',
      whereArgs: [spaceId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<List<CategoryModel>> getForType(String spaceId, String type) async {
    final db = await _db.database;
    final rows = await db.query(
      'categories',
      where: 'space_id = ? AND transaction_type = ?',
      whereArgs: [spaceId, type],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<void> insert(CategoryModel cat) async {
    await _db.insert('categories', cat.toMap());
  }

  Future<void> update(CategoryModel cat) async {
    await _db.update('categories', cat.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('categories', id);
  }

  /// Seed default categories for a space if none exist yet.
  Future<void> seedDefaults(String spaceId) async {
    final existing = await getAll(spaceId);
    if (existing.isNotEmpty) return;
    for (final cat in CategoryModel.defaults) {
      final seeded = CategoryModel(
        id: '${cat.id}_$spaceId',
        name: cat.name,
        emoji: cat.emoji,
        colorValue: cat.colorValue,
        transactionType: cat.transactionType,
        isCustom: false,
        sortOrder: cat.sortOrder,
        spaceId: spaceId,
      );
      await insert(seeded);
    }
  }
}

class CategoryListNotifier extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final CategoryRepository _repo = CategoryRepository();
  final String _spaceId;

  CategoryListNotifier(this._spaceId) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    await _repo.seedDefaults(_spaceId);
    await refresh();
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repo.getAll(_spaceId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<CategoryModel>> getForType(String type) async {
    return _repo.getForType(_spaceId, type);
  }

  Future<void> add(CategoryModel cat) async {
    await _repo.insert(cat);
    await refresh();
  }

  Future<void> updateCategory(CategoryModel cat) async {
    await _repo.update(cat);
    await refresh();
  }

  Future<void> updateBudget(String catId, double amount) async {
    final current = state.valueOrNull ?? [];
    final cat = current.where((c) => c.id == catId).firstOrNull;
    if (cat == null) return;
    await _repo.update(cat.copyWith(budgetAmount: amount));
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await refresh();
  }
}

final categoryListProvider =
    StateNotifierProvider<CategoryListNotifier, AsyncValue<List<CategoryModel>>>(
  (ref) {
    final spaceId = ref.watch(activeSpaceIdProvider);
    return CategoryListNotifier(spaceId);
  },
);
