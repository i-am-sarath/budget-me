import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:agent_money/core/providers/backup_provider.dart';
import 'package:agent_money/core/services/backup_service.dart';
import 'package:agent_money/core/services/budget_service.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/paywall/paywall_screen.dart';
import 'package:agent_money/features/recurring/repositories/recurring_repository.dart';
import 'package:agent_money/features/subscriptions/repositories/subscription_repository.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final isPro = ref.watch(subscriptionProvider).isPro;

    return Scaffold(
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: tc.surface,
        elevation: 0,
        title: Text(
          'Backup & Restore',
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: isPro ? const _BackupBody() : const _BackupUpsell(),
    );
  }
}

// ─────────────────────────────────────────────
// Upsell for free users
// ─────────────────────────────────────────────

class _BackupUpsell extends StatelessWidget {
  const _BackupUpsell();

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tc.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.cloud_upload_outlined, color: tc.onSurface, size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              'Backup & Restore is a Pro feature',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upgrade to Pro to back up your transactions, accounts and settings — on this device or to your own Google Drive.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => showPaywall(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: tc.onSurface,
                foregroundColor: tc.surface,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: Text('Upgrade to Pro', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Main body (Pro users)
// ─────────────────────────────────────────────

class _BackupBody extends ConsumerWidget {
  const _BackupBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupProvider);
    final tc = AppThemeColors.of(context);

    ref.listen(backupProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return AbsorbPointer(
      absorbing: state.isBusy,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(backupProvider.notifier).refreshLocalBackups();
              await ref.read(backupProvider.notifier).refreshDriveBackups();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                _SectionLabel('ON THIS DEVICE', tc: tc),
                const SizedBox(height: 10),
                _LocalBackupCard(state: state),
                const SizedBox(height: 28),
                _SectionLabel('GOOGLE DRIVE', tc: tc),
                const SizedBox(height: 10),
                _DriveBackupCard(state: state),
              ],
            ),
          ),
          if (state.isBusy)
            Container(
              color: Colors.black.withOpacity(0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppThemeColors tc;
  const _SectionLabel(this.label, {required this.tc});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.inter(
          color: tc.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

// ─────────────────────────────────────────────
// Local backup card
// ─────────────────────────────────────────────

class _LocalBackupCard extends ConsumerWidget {
  final BackupState state;
  const _LocalBackupCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final notifier = ref.read(backupProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Saves a copy of your data to this device\'s storage.',
                    style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await notifier.backupLocal();
                      if (context.mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup saved to this device.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text('Back Up Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tc.onSurface,
                      foregroundColor: tc.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _importBackupFile(context, ref),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Import'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tc.onSurface,
                    side: BorderSide(color: tc.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tc.outlineVariant),
          if (state.isLoadingLocal)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.localBackups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No local backups yet.',
                style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 12),
              ),
            )
          else
            ...state.localBackups.map((entry) => Column(
                  children: [
                    _BackupTile(
                      entry: entry,
                      tc: tc,
                      onShare: () => Share.shareXFiles(
                        [XFile(entry.id)],
                        text: 'Budget Me backup',
                      ),
                      onRestore: () => _confirmRestore(
                        context: context,
                        tc: tc,
                        entry: entry,
                        onConfirmed: () => _doRestoreLocal(context, ref, entry.id),
                      ),
                      onDelete: () => _confirmDelete(
                        context: context,
                        tc: tc,
                        onConfirmed: () => notifier.deleteLocal(entry.id),
                      ),
                    ),
                    if (entry != state.localBackups.last)
                      Divider(height: 1, color: tc.outlineVariant),
                  ],
                )),
        ],
      ),
    );
  }

  Future<void> _importBackupFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!context.mounted) return;

    final entryName = path.split(RegExp(r'[\\/]')).last;
    _confirmRestore(
      context: context,
      tc: AppThemeColors.of(context),
      entry: BackupEntry(
        id: path,
        name: entryName,
        createdAt: DateTime.now(),
        sizeBytes: 0,
        source: BackupSource.local,
      ),
      onConfirmed: () => _doRestoreLocal(context, ref, path),
    );
  }

  Future<void> _doRestoreLocal(BuildContext context, WidgetRef ref, String path) async {
    final ok = await ref.read(backupProvider.notifier).restoreFromPickedFile(path);
    if (!context.mounted) return;
    if (ok) {
      _invalidateAppData(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data restored from backup.')),
      );
    }
  }
}

// ─────────────────────────────────────────────
// Google Drive backup card
// ─────────────────────────────────────────────

