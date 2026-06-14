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
import 'package:agent_money/features/transactions/widgets/manual_entry_sheet.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/recurring/screens/recurring_screen.dart';
import 'package:intl/intl.dart';

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

  void _showAddTransactionSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualEntrySheet(),
    ).then((_) {
      ref.read(accountProvider.notifier).loadAccounts();
    });
  }

  void _showAccountDetail(AccountModel account) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountDetailSheet(
        account: account,
        onEdit: () => _showAddSheet(account),
        onTransfer: () => _showTransferSheet(account),
        onAdjust: () => _showAdjustBalance(account),
        onDelete: () => _confirmDelete(account),
      ),
    ).then((_) => ref.read(accountProvider.notifier).loadAccounts());
  }

  /// Quick "set the real balance" correction — writes the new balance directly
  /// without creating a transaction. Useful when the tracked balance drifts.
  void _showAdjustBalance(AccountModel account) {
    final tc = AppThemeColors.of(context);
    final controller =
        TextEditingController(text: account.balance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Correct balance',
            style: AppFonts.sans(
                color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Set the actual balance of "${account.name}". This updates the account directly and does not add a transaction.',
                style: AppFonts.sans(
                    color: tc.onSurfaceVariant, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: AppFonts.sans(
                  color: tc.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '${account.currencyCode}  ',
                prefixStyle: AppFonts.sans(
                    color: tc.onSurfaceVariant, fontWeight: FontWeight.w600),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppFonts.sans(color: tc.onSurfaceVariant))),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null) return;
              ref
                  .read(accountProvider.notifier)
                  .updateAccount(account.copyWith(balance: value));
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: AppFonts.sans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(AccountModel account) {
    final tc = AppThemeColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${account.name}"?',
            style: AppFonts.sans(
                color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
            'This will remove the account. Your transaction history will remain.',
            style: AppFonts.sans(
                color: tc.onSurfaceVariant, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppFonts.sans(color: tc.onSurfaceVariant))),
          TextButton(
            onPressed: () {
              ref.read(accountProvider.notifier).deleteAccount(account.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: AppFonts.sans(
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
                style: AppFonts.sans(
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
                          style: AppFonts.sans(
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
                          style: AppFonts.sans(
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

                    const SizedBox(height: 16),

                    // Add transaction CTA
                    _AddTransactionCta(onTap: _showAddTransactionSheet)
                        .animate()
                        .fadeIn(delay: 120.ms),

                    const SizedBox(height: 12),

                    // Recurring payments (rent, SIP, subscriptions…)
                    _RecurringTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RecurringScreen()),
                      ),
                    ).animate().fadeIn(delay: 160.ms),

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
                              share: totalAssets > 0
                                  ? e.value.balance / totalAssets
                                  : 0,
                              shareLabel: 'of assets',
                              onOpen: () => _showAccountDetail(e.value),
                              onEdit: () => _showAddSheet(e.value),
                              onDelete: () => _confirmDelete(e.value),
                              onAdjust: () => _showAdjustBalance(e.value),
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
                              share: totalDebt > 0
                                  ? e.value.balance / totalDebt
                                  : 0,
                              shareLabel: 'of debt',
                              onOpen: () => _showAccountDetail(e.value),
                              onEdit: () => _showAddSheet(e.value),
                              onDelete: () => _confirmDelete(e.value),
                              onAdjust: () => _showAdjustBalance(e.value),
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
            style: AppFonts.sans(
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
              style: AppFonts.sans(
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
              style: AppFonts.sans(
                  color: tc.surface.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(
            currency.format(netWorth),
            style: AppFonts.sans(
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
              style: AppFonts.sans(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: AppFonts.sans(
                  color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      );
}

// ─── Account Card ────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final CurrencyState currency;
  final double share; // 0..1 portion of total assets / debt
  final String shareLabel;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTransfer;
  final VoidCallback onAdjust;
  final bool isLiability;

  const _AccountCard({
    required this.account,
    required this.currency,
    required this.share,
    required this.shareLabel,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onTransfer,
    required this.onAdjust,
    this.isLiability = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);

    return GestureDetector(
      onTap: onOpen,
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
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    account.bankName.isNotEmpty
                        ? '${account.bankName}${account.accountNumber.isNotEmpty ? ' •••• ${account.accountNumber}' : ''}'
                        : account.type.label,
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 11),
                  ),
                  if (share > 0) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: share.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: tc.surfaceContainerHigh,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  isLiability ? tc.expense : tc.income),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${(share * 100).round()}% $shareLabel',
                          style: AppFonts.sans(
                              color: tc.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Balance + label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(account.balance),
                  style: AppFonts.sans(
                    color: isLiability ? tc.expense : tc.income,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isLiability ? 'owed' : 'available',
                  style: AppFonts.sans(
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
                          style: AppFonts.sans(
                              color: tc.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(account.type.label,
                          style: AppFonts.sans(
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
              icon: Icons.tune_rounded,
              label: 'Correct balance',
              color: tc.onSurface,
              tc: tc,
              onTap: () {
                Navigator.pop(context);
                onAdjust();
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
                  style: AppFonts.sans(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ─── Add Transaction CTA ─────────────────────────────────────
class _AddTransactionCta extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTransactionCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tc.primary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tc.onPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.add_rounded, color: tc.onPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add transaction',
                      style: AppFonts.sans(
                          color: tc.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text('Log income or an expense manually',
                      style: AppFonts.sans(
                          color: tc.onPrimary.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: tc.onPrimary.withOpacity(0.8), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Recurring payments tile ─────────────────────────────────
class _RecurringTile extends StatelessWidget {
  final VoidCallback onTap;
  const _RecurringTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tc.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.repeat_rounded, color: tc.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recurring payments',
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text('Rent, SIP, subscriptions on autopilot',
                      style: AppFonts.sans(
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
                      style: AppFonts.sans(
                          color: tc.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text('Move money from one account to another',
                      style: AppFonts.sans(
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

// ─── Account Detail Sheet ─────────────────────────────────────
// Tap an account card → balance, share, quick actions, recent activity.
class _AccountDetailSheet extends ConsumerStatefulWidget {
  final AccountModel account;
  final VoidCallback onEdit;
  final VoidCallback onTransfer;
  final VoidCallback onAdjust;
  final VoidCallback onDelete;

  const _AccountDetailSheet({
    required this.account,
    required this.onEdit,
    required this.onTransfer,
    required this.onAdjust,
    required this.onDelete,
  });

  @override
  ConsumerState<_AccountDetailSheet> createState() =>
      _AccountDetailSheetState();
}

class _AccountDetailSheetState extends ConsumerState<_AccountDetailSheet> {
  late Future<List<TransactionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = TransactionRepository().getByAccount(widget.account.id);
  }

  bool get _isLiability =>
      widget.account.type == AccountType.loan ||
      widget.account.type == AccountType.creditCard;

  void _close(VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final account = widget.account;

    return Container(
      margin: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: tc.outlineVariant,
                    borderRadius: BorderRadius.circular(100))),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: account.type.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(account.type.icon,
                      color: account.type.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: AppFonts.sans(
                              color: tc.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      Text(
                        account.bankName.isNotEmpty
                            ? account.bankName
                            : account.type.label,
                        style: AppFonts.sans(
                            color: tc.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Balance
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              children: [
                Text(currency.format(account.balance),
                    style: AppFonts.sans(
                        color: _isLiability ? tc.expense : tc.onSurface,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1)),
                const SizedBox(height: 2),
                Text(_isLiability ? 'Outstanding' : 'Available balance',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _QuickAction(
                    icon: Icons.tune_rounded,
                    label: 'Balance',
                    tc: tc,
                    onTap: () => _close(widget.onAdjust)),
                _QuickAction(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Transfer',
                    tc: tc,
                    onTap: () => _close(widget.onTransfer)),
                _QuickAction(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    tc: tc,
                    onTap: () => _close(widget.onEdit)),
                _QuickAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    tc: tc,
                    color: tc.expense,
                    onTap: () => _close(widget.onDelete)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: tc.outlineVariant),
          // Recent activity
          Flexible(
            child: FutureBuilder<List<TransactionModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final txs = (snap.data ?? [])
                  ..sort((a, b) => b.date.compareTo(a.date));
                if (txs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Center(
                      child: Text('No activity on this account yet',
                          style: AppFonts.sans(
                              color: tc.onSurfaceVariant, fontSize: 13)),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('RECENT ACTIVITY',
                              style: AppFonts.sans(
                                  color: tc.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2)),
                          Text('${txs.length} total',
                              style: AppFonts.sans(
                                  color: tc.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    ),
                    ...txs.take(15).map(
                        (t) => _ActivityRow(tx: t, currency: currency, tc: tc)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppThemeColors tc;
  final Color? color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.tc,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? tc.onSurface;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: c, size: 20),
              const SizedBox(height: 6),
              Text(label,
                  style: AppFonts.sans(
                      color: c, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final TransactionModel tx;
  final CurrencyState currency;
  final AppThemeColors tc;
  const _ActivityRow(
      {required this.tx, required this.currency, required this.tc});

  @override
  Widget build(BuildContext context) {
    final isPositive = tx.balanceDelta >= 0;
    final title = tx.note.isNotEmpty
        ? tx.note
        : (tx.payee?.isNotEmpty == true ? tx.payee! : tx.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${tx.category}  ·  ${DateFormat('d MMM').format(tx.date)}',
                    style: AppFonts.sans(
                        color: tc.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${isPositive ? '+' : '-'}${currency.format(tx.amount)}',
            style: AppFonts.sans(
                color: isPositive ? tc.income : tc.expense,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
        ],
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
              style: AppFonts.sans(
                  color: tc.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              'Add bank accounts, cash, loan accounts\nand track your net worth in one place.',
              textAlign: TextAlign.center,
              style: AppFonts.sans(
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
                  style: AppFonts.sans(
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
