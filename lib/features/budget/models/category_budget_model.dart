class CategoryBudgetModel {
  final String id;
  final String categoryName;
  final String monthId; // "2026-05"
  final double limitAmount;

  const CategoryBudgetModel({
    required this.id,
    required this.categoryName,
    required this.monthId,
    required this.limitAmount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_name': categoryName,
        'month_id': monthId,
        'limit_amount': limitAmount,
      };

  factory CategoryBudgetModel.fromMap(Map<String, dynamic> m) =>
      CategoryBudgetModel(
        id: m['id'] as String,
        categoryName: m['category_name'] as String,
        monthId: m['month_id'] as String,
        limitAmount: (m['limit_amount'] as num).toDouble(),
      );

  CategoryBudgetModel copyWith({double? limitAmount}) => CategoryBudgetModel(
        id: id,
        categoryName: categoryName,
        monthId: monthId,
        limitAmount: limitAmount ?? this.limitAmount,
      );
}
