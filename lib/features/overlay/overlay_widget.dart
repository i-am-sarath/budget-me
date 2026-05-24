import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Quick-log overlay bubble.
///
/// Runs in a SEPARATE Flutter engine — has no access to providers,
/// repositories, or theme. The overlay captures audio locally and hands the
/// file path to the main app over IPC; the main app does the transcribe /
/// parse / save pipeline. If the main app isn't running, the recording is
/// silently dropped (Option 1 limitation).
class QuickLogOverlay extends StatefulWidget {
  const QuickLogOverlay({super.key});

  @override
  State<QuickLogOverlay> createState() => _QuickLogOverlayState();
}

class _QuickLogOverlayState extends State<QuickLogOverlay>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isCancelling = false;
  int _recordingMs = 0;

  Timer? _tickTimer;
  StreamSubscription<Amplitude>? _ampSub;
  double _amp = 0; // normalized 0..1

  late final AnimationController _waveCtrl;

  // Overlay window dimensions (logical px). Set on enable() in OverlayService.
  // We resize when entering/leaving the recording state so the wider pill fits.
  static const _idleW = 64;
  static const _idleH = 64;
  static const _recW = 220;
  static const _recH = 72;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _ampSub?.cancel();
    _waveCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Recording ─────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      // Mic permission isn't granted. We can't prompt from the overlay isolate
      // (no Activity), so signal the main app to handle it next time it's
      // foregrounded, and flash the bubble red briefly.
      await _flashError();
      try {
        await FlutterOverlayWindow.shareData({'type': 'mic_permission_needed'});
      } catch (_) {}
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'overlay_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    } catch (_) {
      await _flashError();
      return;
    }

    _resize(_recW, _recH);

    setState(() {
      _isRecording = true;
      _isCancelling = false;
      _recordingMs = 0;
      _amp = 0;
    });

    _tickTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (mounted) setState(() => _recordingMs += 60);
    });

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
      // record's `current` is in dB, typically -60 (silence) to 0 (clipping).
      // Normalize so quiet speech still shows visible motion.
      final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      if (mounted) setState(() => _amp = norm);
    });
  }

  Future<void> _stopRecording({required bool cancel}) async {
    if (!_isRecording) return;

    _tickTimer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {/* swallow */}

    final wasTooShort = _recordingMs < 350;
    setState(() {
      _isRecording = false;
      _isCancelling = false;
    });
    _resize(_idleW, _idleH);

    if (path != null && (cancel || wasTooShort)) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      return;
    }

    if (path != null) {
      try {
        await FlutterOverlayWindow.shareData({
          'type': 'voice_log',
          'path': path,
        });
      } catch (_) {
        // If IPC fails, drop the file rather than leaving it orphaned.
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    }
  }

  Future<void> _flashError() async {
    setState(() => _isCancelling = true);
    await Future.delayed(const Duration(milliseconds: 280));
    if (mounted) setState(() => _isCancelling = false);
  }

  Future<void> _resize(int w, int h) async {
    try {
      await FlutterOverlayWindow.resizeOverlay(w, h, true);
    } catch (_) {/* older OS / package may not support resize */}
  }

  // ── Gestures ──────────────────────────────────────────────
  // Use raw pointer events so press starts the moment the finger touches the
  // bubble (a LongPressGestureRecognizer would add a ~500ms delay).
  // Vertical drag-up while holding cancels the recording.

  double _dragY = 0;
  static const _cancelThresholdY = -60.0;

  void _onPointerDown(PointerDownEvent _) {
    _dragY = 0;
    _startRecording();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_isRecording) return;
    _dragY += e.delta.dy;
    final cancelling = _dragY < _cancelThresholdY;
    if (cancelling != _isCancelling) {
      setState(() => _isCancelling = cancelling);
    }
  }

  void _onPointerUp(PointerUpEvent _) {
    _stopRecording(cancel: _isCancelling);
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _stopRecording(cancel: true);
  }

  // ── UI ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: _isRecording ? 200 : 56,
              height: _isRecording ? 56 : 56,
              padding: EdgeInsets.symmetric(
                horizontal: _isRecording ? 12 : 0,
              ),
              decoration: BoxDecoration(
                color: _isRecording
                    ? (_isCancelling
                        ? const Color(0xFF6B6B6B)
                        : const Color(0xFFB42222))
                    : const Color(0xFF2D6A2D),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: _isRecording
                  ? _RecordingContent(
                      ctrl: _waveCtrl,
                      amp: _amp,
                      ms: _recordingMs,
                      cancelling: _isCancelling,
                    )
                  : const Center(
                      child: Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Inline content shown when recording: waveform pills + timer
// ─────────────────────────────────────────────────────────────

class _RecordingContent extends StatelessWidget {
  final AnimationController ctrl;
  final double amp;
  final int ms;
  final bool cancelling;

  const _RecordingContent({
    required this.ctrl,
    required this.amp,
    required this.ms,
    required this.cancelling,
  });

  String get _time {
    final s = (ms ~/ 1000);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (cancelling) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.close_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'Release to cancel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _WavePills(ctrl: ctrl, amp: amp),
        Text(
          _time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _WavePills extends StatelessWidget {
  final AnimationController ctrl;
  final double amp; // 0..1
  const _WavePills({required this.ctrl, required this.amp});

  static const _barCount = 5;
  static const _maxHeight = 28.0;
  static const _minHeight = 6.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value * math.pi * 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            final phase = i * 0.9;
            final wave = (math.sin(t + phase) + 1) / 2; // 0..1
            // Combine amplitude (real mic input) with a sine baseline so the
            // bars never look frozen even when silent.
            final level = (amp * 0.7) + (wave * 0.3 * (0.4 + amp));
            final h = _minHeight + (_maxHeight - _minHeight) * level;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 4,
                height: h,
                decoration: BoxDecoration(
                  color: Colors.white,
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
