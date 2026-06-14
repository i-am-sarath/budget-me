import 'package:flutter/material.dart';

/// A shared spending group (e.g. "Flat 2B"). Mirrors the `groups` table.
class GroupModel {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final String currencyCode;
  final bool settleUp;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.currencyCode,
    required this.settleUp,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  factory GroupModel.fromMap(Map<String, dynamic> m) => GroupModel(
        id: m['id'] as String,
        name: m['name'] as String? ?? 'Group',
        emoji: (m['emoji'] as String?)?.isNotEmpty == true
            ? m['emoji'] as String
            : '👥',
        colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF6C52DA,
        currencyCode: m['currency_code'] as String? ?? 'USD',
        settleUp: (m['settle_up'] as bool?) ?? true,
        inviteCode: m['invite_code'] as String? ?? '',
        createdBy: m['created_by'] as String? ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// A member of a group. Mirrors the `group_members` table.
class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final String displayName;
  final String role; // 'owner' | 'member'
  final DateTime joinedAt;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  factory GroupMemberModel.fromMap(Map<String, dynamic> m) => GroupMemberModel(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        userId: m['user_id'] as String,
        displayName: m['display_name'] as String? ?? 'Member',
        role: m['role'] as String? ?? 'member',
        joinedAt: DateTime.tryParse(m['joined_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// A shared expense. Mirrors the `group_expenses` table.
class GroupExpenseModel {
  final String id;
  final String groupId;
  final String payerId;
  final double amount;
  final String category;
  final String note;
  final DateTime spentAt;
  final String createdBy;
  final DateTime createdAt;

  GroupExpenseModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.amount,
    required this.category,
    required this.note,
    required this.spentAt,
    required this.createdBy,
    required this.createdAt,
  });

  factory GroupExpenseModel.fromMap(Map<String, dynamic> m) =>
      GroupExpenseModel(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        payerId: m['payer_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String? ?? 'General',
        note: m['note'] as String? ?? '',
        spentAt: DateTime.tryParse(m['spent_at'] as String? ?? '') ??
            DateTime.now(),
        createdBy: m['created_by'] as String? ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Computed per-member settle-up position for a group.
class MemberBalance {
  final String userId;
  final String displayName;
  final double paid; // total this member actually paid
  final double share; // total this member is responsible for

  const MemberBalance({
    required this.userId,
    required this.displayName,
    required this.paid,
    required this.share,
  });

  /// Positive → the group owes this member; negative → this member owes.
  double get net => paid - share;
}

/// A single "X pays Y" suggestion to settle all balances.
class SettleSuggestion {
  final String fromName;
  final String toName;
  final double amount;
  const SettleSuggestion(this.fromName, this.toName, this.amount);
}

/// Greedy settle-up: match biggest debtor to biggest creditor until square.
List<SettleSuggestion> computeSettlements(List<MemberBalance> balances) {
  final creditors = balances
      .where((b) => b.net > 0.01)
      .map((b) => [b.displayName, b.net] as List<dynamic>)
      .toList()
    ..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  final debtors = balances
      .where((b) => b.net < -0.01)
      .map((b) => [b.displayName, -b.net] as List<dynamic>)
      .toList()
    ..sort((a, b) => (b[1] as double).compareTo(a[1] as double));

  final out = <SettleSuggestion>[];
  int i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final owe = debtors[i][1] as double;
    final get = creditors[j][1] as double;
    final pay = owe < get ? owe : get;
    if (pay > 0.01) {
      out.add(SettleSuggestion(
          debtors[i][0] as String, creditors[j][0] as String, pay));
    }
    debtors[i][1] = owe - pay;
    creditors[j][1] = get - pay;
    if ((debtors[i][1] as double) < 0.01) i++;
    if ((creditors[j][1] as double) < 0.01) j++;
  }
  return out;
}
