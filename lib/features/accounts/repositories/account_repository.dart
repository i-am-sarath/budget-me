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
