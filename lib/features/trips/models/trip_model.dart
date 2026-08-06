import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// A trip / travel budget. Spending is tracked by tagging transactions with
/// this trip's [id] (see `transactions.trip_id`). Stored in the `trips` table.
class TripModel {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final double budget; // 0 = no budget set
  final String currencyCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive; // false once the trip is ended/archived
  final DateTime createdAt;

  TripModel({
    String? id,
    required this.name,
    this.emoji = '✈️',
    int? colorValue,
    this.budget = 0,
    this.currencyCode = 'USD',
    this.startDate,
    this.endDate,
    this.isActive = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        colorValue = (colorValue == null || colorValue == 0)
            ? 0xFF6C52DA
            : colorValue,
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
  bool get hasBudget => budget > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color_value': colorValue,
        'budget': budget,
        'currency_code': currencyCode,
        'start_date': startDate?.toIso8601String() ?? '',
        'end_date': endDate?.toIso8601String() ?? '',
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory TripModel.fromMap(Map<String, dynamic> m) => TripModel(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: (m['emoji'] as String?)?.isNotEmpty == true
            ? m['emoji'] as String
            : '✈️',
        colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF6C52DA,
        budget: (m['budget'] as num?)?.toDouble() ?? 0,
        currencyCode: m['currency_code'] as String? ?? 'USD',
        startDate: (m['start_date'] as String?)?.isNotEmpty == true
            ? DateTime.tryParse(m['start_date'] as String)
            : null,
        endDate: (m['end_date'] as String?)?.isNotEmpty == true
            ? DateTime.tryParse(m['end_date'] as String)
            : null,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  TripModel copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    double? budget,
    String? currencyCode,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) =>
      TripModel(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        colorValue: colorValue ?? this.colorValue,
        budget: budget ?? this.budget,
        currencyCode: currencyCode ?? this.currencyCode,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
