import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:agent_money/core/theme.dart';

/// Account types — designed for a global audience.
/// `mobilePay` replaces the India-specific UPI concept with a
/// generic mobile payment wallet (PayPal, GCash, Pix, etc.).
enum AccountType { bank, cash, loan, creditCard, wallet, mobilePay }

extension AccountTypeX on AccountType {
  String get label {
    switch (this) {
      case AccountType.bank:       return 'Bank Account';
      case AccountType.cash:       return 'Cash';
      case AccountType.loan:       return 'Loan';
      case AccountType.creditCard: return 'Credit Card';
      case AccountType.wallet:     return 'Digital Wallet';
      case AccountType.mobilePay:  return 'Mobile Pay';
    }
  }

  /// Short hint shown below the type in the Add Account sheet.
  String get hint {
    switch (this) {
      case AccountType.bank:       return 'Checking, savings, etc.';
      case AccountType.cash:       return 'Physical cash on hand';
      case AccountType.loan:       return 'Personal / car / home loan';
      case AccountType.creditCard: return 'Credit card balance owed';
      case AccountType.wallet:     return 'PayPal, Apple Pay, etc.';
      case AccountType.mobilePay:  return 'GCash, Pix, M-Pesa, etc.';
    }
  }

  IconData get icon {
    switch (this) {
      case AccountType.bank:       return Icons.account_balance_rounded;
      case AccountType.cash:       return Icons.payments_rounded;
      case AccountType.loan:       return Icons.handshake_rounded;
      case AccountType.creditCard: return Icons.credit_card_rounded;
      case AccountType.wallet:     return Icons.account_balance_wallet_rounded;
      case AccountType.mobilePay:  return Icons.phone_android_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AccountType.bank:       return AppColors.primary;
      case AccountType.cash:       return AppColors.income;
      case AccountType.loan:       return AppColors.expense;
      case AccountType.creditCard: return AppColors.borrow;
      case AccountType.wallet:     return AppColors.secondary;
      case AccountType.mobilePay:  return AppColors.lend;
    }
  }

  static AccountType fromString(String s) {
    // Legacy mapping: 'upi' → mobilePay
    if (s == 'upi') return AccountType.mobilePay;
    return AccountType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => AccountType.bank,
    );
  }
}

class AccountModel {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final int colorValue;
  final int iconCode;
  final String bankName;
  final String accountNumber; // last 4 digits only
  final String currencyCode;
  final DateTime createdAt;

  AccountModel({
    String? id,
    required this.name,
    required this.type,
    required this.balance,
    int? colorValue,
    int? iconCode,
    this.bankName = '',
    this.accountNumber = '',
    this.currencyCode = 'USD', // neutral global default
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        colorValue = colorValue ?? type.color.value,
        iconCode = iconCode ?? type.icon.codePoint,
        createdAt = createdAt ?? DateTime.now();

  Color get displayColor => Color(colorValue);
  IconData get displayIcon => AccountType.values
      .firstWhere(
        (type) => type.icon.codePoint == iconCode,
        orElse: () => AccountType.bank,
      )
      .icon;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'balance': balance,
        'color_value': colorValue,
        'icon_code': iconCode,
        'bank_name': bankName,
        'account_number': accountNumber,
        'currency_code': currencyCode,
        'created_at': createdAt.toIso8601String(),
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'] as String,
        name: map['name'] as String,
        type: AccountTypeX.fromString(map['type'] as String),
        balance: (map['balance'] as num).toDouble(),
        colorValue: map['color_value'] as int? ?? 0,
        iconCode: map['icon_code'] as int? ??
            Icons.account_balance_rounded.codePoint,
        bankName: map['bank_name'] as String? ?? '',
        accountNumber: map['account_number'] as String? ?? '',
        currencyCode: map['currency_code'] as String? ?? 'USD',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  AccountModel copyWith({
    double? balance,
    String? name,
    AccountType? type,
    String? bankName,
    String? accountNumber,
  }) =>
      AccountModel(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        colorValue: (type ?? this.type).color.value,
        iconCode: (type ?? this.type).icon.codePoint,
        bankName: bankName ?? this.bankName,
        accountNumber: accountNumber ?? this.accountNumber,
        currencyCode: currencyCode,
        createdAt: createdAt,
      );
}
