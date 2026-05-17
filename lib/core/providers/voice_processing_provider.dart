import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/services/openai_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/voice_language_service.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

enum VoiceProcessingStatus { idle, processing, saved, error }

class VoiceProcessingState {
  final VoiceProcessingStatus status;
  final String statusMessage;
  final List<TransactionModel> transactions;
  final String? errorMessage;
  final File? pendingAudioFile;

  const VoiceProcessingState({
    this.status = VoiceProcessingStatus.idle,
    this.statusMessage = '',
    this.transactions = const [],
    this.errorMessage,
    this.pendingAudioFile,
  });

  bool get isIdle => status == VoiceProcessingStatus.idle;
  bool get isProcessing => status == VoiceProcessingStatus.processing;
  bool get isSaved => status == VoiceProcessingStatus.saved;
  bool get isError => status == VoiceProcessingStatus.error;

  VoiceProcessingState copyWith({
    VoiceProcessingStatus? status,
    String? statusMessage,
    List<TransactionModel>? transactions,
    String? errorMessage,
    File? pendingAudioFile,
  }) {
    return VoiceProcessingState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      transactions: transactions ?? this.transactions,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingAudioFile: pendingAudioFile ?? this.pendingAudioFile,
    );
  }
}

final voiceProcessingProvider =
    StateNotifierProvider<VoiceProcessingNotifier, VoiceProcessingState>(
  (ref) => VoiceProcessingNotifier(ref),
);

class VoiceProcessingNotifier extends StateNotifier<VoiceProcessingState> {
  final Ref _ref;
  final _openAiService = OpenAIService();

  VoiceProcessingNotifier(this._ref) : super(const VoiceProcessingState());

  Future<void> startProcessing(File audioFile) async {
    state = VoiceProcessingState(
      status: VoiceProcessingStatus.processing,
      statusMessage: 'Transcribing your voice...',
      pendingAudioFile: audioFile,
    );

    try {
      final languageCode = _ref.read(voiceLanguageProvider);

      final transcript = await _openAiService.transcribeAudio(
        audioFile,
        languageCode: languageCode,
      );

      if (!mounted) return;
      state = state.copyWith(statusMessage: 'Understanding your request...');

      final transactions = await _openAiService.parseTransactions(transcript);

      if (!mounted) return;

      // Resolve free-form account names against the user's actual accounts.
      final accounts = _ref.read(accountProvider).valueOrNull ?? [];
      final resolved = transactions.map((tx) {
        if (tx.accountName == null || tx.accountName!.isEmpty) return tx;
        final matched = matchAccountByName(tx.accountName!, accounts);
        if (matched == null) return tx;
        return tx.copyWith(accountId: matched.id, accountName: matched.name);
      }).toList();

      // Record usage toward the monthly quota.
      await _ref.read(subscriptionProvider.notifier).recordVoiceLogUsed();

      // Auto-save every transaction immediately.
      for (final tx in resolved) {
        await _ref.read(transactionListProvider.notifier).addTransaction(tx);
      }

      if (!mounted) return;

      final count = resolved.length;
      state = VoiceProcessingState(
        status: VoiceProcessingStatus.saved,
        transactions: resolved,
        statusMessage:
            '$count transaction${count == 1 ? '' : 's'} saved',
      );

      // Auto-dismiss the banner after 3 seconds.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && state.isSaved) {
          state = const VoiceProcessingState();
        }
      });
    } catch (e) {
      if (!mounted) return;
      state = VoiceProcessingState(
        status: VoiceProcessingStatus.error,
        errorMessage: e.toString(),
        pendingAudioFile: audioFile,
      );
    } finally {
      try {
        if (await audioFile.exists()) await audioFile.delete();
      } catch (_) {}
    }
  }

  Future<void> retry() async {
    final audio = state.pendingAudioFile;
    if (audio == null) return;
    await startProcessing(audio);
  }

  void dismiss() => state = const VoiceProcessingState();
}
