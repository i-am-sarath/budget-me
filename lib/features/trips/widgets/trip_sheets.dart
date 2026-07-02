import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/trips/models/trip_model.dart';
import 'package:agent_money/features/trips/repositories/trip_repository.dart';
import 'package:intl/intl.dart';

Future<void> showCreateTripSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TripSheet(),
    );

Future<void> showEditTripSheet(BuildContext context, TripModel trip) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripSheet(existing: trip),
    );

class _TripSheet extends ConsumerStatefulWidget {
  final TripModel? existing;
  const _TripSheet({this.existing});

  @override
  ConsumerState<_TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends ConsumerState<_TripSheet> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  int _color = 0xFF6C52DA;

  static const _emojiOptions = ['✈️', '🏖️', '🏔️', '🚗', '🗺️', '🎒', '🏕️', '🛳️'];
  static const _colorOptions = [
    0xFF6C52DA, 0xFF1565C0, 0xFF00838F, 0xFF2E7D32,
    0xFFE65100, 0xFFC62828, 0xFFAD1457, 0xFF4527A0,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emojiCtrl.text = e.emoji;
      if (e.budget > 0) _budgetCtrl.text = e.budget.toStringAsFixed(0);
      _start = e.startDate;
      _end = e.endDate;
      _color = e.colorValue;
    } else {
      _emojiCtrl.text = '✈️';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your trip a name')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final emoji = _emojiCtrl.text.trim().isEmpty ? '✈️' : _emojiCtrl.text.trim();
    final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 0;
    final notifier = ref.read(tripListProvider.notifier);

    if (widget.existing != null) {
      notifier.update(widget.existing!.copyWith(
        name: name,
        emoji: emoji,
        colorValue: _color,
        budget: budget,
        startDate: _start,
        endDate: _end,
      ));
    } else {
      notifier.add(TripModel(
        name: name,
        emoji: emoji,
        colorValue: _color,
        budget: budget,
        startDate: _start,
        endDate: _end,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(top: 20, left: 24, right: 24, bottom: bottom + 32),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(100)),
              ),
            ),
            const SizedBox(height: 18),
            Text(widget.existing != null ? 'Edit trip' : 'New trip',
                style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),

            // Emoji + name
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: TextField(
                    controller: _emojiCtrl,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    style: const TextStyle(fontSize: 24),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: tc.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    autofocus: widget.existing == null,
                    style: AppFonts.sans(color: tc.onSurface, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Trip name (e.g. Goa 2026)',
                      filled: true,
                      fillColor: tc.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _emojiOptions
                  .map((e) => GestureDetector(
                        onTap: () => setState(() => _emojiCtrl.text = e),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _emojiCtrl.text == e
                                ? tc.primary.withOpacity(0.15)
                                : tc.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 18)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Budget
            TextField(
              controller: _budgetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: AppFonts.sans(color: tc.onSurface, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Trip budget (optional)',
                prefixText: '${currency.currency.symbol}  ',
                filled: true,
                fillColor: tc.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Dates
            Row(
              children: [
                Expanded(
                    child: _DateTile(
                        label: 'Start',
                        date: _start,
                        tc: tc,
                        onTap: () => _pickDate(true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _DateTile(
                        label: 'End',
                        date: _end,
                        tc: tc,
                        onTap: () => _pickDate(false))),
              ],
            ),
            const SizedBox(height: 16),

            // Color
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorOptions.map((c) {
                final sel = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: tc.onSurface, width: 2.5)
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(widget.existing != null ? 'Save trip' : 'Create trip',
                    style: AppFonts.sans(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final AppThemeColors tc;
  final VoidCallback onTap;
  const _DateTile(
      {required this.label,
      required this.date,
      required this.tc,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 15, color: tc.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              date != null ? DateFormat('d MMM').format(date!) : label,
              style: AppFonts.sans(
                  color: date != null ? tc.onSurface : tc.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
