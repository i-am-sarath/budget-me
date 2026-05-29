import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/core/services/ad_service.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/core/services/user_service.dart';
import 'package:agent_money/features/auth/widgets/email_prompt_sheet.dart';
import 'package:agent_money/features/paywall/paywall_screen.dart';
import 'package:agent_money/features/transactions/widgets/manual_entry_sheet.dart';
import 'package:agent_money/features/transactions/widgets/processing_sheet.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';

class MagicFab extends ConsumerStatefulWidget {
  const MagicFab({super.key});

  @override
  ConsumerState<MagicFab> createState() => _MagicFabState();
}

class _MagicFabState extends ConsumerState<MagicFab> {
  bool _isRecording = false;
  double _dragOffset = 0.0;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  final _audioRecorder = AudioRecorder();

  static const double _cancelThreshold = -80.0;
  bool get _isCancelling => _dragOffset < _cancelThreshold;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ── Gesture handlers ──────────────────────────────────────

  void _onTapDown(TapDownDetails _) => _initiateRecording();

  void _onTapUp(TapUpDetails _) {
    if (_isRecording) _stopRecording();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_isRecording) return;
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dx).clamp(-200.0, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (!_isRecording) return;
    if (_isCancelling) {
      _cancelRecording();
    } else {
      _stopRecording();
    }
  }

  // ── Recording logic ──────────────────────────────────────

  Future<void> _initiateRecording() async {
    if (ApiConfig.proxyBaseUrl.isEmpty || ApiConfig.proxyClientSecret.isEmpty) {
      _showVoiceUnavailableSnackbar();
      return;
    }
    // Email registration gate
    final user = ref.read(userProvider);
    if (!user.isRegistered) {
      final registered = await showEmailPrompt(context);
      if (!registered || !mounted) return;
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
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    HapticFeedback.lightImpact();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _dragOffset = 0;
    });
    if (path != null && mounted) {
      _showProcessingSheet(File(path));
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
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

  // ── Sheets ───────────────────────────────────────────────

  void _showProcessingSheet(File audioFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProcessingSheet(audioFile: audioFile),
    );
  }

  void _showManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualEntrySheet(),
    );
  }

  // ── Dialogs / snackbars ──────────────────────────────────

  void _showVoiceUnavailableSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice logging unavailable. Try manual entry.'),
      ),
    );
  }

  void _showPermissionSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone permission required')),
    );
  }

  void _showVoiceLimitDialog(SubscriptionState subscription) {
    final tc = AppThemeColors.of(context);
    final isMobile = Platform.isAndroid || Platform.isIOS;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Monthly limit reached',
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve used all ${SubscriptionState.freeVoiceLogLimit} voice logs this month.\n\nUpgrade to Pro for unlimited voice logging and an ad-free experience.',
              style: GoogleFonts.hankenGrotesk(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ad not ready yet, try again in a moment')),
      );
      return;
    }
    final shown = await ref.read(adProvider.notifier).show(
      onRewarded: () {
        ref.read(subscriptionProvider.notifier).addBonusVoiceLogs(5);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You earned 5 bonus voice logs!')),
          );
        }
      },
    );
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ad not ready yet, try again in a moment')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final cancelProgress =
        (_dragOffset / _cancelThreshold).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left: Manual pill (idle) ↔ recording info (recording)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isRecording
                  ? _RecordingInfoPill(
                      key: const ValueKey('rec'),
                      seconds: _recordingSeconds,
                      isCancelling: _isCancelling,
                      cancelProgress: cancelProgress,
                      tc: tc,
                    )
                  : _ManualEntryPill(
                      key: const ValueKey('manual'),
                      tc: tc,
                      onTap: _showManualEntry,
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Right: Mic button — hold to record, slide left to cancel
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: () {},
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: _isRecording ? 80 : 68,
              height: _isRecording ? 80 : 68,
              decoration: BoxDecoration(
                color: _isRecording
                    ? (_isCancelling ? Colors.grey.shade600 : Colors.red)
                    : tc.onSurface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : tc.onSurface)
                        .withOpacity(_isRecording ? 0.45 : 0.2),
                    blurRadius: _isRecording ? 24 : 12,
                    spreadRadius: _isRecording ? 4 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: _isRecording ? 32 : 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Manual entry pill (shown when not recording)
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

// ─────────────────────────────────────────────────────────────
// Recording info pill (shown while holding the mic button)
// ─────────────────────────────────────────────────────────────

class _RecordingInfoPill extends StatelessWidget {
  final int seconds;
  final bool isCancelling;
  final double cancelProgress; // 0.0 → 1.0 as user slides left
  final AppThemeColors tc;

  const _RecordingInfoPill({
    super.key,
    required this.seconds,
    required this.isCancelling,
    required this.cancelProgress,
    required this.tc,
  });

  String get _time {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isCancelling
            ? Colors.red.withOpacity(0.12)
            : tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isCancelling
              ? Colors.red.withOpacity(0.5)
              : tc.outlineVariant,
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
                Icon(
                  Icons.chevron_left_rounded,
                  color: tc.onSurfaceVariant
                      .withOpacity(0.35 + cancelProgress * 0.65),
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  'Slide to cancel',
                  style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant
                        .withOpacity(0.35 + cancelProgress * 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _time,
                  style: GoogleFonts.inter(
                    color: tc.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
      ),
    );
  }
}
