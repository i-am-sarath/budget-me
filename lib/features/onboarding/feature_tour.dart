import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/services/tour_service.dart';

/// A lightweight, fully-skippable first-run feature tour.
///
/// Implemented as a custom dimmed overlay with a swipeable card stack rather
/// than a third-party coachmark package. Rationale:
///  • The app is built from custom-themed widgets (custom nav, custom FAB with
///    raw pointer gestures) — an anchored-spotlight package would fight the
///    MagicFab's `Listener` and only works on the Home tab anyway.
///  • Zero new dependencies to vet for a finance app.
///  • Full control over colour/contrast in both themes via [AppThemeColors].
///
/// Show it with [showFeatureTour]; it persists "seen" via [tourSeenProvider]
/// when finished or skipped, and can be re-armed from Settings.
class FeatureTour extends ConsumerStatefulWidget {
  const FeatureTour({super.key});

  @override
  ConsumerState<FeatureTour> createState() => _FeatureTourState();
}

class _TourStep {
  final IconData icon;
  final String title;
  final String body;
  final String hint; // short reinforcing line, e.g. the gesture
  const _TourStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.hint,
  });
}

const _steps = <_TourStep>[
  _TourStep(
    icon: Icons.mic_rounded,
    title: 'Log by voice',
    body:
        'Press and HOLD the mic button, say what you spent — like “280 on '
        'groceries” — then let go. We transcribe and save it for you.',
    hint: 'Hold to record · release to save · slide left to cancel',
  ),
  _TourStep(
    icon: Icons.edit_rounded,
    title: 'Or add it by hand',
    body:
        'Prefer typing? Tap the Manual button next to the mic to enter a '
        'transaction the classic way. No account needed.',
    hint: 'Tap “Manual” anytime',
  ),
  _TourStep(
    icon: Icons.donut_large_rounded,
    title: 'Stay on budget',
    body:
        'Set a monthly limit and per-category budgets. We’ll show how much '
        'you have left so there are no end-of-month surprises.',
    hint: 'Find it on the Budget tab',
  ),
  _TourStep(
    icon: Icons.groups_rounded,
    title: 'Split with your people',
    body:
        'Create a Group for roommates or trips, share an invite code, and '
        'track shared spending together — with optional settle-up.',
    hint: 'Open Groups from the top-right of Home',
  ),
  _TourStep(
    icon: Icons.bar_chart_rounded,
    title: 'See the bigger picture',
    body:
        'The Stats tab turns your logs into clear trends and category '
        'breakdowns, so you can spot where the money really goes.',
    hint: 'Tap the Stats tab to explore',
  ),
];

class _FeatureTourState extends ConsumerState<FeatureTour> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _steps.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await ref.read(tourSeenProvider.notifier).markSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    HapticFeedback.lightImpact();
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A deep scrim that reads on either theme. Darker in dark mode for focus.
    final scrim = Colors.black.withOpacity(isDark ? 0.78 : 0.55);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Tap-out scrim also dismisses (treated as skip).
          Positioned.fill(
            child: GestureDetector(
              onTap: _finish,
              child: Container(color: scrim),
            ),
          ),

          // Skip — always reachable, top-right.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: SafeArea(
              child: TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(
                  'Skip',
                  style: AppFonts.sans(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Card stack, vertically centred.
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 360,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _steps.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _TourCard(step: _steps[i], tc: tc),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Dots(count: _steps.length, index: _index, tc: tc),
                    const SizedBox(height: 24),
                    _PrimaryCta(
                      label: _isLast ? 'Start tracking' : 'Next',
                      onTap: _next,
                      tc: tc,
                      // Accent the final, most action-forward CTA.
                      accent: _isLast,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final _TourStep step;
  final AppThemeColors tc;
  const _TourCard({required this.step, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branded icon badge.
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tc.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(step.icon, color: tc.accent, size: 32),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            step.title,
            style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            step.body,
            style: AppFonts.sans(
              color: tc.onSurfaceVariant,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          // Reinforcing hint pill (the gesture / where to find it).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tc.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: tc.accent.withOpacity(0.25), width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    color: tc.accent, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.hint,
                    style: AppFonts.sans(
                      color: tc.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final AppThemeColors tc;
  const _Dots({required this.count, required this.index, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? tc.accent : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final AppThemeColors tc;
  final bool accent;
  const _PrimaryCta(
      {required this.label,
      required this.onTap,
      required this.tc,
      this.accent = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent ? tc.accent : tc.primary,
          foregroundColor: accent ? Colors.white : tc.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.sans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Show the feature tour as a full-screen dialog over the current screen.
Future<void> showFeatureTour(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent, // the tour paints its own scrim
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const FeatureTour(),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}
