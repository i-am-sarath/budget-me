class CategoryModel {
  final String id;
  final String name;
  final String emoji;
  final String type; // matches TransactionType.name
  final int sortOrder;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    required this.sortOrder,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'type': type,
        'sort_order': sortOrder,
        'is_default': isDefault ? 1 : 0,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        type: m['type'] as String,
        sortOrder: m['sort_order'] as int? ?? 0,
        isDefault: (m['is_default'] as int? ?? 0) == 1,
      );

  CategoryModel copyWith({String? name, String? emoji}) => CategoryModel(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        type: type,
        sortOrder: sortOrder,
        isDefault: isDefault,
      );
}
