import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_budget_model.dart';
import '../repositories/category_budget_repository.dart';

final categoryBudgetProvider = StateNotifierProvider.family<
    CategoryBudgetNotifier,
    AsyncValue<List<CategoryBudgetModel>>,
    String>(
  (ref, monthId) =>
      CategoryBudgetNotifier(CategoryBudgetRepository(), monthId),
);

class CategoryBudgetNotifier
    extends StateNotifier<AsyncValue<List<CategoryBudgetModel>>> {
  final CategoryBudgetRepository _repo;
  final String _monthId;
  static const _uuid = Uuid();

  CategoryBudgetNotifier(this._repo, this._monthId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = AsyncValue.data(await _repo.getForMonth(_monthId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  CategoryBudgetModel? budgetFor(String categoryName) =>
      state.valueOrNull?.where((b) => b.categoryName == categoryName).firstOrNull;

  Future<void> setBudget(String categoryName, double limit) async {
    final existing = await _repo.get(categoryName, _monthId);
    await _repo.upsert(existing != null
        ? existing.copyWith(limitAmount: limit)
        : CategoryBudgetModel(
            id: _uuid.v4(),
            categoryName: categoryName,
            monthId: _monthId,
            limitAmount: limit,
          ));
    await _load();
  }

  Future<void> removeBudget(String id) async {
    await _repo.delete(id);
    await _load();
  }
}
