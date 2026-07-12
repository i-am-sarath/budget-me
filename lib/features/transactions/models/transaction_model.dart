import 'package:uuid/uuid.dart';

enum TransactionType {
  expense,
  income,
  investment,
  lend,
  borrow,
  lendReturn,   // someone returned money they owed → user receives money back
  borrowReturn; // user returns money they borrowed → user pays out

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('_', ''),
      orElse: () => TransactionType.expense,
    );
  }

  String get label {
    switch (this) {
      case TransactionType.expense:      return 'Expense';
      case TransactionType.income:       return 'Income';
      case TransactionType.investment:   return 'Investment';
      case TransactionType.lend:         return 'Lent';
      case TransactionType.borrow:       return 'Borrowed';
      case TransactionType.lendReturn:   return 'Lent - Returned';
      case TransactionType.borrowReturn: return 'Borrow - Repaid';
    }
  }
}

class TransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final String note;
  final String? payee;
  final String? accountId;
  final String? accountName;
  final String? tripId;
  final String? tripName;
  final DateTime date;
  final DateTime createdAt;
  final bool isSynced;

  TransactionModel({
    String? id,
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
    this.payee,
    this.accountId,
    this.accountName,
    this.tripId,
    this.tripName,
    required this.date,
    DateTime? createdAt,
    this.isSynced = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // ── Balance effect ──────────────────────────────────────
  double get balanceDelta {
    switch (type) {
      case TransactionType.income:
      case TransactionType.borrow:
      case TransactionType.lendReturn:   // money returned TO user → positive
        return amount;
      case TransactionType.expense:
      case TransactionType.lend:
      case TransactionType.investment:
      case TransactionType.borrowReturn: // user repays → negative
        return -amount;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'type': type.name,
        'category': category,
        'note': note,
        'payee': payee ?? '',
        'account_id': accountId ?? '',
        'account_name': accountName ?? '',
        'trip_id': tripId ?? '',
        'trip_name': tripName ?? '',
        'date': date.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: TransactionType.fromString(map['type'] as String),
        category: map['category'] as String,
        note: map['note'] as String? ?? '',
        payee: (map['payee'] as String?)?.isNotEmpty == true
            ? map['payee'] as String
            : null,
        accountId: (map['account_id'] as String?)?.isNotEmpty == true
            ? map['account_id'] as String
            : null,
        accountName: (map['account_name'] as String?)?.isNotEmpty == true
            ? map['account_name'] as String
            : null,
        tripId: (map['trip_id'] as String?)?.isNotEmpty == true
            ? map['trip_id'] as String
            : null,
        tripName: (map['trip_name'] as String?)?.isNotEmpty == true
            ? map['trip_name'] as String
            : null,
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        isSynced: (map['is_synced'] as int? ?? 0) == 1,
      );

  TransactionModel copyWith({
    double? amount,
    TransactionType? type,
    String? category,
    String? note,
    String? payee,
    String? accountId,
    String? accountName,
    String? tripId,
    String? tripName,
    DateTime? date,
    bool? isSynced,
  }) =>
      TransactionModel(
        id: id,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        note: note ?? this.note,
        payee: payee ?? this.payee,
        accountId: accountId ?? this.accountId,
        accountName: accountName ?? this.accountName,
        tripId: tripId ?? this.tripId,
        tripName: tripName ?? this.tripName,
        date: date ?? this.date,
        createdAt: createdAt,
        isSynced: isSynced ?? this.isSynced,
      );
}
