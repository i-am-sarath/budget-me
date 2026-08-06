import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/services/currency_service.dart';
import 'package:money_pi/core/services/cloud_service.dart';
import 'package:money_pi/features/groups/models/group_models.dart';
import 'package:money_pi/features/groups/providers/groups_providers.dart';

const _emojis = ['👥', '🏠', '🍽️', '✈️', '🎉', '🏢', '🛒', '🏖️'];

Future<bool?> showCreateGroupSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupSheet(),
    );

Future<bool?> showJoinGroupSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _JoinGroupSheet(),
    );

Future<bool?> showAddGroupExpenseSheet(
  BuildContext context, {
  required GroupModel group,
  required List<GroupMemberModel> members,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(group: group, members: members),
    );

// ── Shell ───────────────────────────────────────────────────────────────────
class _SheetShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetShell({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: tc.outlineVariant,
                      borderRadius: BorderRadius.circular(100))),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(AppThemeColors tc, String hint) =>
    InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 14),
      filled: true,
      fillColor: tc.surfaceContainerLow,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tc.outlineVariant, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tc.outlineVariant, width: 0.5),
      ),
    );

Widget _primaryButton(
    AppThemeColors tc, String label, bool busy, VoidCallback? onTap) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: busy ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: tc.onSurface,
        foregroundColor: tc.surface,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Text(label, style: AppFonts.sans(fontWeight: FontWeight.w700)),
    ),
  );
}

// ── Create group ────────────────────────────────────────────────────────────
class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();
  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _name = TextEditingController();
  String _emoji = '👥';
  bool _settleUp = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give your group a name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final currency = ref.read(currencyProvider).currency.code;
      await ref.read(groupsRepositoryProvider).createGroup(
            name: _name.text.trim(),
            emoji: _emoji,
            colorValue: 0xFF6C52DA,
            currencyCode: currency,
            settleUp: _settleUp,
          );
      if (mounted) Navigator.pop(context, true);
    } on CloudException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not create the group.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return _SheetShell(
      title: 'New group',
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          style: AppFonts.sans(color: tc.onSurface, fontSize: 15),
          decoration: _fieldDecoration(tc, 'Group name (e.g. Flat 2B)'),
        ),
        const SizedBox(height: 16),
        Text('Icon',
            style: AppFonts.sans(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _emojis.map((e) {
            final sel = e == _emoji;
            return GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? tc.onSurface : tc.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tc.outlineVariant, width: 0.5),
                ),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _SettleToggle(
          value: _settleUp,
          onChanged: (v) => setState(() => _settleUp = v),
          tc: tc,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: AppFonts.sans(color: tc.expense, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        _primaryButton(tc, 'Create group', _busy, _create),
      ],
    );
  }
}

class _SettleToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppThemeColors tc;
  const _SettleToggle(
      {required this.value, required this.onChanged, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Track who owes whom',
                    style: AppFonts.sans(
                        color: tc.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('Splits each expense equally + Settle up',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Join group ──────────────────────────────────────────────────────────────
class _JoinGroupSheet extends ConsumerStatefulWidget {
  const _JoinGroupSheet();
  @override
  ConsumerState<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<_JoinGroupSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-character code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(groupsRepositoryProvider).joinByCode(code);
      if (mounted) Navigator.pop(context, true);
    } on CloudException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not join. Check the code and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return _SheetShell(
      title: 'Join a group',
      children: [
        Text('Enter the invite code your friend shared.',
            style: AppFonts.sans(
                color: tc.onSurfaceVariant, fontSize: 13, height: 1.5)),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 6),
          decoration: _fieldDecoration(tc, 'ABC123').copyWith(counterText: ''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: AppFonts.sans(color: tc.expense, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        _primaryButton(tc, 'Join group', _busy, _join),
      ],
    );
  }
}

// ── Add expense ─────────────────────────────────────────────────────────────
class _AddExpenseSheet extends ConsumerStatefulWidget {
  final GroupModel group;
  final List<GroupMemberModel> members;
  const _AddExpenseSheet({required this.group, required this.members});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Groceries';
  late String _payerId;
  bool _busy = false;
  String? _error;

  static const _categories = [
    'Groceries', 'Fruits', 'Transport', 'Dining', 'Rent',
    'Utilities', 'Entertainment', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _payerId = CloudService.currentUser?.id ??
        (widget.members.isNotEmpty ? widget.members.first.userId : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(groupsRepositoryProvider).addExpense(
            groupId: widget.group.id,
            payerId: _payerId,
            amount: amount,
            category: _category,
            note: _note.text.trim(),
            spentAt: DateTime.now(),
            settleUp: widget.group.settleUp,
            memberIds: widget.members.map((m) => m.userId).toList(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Could not save the expense.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return _SheetShell(
      title: 'Add shared expense',
      children: [
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: AppFonts.sans(
              color: tc.onSurface, fontSize: 24, fontWeight: FontWeight.w800),
          decoration: _fieldDecoration(tc, '0.00')
              .copyWith(prefixText: '${widget.group.currencyCode}  '),
        ),
        const SizedBox(height: 14),
        Text('Category',
            style: AppFonts.sans(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final sel = c == _category;
            return GestureDetector(
              onTap: () => setState(() => _category = c),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? tc.onSurface : tc.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: tc.outlineVariant, width: 0.5),
                ),
                child: Text(c,
                    style: AppFonts.sans(
                        color: sel ? tc.surface : tc.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          style: AppFonts.sans(color: tc.onSurface, fontSize: 14),
          decoration: _fieldDecoration(tc, 'Note (optional)'),
        ),
        const SizedBox(height: 14),
        // Payer selector
        Text('Paid by',
            style: AppFonts.sans(
                color: tc.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _payerId.isEmpty ? null : _payerId,
              isExpanded: true,
              dropdownColor: tc.surfaceContainerHigh,
              style: AppFonts.sans(color: tc.onSurface, fontSize: 14),
              items: widget.members
                  .map((m) => DropdownMenuItem(
                        value: m.userId,
                        child: Text(m.displayName),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _payerId = v ?? _payerId),
            ),
          ),
        ),
        if (widget.group.settleUp && widget.members.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Split equally across ${widget.members.length} member${widget.members.length == 1 ? '' : 's'}.',
            style: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 11),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: AppFonts.sans(color: tc.expense, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        _primaryButton(tc, 'Add expense', _busy, _save),
      ],
    );
  }
}
