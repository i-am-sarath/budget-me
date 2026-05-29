import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CategoryModel {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final double budgetAmount;  // monthly budget (0 = no budget set)
  final String transactionType;  // 'expense', 'income', 'investment', etc.
  final bool isCustom;
  final int sortOrder;
  final String spaceId;
  final DateTime createdAt;

  CategoryModel({
    String? id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    this.budgetAmount = 0,
    this.transactionType = 'expense',
    this.isCustom = false,
    this.sortOrder = 0,
    this.spaceId = 'personal',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
  bool get hasBudget => budgetAmount > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color_value': colorValue,
        'budget_amount': budgetAmount,
        'transaction_type': transactionType,
        'is_custom': isCustom ? 1 : 0,
        'sort_order': sortOrder,
        'space_id': spaceId,
        'created_at': createdAt.toIso8601String(),
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as String,
        name: map['name'] as String,
        emoji: map['emoji'] as String? ?? '⚙️',
        colorValue: map['color_value'] as int,
        budgetAmount: (map['budget_amount'] as num?)?.toDouble() ?? 0,
        transactionType: map['transaction_type'] as String? ?? 'expense',
        isCustom: (map['is_custom'] as int? ?? 0) == 1,
        sortOrder: map['sort_order'] as int? ?? 0,
        spaceId: map['space_id'] as String? ?? 'personal',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  CategoryModel copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    double? budgetAmount,
    bool? isCustom,
    int? sortOrder,
  }) =>
      CategoryModel(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        colorValue: colorValue ?? this.colorValue,
        budgetAmount: budgetAmount ?? this.budgetAmount,
        transactionType: transactionType,
        isCustom: isCustom ?? this.isCustom,
        sortOrder: sortOrder ?? this.sortOrder,
        spaceId: spaceId,
        createdAt: createdAt,
      );

  // Pre-defined expense categories (seeded into DB on first run)
  static List<CategoryModel> get defaults => [
        CategoryModel(id: 'cat_food',     name: 'Food & Dining',   emoji: '🍔', colorValue: 0xFFE65100, transactionType: 'expense', sortOrder: 0),
        CategoryModel(id: 'cat_transport',name: 'Transport',        emoji: '🚗', colorValue: 0xFF1565C0, transactionType: 'expense', sortOrder: 1),
        CategoryModel(id: 'cat_shopping', name: 'Shopping',         emoji: '🛍️', colorValue: 0xFF6A1B9A, transactionType: 'expense', sortOrder: 2),
        CategoryModel(id: 'cat_housing',  name: 'Housing',          emoji: '🏠', colorValue: 0xFF004D40, transactionType: 'expense', sortOrder: 3),
        CategoryModel(id: 'cat_health',   name: 'Health',           emoji: '💊', colorValue: 0xFFC62828, transactionType: 'expense', sortOrder: 4),
        CategoryModel(id: 'cat_bills',    name: 'Bills & Utilities', emoji: '📱', colorValue: 0xFF37474F, transactionType: 'expense', sortOrder: 5),
        CategoryModel(id: 'cat_entertain',name: 'Entertainment',    emoji: '🎬', colorValue: 0xFF4527A0, transactionType: 'expense', sortOrder: 6),
        CategoryModel(id: 'cat_education',name: 'Education',        emoji: '📚', colorValue: 0xFF00838F, transactionType: 'expense', sortOrder: 7),
        CategoryModel(id: 'cat_general',  name: 'General',          emoji: '⚙️', colorValue: 0xFF546E7A, transactionType: 'expense', sortOrder: 8),
      ];
}
