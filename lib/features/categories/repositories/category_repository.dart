import 'package:agent_money/core/database/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final _db = DatabaseHelper();

  Future<List<CategoryModel>> getAll() async {
    final rows = await _db.queryAll(
      'categories',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<List<CategoryModel>> getByType(String type) async {
    final rows = await _db.queryAll(
      'categories',
      whereClause: 'type = ?',
      whereArgs: [type],
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<void> insert(CategoryModel c) async {
    await _db.insert('categories', c.toMap());
  }

  Future<void> update(CategoryModel c) async {
    await _db.update('categories', c.toMap());
  }

  Future<void> delete(String id) async {
    await _db.delete('categories', id);
  }
}