class _DriveBackupCard extends ConsumerWidget {
  final BackupState state;
  const _DriveBackupCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final notifier = ref.read(backupProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_to_drive_rounded, color: tc.onSurface, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isDriveConnected
                            ? state.googleAccount!.email
                            : 'Not connected',
                        style: GoogleFonts.inter(color: tc.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        'Backups are stored in a private "Budget Me Backups" folder in your own Drive.',
                        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                if (!state.isDriveConnected)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.connectGoogleDrive(),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Connect Google Drive'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tc.onSurface,
                        foregroundColor: tc.surface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await notifier.backupToDrive();
                        if (context.mounted && ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backed up to Google Drive.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.backup_rounded, size: 18),
                      label: const Text('Back Up to Drive'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tc.onSurface,
                        foregroundColor: tc.surface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => notifier.disconnectGoogleDrive(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tc.onSurfaceVariant,
                      side: BorderSide(color: tc.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ],
              ],
            ),
          ),
          if (state.isDriveConnected) ...[
            Divider(height: 1, color: tc.outlineVariant),
            if (state.isLoadingDrive)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.driveBackups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No Drive backups yet.',
                  style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 12),
                ),
              )
            else
              ...state.driveBackups.map((entry) => Column(
                    children: [
                      _BackupTile(
                        entry: entry,
                        tc: tc,
                        onRestore: () => _confirmRestore(
                          context: context,
                          tc: tc,
                          entry: entry,
                          onConfirmed: () => _doRestoreDrive(context, ref, entry.id),
                        ),
                        onDelete: () => _confirmDelete(
                          context: context,
                          tc: tc,
                          onConfirmed: () => notifier.deleteFromDrive(entry.id),
                        ),
                      ),
                      if (entry != state.driveBackups.last)
                        Divider(height: 1, color: tc.outlineVariant),
                    ],
                  )),
          ],
        ],
      ),
    );
  }

  Future<void> _doRestoreDrive(BuildContext context, WidgetRef ref, String fileId) async {
    final ok = await ref.read(backupProvider.notifier).restoreFromDrive(fileId);
    if (!context.mounted) return;
    if (ok) {
      _invalidateAppData(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data restored from Drive backup.')),
      );
    }
  }
}

// ─────────────────────────────────────────────
// Shared: backup row, confirmation dialogs, provider invalidation
// ─────────────────────────────────────────────

class _BackupTile extends StatelessWidget {
  final BackupEntry entry;
  final AppThemeColors tc;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback? onShare;

  const _BackupTile({
    required this.entry,
    required this.tc,
    required this.onRestore,
    required this.onDelete,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final sizeLabel = entry.sizeBytes > 0
        ? '${(entry.sizeBytes / 1024).toStringAsFixed(0)} KB · '
        : '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(Icons.description_outlined, color: tc.onSurfaceVariant, size: 20),
      title: Text(
        DateFormat('MMM d, yyyy · h:mm a').format(entry.createdAt),
        style: GoogleFonts.inter(color: tc.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        '$sizeLabel${entry.name}',
        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: tc.onSurfaceVariant, size: 20),
        onSelected: (value) {
          if (value == 'restore') onRestore();
          if (value == 'delete') onDelete();
          if (value == 'share') onShare?.call();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'restore', child: Text('Restore')),
          if (onShare != null) const PopupMenuItem(value: 'share', child: Text('Share / Export')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

void _confirmRestore({
  required BuildContext context,
  required AppThemeColors tc,
  required BackupEntry entry,
  required VoidCallback onConfirmed,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: tc.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Restore this backup?', style: GoogleFonts.inter(color: tc.onSurface, fontWeight: FontWeight.w700)),
      content: Text(
        'This will replace all current transactions, accounts, subscriptions and recurring rules with the data from this backup. This cannot be undone.',
        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.inter(color: tc.onSurfaceVariant)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: tc.expense, foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(ctx);
            onConfirmed();
          },
          child: Text('Restore', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void _confirmDelete({
  required BuildContext context,
  required AppThemeColors tc,
  required VoidCallback onConfirmed,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: tc.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Delete this backup?', style: GoogleFonts.inter(color: tc.onSurface, fontWeight: FontWeight.w700)),
      content: Text(
        'This backup will be permanently deleted.',
        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.inter(color: tc.onSurfaceVariant)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: tc.expense, foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(ctx);
            onConfirmed();
          },
          child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void _invalidateAppData(WidgetRef ref) {
  ref.invalidate(transactionListProvider);
  ref.invalidate(accountProvider);
  ref.invalidate(recurringListProvider);
  ref.invalidate(subscriptionListProvider);
  ref.invalidate(budgetProvider);
  ref.invalidate(currencyProvider);
}
