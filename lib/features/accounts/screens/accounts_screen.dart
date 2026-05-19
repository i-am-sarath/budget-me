import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/accounts/widgets/add_account_sheet.dart';
import 'package:agent_money/features/accounts/widgets/transfer_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Sheet helpers ────────────────────────────────────────
  void _showAddSheet([AccountModel? existing]) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAccountSheet(existing: existing),
    ).then((_) {
      // Refresh after sheet closes
      ref.read(accountProvider.notifier).loadAccounts();
    });
  }

  void _showTransferSheet([AccountModel? from]) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferSheet(fromAccount: from),
    ).then((_) {
      ref.read(accountProvider.notifier).loadAccounts();
    });
  }

  void _confirmDelete(AccountModel account) {
    final tc = AppThemeColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${account.name}"?',
            style: GoogleFonts.inter(
                color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
            'This will remove the account. Your transaction history will remain.',
            style: GoogleFonts.inter(
                color: tc.onSurfaceVariant, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: tc.onSurfaceVariant))),
          TextButton(
            onPressed: () {
              ref.read(accountProvider.notifier).deleteAccount(account.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: tc.expense, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountProvider);
    final currency = ref.watch(currencyProvider);
    final tc = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ────────────────────────────────────
          SliverAppBar(
            backgroundColor: tc.surface,
            floating: true,
            snap: true,
            elevation: 0,
            titleSpacing: 20,
            title: Text('Accounts',
                style: GoogleFonts.inter(
                  color: tc.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                )),
            actions: [
              // Transfer button
              GestureDetector(
                onTap: () => _showTransferSheet(),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: tc.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: tc.outlineVariant, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded,
                          color: tc.onSurface, size: 15),
                      const SizedBox(width: 4),
                      Text('Transfer',
                          style: GoogleFonts.inter(
                              color: tc.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              // Add button
              GestureDetector(
                onTap: () => _showAddSheet(),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: tc.onSurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: tc.surface, size: 15),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: GoogleFonts.inter(
                              color: tc.surface,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Content ────────────────────────────────────
          accountsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
            data: (accounts) {
              if (accounts.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(onAdd: () => _showAddSheet()),
                );
              }

              // Separate assets from liabilities
              final assets = accounts.where((a) =>
                  a.type != AccountType.loan &&
                  a.type != AccountType.creditCard);
              final liabilities = accounts.where((a) =>
                  a.type == AccountType.loan ||
                  a.type == AccountType.creditCard);

              final totalAssets =
                  assets.fold(0.0, (s, a) => s + a.balance);
              final totalDebt =
                  liabilities.fold(0.0, (s, a) => s + a.balance);

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Net Worth Card
                    _NetWorthCard(
                            assets: totalAssets,
                            debt: totalDebt,
                            currency: currency,
                            total: accounts.length)
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.08),

                    const SizedBox(height: 24),

                    // Assets section
                    if (assets.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'ACCOUNTS',
                          count: assets.length),
                      const SizedBox(height: 10),
                      ...assets.toList().asMap().entries.map(
                            (e) => _AccountCard(
                              account: e.value,
                              currency: currency,
                              onEdit: () => _showAddSheet(e.value),
                              onDelete: () => _confirmDelete(e.value),
                              onTransfer: () =>
                                  _showTransferSheet(e.value),
                            )
                                .animate()
                                .fadeIn(delay: (e.key * 50).ms)
                                .slideX(begin: 0.05),
                          ),
                    ],

                    // Liabilities section
                    if (liabilities.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHeader(
                          label: 'LOANS & CREDIT',
                          count: liabilities.length),
                      const SizedBox(height: 10),
                      ...liabilities.toList().asMap().entries.map(
                            (e) => _AccountCard(
                              account: e.value,
                              currency: currency,
                              onEdit: () => _showAddSheet(e.value),
                              onDelete: () => _confirmDelete(e.value),
                              onTransfer: () =>
                                  _showTransferSheet(e.value),
                              isLiability: true,
                            )
                                .animate()
                                .fadeIn(
                                    delay: ((assets.length + e.key) * 50)
                                        .ms)
                                .slideX(begin: 0.05),
                          ),
                    ],

                    const SizedBox(height: 24),

                    // Quick Transfer CTA
                    _TransferCta(onTap: () => _showTransferSheet())
                        .animate()
                        .fadeIn(delay: 300.ms),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: tc.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: tc.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text('$count',
              style: GoogleFonts.inter(
                  color: tc.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Net Worth Card ──────────────────────────────────────────
class _NetWorthCard extends StatelessWidget {
  final double assets, debt;
  final int total;
  final CurrencyState currency;

  const _NetWorthCard({
    required this.assets,
    required this.debt,
    required this.currency,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final netWorth = assets - debt;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: tc.onSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET WORTH',
              style: GoogleFonts.inter(
                  color: tc.surface.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(
            currency.format(netWorth),
            style: GoogleFonts.inter(
              color: tc.surface,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Total Assets',
                  value: currency.format(assets),
                  color: tc.income,
                  labelColor: tc.surface.withOpacity(0.5),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Total Debt',
                  value: currency.format(debt),
                  color: debt > 0 ? tc.expense : tc.surface.withOpacity(0.5),
                  labelColor: tc.surface.withOpacity(0.5),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Accounts',
                  value: '$total',
                  color: tc.surface,
                  labelColor: tc.surface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color, labelColor;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.color,
      required this.labelColor});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      );
}

// ─── Account Card ────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final CurrencyState currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTransfer;
  final bool isLiability;

  const _AccountCard({
    required this.account,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
    required this.onTransfer,
    this.isLiability = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);

    return GestureDetector(
      onLongPress: () => _showMenu(context, tc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLiability
                ? tc.expense.withOpacity(0.2)
                : tc.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: account.type.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(account.type.icon,
                  color: account.type.color, size: 22),
            ),
            const SizedBox(width: 14),

            // Name & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name,
                      style: GoogleFonts.inter(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    account.bankName.isNotEmpty
                        ? '${account.bankName}${account.accountNumber.isNotEmpty ? ' •••• ${account.accountNumber}' : ''}'
                        : account.type.label,
                    style: GoogleFonts.inter(
                        color: tc.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Balance + label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(account.balance),
                  style: GoogleFonts.inter(
                    color: isLiability ? tc.expense : tc.income,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isLiability ? 'owed' : 'available',
                  style: GoogleFonts.inter(
                      color: tc.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 6),

            // Menu trigger
            GestureDetector(
              onTap: () => _showMenu(context, tc),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.more_vert_rounded,
                    color: tc.onSurfaceVariant, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, AppThemeColors tc) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                      color: tc.outlineVariant,
                      borderRadius: BorderRadius.circular(100))),
            ),
            // Account name header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: account.type.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(account.type.icon,
                        color: account.type.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: GoogleFonts.inter(
                              color: tc.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(account.type.label,
                          style: GoogleFonts.inter(
                              color: tc.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tc.outlineVariant),
            _MenuOption(
              icon: Icons.edit_outlined,
              label: 'Edit account',
              color: tc.onSurface,
              tc: tc,
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            Divider(height: 1, color: tc.outlineVariant),
            _MenuOption(
              icon: Icons.swap_horiz_rounded,
              label: 'Transfer from this account',
              color: tc.onSurface,
              tc: tc,
              onTap: () {
                Navigator.pop(context);
                onTransfer();
              },
            ),
            Divider(height: 1, color: tc.outlineVariant),
            _MenuOption(
              icon: Icons.delete_outline_rounded,
              label: 'Delete account',
              color: tc.expense,
              tc: tc,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final AppThemeColors tc;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Text(label,
                  style: GoogleFonts.inter(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ─── Transfer CTA ────────────────────────────────────────────
class _TransferCta extends StatelessWidget {
  final VoidCallback onTap;
  const _TransferCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tc.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.swap_horiz_rounded,
                  color: tc.onSurface, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transfer between accounts',
                      style: GoogleFonts.inter(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text('Move money from one account to another',
                      style: GoogleFonts.inter(
                          color: tc.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: tc.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Center(
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
            child: Icon(Icons.account_balance_wallet_rounded,
                color: tc.onSurfaceVariant, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No accounts yet',
              style: GoogleFonts.inter(
                  color: tc.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              'Add bank accounts, cash, loan accounts\nand track your net worth in one place.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: tc.onSurfaceVariant, fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: tc.onSurface,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Add Account',
                  style: GoogleFonts.inter(
                      color: tc.surface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
