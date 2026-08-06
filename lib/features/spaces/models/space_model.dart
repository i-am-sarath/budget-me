import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class SpaceModel {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final DateTime createdAt;

  SpaceModel({
    String? id,
    required this.name,
    this.emoji = '🏠',
    required this.colorValue,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  static const String personalId = 'personal';

  bool get isPersonal => id == personalId;

  Color get color => Color(colorValue);

  static SpaceModel get defaultPersonal => SpaceModel(
        id: personalId,
        name: 'Personal',
        emoji: '🏠',
        colorValue: const Color(0xFF2D6A2D).value,
        createdAt: DateTime(2024, 1, 1),
      );

  static final List<({String emoji, String label})> presets = const [
    (emoji: '🏠', label: 'Personal'),
    (emoji: '💼', label: 'Business'),
    (emoji: '🎓', label: 'School'),
    (emoji: '🏢', label: 'Office'),
    (emoji: '🏪', label: 'Shop'),
    (emoji: '🌍', label: 'Travel'),
  ];

  static final List<Color> palette = const [
    Color(0xFF2D6A2D),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFFC62828),
    Color(0xFF37474F),
    Color(0xFF4527A0),
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color_value': colorValue,
        'created_at': createdAt.toIso8601String(),
      };

  factory SpaceModel.fromMap(Map<String, dynamic> map) => SpaceModel(
        id: map['id'] as String,
        name: map['name'] as String,
        emoji: (map['emoji'] as String?)?.isNotEmpty == true
            ? map['emoji'] as String
            : '🏠',
        colorValue: map['color_value'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  SpaceModel copyWith({String? name, String? emoji, int? colorValue}) =>
      SpaceModel(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        colorValue: colorValue ?? this.colorValue,
        createdAt: createdAt,
      );
}
