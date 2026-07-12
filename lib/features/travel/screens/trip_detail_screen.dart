import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/dashboard/widgets/transaction_tile.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/transactions/widgets/manual_entry_sheet.dart';
import 'package:agent_money/features/travel/models/trip_model.dart';
import 'package:agent_money/features/travel/repositories/trip_repository.dart';
import 'package:agent_money/features/travel/screens/travel_screen.dart';
import 'package:agent_money/features/travel/widgets/add_trip_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TripDetailScreen extends ConsumerWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final tripsAsync = ref.watch(tripListProvider);
    final trip = tripsAsync.valueOrNull?.where((t) => t.id == tripId).firstOrNull;

    if (trip == null) {
      // Trip was deleted (e.g. via swipe on the list screen) — pop back.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return Scaffold(
        backgroundColor: tc.surface,
        body: const SizedBox(),
      );
    }

    final currency = ref.watch(currencyProvider);
    final transactionsAsync = ref.watch(transactionListProvider);
    final transactions = (transactionsAsync.valueOrNull ?? [])
        .where((t) => t.tripId == tripId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final spent = tripSpend(transactionsAsync.valueOrNull ?? [], tripId);
    final hasBudget = trip.budget > 0;
    final fraction = hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = hasBudget && spent > trip.budget;

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
            titleSpacing: 8,
            title: Text(
              trip.name,
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: tc.onSurfaceVariant, size: 20),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ProviderScope(
                    parent: ProviderScope.containerOf(context),
                    child: AddTripSheet(existing: trip),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SummaryCard(
                  trip: trip,
                  spent: spent,
                  fraction: fraction,
                  overBudget: overBudget,
                  hasBudget: hasBudget,
                  currency: currency,
                  tc: tc,
                ),
                const SizedBox(height: 24),
                Text(
                  'EXPENSES',
                  style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No expenses tagged to this trip yet',
                        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...transactions.map(
                    (t) => TransactionTile(transaction: t, currency: currency),
                  ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ProviderScope(
            parent: ProviderScope.containerOf(context),
            child: ManualEntrySheet(
              presetTripId: trip.id,
              presetTripName: trip.name,
            ),
          ),
        ),
        backgroundColor: tc.onSurface,
        foregroundColor: tc.surface,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final TripModel trip;
  final double spent;
  final double fraction;
  final bool overBudget;
  final bool hasBudget;
  final CurrencyState currency;
  final AppThemeColors tc;

  const _SummaryCard({
    required this.trip,
    required this.spent,
    required this.fraction,
    required this.overBudget,
    required this.hasBudget,
    required this.currency,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(trip.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trip.destination.isNotEmpty)
                      Text(trip.destination,
                          style: GoogleFonts.inter(
                              color: tc.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${DateFormat('d MMM yyyy').format(trip.startDate)} - ${DateFormat('d MMM yyyy').format(trip.endDate)} · ${trip.durationDays} days',
                      style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spent',
                      style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    currency.format(spent),
                    style: GoogleFonts.inter(
                      color: overBudget ? tc.expense : tc.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (hasBudget) ...[
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(overBudget ? 'Over budget' : 'Remaining',
                        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      currency.format((trip.budget - spent).abs()),
                      style: GoogleFonts.inter(
                        color: overBudget ? tc.expense : tc.income,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (hasBudget) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: tc.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation(overBudget ? tc.expense : tc.income),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Budget: ${currency.format(trip.budget)}',
              style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
