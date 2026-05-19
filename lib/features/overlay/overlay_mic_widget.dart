import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_money/core/services/openai_service.dart';
import 'package:agent_money/features/overlay/overlay_queue_service.dart';

// ─────────────────────────────────────────────
// App shell — no ProviderScope (separate engine)
// ─────────────────────────────────────────────

class OverlayMicApp extends StatelessWidget {
  const OverlayMicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayMicWidget(),
    );
  }
}

// ─────────────────────────────────────────────
// State machine
// ─────────────────────────────────────────────

enum _MicState { idle, recording, processing, saved, error }

// ─────────────────────────────────────────────
// Overlay mic widget
// ─────────────────────────────────────────────

class OverlayMicWidget extends StatefulWidget {
  const OverlayMicWidget({super.key});

  @override
  State<OverlayMicWidget> createState() => _OverlayMicWidgetState();
}

class _OverlayMicWidgetState extends State<OverlayMicWidget>
    with SingleTickerProviderStateMixin {
  _MicState _micState = _MicState.idle;
  String _label = '';
  String? _errorMessage;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  File? _audioFile;

  final _recorder = AudioRecorder();
  final _openAi = OpenAIService();

  // Notification hint data
  String? _hintAmount;
  bool _showHintBadge = false;
  Timer? _hintTimer;
  Timer? _hintPollTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.stop();

    // Listen for payment hints forwarded from the main Flutter engine
    FlutterOverlayWindow.overlayListener.listen(_onOverlayMessage);

    // Poll SharedPreferences for hints written directly by the native
    // BudgetNotificationListenerService (handles the case where the main
    // app is not in the foreground to relay the event).
    _hintPollTimer =
        Timer.periodic(const Duration(seconds: 3), _pollNativeHint);
  }

  void _onOverlayMessage(dynamic data) {
    if (data is! Map) return;
    if (data['event'] == 'payment_hint') {
      final amount = data['amount'] as String?;
      if (amount != null && mounted) {
        setState(() {
          _hintAmount = amount;
          _showHintBadge = true;
        });
        HapticFeedback.mediumImpact();
        _hintTimer?.cancel();
        _hintTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) setState(() => _showHintBadge = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    _hintTimer?.cancel();
    _hintPollTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pollNativeHint(Timer _) async {
    if (_micState != _MicState.idle || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final amount = prefs.getString('native_payment_hint_amount');
      final tsStr = prefs.getString('native_payment_hint_ts');
      if (amount == null || tsStr == null) return;
      final ts = int.tryParse(tsStr) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age < 30000) {
        await prefs.remove('native_payment_hint_amount');
        await prefs.remove('native_payment_hint_ts');
        _onOverlayMessage({'event': 'payment_hint', 'amount': amount});
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // Recording
  // ─────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_micState != _MicState.idle) return;
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _setError('Microphone permission required');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/overlay_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _audioFile = File(path);
      _seconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      _pulseCtrl.repeat(reverse: true);
      setState(() {
        _micState = _MicState.recording;
        _showHintBadge = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      _setError('Could not start recording');
    }
  }

  Future<void> _stopAndProcess() async {
    if (_micState != _MicState.recording) return;
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    final path = await _recorder.stop();
    if (path == null) {
      _setError('Recording failed');
      return;
    }
    final file = File(path);
    setState(() {
      _micState = _MicState.processing;
      _label = 'Processing...';
    });
    HapticFeedback.lightImpact();

    await _processAudio(file);
  }

  Future<void> _processAudio(File file) async {
    try {
      // Check voice quota via SharedPreferences (same keys as SubscriptionNotifier)
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month}';
      final storedMonth = prefs.getString('voice_logs_month_id');
      final count =
          storedMonth == monthId ? (prefs.getInt('voice_logs_month') ?? 0) : 0;
      const freeLimit = 100;

      // Quick Pro check via RevenueCat; fall back to local count on failure
      bool isPro = false;
      try {
        // Import would create circular issues; use a direct flag from prefs
        // We rely on the main app having written 'overlay_is_pro' on last open
        isPro = prefs.getBool('overlay_is_pro') ?? false;
      } catch (_) {}

      if (!isPro && count >= freeLimit) {
        _setError('Monthly limit reached. Open app to upgrade.');
        await _deleteFile(file);
        return;
      }

      final langCode = prefs.getString('voice_language_code') ?? 'auto';
      final transcript =
          await _openAi.transcribeAudio(file, languageCode: langCode);

      if (transcript.isEmpty) {
        _setError('Nothing heard. Try again.');
        await _deleteFile(file);
        return;
      }

      final transactions = await _openAi.parseTransactions(transcript);

      if (transactions.isEmpty) {
        _setError('Could not parse. Try again.');
        await _deleteFile(file);
        return;
      }

      // Write to the shared queue for the main app to pick up
      await OverlayQueueService.enqueue(transactions);

      // Update quota
      final newCount = storedMonth == monthId ? count + 1 : 1;
      await prefs.setInt('voice_logs_month', newCount);
      await prefs.setString('voice_logs_month_id', monthId);

      // Notify the main app
      await FlutterOverlayWindow.shareData({
        'event': 'overlay_saved',
        'count': transactions.length,
      });

      await _deleteFile(file);

      if (!mounted) return;
      final n = transactions.length;
      setState(() {
        _micState = _MicState.saved;
        _label = '✓ $n transaction${n == 1 ? '' : 's'} queued';
        _hintAmount = null;
        _showHintBadge = false;
      });
      HapticFeedback.heavyImpact();

      // Auto-return to idle after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _micState = _MicState.idle;
            _label = '';
          });
        }
      });
    } catch (e) {
      await _deleteFile(file);
      _setError(e.toString().length > 60
          ? 'Processing failed. Try again.'
          : e.toString());
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _micState = _MicState.error;
      _label = msg;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _micState = _MicState.idle;
      _label = '';
      _errorMessage = null;
    });
  }

  Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopAndProcess(),
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              // Payment hint badge
              if (_showHintBadge && _hintAmount != null)
                Positioned(
                  right: 68,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8)
                      ],
                    ),
                    child: Text(
                      '₹$_hintAmount detected\nHold to log',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),

              // State pill label
              if (_micState != _MicState.idle)
                Positioned(
                  right: 68,
                  child: _StatePill(
                    micState: _micState,
                    label: _micState == _MicState.recording
                        ? _formatTime(_seconds)
                        : _label,
                    onRetry: _retry,
                  ),
                ),

              // Mic button
              Positioned(
                right: 8,
                child: _MicButton(
                  micState: _micState,
                  pulseAnim: _pulseAnim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
// Mic button
// ─────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final _MicState micState;
  final Animation<double> pulseAnim;

  const _MicButton({required this.micState, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final isRecording = micState == _MicState.recording;
    final isProcessing = micState == _MicState.processing;
    final isSaved = micState == _MicState.saved;
    final isError = micState == _MicState.error;

    Color bgColor;
    Color iconColor;
    IconData icon;

    if (isRecording) {
      bgColor = Colors.red;
      iconColor = Colors.white;
      icon = Icons.mic_rounded;
    } else if (isProcessing) {
      bgColor = const Color(0xFF1B2640);
      iconColor = Colors.white;
      icon = Icons.hourglass_empty_rounded;
    } else if (isSaved) {
      bgColor = const Color(0xFF22C55E);
      iconColor = Colors.white;
      icon = Icons.check_rounded;
    } else if (isError) {
      bgColor = Colors.red.shade700;
      iconColor = Colors.white;
      icon = Icons.mic_off_rounded;
    } else {
      bgColor = const Color(0xFF080D1A).withOpacity(0.85);
      iconColor = Colors.white;
      icon = Icons.mic_rounded;
    }

    final button = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isProcessing
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
          : Icon(icon, color: iconColor, size: 22),
    );

    if (isRecording) {
      return AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: pulseAnim.value,
          child: child,
        ),
        child: button,
      );
    }
    return button;
  }
}

// ─────────────────────────────────────────────
// State pill label
// ─────────────────────────────────────────────

class _StatePill extends StatelessWidget {
  final _MicState micState;
  final String label;
  final VoidCallback onRetry;

  const _StatePill({
    required this.micState,
    required this.label,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = micState == _MicState.recording;
    final isError = micState == _MicState.error;

    Color bgColor = const Color(0xFF1B2640).withOpacity(0.9);
    if (isRecording) bgColor = Colors.red.withOpacity(0.9);
    if (micState == _MicState.saved) bgColor = const Color(0xFF22C55E).withOpacity(0.9);
    if (isError) bgColor = Colors.red.shade800.withOpacity(0.9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording)
            const Padding(
              padding: EdgeInsets.only(right: 5),
              child: Icon(Icons.fiber_manual_record,
                  color: Colors.white, size: 8),
            ),
          Text(
            isRecording ? 'Recording $label' : label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isError) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
