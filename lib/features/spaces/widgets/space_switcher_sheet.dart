import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/database/database_helper.dart';
import 'package:agent_money/core/services/subscription_service.dart';
import 'package:agent_money/features/spaces/models/space_model.dart';
import 'package:agent_money/features/spaces/repositories/space_repository.dart';
import 'package:agent_money/features/paywall/paywall_screen.dart';

void showSpaceSwitcher(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const SpaceSwitcherSheet(),
  );
}

class SpaceSwitcherSheet extends ConsumerStatefulWidget {
  const SpaceSwitcherSheet({super.key});

  @override
  ConsumerState<SpaceSwitcherSheet> createState() => _SpaceSwitcherSheetState();
}

class _SpaceSwitcherSheetState extends ConsumerState<SpaceSwitcherSheet> {
  bool _showCreateForm = false;
  final _nameCtrl = TextEditingController();
  String _selectedEmoji = '💼';
  int _selectedColorIdx = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchTo(SpaceModel space) async {
    await ref.read(activeSpaceIdProvider.notifier).switchTo(space.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _createSpace() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final space = SpaceModel(
      name: name,
      emoji: _selectedEmoji,
      colorValue: SpaceModel.palette[_selectedColorIdx].value,
    );
    await ref.read(spaceListProvider.notifier).add(space);
    await ref.read(activeSpaceIdProvider.notifier).switchTo(space.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteSpace(SpaceModel space) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${space.name}"?',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700)),
        content: const Text(
            'All transactions, accounts, and subscriptions in this space will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final db = await _getDb();
    await db.clearDataForSpace(space.id);
    await ref.read(spaceListProvider.notifier).delete(space.id);

    // If we just deleted the active space, fall back to personal
    final activeId = ref.read(activeSpaceIdProvider);
    if (activeId == space.id) {
      await ref
          .read(activeSpaceIdProvider.notifier)
          .switchTo(SpaceModel.personalId);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final spacesAsync = ref.watch(spaceListProvider);
    final activeId = ref.watch(activeSpaceIdProvider);
    final subscription = ref.watch(subscriptionProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tc.outlineVariant,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Row(
              children: [
                Text('Your Spaces',
                    style: GoogleFonts.hankenGrotesk(
                      color: tc.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    )),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: tc.onSurfaceVariant, size: 20),
                ),
              ],
            ),
          ),
          // Space list
          spacesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox(),
            data: (spaces) => Column(
              children: spaces
                  .asMap()
                  .entries
                  .map((e) => _SpaceTile(
                        space: e.value,
                        isActive: e.value.id == activeId,
                        tc: tc,
                        onTap: () => _switchTo(e.value),
                        onDelete: e.value.isPersonal
                            ? null
                            : () => _deleteSpace(e.value),
                      ).animate().fadeIn(
                            duration: 200.ms,
                            delay: (e.key * 40).ms,
                          ))
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          // Create form or button
          AnimatedSwitcher(
            duration: 250.ms,
            child: _showCreateForm
                ? _CreateSpaceForm(
                    key: const ValueKey('form'),
                    nameCtrl: _nameCtrl,
                    selectedEmoji: _selectedEmoji,
                    selectedColorIdx: _selectedColorIdx,
                    tc: tc,
                    onEmojiChanged: (e) =>
                        setState(() => _selectedEmoji = e),
                    onColorChanged: (i) =>
                        setState(() => _selectedColorIdx = i),
                    onCancel: () =>
                        setState(() => _showCreateForm = false),
                    onSave: _createSpace,
                  )
                : Padding(
                    key: const ValueKey('button'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: _AddSpaceButton(
                      isPro: subscription.isPro,
                      tc: tc,
                      onTap: () {
                        if (!subscription.isPro) {
                          Navigator.pop(context);
                          showPaywall(context);
                          return;
                        }
                        setState(() => _showCreateForm = true);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Space tile row
// ─────────────────────────────────────────────

class _SpaceTile extends StatelessWidget {
  final SpaceModel space;
  final bool isActive;
  final AppThemeColors tc;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SpaceTile({
    required this.space,
    required this.isActive,
    required this.tc,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Emoji avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(space.colorValue).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(space.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(space.name,
                      style: GoogleFonts.hankenGrotesk(
                        color: tc.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )),
                  if (isActive)
                    Text('Active',
                        style: GoogleFonts.hankenGrotesk(
                          color: tc.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        )),
                ],
              ),
            ),
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tc.primary,
                  shape: BoxShape.circle,
                ),
              ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded,
                    color: tc.onSurfaceVariant, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Add space button
// ─────────────────────────────────────────────

class _AddSpaceButton extends StatelessWidget {
  final bool isPro;
  final AppThemeColors tc;
  final VoidCallback onTap;

  const _AddSpaceButton(
      {required this.isPro, required this.tc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: tc.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: tc.primary.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPro ? Icons.add_rounded : Icons.lock_outline_rounded,
              color: tc.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isPro ? 'Create New Space' : 'Create New Space  •  Pro',
              style: GoogleFonts.hankenGrotesk(
                color: tc.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Create space form
// ─────────────────────────────────────────────

class _CreateSpaceForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String selectedEmoji;
  final int selectedColorIdx;
  final AppThemeColors tc;
  final ValueChanged<String> onEmojiChanged;
  final ValueChanged<int> onColorChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _CreateSpaceForm({
    super.key,
    required this.nameCtrl,
    required this.selectedEmoji,
    required this.selectedColorIdx,
    required this.tc,
    required this.onEmojiChanged,
    required this.onColorChanged,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New Space',
              style: GoogleFonts.hankenGrotesk(
                color: tc.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 12),
          // Emoji row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SpaceModel.presets.map((p) {
                final isSelected = p.emoji == selectedEmoji;
                return GestureDetector(
                  onTap: () {
                    onEmojiChanged(p.emoji);
                    // Auto-fill name if empty
                    if (nameCtrl.text.isEmpty) nameCtrl.text = p.label;
                  },
                  child: AnimatedContainer(
                    duration: 150.ms,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tc.primary.withOpacity(0.12)
                          : tc.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? tc.primary
                            : tc.outlineVariant,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(p.emoji,
                        style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Name field
          TextField(
            controller: nameCtrl,
            autofocus: true,
            inputFormatters: [LengthLimitingTextInputFormatter(24)],
            style: GoogleFonts.hankenGrotesk(
                color: tc.onSurface, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Space name',
              hintStyle: GoogleFonts.hankenGrotesk(color: tc.onSurfaceVariant),
              filled: true,
              fillColor: tc.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tc.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tc.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tc.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Color row
          Row(
            children: SpaceModel.palette.asMap().entries.map((e) {
              final isSelected = e.key == selectedColorIdx;
              return GestureDetector(
                onTap: () => onColorChanged(e.key),
                child: AnimatedContainer(
                  duration: 150.ms,
                  margin: const EdgeInsets.only(right: 8),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: tc.onSurface, width: 2)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onCancel,
                  child: Text('Cancel',
                      style: GoogleFonts.hankenGrotesk(color: tc.onSurfaceVariant)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tc.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Create',
                      style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<DatabaseHelper> _getDb() async => DatabaseHelper();
