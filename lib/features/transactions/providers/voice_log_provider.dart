import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent_money/main.dart' show rootScaffoldMessengerKey;
import 'package:agent_money/core/services/openai_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';

/// Drives the "hold → release → it just appears in the list" voice flow.
///
/// When recording stops, the audio is processed in the background (no blocking
/// modal). While [VoiceLogState.isProcessing] is true the transaction list shows
/// a shimmer row. On success the parsed transaction(s) are saved straight into
/// the list and an "Undo" snackbar is shown; on failure a friendly snackbar.
class VoiceLogState {
  final bool isProcessing;
  const VoiceLogState({this.isProcessing = false});
}

class VoiceLogNotifier extends StateNotifier<VoiceLogState> {
  VoiceLogNotifier(this._ref) : super(const VoiceLogState());

  final Ref _ref;
  final OpenAIService _service = OpenAIService();

  Future<void> processAndSave(File audio) async {
    state = const VoiceLogState(isProcessing: true);
    try {
      final transcript = await _service.transcribeAudio(audio);
      final parsed = await _service.parseTransactions(transcript);

      // Resolve free-form account names ("SBI") to real accounts so balances
      // update, exactly like the old review sheet did.
      final accounts = _ref.read(accountProvider).valueOrNull ?? [];
      final resolved = parsed.map((tx) {
        if (tx.accountName == null || tx.accountName!.isEmpty) return tx;
        final matched = matchAccountByName(tx.accountName!, accounts);
        if (matched == null) return tx;
        return tx.copyWith(accountId: matched.id, accountName: matched.name);
      }).toList();

      if (resolved.isEmpty) {
        _snack("Couldn't find a transaction in that — try again.");
        return;
      }

      final ids = <String>[];
      for (final tx in resolved) {
        await _ref.read(transactionListProvider.notifier).addTransaction(tx);
        ids.add(tx.id);
      }
      await _ref.read(subscriptionProvider.notifier).recordVoiceLogUsed();
      _snackSaved(resolved.length, ids);
    } on VoiceLogException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not process that. Please try again.');
    } finally {
      state = const VoiceLogState();
      try {
        if (await audio.exists()) await audio.delete();
      } catch (_) {}
    }
  }

  void _snackSaved(int count, List<String> ids) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$count transaction${count == 1 ? '' : 's'} added'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            for (final id in ids) {
              _ref.read(transactionListProvider.notifier).deleteTransaction(id);
            }
          },
        ),
      ),
    );
  }

  void _snack(String message) {
    rootScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final voiceLogProvider =
    StateNotifierProvider<VoiceLogNotifier, VoiceLogState>(
  (ref) => VoiceLogNotifier(ref),
);
