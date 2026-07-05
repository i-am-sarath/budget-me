import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/features/groups/models/group_models.dart';
import 'package:money_pi/features/groups/providers/groups_providers.dart';
import 'package:money_pi/features/groups/screens/group_detail_screen.dart';
import 'package:money_pi/features/groups/widgets/group_sheets.dart';
import 'package:money_pi/features/trips/screens/trips_screen.dart';

/// Entry point for shared spending. Adapts to three states:
/// not-configured → signed-out → group list.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final enabled = ref.watch(cloudEnabledProvider);
    final auth = ref.watch(cloudAuthProvider);

    return Scaffold(
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: tc.surface,
        elevation: 0,
        title: Text('Groups',
            style: AppFonts.sans(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        actions: [
          if (enabled && auth.isSignedIn)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => ref.read(cloudAuthProvider.notifier).signOut(),
              icon: Icon(Icons.logout_rounded, color: tc.onSurfaceVariant, size: 20),
            ),
        ],
      ),
      body: Column(
        children: [
          // Personal travel tracking lives next to shared groups so users can
          // pick the right tool: a Group (shared, online) or a Trip (your own
          // travel spending, works offline).
          _TripBanner(tc: tc),
          Expanded(
            child: !enabled
                ? const _NotConfigured()
                : !auth.isSignedIn
                    ? _SignedOut(auth: auth)
                    : const _GroupList(),
          ),
        ],
      ),
    );
  }
}

