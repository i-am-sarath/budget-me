import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/travel/models/trip_model.dart';
import 'package:agent_money/features/travel/repositories/trip_repository.dart';
import 'package:agent_money/features/travel/screens/trip_detail_screen.dart';
import 'package:agent_money/features/travel/widgets/add_trip_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Sum of expense transactions tagged to [tripId].
double tripSpend(List<TransactionModel> transactions, String tripId) {
  return transactions
      .where((t) => t.tripId == tripId && t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);
}

class TravelScreen extends ConsumerWidget {
  const TravelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);
    final transactionsAsync = ref.watch(transactionListProvider);
    final currency = ref.watch(currencyProvider);
    final tc = AppThemeColors.of(context);
    final transactions = transactionsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: tc.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: tc.surface,
            floating: true,
            snap: true,
            elevation: 0,
            titleSpacing: 20,
            title: Text(
              'Travel',
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add_rounded, color: tc.onSurface),
                onPressed: () => _showAddSheet(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: tripsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
              data: (trips) {
                if (trips.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(onAdd: () => _showAddSheet(context)),
                  );
                }

                final ongoing = trips.where((t) => t.isOngoing).toList();
                final upcoming = trips.where((t) => t.isUpcoming).toList();
                final past = trips.where((t) => t.isPast).toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    if (ongoing.isNotEmpty) ...[
                      _SectionLabel(label: 'ONGOING', color: tc.income),
                      const SizedBox(height: 10),
                      ...ongoing.asMap().entries.map((e) => _TripTile(
                            trip: e.value,
                            spent: tripSpend(transactions, e.value.id),
                            currency: currency,
                            tc: tc,
                            onDelete: () =>
                                ref.read(tripListProvider.notifier).delete(e.value.id),
                          ).animate().fadeIn(delay: (e.key * 60).ms).slideY(begin: 0.1)),
                      const SizedBox(height: 20),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      _SectionLabel(label: 'UPCOMING', color: tc.onSurfaceVariant),
                      const SizedBox(height: 10),
                      ...upcoming.asMap().entries.map((e) => _TripTile(
                            trip: e.value,
                            spent: tripSpend(transactions, e.value.id),
                            currency: currency,
                            tc: tc,
                            onDelete: () =>
                                ref.read(tripListProvider.notifier).delete(e.value.id),
                          ).animate().fadeIn(delay: (e.key * 50).ms)),
                      const SizedBox(height: 20),
                    ],
                    if (past.isNotEmpty) ...[
                      _SectionLabel(label: 'PAST', color: tc.onSurfaceVariant),
                      const SizedBox(height: 10),
                      ...past.map((trip) => _TripTile(
                            trip: trip,
                            spent: tripSpend(transactions, trip.id),
                            currency: currency,
                            tc: tc,
                            onDelete: () =>
                                ref.read(tripListProvider.notifier).delete(trip.id),
                          )),
                    ],
                  ]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        backgroundColor: tc.onSurface,
        foregroundColor: tc.surface,
        elevation: 0,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const AddTripSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Trip tile
// ─────────────────────────────────────────────

class _TripTile extends StatelessWidget {
  final TripModel trip;
  final double spent;
  final CurrencyState currency;
  final AppThemeColors tc;
  final VoidCallback onDelete;

  const _TripTile({
    required this.trip,
    required this.spent,
    required this.currency,
    required this.tc,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = trip.budget > 0;
    final fraction = hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = hasBudget && spent > trip.budget;

    return Dismissible(
      key: Key(trip.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: tc.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_sweep_rounded, color: tc.expense, size: 26),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: trip.isOngoing
                ? Border.all(color: tc.income.withOpacity(0.3), width: 1)
                : Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tc.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(trip.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: GoogleFonts.inter(
                            color: tc.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (trip.destination.isNotEmpty) trip.destination,
                            '${DateFormat('d MMM').format(trip.startDate)} - ${DateFormat('d MMM').format(trip.endDate)}',
                          ].join(' · '),
                          style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(spent),
                        style: GoogleFonts.inter(
                          color: overBudget ? tc.expense : tc.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (hasBudget)
                        Text(
                          'of ${currency.format(trip.budget)}',
                          style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
              if (hasBudget) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: tc.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(
                      overBudget ? tc.expense : tc.income,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${trip.name}"?',
            style: GoogleFonts.inter(color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
          'Transactions already tagged to this trip will be kept.',
          style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: tc.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.inter(color: tc.expense, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: tc.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.flight_takeoff_rounded, color: tc.onSurfaceVariant, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          'No trips yet',
          style: GoogleFonts.inter(color: tc.onSurface, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'Plan a trip budget and tag expenses to it\nto track your travel spending.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: tc.onSurface,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Add a trip',
              style: GoogleFonts.inter(color: tc.surface, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
