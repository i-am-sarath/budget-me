import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/database/database_helper.dart';

// ─────────────────────────────────────────────
// Backup data model
// ─────────────────────────────────────────────

enum BackupSource { local, drive }

class BackupEntry {
  /// Local file path (BackupSource.local) or Drive file id (BackupSource.drive).
  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
  final BackupSource source;

  const BackupEntry({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
    required this.source,
  });
}

// ─────────────────────────────────────────────
// BackupService
//
// Builds a single .zip archive containing a snapshot of the sqlite
// database plus the small set of user preferences (budget, currency)
// and stores it either on-device or in a dedicated folder in the
// signed-in user's own Google Drive (drive.file scope — this app can
// only see files it created, never the rest of the user's Drive).
// ─────────────────────────────────────────────

class BackupService {
  static const _dbEntryName = 'quicklog.db';
  static const _settingsEntryName = 'settings.json';

  // Keys mirrored from BudgetNotifier / CurrencyNotifier — kept in sync
  // manually since they live in SharedPreferences rather than sqlite.
  static const _prefKeysToBackup = [
    'monthly_budget',
    'country_code',
    'country_name',
    'selected_currency_code',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
    serverClientId: ApiConfig.googleDriveServerClientId.isEmpty
        ? null
        : ApiConfig.googleDriveServerClientId,
  );

  GoogleSignInAccount? get currentGoogleAccount => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> restoreGoogleSession() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInToGoogle() => _googleSignIn.signIn();

  Future<void> signOutOfGoogle() => _googleSignIn.signOut();

  // ─────────────────────────────────────────────
  // Archive build / restore (shared by local + Drive)
  // ─────────────────────────────────────────────

