import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:agent_money/core/services/backup_service.dart';

// ─────────────────────────────────────────────
// Backup & Restore state
//
// Pro-gating happens in the UI (settings screen / backup screen) via
// subscriptionProvider — this notifier is purely the I/O layer.
// ─────────────────────────────────────────────

class BackupState {
  final List<BackupEntry> localBackups;
  final List<BackupEntry> driveBackups;
  final GoogleSignInAccount? googleAccount;
  final bool isLoadingLocal;
  final bool isLoadingDrive;
  final bool isBusy; // backup/restore/delete in flight
  final String? error;

  const BackupState({
    this.localBackups = const [],
    this.driveBackups = const [],
    this.googleAccount,
    this.isLoadingLocal = false,
    this.isLoadingDrive = false,
    this.isBusy = false,
    this.error,
  });

  bool get isDriveConnected => googleAccount != null;

  BackupState copyWith({
    List<BackupEntry>? localBackups,
    List<BackupEntry>? driveBackups,
    GoogleSignInAccount? googleAccount,
    bool clearGoogleAccount = false,
    bool? isLoadingLocal,
    bool? isLoadingDrive,
    bool? isBusy,
    String? error,
    bool clearError = false,
  }) {
    return BackupState(
      localBackups: localBackups ?? this.localBackups,
      driveBackups: driveBackups ?? this.driveBackups,
      googleAccount:
          clearGoogleAccount ? null : (googleAccount ?? this.googleAccount),
      isLoadingLocal: isLoadingLocal ?? this.isLoadingLocal,
      isLoadingDrive: isLoadingDrive ?? this.isLoadingDrive,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BackupNotifier extends StateNotifier<BackupState> {
  final BackupService _service = BackupService();

  BackupNotifier() : super(const BackupState()) {
    _init();
  }

  Future<void> _init() async {
    await refreshLocalBackups();
    final account = await _service.restoreGoogleSession();
    if (account != null) {
      state = state.copyWith(googleAccount: account);
      await refreshDriveBackups();
    }
  }

  Future<void> refreshLocalBackups() async {
    state = state.copyWith(isLoadingLocal: true, clearError: true);
    try {
      final backups = await _service.listLocalBackups();
      state = state.copyWith(localBackups: backups, isLoadingLocal: false);
    } catch (e) {
      state = state.copyWith(isLoadingLocal: false, error: 'Failed to load local backups: $e');
    }
  }

  Future<void> refreshDriveBackups() async {
    if (!state.isDriveConnected) return;
    state = state.copyWith(isLoadingDrive: true, clearError: true);
    try {
      final backups = await _service.listDriveBackups();
      state = state.copyWith(driveBackups: backups, isLoadingDrive: false);
    } catch (e) {
      state = state.copyWith(isLoadingDrive: false, error: 'Failed to load Drive backups: $e');
    }
  }

  Future<bool> backupLocal() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.createLocalBackup();
      await refreshLocalBackups();
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: 'Backup failed: $e');
      return false;
    }
  }

  Future<bool> restoreLocal(String filePath) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.restoreLocalBackup(filePath);
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: 'Restore failed: $e');
      return false;
    }
  }

  Future<bool> restoreFromPickedFile(String filePath) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.restoreFromPickedFile(filePath);
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: 'Restore failed: $e');
      return false;
    }
  }

  Future<void> deleteLocal(String filePath) async {
    try {
      await _service.deleteLocalBackup(filePath);
      await refreshLocalBackups();
    } catch (e) {
      state = state.copyWith(error: 'Delete failed: $e');
    }
  }

  Future<bool> connectGoogleDrive() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final account = await _service.signInToGoogle();
      if (account == null) {
        state = state.copyWith(isBusy: false); // user cancelled
        return false;
      }
      state = state.copyWith(googleAccount: account, isBusy: false);
      await refreshDriveBackups();
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: 'Google sign-in failed: $e');
      return false;
    }
  }

  Future<void> disconnectGoogleDrive() async {
    await _service.signOutOfGoogle();
    state = state.copyWith(clearGoogleAccount: true, driveBackups: []);
  }

  Future<bool> backupToDrive() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.createDriveBackup();
      await refreshDriveBackups();
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: 'Drive backup failed: $e');
      return false;
    }
  }

  Future<bool> restoreFromDrive(String fileId) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.restoreDriveBackup(fileId);
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: 'Restore failed: $e');
      return false;
    }
  }

  Future<void> deleteFromDrive(String fileId) async {
    try {
      await _service.deleteDriveBackup(fileId);
      await refreshDriveBackups();
    } catch (e) {
      state = state.copyWith(error: 'Delete failed: $e');
    }
  }
}

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>(
  (ref) => BackupNotifier(),
);
