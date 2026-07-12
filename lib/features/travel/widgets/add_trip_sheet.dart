import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/travel/models/trip_model.dart';
import 'package:agent_money/features/travel/repositories/trip_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AddTripSheet extends ConsumerStatefulWidget {
  final TripModel? existing;
  const AddTripSheet({super.key, this.existing});

  @override
  ConsumerState<AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends ConsumerState<AddTripSheet> {
  final _nameCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  String _icon = '✈️';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));

  bool get _isEditing => widget.existing != null;

  static const _icons = ['✈️', '🏖️', '🏔️', '🗺️', '🚗', '🚆', '🛳️', '🎒'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _destinationCtrl.text = e.destination;
      _budgetCtrl.text = e.budget == 0 ? '' : e.budget.toString();
      _icon = e.icon;
      _startDate = e.startDate;
      _endDate = e.endDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destinationCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;
    final endDate = _endDate.isBefore(_startDate) ? _startDate : _endDate;

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        name: _nameCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        icon: _icon,
        budget: budget,
        startDate: _startDate,
        endDate: endDate,
      );
      ref.read(tripListProvider.notifier).update(updated);
    } else {
      final trip = TripModel(
        name: _nameCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        icon: _icon,
        budget: budget,
        startDate: _startDate,
        endDate: endDate,
      );
      ref.read(tripListProvider.notifier).add(trip);
    }
    Navigator.pop(context);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: bottomPad + 32),
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
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? 'Edit Trip' : 'New Trip',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Icon picker
            Text('Icon',
                style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((i) {
                final sel = i == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? tc.onSurface.withOpacity(0.12) : tc.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: sel ? Border.all(color: tc.onSurface, width: 1.5) : null,
                    ),
                    child: Text(i, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Trip name
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Trip name',
                prefixIcon: Icon(Icons.flight_takeoff_rounded, color: tc.onSurfaceVariant, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Destination
            TextField(
              controller: _destinationCtrl,
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Destination (optional)',
                prefixIcon: Icon(Icons.place_outlined, color: tc.onSurfaceVariant, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Budget
            TextField(
              controller: _budgetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Trip budget (${currency.currency.symbol})',
                prefixIcon: Icon(Icons.savings_outlined, color: tc.onSurfaceVariant, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Dates
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start',
                    date: _startDate,
                    tc: tc,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: 'End',
                    date: _endDate,
                    tc: tc,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Update Trip' : 'Save Trip',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final AppThemeColors tc;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: tc.onSurfaceVariant, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 9)),
                  Text(DateFormat('d MMM yyyy').format(date),
                      style: GoogleFonts.inter(
                          color: tc.onSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