  Future<Uint8List> _buildArchiveBytes() async {
    final dbHelper = DatabaseHelper();
    final dbPath = await dbHelper.databaseFilePath;

    // Close the live connection first so the file on disk is a
    // consistent snapshot, not a half-written page.
    await dbHelper.closeForBackup();
    late final Uint8List dbBytes;
    try {
      dbBytes = await File(dbPath).readAsBytes();
    } finally {
      await dbHelper.database; // reopen so the app keeps working
    }

    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{
      for (final key in _prefKeysToBackup)
        if (prefs.containsKey(key)) key: prefs.get(key),
      'backed_up_at': DateTime.now().toIso8601String(),
    };

    final archive = Archive()
      ..addFile(ArchiveFile(_dbEntryName, dbBytes.length, dbBytes))
      ..addFile(_jsonArchiveFile(_settingsEntryName, settings));

    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  ArchiveFile _jsonArchiveFile(String name, Map<String, dynamic> data) {
    final bytes = utf8.encode(jsonEncode(data));
    return ArchiveFile(name, bytes.length, bytes);
  }

  Future<void> _restoreFromArchiveBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbFile = archive.findFile(_dbEntryName);
    if (dbFile == null) {
      throw StateError('This file is not a valid Budget Me backup.');
    }

    final dbHelper = DatabaseHelper();
    final dbPath = await dbHelper.databaseFilePath;
    await dbHelper.closeForBackup();
    await File(dbPath).writeAsBytes(dbFile.content as List<int>, flush: true);
    await dbHelper.database; // reopen with the restored data

    final settingsFile = archive.findFile(_settingsEntryName);
    if (settingsFile == null) return;

    final decoded = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      }
    }
  }

  String _backupFileName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'budgetme_backup_${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}.zip';
  }

  // ─────────────────────────────────────────────
  // Local backups
  // ─────────────────────────────────────────────

  Future<Directory> _localBackupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<BackupEntry> createLocalBackup() async {
    final bytes = await _buildArchiveBytes();
    final dir = await _localBackupDir();
    final name = _backupFileName();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    await _pruneLocalBackups();

    final stat = await file.stat();
    return BackupEntry(
      id: file.path,
      name: name,
      createdAt: stat.modified,
      sizeBytes: stat.size,
      source: BackupSource.local,
    );
  }

  Future<List<BackupEntry>> listLocalBackups() async {
    final dir = await _localBackupDir();
    final entries = <BackupEntry>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.zip')) continue;
      final stat = await entity.stat();
      entries.add(BackupEntry(
        id: entity.path,
        name: p.basename(entity.path),
        createdAt: stat.modified,
        sizeBytes: stat.size,
        source: BackupSource.local,
      ));
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> restoreLocalBackup(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    await _restoreFromArchiveBytes(bytes);
  }

  /// Restores from an arbitrary .zip file path (e.g. one picked by the
  /// user via a file browser, such as a backup downloaded from Drive).
  Future<void> restoreFromPickedFile(String filePath) =>
      restoreLocalBackup(filePath);

  Future<void> deleteLocalBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> _pruneLocalBackups() async {
    final entries = await listLocalBackups();
    if (entries.length <= ApiConfig.maxBackupsRetained) return;
    for (final e in entries.skip(ApiConfig.maxBackupsRetained)) {
      await deleteLocalBackup(e.id);
    }
  }

  // ─────────────────────────────────────────────
  // Google Drive backups
  // ─────────────────────────────────────────────

  Future<drive.DriveApi> _driveApi() async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) {
      throw StateError('Google sign-in was cancelled.');
    }
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw StateError('Could not authenticate with Google Drive.');
    }
    return drive.DriveApi(client);
  }

  Future<String> _ensureBackupFolderId(drive.DriveApi api) async {
    final query = "mimeType = 'application/vnd.google-apps.folder' "
        "and name = '${ApiConfig.driveBackupFolderName}' "
        "and trashed = false and 'root' in parents";
    final result = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }
    final folder = drive.File()
      ..name = ApiConfig.driveBackupFolderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = ['root'];
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  Future<BackupEntry> createDriveBackup() async {
    final api = await _driveApi();
    final folderId = await _ensureBackupFolderId(api);
    final bytes = await _buildArchiveBytes();
    final name = _backupFileName();

    final metadata = drive.File()
      ..name = name
      ..parents = [folderId];
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final created = await api.files.create(
      metadata,
      uploadMedia: media,
      $fields: 'id, name, createdTime, size',
    );
    await _pruneDriveBackups(api, folderId);

    return BackupEntry(
      id: created.id!,
      name: created.name ?? name,
      createdAt: created.createdTime ?? DateTime.now(),
      sizeBytes: int.tryParse(created.size ?? '') ?? bytes.length,
      source: BackupSource.drive,
    );
  }

  Future<List<BackupEntry>> listDriveBackups() async {
    final api = await _driveApi();
    final folderId = await _ensureBackupFolderId(api);
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      spaces: 'drive',
      $fields: 'files(id, name, createdTime, size)',
    );
    return (result.files ?? [])
        .map((f) => BackupEntry(
              id: f.id!,
              name: f.name ?? 'backup.zip',
              createdAt: f.createdTime ?? DateTime.now(),
              sizeBytes: int.tryParse(f.size ?? '') ?? 0,
              source: BackupSource.drive,
            ))
        .toList();
  }

  Future<void> restoreDriveBackup(String fileId) async {
    final api = await _driveApi();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = await _collectBytes(media.stream);
    await _restoreFromArchiveBytes(bytes);
  }

  Future<void> deleteDriveBackup(String fileId) async {
    final api = await _driveApi();
    await api.files.delete(fileId);
  }

  Future<void> _pruneDriveBackups(drive.DriveApi api, String folderId) async {
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      spaces: 'drive',
      $fields: 'files(id, createdTime)',
    );
    final files = result.files ?? [];
    if (files.length <= ApiConfig.maxBackupsRetained) return;
    for (final f in files.skip(ApiConfig.maxBackupsRetained)) {
      if (f.id != null) await api.files.delete(f.id!);
    }
  }

  Future<Uint8List> _collectBytes(Stream<List<int>> stream) async {
    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }
}
