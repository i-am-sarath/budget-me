import 'package:shared_preferences/shared_preferences.dart';

/// Stops two quick-capture entry points — the in-app button, the widget,
/// and the floating overlay bubble — from recording at the same time and
/// stepping on each other's mic session and transaction writes. Not a true
/// cross-isolate mutex, just a timestamped SharedPreferences flag; good
/// enough for "one phone, one mic, one user."
class CaptureLock {
  static const _key = 'quick_capture_lock_started_at';
  static const _staleAfter = Duration(seconds: 40);

  /// Returns true if the lock was acquired. A stale lock (e.g. left behind
  /// by a crashed/killed process) is treated as free.
  static Future<bool> acquire() async {
    final prefs = await SharedPreferences.getInstance();
    final startedAtMs = prefs.getInt(_key);
    if (startedAtMs != null) {
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(startedAtMs));
      if (age < _staleAfter) return false;
    }
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  static Future<void> release() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
