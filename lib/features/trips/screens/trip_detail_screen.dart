import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/trips/models/trip_model.dart';
import 'package:agent_money/features/trips/repositories/trip_repository.dart';
import 'package:agent_money/features/trips/widgets/trip_sheets.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:intl/intl.dart';

class TripDetailScreen extends ConsumerWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final tripsAsync = ref.watch(tripListProvider);
    final trip =
        tripsAsync.valueOrNull?.where((t) => t.id == tripId).firstOrNull;

    if (trip == null) {
      return Scaffold(
        backgroundColor: tc.surface,
        appBar: AppBar(backgroundColor: tc.surface, elevation: 0),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final activeId = ref.watch(activeTripIdProvider);
    final isTracking = activeId == trip.id;
    final txsAsync = ref.watch(tripTransactionsProvider(trip.id));
    final txs = txsAsync.valueOrNull ?? const <TransactionModel>[];
    final spent = txs
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: tc.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: tc.onSurface),
        title: Row(
          children: [
            Text(trip.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(trip.name,
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
            tooltip: 'Edit trip',
            onPressed: () => showEditTripSheet(context, trip),
            icon: Icon(Icons.edit_outlined, color: tc.onSurfaceVariant, size: 20),
          ),
          IconButton(
            tooltip: 'Delete trip',
            onPressed: () => _confirmDelete(context, ref, trip),
            icon: Icon(Icons.delete_outline_rounded,
                color: tc.onSurfaceVariant, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HeroCard(trip: trip, spent: spent, currency: currency, tc: tc),
          const SizedBox(height: 14),
          // Track toggle — when on, new expenses are auto-tagged to this trip.
          _TrackToggle(
            tc: tc,
            color: trip.color,
            isTracking: isTracking,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              ref
                  .read(activeTripIdProvider.notifier)
                  .setActive(v ? trip.id : null);
            },
          ),
          const SizedBox(height: 20),
          Text('SPENDING',
              style: AppFonts.sans(
                  color: tc.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 8),
          if (txs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Text(
                isTracking
                    ? 'No spending yet — your expenses will appear here.'
                    : 'No spending tagged to this trip yet.\nTurn on tracking, then log expenses.',
                textAlign: TextAlign.center,
                style: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 13),
              ),
            )
          else
            ...txs.map((t) => _TxRow(tx: t, currency: currency, tc: tc)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TripModel trip) async {
    final tc = AppThemeColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${trip.name}"?',
            style: AppFonts.sans(
                color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
            'The trip is removed. Your transactions stay — they just lose the trip tag.',
            style: AppFonts.sans(
                color: tc.onSurfaceVariant, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppFonts.sans(color: tc.onSurfaceVariant))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: AppFonts.sans(
                      color: tc.expense, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    if (ref.read(activeTripIdProvider) == trip.id) {
      await ref.read(activeTripIdProvider.notifier).setActive(null);
    }
    await ref.read(tripListProvider.notifier).delete(trip.id);
    if (context.mounted) Navigator.pop(context);
  }
}

class _HeroCard extends StatelessWidget {
  final TripModel trip;
  final double spent;
  final CurrencyState currency;
  final AppThemeColors tc;
  const _HeroCard(
      {required this.trip,
      required this.spent,
      required this.currency,
      required this.tc});

  @override
  Widget build(BuildContext context) {
    final over = trip.hasBudget && spent > trip.budget;
    final remaining = trip.budget - spent;
    final pct = trip.hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_dateRange(trip) != null) ...[
            Text(_dateRange(trip)!,
                style: AppFonts.sans(
                    color: tc.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(spent),
                  style: AppFonts.sans(
                      color: over ? tc.expense : tc.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1)),
              if (trip.hasBudget) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('of ${currency.format(trip.budget)}',
                      style: AppFonts.sans(
                          color: tc.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
          if (trip.hasBudget) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: tc.surfaceContainerHigh,
                valueColor:
                    AlwaysStoppedAnimation<Color>(over ? tc.expense : trip.color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              over
                  ? 'Over budget by ${currency.format(spent - trip.budget)}'
                  : '${currency.format(remaining)} left',
              style: AppFonts.sans(
                  color: over ? tc.expense : tc.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  String? _dateRange(TripModel t) {
    if (t.startDate == null && t.endDate == null) return null;
    final f = DateFormat('EEE, d MMM');
    if (t.startDate != null && t.endDate != null) {
      return '${f.format(t.startDate!)}  →  ${f.format(t.endDate!)}';
    }
    return f.format((t.startDate ?? t.endDate)!);
  }
}

class _TrackToggle extends StatelessWidget {
  final AppThemeColors tc;
  final Color color;
  final bool isTracking;
  final ValueChanged<bool> onChanged;
  const _TrackToggle({
    required this.tc,
    required this.color,
    required this.isTracking,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.my_location_rounded,
              size: 18, color: isTracking ? color : tc.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Track new spending',
                    style: AppFonts.sans(
                        color: tc.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('Auto-tag expenses you log to this trip',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: isTracking,
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionModel tx;
  final CurrencyState currency;
  final AppThemeColors tc;
  const _TxRow({required this.tx, required this.currency, required this.tc});

  @override
  Widget build(BuildContext context) {
    final title = tx.note.isNotEmpty
        ? tx.note
        : (tx.payee?.isNotEmpty == true ? tx.payee! : tx.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.sans(
                        color: tc.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${tx.category}  ·  ${DateFormat('d MMM').format(tx.date)}',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(currency.format(tx.amount),
              style: AppFonts.sans(
                  color: tc.expense,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
