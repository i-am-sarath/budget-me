import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/openai_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// ProcessingSheet — shows while Whisper + GPT runs,
// then shows results with Re-speak & Save options.
// ─────────────────────────────────────────────

class ProcessingSheet extends ConsumerStatefulWidget {
  final File audioFile;

  const ProcessingSheet({super.key, required this.audioFile});

  @override
  ConsumerState<ProcessingSheet> createState() => _ProcessingSheetState();
}

class _ProcessingSheetState extends ConsumerState<ProcessingSheet>
    with SingleTickerProviderStateMixin {
  final _openAiService = OpenAIService();
  final _audioRecorder = AudioRecorder();

  String _status = 'Transcribing audio...';
  String _transcript = '';
  List<TransactionModel> _transactions = [];
  bool _isProcessing = true;
  bool _isReRecording = false;
  String? _error;
  File? _currentAudioFile;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _currentAudioFile = widget.audioFile;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _processAudio();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _processAudio() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _transactions = [];
      _status = 'Listening to your voice...';
    });

    try {
      final transcription =
          await _openAiService.transcribeAudio(_currentAudioFile!);
      setState(() {
        _transcript = transcription;
        _status = 'Understanding your request...';
      });

      final transactions =
          await _openAiService.parseTransactions(transcription);

      await ref.read(subscriptionProvider.notifier).recordVoiceLogUsed();

      setState(() {
        _transactions = transactions;
        _isProcessing = false;
        _status = 'Done';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = e.toString();
      });
    } finally {
      if (_currentAudioFile != null &&
          await _currentAudioFile!.exists()) {
        await _currentAudioFile!.delete();
      }
    }
  }

  // ── Re-speak: record a new clip without closing the sheet ──

  Future<void> _startReSpeak() async {
    if (!await _audioRecorder.hasPermission()) return;
    HapticFeedback.heavyImpact();
    final dir = await getTemporaryDirectory();
    final path = p.join(
        dir.path, 'tx_respeak_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() => _isReRecording = true);
  }

  Future<void> _stopReSpeak() async {
    HapticFeedback.lightImpact();
    final path = await _audioRecorder.stop();
    setState(() => _isReRecording = false);
    if (path != null) {
      _currentAudioFile = File(path);
      await _processAudio();
    }
  }

  void _saveAll() {
    for (final tx in _transactions) {
      ref.read(transactionListProvider.notifier).addTransaction(tx);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_transactions.length} transaction${_transactions.length == 1 ? '' : 's'} saved',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: bottomPad + 32,
      ),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tc.outlineVariant,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 24),

          if (_isProcessing)
            _ProcessingView(
              status: _status,
              transcript: _transcript,
              waveController: _waveController,
              tc: tc,
            )
          else if (_isReRecording)
            _ReRecordingView(
              tc: tc,
              onStop: _stopReSpeak,
            )
          else if (_error != null)
            _ErrorView(
              error: _error!,
              tc: tc,
              onRetry: () => _startReSpeak(),
              onClose: () => Navigator.pop(context),
            )
          else
            _ResultView(
              transactions: _transactions,
              transcript: _transcript,
              currency: currency,
              tc: tc,
              onSave: _saveAll,
              onRespeak: _startReSpeak,
              onCancel: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Processing view (animated while waiting)
// ─────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  final String status;
  final String transcript;
  final AnimationController waveController;
  final AppThemeColors tc;

  const _ProcessingView({
    required this.status,
    required this.transcript,
    required this.waveController,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: waveController,
          builder: (_, __) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tc.surfaceContainerHigh,
                boxShadow: [
                  BoxShadow(
                    color: tc.onSurface.withOpacity(0.08 + waveController.value * 0.1),
                    blurRadius: 20 + waveController.value * 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.mic_rounded, color: tc.onSurface, size: 36),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          status,
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
              color: tc.onSurfaceVariant,
              duration: 1500.ms,
            ),
        if (transcript.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '"$transcript"',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Re-recording view
// ─────────────────────────────────────────────

class _ReRecordingView extends StatelessWidget {
  final AppThemeColors tc;
  final VoidCallback onStop;

  const _ReRecordingView({required this.tc, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.15),
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.red, size: 36),
        ).animate(onPlay: (c) => c.repeat()).scaleXY(
              begin: 1.0,
              end: 1.12,
              duration: 700.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 16),
        Text(
          'Recording... tap to stop',
          style: GoogleFonts.inter(
            color: Colors.red,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded),
            label: Text('Stop & Process',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Error view (with Retry = Re-speak)
// ─────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final AppThemeColors tc;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _ErrorView({
    required this.error,
    required this.tc,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
        ),
        const SizedBox(height: 16),
        Text('Processing failed',
            style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          error.length > 140 ? '${error.substring(0, 140)}...' : error,
          textAlign: TextAlign.center,
          style:
              GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 24),
        _Btn(
          label: '🎤  Re-speak',
          onTap: onRetry,
          isPrimary: true,
          tc: tc,
        ),
        const SizedBox(height: 10),
        _Btn(label: 'Close', onTap: onClose, isPrimary: false, tc: tc),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Result view — shows parsed transactions
// ─────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String transcript;
  final CurrencyState currency;
  final AppThemeColors tc;
  final VoidCallback onSave;
  final VoidCallback onRespeak;
  final VoidCallback onCancel;

  const _ResultView({
    required this.transactions,
    required this.transcript,
    required this.currency,
    required this.tc,
    required this.onSave,
    required this.onRespeak,
    required this.onCancel,
  });

  Color _typeColor(TransactionType type) {
    switch (type) {
      case TransactionType.income:       return const Color(0xFF22C55E);
      case TransactionType.lendReturn:   return const Color(0xFF22C55E);
      case TransactionType.expense:      return Colors.red;
      case TransactionType.borrowReturn: return Colors.red;
      case TransactionType.lend:         return const Color(0xFFF59E0B);
      case TransactionType.borrow:       return const Color(0xFF8B5CF6);
      case TransactionType.investment:   return const Color(0xFF3B82F6);
    }
  }

  IconData _typeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.income:       return Icons.arrow_downward_rounded;
      case TransactionType.lendReturn:   return Icons.undo_rounded;
      case TransactionType.expense:      return Icons.arrow_upward_rounded;
      case TransactionType.borrowReturn: return Icons.redo_rounded;
      case TransactionType.lend:         return Icons.people_rounded;
      case TransactionType.borrow:       return Icons.savings_rounded;
      case TransactionType.investment:   return Icons.trending_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF22C55E), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transactions.length} transaction${transactions.length == 1 ? '' : 's'} found',
                    style: GoogleFonts.inter(
                        color: tc.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  if (transcript.isNotEmpty)
                    Text(
                      '"$transcript"',
                      style: GoogleFonts.inter(
                          color: tc.onSurfaceVariant,
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Transaction cards
        ...transactions.asMap().entries.map((e) {
          final tx = e.value;
          final color = _typeColor(tx.type);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_typeIcon(tx.type), color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.note.isNotEmpty ? tx.note : tx.category,
                        style: GoogleFonts.inter(
                            color: tc.onSurface, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${tx.type.label}${tx.payee != null && tx.payee!.isNotEmpty ? ' · ${tx.payee}' : ''} · ${tx.category}',
                        style: GoogleFonts.inter(
                            color: tc.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  currency.format(tx.amount),
                  style: GoogleFonts.inter(
                      color: color, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms, delay: (e.key * 80).ms).slideY(begin: 0.2);
        }),

        const SizedBox(height: 16),

        // Actions
        _Btn(label: 'Save All', onTap: onSave, isPrimary: true, tc: tc),
        const SizedBox(height: 10),

        // Re-speak + Cancel row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRespeak,
                icon: const Icon(Icons.mic_rounded, size: 16),
                label: Text('Re-speak',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tc.onSurface,
                  side: BorderSide(color: tc.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tc.onSurfaceVariant,
                  side: BorderSide(color: tc.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
                child:
                    Text('Cancel', style: GoogleFonts.inter()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared button
// ─────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final AppThemeColors tc;

  const _Btn({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onTap,
              child: Text(label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: tc.onSurfaceVariant,
                side: BorderSide(color: tc.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
              ),
              child: Text(label, style: GoogleFonts.inter()),
            ),
    );
  }
}
