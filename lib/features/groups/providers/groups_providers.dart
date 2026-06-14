import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/services/cloud_service.dart';
import 'package:agent_money/features/groups/models/group_models.dart';
import 'package:agent_money/features/groups/repositories/groups_repository.dart';

final groupsRepositoryProvider = Provider((_) => GroupsRepository());

// ── Auth ──────────────────────────────────────────────────────────────────

class CloudAuthState {
  final User? user;
  final bool busy;
  final String? error;
  const CloudAuthState({this.user, this.busy = false, this.error});

  bool get isSignedIn => user != null;

  CloudAuthState copyWith({User? user, bool? busy, String? error}) =>
      CloudAuthState(
        user: user ?? this.user,
        busy: busy ?? this.busy,
        error: error,
      );
}

class CloudAuthNotifier extends StateNotifier<CloudAuthState> {
  StreamSubscription<AuthState>? _sub;

  CloudAuthNotifier() : super(const CloudAuthState()) {
    if (CloudService.isReady) {
      state = CloudAuthState(user: CloudService.currentUser);
      _sub = CloudService.authChanges.listen((event) {
        state = state.copyWith(user: event.session?.user, busy: false);
      });
    }
  }

  Future<void> signIn() async {
    state = state.copyWith(busy: true, error: null);
    try {
      final user = await CloudService.signInWithGoogle();
      state = CloudAuthState(user: user);
    } on CloudException catch (e) {
      state = CloudAuthState(user: state.user, error: e.message);
    } catch (e) {
      state = CloudAuthState(user: state.user, error: 'Sign-in failed.');
    }
  }

  Future<void> signOut() async {
    await CloudService.signOut();
    state = const CloudAuthState();
  }

  /// Permanently deletes the account + all cloud data, then signs out.
  /// Throws [CloudException] on failure so the UI can surface it.
  Future<void> deleteAccount() async {
    state = state.copyWith(busy: true, error: null);
    try {
      await CloudService.deleteAccount();
      state = const CloudAuthState();
    } on CloudException catch (e) {
      state = CloudAuthState(user: state.user, error: e.message);
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final cloudAuthProvider =
    StateNotifierProvider<CloudAuthNotifier, CloudAuthState>(
        (_) => CloudAuthNotifier());

/// Whether the Groups feature is usable in this build.
final cloudEnabledProvider = Provider((_) => ApiConfig.cloudGroupsEnabled);

// ── Group list ──────────────────────────────────────────────────────────────

final myGroupsProvider = FutureProvider.autoDispose<List<GroupModel>>((ref) {
  // Re-fetch whenever auth changes.
  final auth = ref.watch(cloudAuthProvider);
  if (!auth.isSignedIn) return Future.value(const []);
  return ref.watch(groupsRepositoryProvider).myGroups();
});

// ── Group detail ──────────────────────────────────────────────────────────

class GroupDetailData {
  final List<GroupMemberModel> members;
  final List<GroupExpenseModel> expenses;
  final List<MemberBalance> balances;
  const GroupDetailData(this.members, this.expenses, this.balances);

  /// Spending totals per category, descending.
  List<MapEntry<String, double>> get categoryTotals {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  double get total => expenses.fold(0.0, (s, e) => s + e.amount);
}

final groupDetailProvider = FutureProvider.autoDispose
    .family<GroupDetailData, GroupModel>((ref, group) async {
  final repo = ref.watch(groupsRepositoryProvider);
  final members = await repo.members(group.id);
  final expenses = await repo.expenses(group.id);
  final balances =
      group.settleUp ? await repo.balances(group.id, members) : <MemberBalance>[];
  return GroupDetailData(members, expenses, balances);
});
