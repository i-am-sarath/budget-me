import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-run feature tour has been seen.
///
/// Deliberately tiny — a single persisted bool in the same SharedPreferences
/// style as [BudgetNotifier]/[ThemeNotifier]. The tour itself is a custom
/// overlay (see `feature_tour.dart`); this only owns the "should we show it"
/// decision so it can be re-triggered from Settings.
class TourNotifier extends StateNotifier<bool> {
  static const _key = 'feature_tour_seen_v1';

  /// `true` once the user has finished or skipped the tour.
  TourNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to "seen" until we've actually read prefs, so we never flash the
    // tour over a loading frame. If the key is missing, this is a fresh install
    // → not seen yet.
    state = prefs.getBool(_key) ?? false;
  }

  /// Mark the tour complete (finished or skipped). Idempotent.
  Future<void> markSeen() async {
    if (state) return;
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Re-arm the tour so it shows again (used by the "Replay tour" Settings row).
  Future<void> replay() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}

/// `false` = tour should be shown, `true` = already seen.
final tourSeenProvider = StateNotifierProvider<TourNotifier, bool>(
  (ref) => TourNotifier(),
);
