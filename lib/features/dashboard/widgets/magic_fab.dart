import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/subscription_service.dart';
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

class _MagicFabState extends ConsumerState<MagicFab>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _pulseController;
  final _audioRecorder = AudioRecorder();
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();
    if (_isRecording) {
      await _stopRecording();
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
    _audioPath = p.join(
        dir.path, 'tx_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _audioPath!,
    );
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    HapticFeedback.lightImpact();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path != null && mounted) {
      _showProcessingSheet(File(path));
    }
  }

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

  void _showVoiceLimitDialog(SubscriptionState subscription) {
    final tc = AppThemeColors.of(context);
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
        content: Text(
          'You\'ve used all ${SubscriptionState.freeVoiceLogLimit} voice logs this month.\n\nUpgrade to Pro for unlimited voice logging, or wait until next month.',
          style: GoogleFonts.inter(
              color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
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

  void _showPermissionSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone permission required')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulse ring while recording
          if (_isRecording) _PulseRing(controller: _pulseController),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Manual entry pill (left)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isRecording ? 0 : 1,
                child: GestureDetector(
                  onTap: _isRecording ? null : _showManualEntry,
                  child: Builder(builder: (ctx) {
                    final tc = AppThemeColors.of(ctx);
                    return Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: tc.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: tc.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              color: tc.onSurfaceVariant, size: 16),
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
                    );
                  }),
                ),
              ),
              const SizedBox(width: 16),

              // Main voice/stop button
              Builder(builder: (ctx) {
                final tc = AppThemeColors.of(ctx);
                return GestureDetector(
                  onTap: _handleTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    width: _isRecording ? 80 : 68,
                    height: _isRecording ? 80 : 68,
                    decoration: BoxDecoration(
                      color: _isRecording ? tc.expense : tc.onSurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? tc.expense : tc.onSurface)
                              .withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isRecording
                          ? Icon(Icons.stop_rounded,
                              key: const ValueKey('stop'),
                              color: tc.surface,
                              size: 32)
                          : Icon(Icons.mic_rounded,
                              key: const ValueKey('mic'),
                              color: tc.surface,
                              size: 30),
                    ),
                  ),
                );
              }),
            ],
          ),

          // "Tap to stop" label while recording
          if (_isRecording) ...[
            const SizedBox(height: 12),
            Builder(builder: (ctx) {
              final tc = AppThemeColors.of(ctx);
              return Text(
                'Tap to stop',
                style: GoogleFonts.inter(
                  color: tc.expense,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ).animate(onPlay: (c) => c.repeat()).fadeIn().then().fadeOut();
            }),
          ],
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  const _PulseRing({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          width: 110 + controller.value * 30,
          height: 110 + controller.value * 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withOpacity(0.3 * (1 - controller.value)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
