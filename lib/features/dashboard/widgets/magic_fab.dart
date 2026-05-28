import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/services/ad_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/providers/voice_processing_provider.dart';
import 'package:agent_money/core/providers/quick_log_provider.dart';
import 'package:agent_money/features/paywall/paywall_screen.dart';
import 'package:agent_money/features/transactions/widgets/manual_entry_sheet.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';

class MagicFab extends ConsumerStatefulWidget {
  const MagicFab({super.key});

  @override
  ConsumerState<MagicFab> createState() => _MagicFabState();
}

class _MagicFabState extends ConsumerState<MagicFab>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  double _dragOffset = 0.0;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  final _audioRecorder = AudioRecorder();

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  static const double _cancelThreshold = -80.0;
  bool get _isCancelling => _dragOffset < _cancelThreshold;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseCtrl.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ── Gesture handlers ─────────────────────────────────────

  void _onTapDown(TapDownDetails _) => _initiateRecording();
  void _onTapUp(TapUpDetails _) { if (_isRecording) _stopRecording(); }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_isRecording) return;
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dx).clamp(-200.0, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (!_isRecording) return;
    if (_isCancelling) _cancelRecording(); else _stopRecording();
  }

  // ── Recording logic ──────────────────────────────────────

  Future<void> _initiateRecording() async {
    if (ApiConfig.proxyBaseUrl.isEmpty || ApiConfig.proxyClientSecret.isEmpty) {
      _showVoiceUnavailableSnackbar();
      return;
    }
    final subscription = ref.read(subscriptionProvider);
    if (!subscription.canUseVoice) {
      _showVoiceLimitDialog(subscription);
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      _showPermissionSnackbar();
      return;
    }
    HapticFeedback.heavyImpact();
    final dir = await getTemporaryDirectory();
    final audioPath = p.join(
      dir.path,
      'tx_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: audioPath,
    );
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _dragOffset = 0;
    });
    _pulseCtrl.repeat(reverse: true);
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    HapticFeedback.lightImpact();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _dragOffset = 0;
    });
    if (path != null && mounted) {
      ref.read(voiceProcessingProvider.notifier).startProcessing(File(path));
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    HapticFeedback.mediumImpact();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _dragOffset = 0;
    });
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  // ── Sheets & dialogs ─────────────────────────────────────

  void _showManualEntry() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ManualEntrySheet(),
      );

  void _showVoiceUnavailableSnackbar() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(
          content: Text('Voice logging unavailable. Try manual entry.')));

  void _showPermissionSnackbar() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(
          content: Text('Microphone permission required')));

  void _showVoiceLimitDialog(SubscriptionState subscription) {
    final tc = AppThemeColors.of(context);
    final isMobile = Platform.isAndroid || Platform.isIOS;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Monthly limit reached',
            style: GoogleFonts.inter(
                color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve used all ${SubscriptionState.freeVoiceLogLimit} voice '
              'logs this month.\n\nUpgrade to Pro for unlimited voice logging, '
              'or watch an ad for +5 logs.',
              style: GoogleFonts.inter(
                  color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
            if (isMobile) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: Text('Watch ad for +5 logs',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _watchAdForBonusLogs();
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Maybe later',
                style: GoogleFonts.inter(color: tc.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              showPaywall(context);
            },
            child: Text('Upgrade to Pro',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAdForBonusLogs() async {
    final adState = ref.read(adProvider);
    if (!adState.isAdLoaded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ad not ready yet, try again in a moment')));
      return;
    }
    final shown = await ref.read(adProvider.notifier).show(
      onRewarded: () {
        ref.read(subscriptionProvider.notifier).addBonusVoiceLogs(5);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You earned 5 bonus voice logs!')));
        }
      },
    );
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ad not ready yet, try again in a moment')));
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final voiceState = ref.watch(voiceProcessingProvider);
    final cancelProgress = (_dragOffset / _cancelThreshold).clamp(0.0, 1.0);

    ref.listen(quickLogProvider, (_, __) {
      if (!_isRecording) _initiateRecording();
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left status pill — waveform while recording, status otherwise
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-0.25, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: _buildLeftPill(tc, voiceState, cancelProgress),
            ),
          ),
          const SizedBox(width: 16),

          // Mic button
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: () {},
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: ScaleTransition(
              scale: _isRecording
                  ? _pulseAnim
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: _isRecording ? 80 : 68,
                height: _isRecording ? 80 : 68,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? (_isCancelling
                          ? Colors.grey.shade600
                          : Colors.red)
                      : tc.onSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : tc.onSurface)
                          .withOpacity(_isRecording ? 0.4 : 0.2),
                      blurRadius: _isRecording ? 28 : 12,
                      spreadRadius: _isRecording ? 6 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording && _isCancelling
                      ? Icons.close_rounded
                      : Icons.mic_rounded,
                  color: Colors.white,
                  size: _isRecording ? 32 : 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPill(
      AppThemeColors tc, VoiceProcessingState vs, double cancelProgress) {
    if (_isRecording) {
      return _WaveformPill(
        key: const ValueKey('waveform'),
        seconds: _recordingSeconds,
        isCancelling: _isCancelling,
        cancelProgress: cancelProgress,
        tc: tc,
      );
    }
    if (vs.isProcessing) {
      return _StatusPill(
        key: const ValueKey('processing'),
        tc: tc,
        isLoading: true,
        label: vs.statusMessage.isNotEmpty ? vs.statusMessage : 'Processing…',
        color: tc.onSurface,
      );
    }
    if (vs.isSaved) {
      return _StatusPill(
        key: const ValueKey('saved'),
        tc: tc,
        icon: Icons.check_rounded,
        label: vs.statusMessage,
        color: const Color(0xFF22C55E),
      );
    }
    if (vs.isError) {
      return _StatusPill(
        key: const ValueKey('error'),
        tc: tc,
        icon: Icons.replay_rounded,
        label: 'Failed · retry',
        color: Colors.red,
        onTap: () => ref.read(voiceProcessingProvider.notifier).retry(),
      );
    }
    return _ManualEntryPill(
      key: const ValueKey('manual'),
      tc: tc,
      onTap: _showManualEntry,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Waveform pill — animated bars while holding the mic button
// ─────────────────────────────────────────────────────────────

class _WaveformPill extends StatefulWidget {
  final int seconds;
  final bool isCancelling;
  final double cancelProgress;
  final AppThemeColors tc;

  const _WaveformPill({
    super.key,
    required this.seconds,
    required this.isCancelling,
    required this.cancelProgress,
    required this.tc,
  });

  @override
  State<_WaveformPill> createState() => _WaveformPillState();
}

class _WaveformPillState extends State<_WaveformPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Each bar gets a different phase offset for a natural wave look
  static const _phases = [0.0, 0.28, 0.56, 0.84, 0.14, 0.42, 0.70];
  static const _minH = 4.0;
  static const _maxH = 24.0;

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

  String get _time {
    final m = (widget.seconds ~/ 60).toString();
    final s = (widget.seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isCancelling = widget.isCancelling;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isCancelling
            ? Colors.red.withOpacity(0.08)
            : widget.tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isCancelling
              ? Colors.red.withOpacity(0.4)
              : widget.tc.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isCancelling
            ? [
                const Icon(Icons.close_rounded, color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Release to cancel',
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [
                // Animated waveform bars
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(7, (i) {
                      final t = (_ctrl.value + _phases[i]) % 1.0;
                      final frac = (sin(t * 2 * pi) + 1) / 2;
                      final h = _minH + frac * (_maxH - _minH);
                      return Container(
                        width: 3,
                        height: h,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                // Recording timer
                Text(
                  _time,
                  style: GoogleFonts.inter(
                    color: widget.tc.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                // Slide-to-cancel hint fades in as user drags
                Text(
                  '← cancel',
                  style: GoogleFonts.inter(
                    color: widget.tc.onSurfaceVariant.withOpacity(
                        0.25 + widget.cancelProgress * 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status pill — processing / saved / error
// ─────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final AppThemeColors tc;
  final IconData? icon;
  final bool isLoading;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _StatusPill({
    super.key,
    required this.tc,
    this.icon,
    this.isLoading = false,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color),
              )
            else if (icon != null)
              Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Manual entry pill (idle state)
// ─────────────────────────────────────────────────────────────

class _ManualEntryPill extends StatelessWidget {
  final AppThemeColors tc;
  final VoidCallback onTap;

  const _ManualEntryPill({
    super.key,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: tc.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, color: tc.onSurfaceVariant, size: 16),
            const SizedBox(width: 6),
            Text(
              'Manual',
              style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
