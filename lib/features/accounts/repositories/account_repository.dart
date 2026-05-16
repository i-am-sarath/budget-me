import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';

class AccountNotifier extends StateNotifier<AsyncValue<List<AccountModel>>> {
  final DatabaseHelper _db = DatabaseHelper();

  AccountNotifier() : super(const AsyncValue.loading()) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    try {
      state = const AsyncValue.loading();
      final rows = await _db.queryAll('accounts', orderBy: 'created_at DESC');
      state = AsyncValue.data(rows.map(AccountModel.fromMap).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAccount(AccountModel account) async {
    await _db.insert('accounts', account.toMap());
    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _db.delete('accounts', id);
    await loadAccounts();
  }

  Future<void> updateAccount(AccountModel account) async {
    await _db.update('accounts', account.toMap());
    await loadAccounts();
  }

  /// Called when a transaction is saved/deleted to adjust the linked account balance.
  /// [delta] is positive for income/borrow, negative for expense/lend.
  Future<void> adjustBalance(String accountId, double delta) async {
    await _db.adjustAccountBalance(accountId, delta);
    await loadAccounts();
  }

  List<AccountModel> get accounts => state.valueOrNull ?? [];
}

final accountProvider =
    StateNotifierProvider<AccountNotifier, AsyncValue<List<AccountModel>>>(
      (ref) => AccountNotifier(),
    );

// ─── Voice account-name matcher ─────────────────────────────
//
// Resolves a free-form name spoken by the user (e.g. "SBI", "my hdfc bank")
// to the user's actual accounts. Returns the best match or null.

AccountModel? matchAccountByName(String query, List<AccountModel> accounts) {
  if (accounts.isEmpty) return null;
  final q = _normalizeForMatch(query);
  if (q.length < 2) return null;

  AccountModel? best;
  int bestScore = 0;
  for (final a in accounts) {
    final name = _normalizeForMatch(a.name);
    final bank = _normalizeForMatch(a.bankName);
    int score = 0;

    if (name == q || (bank.isNotEmpty && bank == q)) {
      score = 100;
    } else if (name.contains(q) || (q.contains(name) && name.length >= 2)) {
      score = 80;
    } else if (bank.isNotEmpty &&
        (bank.contains(q) || (q.contains(bank) && bank.length >= 2))) {
      score = 70;
    }

    if (score > bestScore) {
      bestScore = score;
      best = a;
    }
  }

  return bestScore >= 70 ? best : null;
}

String _normalizeForMatch(String s) {
  var n = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  const fillers = [
    'my',
    'the',
    'account',
    'bank',
    'savings',
    'checking',
    'card',
    'wallet',
  ];
  for (final w in fillers) {
    n = n.replaceAll(RegExp(r'\b' + w + r'\b'), '');
  }
  return n.replaceAll(RegExp(r'\s+'), '').trim();
}
