import 'package:uuid/uuid.dart';

enum TransactionType {
  expense,
  income,
  investment,
  lend,
  borrow,
  lendReturn,    // someone returned money they owed → user receives money back
  borrowReturn,  // user returns money they borrowed → user pays out
  transferOut,   // money leaving an account via transfer (not a budget expense)
  transferIn;    // money arriving in an account via transfer (not real income)

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
      case TransactionType.transferOut:  return 'Transfer Out';
      case TransactionType.transferIn:   return 'Transfer In';
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
  final String? tripId; // optional: tags this spend to a Trip (travel tracking)
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
    required this.date,
    DateTime? createdAt,
    this.isSynced = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // ── Balance effect ──────────────────────────────────────
  //
  // Debt/receivable tracking accounts hold an *outstanding* balance:
  //   • borrow      → increases what you owe on a loan account
  //   • borrowReturn→ decreases it (repayment)
  //   • lend        → increases what's owed to you on a receivable account
  //   • lendReturn  → decreases it (you got the money back)
  // The matching effect on your own cash/bank account is recorded as a
  // separate transferIn/transferOut transaction by the debt flow.
  double get balanceDelta {
    switch (type) {
      case TransactionType.income:
      case TransactionType.borrow:
      case TransactionType.lend:
      case TransactionType.transferIn:   // funds arrive → positive
        return amount;
      case TransactionType.expense:
      case TransactionType.lendReturn:
      case TransactionType.investment:
      case TransactionType.borrowReturn:
      case TransactionType.transferOut:  // funds leave → negative
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
        date: date ?? this.date,
        createdAt: createdAt,
        isSynced: isSynced ?? this.isSynced,
      );
}
