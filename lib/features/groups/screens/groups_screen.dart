import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/groups/models/group_models.dart';
import 'package:agent_money/features/groups/providers/groups_providers.dart';
import 'package:agent_money/features/groups/screens/group_detail_screen.dart';
import 'package:agent_money/features/groups/widgets/group_sheets.dart';

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
      body: !enabled
          ? const _NotConfigured()
          : !auth.isSignedIn
              ? _SignedOut(auth: auth)
              : const _GroupList(),
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
                return _CenteredMessage(
                  icon: Icons.groups_2_rounded,
                  title: 'No groups yet',
                  body:
                      'Create a group and share its invite code with your roommates.',
                  tc: tc,
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

class _GroupCard extends StatelessWidget {
  final GroupModel group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: group.color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(group.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    group.settleUp
                        ? 'Shared · settle-up on'
                        : 'Shared · track only',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(group.inviteCode,
                  style: AppFonts.sans(
                      color: tc.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: tc.onSurfaceVariant, size: 18),
          ],
        ),
      ),
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
          color: filled ? tc.onSurface : tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: filled ? tc.surface : tc.onSurface),
            const SizedBox(width: 8),
            Text(label,
                style: AppFonts.sans(
                    color: filled ? tc.surface : tc.onSurface,
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
