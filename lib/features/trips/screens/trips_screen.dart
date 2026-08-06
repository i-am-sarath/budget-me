import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/services/currency_service.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/features/trips/models/trip_model.dart';
import 'package:money_pi/features/trips/repositories/trip_repository.dart';
import 'package:money_pi/features/trips/screens/trip_detail_screen.dart';
import 'package:money_pi/features/trips/widgets/trip_sheets.dart';
import 'package:intl/intl.dart';

/// Personal travel tracking. Create a trip, give it a budget, then tag your
/// spending to it (the entry sheet auto-tags the active trip). Works offline.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final tripsAsync = ref.watch(tripListProvider);

    return Scaffold(
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: tc.surface,
        elevation: 0,
        title: Text('Trips',
            style: AppFonts.sans(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showCreateTripSheet(context);
        },
        backgroundColor: tc.primary,
        foregroundColor: tc.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text('New trip',
            style: AppFonts.sans(fontWeight: FontWeight.w700)),
      ),
      body: tripsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trips) {
          if (trips.isEmpty) return _EmptyTrips(tc: tc);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: trips.length,
            itemBuilder: (_, i) => _TripCard(trip: trips[i]),
          );
        },
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  final TripModel trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final spentAsync = ref.watch(tripSpentProvider(trip.id));
    final activeId = ref.watch(activeTripIdProvider);
    final isTracking = activeId == trip.id;
    final spent = spentAsync.valueOrNull ?? 0;
    final pct = trip.hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final over = trip.hasBudget && spent > trip.budget;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
              color: isTracking ? trip.color.withOpacity(0.5) : tc.outlineVariant,
              width: isTracking ? 1 : 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: trip.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(trip.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(trip.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.sans(
                                    color: tc.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (isTracking) ...[
                            const SizedBox(width: 8),
                            _TrackingPill(color: trip.color),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dateRange(trip) ?? (trip.isActive ? 'Ongoing' : 'Ended'),
                        style: AppFonts.sans(
                            color: tc.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currency.format(spent),
                        style: AppFonts.sans(
                            color: over ? tc.expense : tc.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    Text(trip.hasBudget ? 'of ${currency.format(trip.budget)}' : 'spent',
                        style: AppFonts.sans(
                            color: tc.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ],
            ),
            if (trip.hasBudget) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: tc.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      over ? tc.expense : trip.color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _dateRange(TripModel t) {
    if (t.startDate == null && t.endDate == null) return null;
    final f = DateFormat('d MMM');
    if (t.startDate != null && t.endDate != null) {
      return '${f.format(t.startDate!)} – ${f.format(t.endDate!)}';
    }
    return f.format((t.startDate ?? t.endDate)!);
  }
}

class _TrackingPill extends StatelessWidget {
  final Color color;
  const _TrackingPill({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text('Tracking',
              style: AppFonts.sans(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  final AppThemeColors tc;
  const _EmptyTrips({required this.tc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
              child: Icon(Icons.card_travel_rounded,
                  color: tc.primary, size: 34),
            ),
            const SizedBox(height: 18),
            Text('Track a trip',
                style: AppFonts.sans(
                    color: tc.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Create a trip with a budget, then tag your spending to it while '
              'you travel. See exactly what the trip cost.',
              textAlign: TextAlign.center,
              style: AppFonts.sans(
                  color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