// ── Banner: jump to personal Trips (travel tracking) ────────────────────────
class _TripBanner extends StatelessWidget {
  final AppThemeColors tc;
  const _TripBanner({required this.tc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TripsScreen())),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tc.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.card_travel_rounded,
                    color: tc.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track a trip',
                        style: AppFonts.sans(
                            color: tc.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text('Budget a trip and track your travel spending',
                        style: AppFonts.sans(
                            color: tc.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: tc.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── State: cloud not configured in this build ───────────────────────────────
class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return _CenteredMessage(
      icon: Icons.cloud_off_rounded,
      title: 'Cloud sync not set up',
      body:
          'Shared groups need a Supabase backend. Add SUPABASE_URL and SUPABASE_ANON_KEY '
          'to your build (see supabase/README.md), then groups will appear here.',
      tc: tc,
    );
  }
}

// ── State: signed out ───────────────────────────────────────────────────────
class _SignedOut extends ConsumerWidget {
  final CloudAuthState auth;
  const _SignedOut({required this.auth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.groups_rounded,
                  color: tc.onSurfaceVariant, size: 34),
            ),
            const SizedBox(height: 18),
            Text('Split spending with others',
                style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Create a group with roommates or friends, log spending together, '
              'and see category totals — with optional settle-up.',
              textAlign: TextAlign.center,
              style: AppFonts.sans(
                  color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    auth.busy ? null : () => ref.read(cloudAuthProvider.notifier).signIn(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tc.onSurface,
                  foregroundColor: tc.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: auth.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login_rounded, size: 18),
                label: Text('Continue with Google',
                    style: AppFonts.sans(fontWeight: FontWeight.w700)),
              ),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Text(auth.error!,
                  textAlign: TextAlign.center,
                  style: AppFonts.sans(color: tc.expense, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── State: signed in → list of groups ───────────────────────────────────────
class _GroupList extends ConsumerWidget {
  const _GroupList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final groupsAsync = ref.watch(myGroupsProvider);

    return Column(
      children: [
        // Create / Join actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_rounded,
                  label: 'New group',
                  filled: true,
                  tc: tc,
                  onTap: () async {
                    await showCreateGroupSheet(context);
                    ref.invalidate(myGroupsProvider);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.qr_code_rounded,
                  label: 'Join by code',
                  filled: false,
                  tc: tc,
                  onTap: () async {
                    await showJoinGroupSheet(context);
                    ref.invalidate(myGroupsProvider);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: groupsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => _CenteredMessage(
              icon: Icons.error_outline_rounded,
              title: 'Could not load groups',
              body: '$e',
              tc: tc,
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return _EmptyGroups(
                  tc: tc,
                  onCreate: () async {
                    await showCreateGroupSheet(context);
                    ref.invalidate(myGroupsProvider);
                  },
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(myGroupsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: groups.length,
                  itemBuilder: (_, i) =>
                      _GroupCard(group: groups[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends ConsumerStatefulWidget {
  final GroupModel group;
  const _GroupCard({required this.group});

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  bool _pressed = false;

  void _copyInvite() {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code ${widget.group.inviteCode} copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final tc = AppThemeColors.of(context);
    // Live detail (members + total) so the card feels alive, not static.
    final detail = ref.watch(groupDetailProvider(group));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)));
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Emoji avatar with a coloured accent ring drawn from the
                  // group's own colour — gives each group its own identity.
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: group.color.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: group.color.withOpacity(0.35), width: 1),
                    ),
                    child:
                        Text(group.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sans(
                                color: tc.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              group.settleUp
                                  ? Icons.swap_horiz_rounded
                                  : Icons.visibility_outlined,
                              size: 13,
                              color: tc.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              group.settleUp ? 'Settle-up' : 'Track only',
                              style: AppFonts.sans(
                                  color: tc.onSurfaceVariant, fontSize: 11),
                            ),
                            detail.maybeWhen(
                              data: (d) => Row(
                                children: [
                                  _dot(tc),
                                  Text(
                                    '${d.members.length} '
                                    '${d.members.length == 1 ? "member" : "members"}',
                                    style: AppFonts.sans(
                                        color: tc.onSurfaceVariant,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: tc.onSurfaceVariant, size: 20),
                ],
              ),
              const SizedBox(height: 14),
              // Footer: member avatar cluster + total + tappable invite code.
              Row(
                children: [
                  detail.maybeWhen(
                    data: (d) => _AvatarCluster(
                        members: d.members, color: group.color, tc: tc),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  detail.maybeWhen(
                    data: (d) => d.expenses.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              '${group.currencyCode} ${d.total.toStringAsFixed(0)}',
                              style: AppFonts.sans(
                                  color: tc.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  // Invite code — now a tappable copy chip.
                  GestureDetector(
                    onTap: _copyInvite,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: tc.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border:
                            Border.all(color: tc.outlineVariant, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(group.inviteCode,
                              style: AppFonts.sans(
                                  color: tc.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1)),
                          const SizedBox(width: 6),
                          Icon(Icons.copy_rounded,
                              color: tc.onSurfaceVariant, size: 13),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(AppThemeColors tc) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: tc.onSurfaceVariant.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
        ),
      );
}

/// Overlapping circular initials for the first few members.
class _AvatarCluster extends StatelessWidget {
  final List<GroupMemberModel> members;
  final Color color;
  final AppThemeColors tc;
  const _AvatarCluster(
      {required this.members, required this.color, required this.tc});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    const maxShown = 3;
    final shown = members.take(maxShown).toList();
    final extra = members.length - shown.length;

    final avatars = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      final initial = (shown[i].displayName.isNotEmpty
              ? shown[i].displayName.characters.first
              : '?')
          .toUpperCase();
      avatars.add(Padding(
        padding: EdgeInsets.only(left: i == 0 ? 0 : 16.0 * i),
        child: _avatarCircle(initial, color),
      ));
    }
    if (extra > 0) {
      avatars.add(Padding(
        padding: EdgeInsets.only(left: 16.0 * shown.length),
        child: _avatarCircle('+$extra', tc.onSurfaceVariant),
      ));
    }

    return SizedBox(
      height: 26,
      width: 26.0 + 16.0 * (avatars.length - 1),
      child: Stack(children: avatars),
    );
  }

  Widget _avatarCircle(String label, Color base) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color.alphaBlend(base.withOpacity(0.18), tc.surfaceContainer),
          shape: BoxShape.circle,
          border: Border.all(color: tc.surfaceContainerLow, width: 1.5),
        ),
        child: Text(
          label,
          style: AppFonts.sans(
              color: base, fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
}

/// Friendly, action-oriented empty state for the signed-in-but-no-groups case.
class _EmptyGroups extends StatelessWidget {
  final AppThemeColors tc;
  final VoidCallback onCreate;
  const _EmptyGroups({required this.tc, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child:
                  Icon(Icons.groups_2_rounded, color: tc.primary, size: 36),
            ),
            const SizedBox(height: 18),
            Text('Start your first group',
                textAlign: TextAlign.center,
                style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Track shared spending with roommates, partners or trip buddies. '
              'Create one and share the invite code.',
              textAlign: TextAlign.center,
              style: AppFonts.sans(
                  color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            // Three quick example ideas to spark intent.
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _IdeaChip('🏠 Flatmates'),
                _IdeaChip('✈️ Trip'),
                _IdeaChip('💑 Partner'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tc.primary,
                  foregroundColor: tc.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Create a group',
                    style: AppFonts.sans(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaChip extends StatelessWidget {
  final String label;
  const _IdeaChip(this.label);

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Text(label,
          style: AppFonts.sans(
              color: tc.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final AppThemeColors tc;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? tc.primary : tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: filled
              ? null
              : Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: filled ? tc.onPrimary : tc.onSurface),
            const SizedBox(width: 8),
            Text(label,
                style: AppFonts.sans(
                    color: filled ? tc.onPrimary : tc.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final AppThemeColors tc;
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: tc.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: AppFonts.sans(
                    color: tc.onSurfaceVariant, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
