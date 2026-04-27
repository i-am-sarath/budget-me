import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum BillingCycle {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly;

  String get label {
    switch (this) {
      case BillingCycle.daily:     return 'Daily';
      case BillingCycle.weekly:    return 'Weekly';
      case BillingCycle.monthly:   return 'Monthly';
      case BillingCycle.quarterly: return 'Quarterly';
      case BillingCycle.yearly:    return 'Yearly';
    }
  }

  static BillingCycle fromString(String v) => BillingCycle.values.firstWhere(
        (e) => e.name == v.toLowerCase(),
        orElse: () => BillingCycle.monthly,
      );
}

enum SubscriptionCategory {
  ott,
  music,
  utility,
  insurance,
  rent,
  gym,
  software,
  education,
  other;

  String get label {
    switch (this) {
      case SubscriptionCategory.ott:       return 'OTT / Video';
      case SubscriptionCategory.music:     return 'Music';
      case SubscriptionCategory.utility:   return 'Utility / Bill';
      case SubscriptionCategory.insurance: return 'Insurance';
      case SubscriptionCategory.rent:      return 'Rent';
      case SubscriptionCategory.gym:       return 'Gym / Fitness';
      case SubscriptionCategory.software:  return 'Software';
      case SubscriptionCategory.education: return 'Education';
      case SubscriptionCategory.other:     return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case SubscriptionCategory.ott:       return Icons.play_circle_outline_rounded;
      case SubscriptionCategory.music:     return Icons.music_note_rounded;
      case SubscriptionCategory.utility:   return Icons.bolt_rounded;
      case SubscriptionCategory.insurance: return Icons.shield_outlined;
      case SubscriptionCategory.rent:      return Icons.home_outlined;
      case SubscriptionCategory.gym:       return Icons.fitness_center_rounded;
      case SubscriptionCategory.software:  return Icons.code_rounded;
      case SubscriptionCategory.education: return Icons.school_outlined;
      case SubscriptionCategory.other:     return Icons.subscriptions_outlined;
    }
  }

  static SubscriptionCategory fromString(String v) =>
      SubscriptionCategory.values.firstWhere(
        (e) => e.name == v.toLowerCase(),
        orElse: () => SubscriptionCategory.other,
      );
}

class SubscriptionModel {
  final String id;
  final String name;
  final SubscriptionCategory category;
  final double amount;
  final BillingCycle billingCycle;
  final DateTime nextDueDate;
  final int colorValue;
  final bool isActive;
  final String notes;
  final DateTime createdAt;

  SubscriptionModel({
    String? id,
    required this.name,
    required this.category,
    required this.amount,
    required this.billingCycle,
    required this.nextDueDate,
    int? colorValue,
    this.isActive = true,
    this.notes = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        colorValue = colorValue ?? Colors.grey.value,
        createdAt = createdAt ?? DateTime.now();

  /// Days until next payment
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.difference(today).inDays;
  }

  bool get isDueToday => daysUntilDue == 0;
  bool get isDueSoon => daysUntilDue <= 3 && daysUntilDue >= 0;
  bool get isOverdue => daysUntilDue < 0;

  /// Advance due date by one billing cycle
  SubscriptionModel advanceDueDate() {
    DateTime next;
    switch (billingCycle) {
      case BillingCycle.daily:
        next = nextDueDate.add(const Duration(days: 1));
      case BillingCycle.weekly:
        next = nextDueDate.add(const Duration(days: 7));
      case BillingCycle.monthly:
        next = DateTime(nextDueDate.year, nextDueDate.month + 1, nextDueDate.day);
      case BillingCycle.quarterly:
        next = DateTime(nextDueDate.year, nextDueDate.month + 3, nextDueDate.day);
      case BillingCycle.yearly:
        next = DateTime(nextDueDate.year + 1, nextDueDate.month, nextDueDate.day);
    }
    return copyWith(nextDueDate: next);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category.name,
        'amount': amount,
        'billing_cycle': billingCycle.name,
        'next_due_date': nextDueDate.toIso8601String(),
        'color_value': colorValue,
        'icon_code': category.icon.codePoint,
        'is_active': isActive ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) =>
      SubscriptionModel(
        id: map['id'] as String,
        name: map['name'] as String,
        category: SubscriptionCategory.fromString(map['category'] as String? ?? 'other'),
        amount: (map['amount'] as num).toDouble(),
        billingCycle: BillingCycle.fromString(map['billing_cycle'] as String? ?? 'monthly'),
        nextDueDate: DateTime.parse(map['next_due_date'] as String),
        colorValue: map['color_value'] as int? ?? Colors.grey.value,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        notes: map['notes'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  SubscriptionModel copyWith({
    String? name,
    SubscriptionCategory? category,
    double? amount,
    BillingCycle? billingCycle,
    DateTime? nextDueDate,
    int? colorValue,
    bool? isActive,
    String? notes,
  }) =>
      SubscriptionModel(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        billingCycle: billingCycle ?? this.billingCycle,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        colorValue: colorValue ?? this.colorValue,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
