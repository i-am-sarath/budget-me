import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';

final categoryRepositoryProvider = Provider((_) => CategoryRepository());

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<List<CategoryModel>>>(
  (ref) => CategoryNotifier(ref.read(categoryRepositoryProvider)),
);

class CategoryNotifier
    extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final CategoryRepository _repo;
  static const _uuid = Uuid();

  CategoryNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = AsyncValue.data(await _repo.getAll());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  List<CategoryModel> forType(TransactionType type) {
    final all = state.valueOrNull ?? [];
    return all.where((c) => c.type == type.name).toList();
  }

  Future<void> add(String name, String emoji, TransactionType type) async {
    final existing = forType(type);
    await _repo.insert(CategoryModel(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      type: type.name,
      sortOrder: existing.length,
    ));
    await _load();
  }

  Future<void> edit(CategoryModel c, String name, String emoji) async {
    await _repo.update(c.copyWith(name: name, emoji: emoji));
    await _load();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    await _load();
  }
}
