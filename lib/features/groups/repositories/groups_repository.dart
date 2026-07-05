import 'dart:math';
import 'package:money_pi/core/services/cloud_service.dart';
import 'package:money_pi/features/groups/models/group_models.dart';

/// All Supabase reads/writes for the cloud Groups feature live here.
class GroupsRepository {

  // ── Groups ────────────────────────────────────────────────────────────────

  /// Groups the current user belongs to (RLS scopes this automatically).
  Future<List<GroupModel>> myGroups() async {
    final rows = await CloudService.client
        .from('groups')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => GroupModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupModel> createGroup({
    required String name,
    required String emoji,
    required int colorValue,
    required String currencyCode,
    required bool settleUp,
  }) async {
    final user = CloudService.currentUser!;
    // Generate a unique invite code, retrying on the rare collision.
    Map<String, dynamic>? inserted;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        inserted = await CloudService.client
            .from('groups')
            .insert({
              'name': name,
              'emoji': emoji,
              'color_value': colorValue,
              'currency_code': currencyCode,
              'settle_up': settleUp,
              'invite_code': _randomCode(),
              'created_by': user.id,
            })
            .select()
            .single();
        break;
      } on Object catch (e) {
        if (attempt == 4 || !e.toString().contains('invite_code')) rethrow;
      }
    }
    final group = GroupModel.fromMap(inserted!);
    // Add the creator as the owner member.
    await CloudService.client.from('group_members').insert({
      'group_id': group.id,
      'user_id': user.id,
      'display_name': CloudService.displayName,
      'role': 'owner',
    });
    return group;
  }

  /// Join a group by its 6-char invite code. Returns the joined group.
  ///
  /// Uses the `join_group` Postgres function (SECURITY DEFINER) which verifies
  /// the invite code server-side and inserts the membership row. This is the
  /// only way to join: RLS blocks reading or self-inserting into a group you're
  /// not a member of, so knowing a group's UUID alone can't get you in.
  Future<GroupModel> joinByCode(String code) async {
    try {
      final row = await CloudService.client.rpc(
        'join_group',
        params: {'p_code': code.trim().toUpperCase()},
      );
      final map = row is List
          ? (row.isNotEmpty ? row.first as Map<String, dynamic> : null)
          : row as Map<String, dynamic>?;
      if (map == null) {
        throw CloudException('No group found for that code.');
      }
      return GroupModel.fromMap(map);
    } on CloudException {
      rethrow;
    } catch (_) {
      // The function raises when the code is invalid; surface a clean message.
      throw CloudException('No group found for that code.');
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final user = CloudService.currentUser!;
    await CloudService.client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', user.id);
  }

  // ── Members ───────────────────────────────────────────────────────────────

  Future<List<GroupMemberModel>> members(String groupId) async {
    final rows = await CloudService.client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .order('joined_at');
    return (rows as List)
        .map((e) => GroupMemberModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ── Expenses ──────────────────────────────────────────────────────────────

  Future<List<GroupExpenseModel>> expenses(String groupId) async {
    final rows = await CloudService.client
        .from('group_expenses')
        .select()
        .eq('group_id', groupId)
        .order('spent_at', ascending: false);
    return (rows as List)
        .map((e) => GroupExpenseModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Add a shared expense. When [settleUp] is on, an equal split is recorded
  /// across the supplied [memberIds] so balances stay correct.
  Future<void> addExpense({
    required String groupId,
    required String payerId,
    required double amount,
    required String category,
    required String note,
    required DateTime spentAt,
    required bool settleUp,
    required List<String> memberIds,
  }) async {
    final user = CloudService.currentUser!;
    final expense = await CloudService.client
        .from('group_expenses')
        .insert({
          'group_id': groupId,
          'payer_id': payerId,
          'amount': amount,
          'category': category,
          'note': note,
          'spent_at': spentAt.toIso8601String().split('T').first,
          'created_by': user.id,
        })
        .select()
        .single();

    if (settleUp && memberIds.isNotEmpty) {
      final each = (amount / memberIds.length);
      final splits = memberIds
          .map((uid) => {
                'expense_id': expense['id'],
                'group_id': groupId,
                'user_id': uid,
                'share_amount': each,
              })
          .toList();
      await CloudService.client.from('group_expense_splits').insert(splits);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    await CloudService.client
        .from('group_expenses')
        .delete()
        .eq('id', expenseId);
  }

  // ── Balances (settle-up) ──────────────────────────────────────────────────

  Future<List<MemberBalance>> balances(
      String groupId, List<GroupMemberModel> members) async {
    final expenseRows = await CloudService.client
        .from('group_expenses')
        .select('payer_id, amount')
        .eq('group_id', groupId);
    final splitRows = await CloudService.client
        .from('group_expense_splits')
        .select('user_id, share_amount')
        .eq('group_id', groupId);

    final paid = <String, double>{};
    for (final r in expenseRows as List) {
      final id = r['payer_id'] as String;
      paid[id] = (paid[id] ?? 0) + (r['amount'] as num).toDouble();
    }
    final share = <String, double>{};
    for (final r in splitRows as List) {
      final id = r['user_id'] as String;
      share[id] = (share[id] ?? 0) + (r['share_amount'] as num).toDouble();
    }
    return members
        .map((m) => MemberBalance(
              userId: m.userId,
              displayName: m.displayName,
              paid: paid[m.userId] ?? 0,
              share: share[m.userId] ?? 0,
            ))
        .toList();
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
