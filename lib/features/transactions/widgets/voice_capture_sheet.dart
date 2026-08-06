import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:agent_money/main.dart' show rootNavigatorKey;
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/features/auth/widgets/account_sheet.dart';
import 'package:agent_money/features/paywall/paywall_screen.dart';
import 'package:agent_money/features/transactions/widgets/processing_sheet.dart';

/// Full-screen, tap-to-record voice capture.
///
/// Unlike [MagicFab] (which is hold-to-record), this auto-starts recording the
/// moment it opens and is stopped with a button tap. It's the entry point used
/// by the home-screen quick-add widget (`budgetme://voice`) so a single tap on
/// the launcher widget drops the user straight into recording.
///
/// Runs the same gates as the in-app FAB: proxy configured, email registered,
/// monthly voice quota, mic permission.
Future<void> showVoiceCapture(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const VoiceCaptureSheet(),
  );
}

class VoiceCaptureSheet extends ConsumerStatefulWidget {
  const VoiceCaptureSheet({super.key});

  @override
  ConsumerState<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends ConsumerState<VoiceCaptureSheet> {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _starting = true;
  int _recordingMs = 0;
  Timer? _tickTimer;
  StreamSubscription<Amplitude>? _ampSub;
  double _amp = 0; // normalized 0..1

  @override
  void initState() {
    super.initState();
    // Defer so we have a valid context for prompts/snackbars.
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Gating + start ────────────────────────────────────────

  Future<void> _begin() async {
    if (ApiConfig.proxyBaseUrl.isEmpty || ApiConfig.proxyClientSecret.isEmpty) {
      _bail('Voice logging unavailable. Try manual entry.');
      return;
    }

    final hasAccount = await requireAccount(
      context,
      ref,
      reason: 'Sign in to log transactions by voice.',
    );
    if (!hasAccount || !mounted) {
      _closeQuietly();
      return;
    }

    final subscription = ref.read(subscriptionProvider);
    if (!subscription.canUseVoice) {
      if (!mounted) return;
      _closeQuietly();
      await showPaywall(context);
      return;
    }

    if (!await _recorder.hasPermission()) {
      _bail('Microphone permission required');
      return;
    }

    await _startRecording();
  }

  Future<void> _startRecording() async {
    HapticFeedback.heavyImpact();
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'widget_tx_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    } catch (_) {
      _bail('Could not start recording');
      return;
    }
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _starting = false;
      _recordingMs = 0;
    });
    _tickTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (mounted) setState(() => _recordingMs += 60);
    });
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
      final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      if (mounted) setState(() => _amp = norm);
    });
  }

  // ── Stop / cancel ─────────────────────────────────────────

  Future<void> _finish() async {
    if (!_isRecording) return;
    _tickTimer?.cancel();
    await _ampSub?.cancel();
    HapticFeedback.lightImpact();

    final tooShort = _recordingMs < 350;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {/* swallow */}

    if (!mounted) return;
    Navigator.of(context).pop(); // close this sheet first

    if (path == null || tooShort) {
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      return;
    }

    // Hand off to the shared transcribe → parse → save pipeline. Use the global
    // root navigator (valid even though this sheet's context is now defunct).
    final navCtx = rootNavigatorKey.currentContext;
    if (navCtx != null) {
      // navCtx is the global root navigator, not this (now-popped) State's
      // context, so it's safe to use here.
      showModalBottomSheet(
        // ignore: use_build_context_synchronously
        context: navCtx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProcessingSheet(audioFile: File(path!)),
      );
    }
  }

  Future<void> _cancel() async {
    _tickTimer?.cancel();
    await _ampSub?.cancel();
    HapticFeedback.mediumImpact();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _bail(String message) {
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _closeQuietly() {
    if (mounted) Navigator.of(context).pop();
  }

  // ── UI ────────────────────────────────────────────────────

  String get _time {
    final s = _recordingMs ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tc.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _starting ? 'Getting ready…' : 'Listening…',
            style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _starting
                ? 'Speak your transaction in a moment'
                : 'e.g. "spent 300 on lunch, got salary 50000"',
            textAlign: TextAlign.center,
            style: AppFonts.sans(
              color: tc.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 64,
            child: _starting
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : _Waveform(amp: _amp, color: tc.onSurface),
          ),
          const SizedBox(height: 24),
          Text(
            _time,
            style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _starting ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: tc.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Cancel',
                      style: AppFonts.sans(
                          color: tc.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _starting ? null : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tc.onSurface,
                    foregroundColor: tc.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text('Done',
                      style: AppFonts.sans(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatefulWidget {
  final double amp;
  final Color color;
  const _Waveform({required this.amp, required this.color});

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const _barCount = 13;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * math.pi * 2;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            final phase = i * 0.6;
            final wave = (math.sin(t + phase) + 1) / 2;
            final level = (widget.amp * 0.7) + (wave * 0.3 * (0.4 + widget.amp));
            final h = 6.0 + 52.0 * level;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 4,
                height: h,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
