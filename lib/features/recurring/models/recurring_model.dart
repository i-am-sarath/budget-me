import 'package:uuid/uuid.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';

enum RecurringFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case RecurringFrequency.daily:     return 'Daily';
      case RecurringFrequency.weekly:    return 'Weekly';
      case RecurringFrequency.biweekly:  return 'Bi-weekly';
      case RecurringFrequency.monthly:   return 'Monthly';
      case RecurringFrequency.yearly:    return 'Yearly';
    }
  }

  static RecurringFrequency fromString(String v) =>
      RecurringFrequency.values.firstWhere(
        (e) => e.name == v.toLowerCase(),
        orElse: () => RecurringFrequency.monthly,
      );
}

class RecurringModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String? accountId;
  final String? accountName;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextRunDate;
  final DateTime? lastRunDate;
  final bool isActive;
  final String note;
  final DateTime createdAt;

  RecurringModel({
    String? id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.accountId,
    this.accountName,
    required this.frequency,
    required this.startDate,
    required this.nextRunDate,
    this.lastRunDate,
    this.isActive = true,
    this.note = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextRunDate.year, nextRunDate.month, nextRunDate.day);
    return due.compareTo(today) <= 0;
  }

  /// Advance nextRunDate by one frequency period
  RecurringModel advance() {
    DateTime next;
    switch (frequency) {
      case RecurringFrequency.daily:
        next = nextRunDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        next = nextRunDate.add(const Duration(days: 7));
      case RecurringFrequency.biweekly:
        next = nextRunDate.add(const Duration(days: 14));
      case RecurringFrequency.monthly:
        next = DateTime(nextRunDate.year, nextRunDate.month + 1, nextRunDate.day);
      case RecurringFrequency.yearly:
        next = DateTime(nextRunDate.year + 1, nextRunDate.month, nextRunDate.day);
    }
    return copyWith(nextRunDate: next, lastRunDate: DateTime.now());
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'category': category,
        'account_id': accountId ?? '',
        'account_name': accountName ?? '',
        'frequency': frequency.name,
        'start_date': startDate.toIso8601String(),
        'next_run_date': nextRunDate.toIso8601String(),
        'last_run_date': lastRunDate?.toIso8601String() ?? '',
        'is_active': isActive ? 1 : 0,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory RecurringModel.fromMap(Map<String, dynamic> map) => RecurringModel(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: TransactionType.fromString(map['type'] as String? ?? 'expense'),
        category: map['category'] as String? ?? 'General',
        accountId: (map['account_id'] as String?)?.isNotEmpty == true
            ? map['account_id'] as String
            : null,
        accountName: (map['account_name'] as String?)?.isNotEmpty == true
            ? map['account_name'] as String
            : null,
        frequency: RecurringFrequency.fromString(map['frequency'] as String? ?? 'monthly'),
        startDate: DateTime.parse(map['start_date'] as String),
        nextRunDate: DateTime.parse(map['next_run_date'] as String),
        lastRunDate: (map['last_run_date'] as String?)?.isNotEmpty == true
            ? DateTime.parse(map['last_run_date'] as String)
            : null,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        note: map['note'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  RecurringModel copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    String? accountId,
    String? accountName,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? nextRunDate,
    DateTime? lastRunDate,
    bool? isActive,
    String? note,
  }) =>
      RecurringModel(
        id: id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        accountId: accountId ?? this.accountId,
        accountName: accountName ?? this.accountName,
        frequency: frequency ?? this.frequency,
        startDate: startDate ?? this.startDate,
        nextRunDate: nextRunDate ?? this.nextRunDate,
        lastRunDate: lastRunDate ?? this.lastRunDate,
        isActive: isActive ?? this.isActive,
        note: note ?? this.note,
        createdAt: createdAt,
      );
}
