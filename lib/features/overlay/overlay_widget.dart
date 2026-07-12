import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:agent_money/core/services/notification_service.dart';
import 'package:agent_money/core/services/overlay_capture_runner.dart';
import 'package:agent_money/core/services/overlay_service.dart';

/// The bubble itself — runs in a second Flutter engine (see `overlayMain`
/// in main.dart) that has no ProviderScope, so it can't use the app's
/// normal Riverpod services directly. It talks to the device through
/// [OverlayCaptureRunner] (a Riverpod-free copy of the capture pipeline)
/// and [NotificationService] (already Riverpod-free) instead.
///
/// Interaction model: a plain tap (no meaningful movement) starts a
/// capture; any drag beyond a small slop repositions the bubble and snaps
/// it to the nearest edge on release. We can't use the plugin's built-in
/// `enableDrag` because that consumes touch events at the native window
/// level before Flutter ever sees a tap.
class QuickLogOverlay extends StatefulWidget {
  const QuickLogOverlay({super.key});

  @override
  State<QuickLogOverlay> createState() => _QuickLogOverlayState();
}

class _QuickLogOverlayState extends State<QuickLogOverlay> {
  static const _idleSize = OverlayService.bubbleSize;
  static const _recordingWidth = 220;
  static const _recordingHeight = 72;
  static const _dragSlop = 8.0;

  final _runner = OverlayCaptureRunner();

  bool _capturing = false;
  bool _dragging = false;
  Offset _cumulativeDelta = Offset.zero;
  OverlayPosition? _dragOrigin;
  DateTime _lastMoveSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  Future<void> _onPointerDown(PointerDownEvent event) async {
    _cumulativeDelta = Offset.zero;
    _dragging = false;
    _dragOrigin = await FlutterOverlayWindow.getOverlayPosition();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragOrigin == null || _capturing) return;
    _cumulativeDelta += event.delta;
    if (_cumulativeDelta.distance <= _dragSlop) return;

    _dragging = true;
    final now = DateTime.now();
    if (now.difference(_lastMoveSentAt) < const Duration(milliseconds: 32)) return;
    _lastMoveSentAt = now;

    final origin = _dragOrigin!;
    FlutterOverlayWindow.moveOverlay(OverlayPosition(
      origin.x + _cumulativeDelta.dx,
      origin.y + _cumulativeDelta.dy,
    ));
  }

  Future<void> _onPointerUp(PointerEvent event) async {
    if (_dragging && _dragOrigin != null) {
      // Make sure the final (possibly throttled-away) position lands before
      // snapping, so the snap decision uses where the finger actually let go.
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(
        _dragOrigin!.x + _cumulativeDelta.dx,
        _dragOrigin!.y + _cumulativeDelta.dy,
      ));
      await _snapToNearestEdge();
    } else if (!_capturing) {
      unawaited(_startCapture());
    }
    _dragging = false;
    _dragOrigin = null;
  }

  Future<void> _snapToNearestEdge() async {
    final current = await FlutterOverlayWindow.getOverlayPosition();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenWidth = view.physicalSize.width / view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;

    final snapLeft = current.x + _idleSize / 2 < screenWidth / 2;
    final targetX = snapLeft ? 0.0 : screenWidth - _idleSize;
    final targetY = current.y.clamp(0.0, screenHeight - _idleSize);

    await FlutterOverlayWindow.moveOverlay(OverlayPosition(targetX, targetY));
  }

  Future<void> _startCapture() async {
    setState(() => _capturing = true);
    await FlutterOverlayWindow.resizeOverlay(_recordingWidth, _recordingHeight, false);
    try {
      if (!await _runner.hasMicPermission()) {
        await NotificationService.instance.showError(
          'Microphone permission needed — open Money Pi once to grant it, then try the bubble again.',
        );
        return;
      }
      await _runner.captureExpense();
    } finally {
      await FlutterOverlayWindow.resizeOverlay(_idleSize, _idleSize, false);
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: (_capturing ? _recordingWidth : _idleSize).toDouble(),
          height: (_capturing ? _recordingHeight : _idleSize).toDouble(),
          decoration: BoxDecoration(
            color: const Color(0xFF6C52DA),
            borderRadius: BorderRadius.circular(_capturing ? 24 : _idleSize / 2),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: _capturing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _PulsingDot(),
                    const SizedBox(width: 10),
                    const Text(
                      'Listening…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}
