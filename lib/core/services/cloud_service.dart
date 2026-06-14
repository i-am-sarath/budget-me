import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agent_money/core/config/api_config.dart';

/// Thin wrapper around Supabase init + Google auth for the cloud Groups feature.
///
/// Everything here is a no-op / throws a friendly error when Supabase isn't
/// configured ([ApiConfig.cloudGroupsEnabled] == false), so the rest of the app
/// keeps working as a purely-local budget tracker.
class CloudService {
  CloudService._();

  static bool _initialized = false;
  static bool get isReady => _initialized && ApiConfig.cloudGroupsEnabled;

  /// Call once from main(). Safe to call when keys are missing (does nothing).
  static Future<void> init() async {
    if (!ApiConfig.cloudGroupsEnabled || _initialized) return;
    await Supabase.initialize(
      url: ApiConfig.supabaseUrl,
      anonKey: ApiConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// The single, app-wide Google sign-in client. EVERY Google sign-in/out in
  /// the app (auth here + Sheets connect) MUST go through this one instance.
  /// `google_sign_in` caches one native client per process, so mixing
  /// differently-configured `GoogleSignIn()` objects (different serverClientId
  /// or scopes) reconfigures that client and makes the next sign-in fail with
  /// DEVELOPER_ERROR (10). Extra scopes (e.g. Sheets' drive.file) are added
  /// incrementally via `requestScopes`, not by creating a second instance.
  static final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId: ApiConfig.googleWebClientId.isNotEmpty
        ? ApiConfig.googleWebClientId
        : null,
  );

  static User? get currentUser => isReady ? client.auth.currentUser : null;
  static bool get isSignedIn => currentUser != null;

  /// Emits on sign-in / sign-out so the UI can react.
  static Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  /// Native Google sign-in → exchange the id token with Supabase.
  /// Returns the signed-in [User]. Throws [CloudException] on failure.
  static Future<User> signInWithGoogle() async {
    if (!isReady) {
      throw CloudException('Cloud sync isn\'t set up in this build.');
    }
    if (ApiConfig.googleWebClientId.isEmpty) {
      throw CloudException('Google sign-in isn\'t configured.');
    }

    final GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signIn();
    } on PlatformException catch (e) {
      // Translate the opaque Google Play Services error codes into something
      // actionable. Code 10 = DEVELOPER_ERROR: the app's Android OAuth client
      // (package name + SHA-1) isn't registered in Google Cloud, or the
      // serverClientId isn't the *Web* client.
      final detail = '${e.code} ${e.message ?? ''}';
      if (detail.contains('10')) {
        throw CloudException(
          'Google sign-in isn\'t set up for this app yet (error 10). '
          'Add an Android OAuth client (package com.budgetme.budgettracker + '
          'this build\'s SHA-1) in Google Cloud, and make sure '
          'GOOGLE_WEB_CLIENT_ID is the Web client.',
        );
      }
      if (detail.contains('12501') || detail.contains('canceled') ||
          detail.contains('cancelled')) {
        throw CloudException('Sign-in cancelled.');
      }
      if (detail.contains('7') && detail.toLowerCase().contains('network')) {
        throw CloudException('Network error. Check your connection and retry.');
      }
      throw CloudException('Google sign-in failed (${e.code}).');
    }
    if (account == null) {
      throw CloudException('Sign-in cancelled.'); // user dismissed the sheet
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw CloudException('Could not get Google credentials. Try again.');
    }

    final res = await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    final user = res.user;
    if (user == null) {
      throw CloudException('Sign-in failed. Please try again.');
    }
    return user;
  }

  /// Reads the signed-in user's complimentary-Pro flag from `profiles.is_pro`.
  /// This is how Pro is comped to friends/testers without a payment: flip the
  /// boolean in the Supabase table editor. Returns false when not configured,
  /// not signed in, or the row/flag is missing.
  static Future<bool> fetchIsProFlag() async {
    if (!isReady || !isSignedIn) return false;
    try {
      final row = await client
          .from('profiles')
          .select('is_pro')
          .eq('id', currentUser!.id)
          .maybeSingle();
      return (row?['is_pro'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() async {
    if (!isReady) return;
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    await client.auth.signOut();
  }

  /// Permanently deletes the signed-in user's account and all their cloud data.
  ///
  /// Calls the `delete_user` Postgres function (SECURITY DEFINER) which removes
  /// the row from `auth.users`; every group / member / expense row cascades from
  /// the foreign keys. Then signs the user out locally. Required by the Google
  /// Play "account deletion" policy. No-op when cloud isn't configured.
  static Future<void> deleteAccount() async {
    if (!isReady || !isSignedIn) return;
    try {
      await client.rpc('delete_user');
    } on Object catch (e) {
      throw CloudException('Could not delete your account: $e');
    }
    // Best-effort local sign-out; the auth row is already gone server-side.
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  /// Best-effort display name for the current user.
  static String get displayName {
    final u = currentUser;
    if (u == null) return 'Me';
    final meta = u.userMetadata ?? const {};
    final name = (meta['full_name'] ?? meta['name']) as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = u.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Me';
  }
}

class CloudException implements Exception {
  final String message;
  CloudException(this.message);
  @override
  String toString() => message;
}
