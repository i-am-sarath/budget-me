import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_money/core/services/notification_service.dart';
import 'package:agent_money/core/services/openai_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

/// The shared capture pipeline behind every no-open-the-app voice entry
/// point (Android widget, iOS Siri Shortcut/App Intent/Back Tap, and — for
/// now, until those native triggers exist — the in-app quick-capture entry
/// in Settings): record with silence auto-stop → Whisper transcribe → parse
/// → write transaction → confirmation notification. Fire-and-forget: the
/// caller does not await a UI result, everything is reported via
/// [NotificationService].
class QuickCaptureService {
  QuickCaptureService(this._ref);

  final Ref _ref;
  final _recorder = AudioRecorder();
  final _openAi = OpenAIService();

  // dBFS below which the mic is considered "quiet". `record`'s amplitude
  // stream reports current level in dBFS (roughly -160 silence to 0 loudest).
  static const _silenceThresholdDb = -35.0;
  static const _silenceDuration = Duration(milliseconds: 1500);
  static const _minDuration = Duration(milliseconds: 800);
  static const _maxDuration = Duration(seconds: 30);
  static const _pendingQueueKey = 'quick_capture_pending_audio';

  /// Entry point for every trigger. Checks Pro entitlement *before*
  /// recording so free users never hit Whisper, records with silence
  /// auto-stop, and reports the outcome via a local notification.
  Future<void> captureExpense() async {
    if (!_ref.read(subscriptionProvider).isPro) {
      await NotificationService.instance.showProUpsell();
      return;
    }

    if (!await _recorder.hasPermission()) {
      await NotificationService.instance.showError(
        'Microphone permission is required for voice logging.',
      );
      return;
    }

    File? audioFile;
    try {
      audioFile = await _recordWithSilenceDetection();
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
      // Network/proxy failure with audio already captured — queue it rather
      // than silently drop the user's spoken transaction.
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
    }
  }

  Future<File?> _recordWithSilenceDetection() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'quick_capture_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

    final start = DateTime.now();
    var lastLoud = DateTime.now();
    final stopSignal = Completer<void>();
    final sub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((amp) {
      final now = DateTime.now();
      if (amp.current > _silenceThresholdDb) lastLoud = now;
      final elapsed = now.difference(start);
      final quietFor = now.difference(lastLoud);
      final shouldStop = elapsed >= _maxDuration ||
          (elapsed >= _minDuration && quietFor >= _silenceDuration);
      if (shouldStop && !stopSignal.isCompleted) stopSignal.complete();
    });

    await stopSignal.future.timeout(
      _maxDuration + const Duration(seconds: 2),
      onTimeout: () {},
    );
    await sub.cancel();

    final resultPath = await _recorder.stop();
    if (resultPath == null) return null;
    final file = File(resultPath);
    return (await file.exists()) ? file : null;
  }

  Future<void> _transcribeParseAndSave(File audioFile) async {
    try {
      final transcript = await _openAi.transcribeAudio(audioFile);
      final parsed = await _openAi.parseTransactions(transcript);
      await _saveResolved(parsed);
      await _ref.read(subscriptionProvider.notifier).recordVoiceLogUsed();
      await NotificationService.instance.showCaptureResult(parsed);
    } finally {
      if (await audioFile.exists()) await audioFile.delete();
    }
  }

  Future<void> _saveResolved(List<ParsedTransaction> parsed) async {
    final accounts = _ref.read(accountProvider).valueOrNull ?? [];
    for (final pt in parsed) {
      final tx = pt.transaction;
      var resolvedTx = tx;
      if (tx.accountName != null && tx.accountName!.isNotEmpty) {
        final matched = matchAccountByName(tx.accountName!, accounts);
        if (matched != null) {
          resolvedTx = tx.copyWith(accountId: matched.id, accountName: matched.name);
        }
      }
      await _ref.read(transactionListProvider.notifier).addTransaction(resolvedTx);
    }
  }

  // ── Offline queue: retry audio that failed to reach the transcribe/parse
  // proxy (e.g. no connectivity at capture time) the next time the pipeline
  // runs successfully. ──

  Future<void> _queueForRetry(File audioFile) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_pendingQueueKey) ?? [];
    queue.add(jsonEncode({'path': audioFile.path}));
    await prefs.setStringList(_pendingQueueKey, queue);
  }

  /// Call once at app startup (when connectivity is most likely restored)
  /// to flush any audio queued by a previous offline capture attempt.
  Future<void> processPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_pendingQueueKey) ?? [];
    if (queue.isEmpty) return;
    await prefs.remove(_pendingQueueKey);

    for (final entry in queue) {
      try {
        final path = (jsonDecode(entry) as Map<String, dynamic>)['path'] as String;
        final file = File(path);
        if (!await file.exists()) continue;
        await _transcribeParseAndSave(file);
      } catch (_) {
        // Still unreachable, or the temp file was cleaned up by the OS —
        // drop it rather than retry forever.
      }
    }
  }

  void dispose() => _recorder.dispose();
}

final quickCaptureServiceProvider = Provider<QuickCaptureService>((ref) {
  final service = QuickCaptureService(ref);
  ref.onDispose(service.dispose);
  return service;
});
