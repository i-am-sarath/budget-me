import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserState {
  final String? email;
  final bool isLoaded;

  const UserState({this.email, this.isLoaded = false});

  bool get isRegistered => email != null && email!.isNotEmpty;

  UserState copyWith({String? email, bool? isLoaded}) => UserState(
        email: email ?? this.email,
        isLoaded: isLoaded ?? this.isLoaded,
      );
}

class UserNotifier extends StateNotifier<UserState> {
  static const _emailKey = 'user_email';

  UserNotifier() : super(const UserState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey);
    if (mounted) state = UserState(email: email, isLoaded: true);
  }

  Future<void> register(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email.trim().toLowerCase());
    state = state.copyWith(email: email.trim().toLowerCase(), isLoaded: true);
  }

  Future<void> clearEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    state = const UserState(isLoaded: true);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>(
  (ref) => UserNotifier(),
);
