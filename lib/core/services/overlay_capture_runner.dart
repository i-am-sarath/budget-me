import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/core/services/capture_lock.dart';
import 'package:agent_money/core/services/notification_service.dart';
import 'package:agent_money/core/services/openai_service.dart';
import 'package:agent_money/core/services/silence_recorder.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

/// The floating bubble runs in its own Flutter engine/isolate
/// (`overlayMain` in main.dart) with no access to the main isolate's
/// Riverpod [ProviderScope] — [QuickCaptureService] can't be reused
/// directly. This mirrors its record → transcribe → parse → save →
/// notify pipeline using the repositories directly instead of providers;
/// sqflite supports opening the same database from multiple isolates, so
/// the write lands immediately, exactly like the widget/in-app entry
/// points, without waiting for the main app to next be opened.
///
/// Pro-gating and the overlay-permission dance happen before this runs
/// (in the Settings toggle and the bubble's tap handler) — this class
/// assumes both are already satisfied.
class OverlayCaptureRunner {
  final _recorder = SilenceRecorder();
  final _openAi = OpenAIService();
  final _transactions = TransactionRepository();
  final _db = DatabaseHelper();

  static const _pendingQueueKey = 'quick_capture_pending_audio';

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  /// Re-checks Pro status at capture time (not just when the bubble was
  /// enabled in Settings) — e.g. a subscription that lapsed since. Fails
  /// closed: any RevenueCat error is treated as "not Pro".
  Future<bool> _isPro() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(ApiConfig.entitlementPro);
    } catch (_) {
      return false;
    }
  }

  /// Records with silence auto-stop, transcribes, parses, saves, and shows
  /// a confirmation notification — the full pipeline for a single bubble
  /// tap. Never throws; failures are reported via [NotificationService].
  Future<void> captureExpense() async {
    if (!await _isPro()) {
      await NotificationService.instance.showProUpsell();
      return;
    }

    if (!await CaptureLock.acquire()) {
      await NotificationService.instance.showError(
        'Already logging a voice entry — try again in a moment.',
      );
      return;
    }

    File? audioFile;
    try {
      audioFile = await _recorder.recordWithSilenceDetection(prefix: 'overlay_capture');
      if (audioFile == null) {
        await NotificationService.instance.showError(
          "Didn't catch any speech. Please try again.",
        );
        return;
      }
      await _transcribeParseAndSave(audioFile);
    } on VoiceLogException catch (e) {
      await NotificationService.instance.showError(e.message);
    } catch (_) {
      if (audioFile != null && await audioFile.exists()) {
        await _queueForRetry(audioFile);
        await NotificationService.instance.showError(
          "Couldn't reach the server — we'll log it once you're back online.",
        );
      } else {
        await NotificationService.instance.showError(
          'Voice logging failed. Please try again.',
        );
      }
    } finally {
      await CaptureLock.release();
    }
  }

  Future<void> _transcribeParseAndSave(File audioFile) async {
    try {
      final transcript = await _openAi.transcribeAudio(audioFile);
      final parsed = await _openAi.parseTransactions(transcript);
      await _saveResolved(parsed);
      await NotificationService.instance.showCaptureResult(parsed);
    } finally {
      if (await audioFile.exists()) await audioFile.delete();
    }
  }

  Future<void> _saveResolved(List<ParsedTransaction> parsed) async {
    final accountRows = await _db.queryAll('accounts', orderBy: 'created_at DESC');
    final accounts = accountRows.map(AccountModel.fromMap).toList();

    for (final pt in parsed) {
      final tx = pt.transaction;
      var resolvedTx = tx;
      if (tx.accountName != null && tx.accountName!.isNotEmpty) {
        final matched = matchAccountByName(tx.accountName!, accounts);
        if (matched != null) {
          resolvedTx = tx.copyWith(accountId: matched.id, accountName: matched.name);
        }
      }
      await _transactions.addTransaction(resolvedTx);
      if (resolvedTx.accountId != null && resolvedTx.accountId!.isNotEmpty) {
        await _db.adjustAccountBalance(resolvedTx.accountId!, resolvedTx.balanceDelta);
      }
    }
  }

  Future<void> _queueForRetry(File audioFile) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_pendingQueueKey) ?? [];
    queue.add(jsonEncode({'path': audioFile.path}));
    await prefs.setStringList(_pendingQueueKey, queue);
  }

  void dispose() => _recorder.dispose();
}
