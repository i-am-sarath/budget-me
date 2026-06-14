import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import 'package:agent_money/core/services/cloud_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/user_service.dart';

/// Unified "do we have an account?" layer for the whole app.
///
/// One rule: **manual entry needs no account; everything else (voice, Google
/// Sheets, Spaces) requires one.** This service is the single place that
/// answers "is the user signed in?" and performs sign-in.
///
/// Two backends, chosen automatically:
///  - **Cloud (real accounts)** when Supabase is configured
///    ([CloudService.isReady]): Google sign-in or passwordless email OTP,
///    backed by Supabase Auth. This is the production path.
///  - **Local fallback** when Supabase isn't configured (local-only / dev
///    builds): degrades to the lightweight email registration in
///    [userProvider] so gated features still work without a backend. No code
///    is emailed; the email is simply remembered.
class AuthService {
  AuthService(this._ref);
  final Ref _ref;

  bool get cloudReady => CloudService.isReady;

  bool get isSignedIn => cloudReady
      ? CloudService.isSignedIn
      : _ref.read(userProvider).isRegistered;

  String? get email =>
      cloudReady ? CloudService.currentUser?.email : _ref.read(userProvider).email;

  String get displayName {
    if (cloudReady) return CloudService.displayName;
    final e = _ref.read(userProvider).email;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'Me';
  }

  /// Native Google sign-in → Supabase session. Throws [CloudException] when
  /// cloud isn't configured or the user cancels.
  Future<void> signInWithGoogle() => CloudService.signInWithGoogle();

  /// Send a 6-digit login code to [email]. No-op (but harmless) on the local
  /// fallback — there the code step is skipped and [verifyEmailCode] just
  /// stores the address.
  Future<void> sendEmailCode(String email) async {
    final e = email.trim().toLowerCase();
    if (!cloudReady) return;
    await CloudService.client.auth.signInWithOtp(
      email: e,
      shouldCreateUser: true,
    );
  }

  /// Verify the [code] for [email]. Returns true on success.
  Future<bool> verifyEmailCode(String email, String code) async {
    final e = email.trim().toLowerCase();
    if (cloudReady) {
      final res = await CloudService.client.auth.verifyOTP(
        type: OtpType.email,
        email: e,
        token: code.trim(),
      );
      return res.user != null;
    }
    // Local fallback: no real verification — remember the email so gated
    // features unlock in builds without a cloud backend.
    await _ref.read(userProvider.notifier).register(e);
    return true;
  }

  Future<void> signOut() async {
    if (cloudReady) {
      await CloudService.signOut();
    }
    // Always clear the local email too, so both backends end up signed out.
    await _ref.read(userProvider.notifier).clearEmail();
  }
}

/// Snapshot of the signed-in account for the UI to watch.
class AccountState {
  final bool signedIn;
  final String? email;
  final String displayName;

  /// True when the real (Supabase) backend is active; false on local fallback.
  final bool cloud;

  const AccountState({
    this.signedIn = false,
    this.email,
    this.displayName = 'Me',
    this.cloud = false,
  });
}

class AuthNotifier extends StateNotifier<AccountState> {
  AuthNotifier(this._ref) : super(const AccountState()) {
    _svc = AuthService(_ref);
    _init();
  }

  final Ref _ref;
  late final AuthService _svc;
  StreamSubscription<dynamic>? _authSub;

  /// The RevenueCat app-user id we last synced to, so we don't re-`logIn` on
  /// every token-refresh event.
  String? _rcSyncedId;

  void _init() {
    refresh();
    unawaited(_syncRevenueCat());
    // React to Supabase sign-in/out (real backend)…
    if (CloudService.isReady) {
      _authSub = CloudService.authChanges.listen((_) {
        refresh();
        unawaited(_syncRevenueCat());
      });
    }
    // …and to local email registration changes (fallback backend).
    _ref.listen(userProvider, (_, __) => refresh());
  }

  /// Tie the RevenueCat customer to the Supabase user, so Pro follows the
  /// account across devices/reinstalls (instead of a throwaway anonymous id).
  /// On sign-out, drop back to an anonymous RevenueCat user.
  Future<void> _syncRevenueCat() async {
    if (!CloudService.isReady) return;
    final uid = CloudService.isSignedIn ? CloudService.currentUser!.id : null;
    if (uid == _rcSyncedId) return; // nothing changed
    _rcSyncedId = uid;
    try {
      if (uid != null) {
        await Purchases.logIn(uid);
      } else if (!await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
      // Pull entitlements for the (now identified) customer so isPro updates.
      await _ref.read(subscriptionProvider.notifier).refreshSubscriptionStatus();
      // Also sync the server-granted complimentary-Pro flag from Supabase
      // (profiles.is_pro) — how Pro is comped to friends without a payment.
      final comped = await CloudService.fetchIsProFlag();
      await _ref.read(subscriptionProvider.notifier).setCompedPro(comped);
    } catch (_) {
      _rcSyncedId = null; // allow a retry next auth event
    }
  }

  /// Recompute [state] from whichever backend is active.
  void refresh() {
    state = AccountState(
      signedIn: _svc.isSignedIn,
      email: _svc.email,
      displayName: _svc.displayName,
      cloud: _svc.cloudReady,
    );
  }

  Future<void> signInWithGoogle() async {
    await _svc.signInWithGoogle();
    refresh();
  }

  Future<void> sendEmailCode(String email) => _svc.sendEmailCode(email);

  Future<bool> verifyEmailCode(String email, String code) async {
    final ok = await _svc.verifyEmailCode(email, code);
    if (ok) refresh();
    return ok;
  }

  Future<void> signOut() async {
    await _svc.signOut();
    refresh();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// Watch this for the signed-in account; read `.notifier` to perform sign-in.
final authProvider =
    StateNotifierProvider<AuthNotifier, AccountState>((ref) => AuthNotifier(ref));

/// Convenience accessor for the imperative service (sign-in actions).
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));
