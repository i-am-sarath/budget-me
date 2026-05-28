import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:agent_money/core/database/database_helper.dart';
import '../models/category_budget_model.dart';

class CategoryBudgetRepository {
  final _db = DatabaseHelper();

  Future<List<CategoryBudgetModel>> getForMonth(String monthId) async {
    final db = await _db.database;
    final rows = await db.query(
      'category_budgets',
      where: 'month_id = ?',
      whereArgs: [monthId],
    );
    return rows.map(CategoryBudgetModel.fromMap).toList();
  }

  Future<CategoryBudgetModel?> get(String categoryName, String monthId) async {
    final db = await _db.database;
    final rows = await db.query(
      'category_budgets',
      where: 'category_name = ? AND month_id = ?',
      whereArgs: [categoryName, monthId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CategoryBudgetModel.fromMap(rows.first);
  }

  Future<void> upsert(CategoryBudgetModel b) async {
    final db = await _db.database;
    await db.insert(
      'category_budgets',
      b.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('category_budgets', id);
  }
}
