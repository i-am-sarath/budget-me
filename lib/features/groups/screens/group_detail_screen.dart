import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/groups/models/group_models.dart';
import 'package:agent_money/features/groups/providers/groups_providers.dart';
import 'package:agent_money/features/groups/widgets/group_sheets.dart';

String _money(String code, double v) => '$code ${v.toStringAsFixed(2)}';

class GroupDetailScreen extends ConsumerWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final detail = ref.watch(groupDetailProvider(group));

    return Scaffold(
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: tc.surface,
        elevation: 0,
        title: Row(
          children: [
            Text(group.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(group.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.sans(
                      color: tc.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share invite',
            onPressed: () => Share.share(
                'Join my "${group.name}" group on Budget Me. Invite code: ${group.inviteCode}'),
            icon: Icon(Icons.ios_share_rounded,
                color: tc.onSurface, size: 20),
          ),
          PopupMenuButton<String>(
            color: tc.surfaceContainerHigh,
            onSelected: (v) async {
              if (v == 'leave') {
                await ref.read(groupsRepositoryProvider).leaveGroup(group.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'leave',
                child: Text('Leave group',
                    style: AppFonts.sans(color: tc.expense)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: detail.maybeWhen(
        data: (d) => FloatingActionButton.extended(
          backgroundColor: tc.onSurface,
          foregroundColor: tc.surface,
          onPressed: () async {
            final added = await showAddGroupExpenseSheet(context,
                group: group, members: d.members);
            if (added == true) ref.invalidate(groupDetailProvider(group));
          },
          icon: const Icon(Icons.add_rounded),
          label: Text('Add expense',
              style: AppFonts.sans(fontWeight: FontWeight.w700)),
        ),
        orElse: () => null,
      ),
      body: detail.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load group.\n$e',
                textAlign: TextAlign.center,
                style: AppFonts.sans(color: tc.onSurfaceVariant)),
          ),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupDetailProvider(group)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _TotalCard(group: group, data: d, tc: tc),
              const SizedBox(height: 16),
              _CategoryBreakdown(group: group, data: d, tc: tc),
              if (group.settleUp) ...[
                const SizedBox(height: 16),
                _SettleUpSection(group: group, data: d, tc: tc),
              ],
              const SizedBox(height: 16),
              _MembersRow(data: d, tc: tc),
              const SizedBox(height: 16),
              _RecentExpenses(group: group, data: d, tc: tc),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final GroupModel group;
  final GroupDetailData data;
  final AppThemeColors tc;
  const _TotalCard(
      {required this.group, required this.data, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: tc.onSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL SHARED SPENDING',
              style: AppFonts.sans(
                  color: tc.surface.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(_money(group.currencyCode, data.total),
              style: AppFonts.sans(
                  color: tc.surface,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1)),
          const SizedBox(height: 6),
          Text(
            '${data.expenses.length} expense${data.expenses.length == 1 ? '' : 's'} · ${data.members.length} member${data.members.length == 1 ? '' : 's'}',
            style: AppFonts.sans(
                color: tc.surface.withOpacity(0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final GroupModel group;
  final GroupDetailData data;
  final AppThemeColors tc;
  const _CategoryBreakdown(
      {required this.group, required this.data, required this.tc});

  @override
  Widget build(BuildContext context) {
    final totals = data.categoryTotals;
    if (totals.isEmpty) {
      return _Section(
        title: 'BY CATEGORY',
        tc: tc,
        child: Text('No spending logged yet.',
            style: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 13)),
      );
    }
    final max = totals.first.value;
    return _Section(
      title: 'BY CATEGORY',
      tc: tc,
      child: Column(
        children: totals.map((e) {
          final pct = data.total > 0 ? e.value / data.total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key,
                        style: AppFonts.sans(
                            color: tc.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(
                        '${_money(group.currencyCode, e.value)}  ·  ${(pct * 100).round()}%',
                        style: AppFonts.sans(
                            color: tc.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: max > 0 ? e.value / max : 0,
                    minHeight: 5,
                    backgroundColor: tc.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(group.color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SettleUpSection extends StatelessWidget {
  final GroupModel group;
  final GroupDetailData data;
  final AppThemeColors tc;
  const _SettleUpSection(
      {required this.group, required this.data, required this.tc});

  @override
  Widget build(BuildContext context) {
    final settlements = computeSettlements(data.balances);
    return _Section(
      title: 'SETTLE UP',
      tc: tc,
      child: Column(
        children: [
          // Per-member net
          ...data.balances.map((b) {
            final positive = b.net >= 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(b.displayName,
                      style: AppFonts.sans(
                          color: tc.onSurface, fontSize: 13)),
                  Text(
                    positive
                        ? 'gets back ${_money(group.currencyCode, b.net.abs())}'
                        : 'owes ${_money(group.currencyCode, b.net.abs())}',
                    style: AppFonts.sans(
                        color: b.net.abs() < 0.01
                            ? tc.onSurfaceVariant
                            : (positive ? tc.income : tc.expense),
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
          if (settlements.isNotEmpty) ...[
            Divider(height: 20, color: tc.outlineVariant),
            ...settlements.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: tc.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${s.fromName} pays ${s.toName}',
                          style: AppFonts.sans(
                              color: tc.onSurface, fontSize: 13),
                        ),
                      ),
                      Text(_money(group.currencyCode, s.amount),
                          style: AppFonts.sans(
                              color: tc.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
          ] else ...[
            const SizedBox(height: 4),
            Text('Everyone is settled up 🎉',
                style:
                    AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _MembersRow extends StatelessWidget {
  final GroupDetailData data;
  final AppThemeColors tc;
  const _MembersRow({required this.data, required this.tc});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'MEMBERS · ${data.members.length}',
      tc: tc,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: data.members.map((m) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(m.isOwner ? Icons.star_rounded : Icons.person_rounded,
                    size: 14, color: tc.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(m.displayName,
                    style: AppFonts.sans(
                        color: tc.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentExpenses extends ConsumerWidget {
  final GroupModel group;
  final GroupDetailData data;
  final AppThemeColors tc;
  const _RecentExpenses(
      {required this.group, required this.data, required this.tc});

  String _payerName(String id) {
    final m = data.members.where((m) => m.userId == id).firstOrNull;
    return m?.displayName ?? 'Someone';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.expenses.isEmpty) {
      return _Section(
        title: 'ACTIVITY',
        tc: tc,
        child: Text('No expenses yet. Tap “Add expense”.',
            style: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 13)),
      );
    }
    return _Section(
      title: 'ACTIVITY',
      tc: tc,
      child: Column(
        children: data.expenses.take(20).map((e) {
          return Dismissible(
            key: ValueKey(e.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.delete_outline_rounded, color: tc.expense),
            ),
            onDismissed: (_) async {
              await ref.read(groupsRepositoryProvider).deleteExpense(e.id);
              ref.invalidate(groupDetailProvider(group));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.note.isNotEmpty ? e.note : e.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sans(
                                color: tc.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            '${e.category} · ${_payerName(e.payerId)} · ${DateFormat('d MMM').format(e.spentAt)}',
                            style: AppFonts.sans(
                                color: tc.onSurfaceVariant, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_money(group.currencyCode, e.amount),
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final AppThemeColors tc;
  const _Section(
      {required this.title, required this.child, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppFonts.sans(
                  color: tc.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
