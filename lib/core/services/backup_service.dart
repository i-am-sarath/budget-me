import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:money_pi/core/database/database_helper.dart';

/// Defensive auto-backup: serializes every table to a JSON file in the app's
/// documents directory. Runs at most once per [_minIntervalHours] hours.
/// Keeps the [_maxBackups] most recent files; older ones are pruned.
///
/// This is *insurance*, not the source of truth. The SQLite DB remains
/// authoritative. If a future migration corrupts the DB, the most recent
/// JSON file can be inspected or imported manually.
class BackupService {
  static const _prefsLastBackupKey = 'auto_backup_last_run_iso';
  static const _backupFilePrefix = 'budgetme_auto_backup_';
  static const int _maxBackups = 5;
  static const int _minIntervalHours = 24;

  static const List<String> _tables = [
    'spaces',
    'transactions',
    'accounts',
    'subscriptions',
    'recurring_transactions',
  ];

  /// Exports every table as one JSON file. Returns the file path on success,
  /// null if skipped (rate-limited) or failed.
  static Future<String?> exportAllIfDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIso = prefs.getString(_prefsLastBackupKey);
      if (lastIso != null) {
        final last = DateTime.tryParse(lastIso);
        if (last != null &&
            DateTime.now().difference(last).inHours < _minIntervalHours) {
          return null;
        }
      }

      final path = await _writeBackup();
      await prefs.setString(
          _prefsLastBackupKey, DateTime.now().toIso8601String());
      await _pruneOldBackups();
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Force a backup regardless of the rate limit. Used by manual "Export now"
  /// flows in future settings UI.
  static Future<String?> exportNow() async {
    try {
      final path = await _writeBackup();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsLastBackupKey, DateTime.now().toIso8601String());
      await _pruneOldBackups();
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _writeBackup() async {
    final db = await DatabaseHelper().database;
    final versionRow = await db.rawQuery('PRAGMA user_version');
    final dbVersion = versionRow.isNotEmpty
        ? (versionRow.first.values.first as int?)
        : null;
    final payload = <String, dynamic>{
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'db_version': dbVersion,
      'tables': <String, dynamic>{},
    };
    for (final table in _tables) {
      try {
        payload['tables'][table] = await db.query(table);
      } catch (_) {
        payload['tables'][table] = const [];
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(p.join(dir.path, '$_backupFilePrefix$stamp.json'));
    await file.writeAsString(jsonEncode(payload));
    return file.path;
  }

  static Future<void> _pruneOldBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = await dir
          .list()
          .where((e) =>
              e is File && p.basename(e.path).startsWith(_backupFilePrefix))
          .cast<File>()
          .toList();
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (var i = _maxBackups; i < files.length; i++) {
        try {
          await files[i].delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// List existing backup files, newest first. For future settings UI.
  static Future<List<File>> listBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = await dir
          .list()
          .where((e) =>
              e is File && p.basename(e.path).startsWith(_backupFilePrefix))
          .cast<File>()
          .toList();
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (_) {
      return const [];
    }
  }
}
