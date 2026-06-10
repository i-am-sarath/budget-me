import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ManualEntrySheet extends ConsumerStatefulWidget {
  final TransactionModel? prefill;
  const ManualEntrySheet({super.key, this.prefill});

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _payeeController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _category = 'General';
  AccountModel? _selectedAccount;
  DateTime _date = DateTime.now();

  static const _categories = {
    TransactionType.expense: [
      ('🍔', 'Food & Dining'),
      ('🚗', 'Transport'),
      ('🛍️', 'Shopping'),
      ('🏠', 'Housing'),
      ('💊', 'Health'),
      ('📱', 'Bills & Utilities'),
      ('🎬', 'Entertainment'),
      ('📚', 'Education'),
      ('✈️', 'Travel'),
      ('👗', 'Clothing'),
      ('🐾', 'Pet Care'),
      ('⚙️', 'General'),
    ],
    TransactionType.income: [
      ('💼', 'Salary'),
      ('💰', 'Freelance'),
      ('🎁', 'Gift'),
      ('🏦', 'Interest'),
      ('🏡', 'Rental Income'),
      ('📦', 'Side Business'),
      ('💹', 'Dividends'),
      ('⚙️', 'Other'),
    ],
    TransactionType.investment: [
      ('📈', 'Stocks'),
      ('🏦', 'Mutual Fund'),
      ('🏠', 'Real Estate'),
      ('💎', 'Crypto'),
      ('🪙', 'Gold / Metals'),
      ('📊', 'ETF / Index Fund'),
      ('💵', 'Fixed Deposit'),
      ('⚙️', 'Other'),
    ],
    TransactionType.lend: [
      ('👤', 'Friend'),
      ('👨‍👩‍👧', 'Family'),
      ('💼', 'Colleague'),
      ('⚙️', 'Other'),
    ],
    TransactionType.borrow: [
      ('👤', 'Friend'),
      ('👨‍👩‍👧', 'Family'),
      ('🏦', 'Bank / Lender'),
      ('💼', 'Colleague'),
      ('⚙️', 'Other'),
    ],
    TransactionType.lendReturn: [
      ('👤', 'Friend'),
      ('👨‍👩‍👧', 'Family'),
      ('💼', 'Colleague'),
      ('⚙️', 'Other'),
    ],
    TransactionType.borrowReturn: [
      ('👤', 'Friend'),
      ('👨‍👩‍👧', 'Family'),
      ('🏦', 'Bank / Lender'),
      ('💼', 'Colleague'),
      ('💳', 'Loan Repayment'),
      ('⚙️', 'Other'),
    ],
  };

  // Types shown in the entry sheet — two rows for clarity
  static const _row1Types = [
    (TransactionType.expense, 'Expense', Icons.arrow_upward_rounded),
    (TransactionType.income, 'Income', Icons.arrow_downward_rounded),
    (TransactionType.investment, 'Invest', Icons.trending_up_rounded),
  ];

  static const _row2Types = [
    (TransactionType.lend, 'Lend', Icons.people_alt_rounded),
    (TransactionType.lendReturn, 'Got Back', Icons.undo_rounded),
    (TransactionType.borrow, 'Borrow', Icons.person_add_alt_1_rounded),
    (TransactionType.borrowReturn, 'Repaid', Icons.redo_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _amountController.text = p.amount.toString();
      _noteController.text = p.note;
      _payeeController.text = p.payee ?? '';
      _type = p.type;
      _category = p.category;
      _date = p.date;
    }
  }

  bool _accountInitialized = false;

  /// On first build, set the default account. Editing → restore the saved
  /// account. New entry → default to the first account so the user sees the
  /// picker is active and doesn't accidentally save without one.
  void _initAccount(List<AccountModel> accounts) {
    if (_accountInitialized) return;
    _accountInitialized = true;
    if (accounts.isEmpty) return;

    final prefillAccountId = widget.prefill?.accountId;
    if (prefillAccountId != null && prefillAccountId.isNotEmpty) {
      _selectedAccount = accounts
          .where((a) => a.id == prefillAccountId)
          .firstOrNull;
    } else if (widget.prefill == null) {
      _selectedAccount = accounts.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _payeeController.dispose();
    super.dispose();
  }

  List<(String, String)> get _currentCategories =>
      _categories[_type] ?? _categories[TransactionType.expense]!;

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      final cats = _categories[type]!;
      if (!cats.any((c) => c.$2 == _category)) {
        _category = cats.first.$2;
      }
    });
  }

  bool get _showPayeeField =>
      _type == TransactionType.lend ||
      _type == TransactionType.borrow ||
      _type == TransactionType.lendReturn ||
      _type == TransactionType.borrowReturn;

  String get _payeeLabel {
    switch (_type) {
      case TransactionType.lend:
        return 'Who did you lend to?';
      case TransactionType.lendReturn:
        return 'Who returned the money?';
      case TransactionType.borrow:
        return 'Who did you borrow from?';
      case TransactionType.borrowReturn:
        return 'Who did you repay?';
      default:
        return 'Person / organisation';
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      final amount = double.tryParse(_amountController.text) ?? 0;
      // Security fix: strictly enforce transaction amount > 0 to prevent negative balance exploits
      if (amount <= 0) {
        throw ArgumentError('Invalid amount');
      }
      final transaction = TransactionModel(
        id: widget.prefill?.id,
        amount: amount,
        type: _type,
        category: _category,
        note: _noteController.text,
        payee: _payeeController.text.isEmpty ? null : _payeeController.text,
        accountId: _selectedAccount?.id,
        accountName: _selectedAccount?.name,
        date: _date,
      );

      if (widget.prefill != null) {
        ref
            .read(transactionListProvider.notifier)
            .updateTransaction(widget.prefill!, transaction);
      } else {
        ref.read(transactionListProvider.notifier).addTransaction(transaction);
      }
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final tc = AppThemeColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete this transaction?',
          style: GoogleFonts.inter(
            color: tc.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'The linked account balance will be reversed.',
          style: GoogleFonts.inter(
            color: tc.onSurfaceVariant,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: tc.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: tc.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    ref
        .read(transactionListProvider.notifier)
        .deleteTransaction(widget.prefill!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final tc = AppThemeColors.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: bottomPad + 32,
      ),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
              const SizedBox(height: 12),

              // Header row — title + (Delete in edit mode)
              Row(
                children: [
                  Text(
                    widget.prefill != null
                        ? 'Edit transaction'
                        : 'New transaction',
                    style: GoogleFonts.inter(
                      color: tc.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (widget.prefill != null)
                    GestureDetector(
                      onTap: _confirmDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tc.expense.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: tc.expense,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Delete',
                              style: GoogleFonts.inter(
                                color: tc.expense,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Type selector — two rows
              _buildTypeSelector(tc),
              const SizedBox(height: 16),

              // Amount field
              _buildAmountField(currency, tc),
              const SizedBox(height: 14),

              // Category chips
              _buildLabel('Category', tc),
              const SizedBox(height: 8),
              _buildCategoryGrid(tc),
              const SizedBox(height: 14),

              // Payee field for lend/borrow/returns
              if (_showPayeeField) ...[
                _buildTextField(
                  controller: _payeeController,
                  label: _payeeLabel,
                  icon: Icons.person_outline_rounded,
                  tc: tc,
                ),
                const SizedBox(height: 14),
              ],

              // Note
              _buildTextField(
                controller: _noteController,
                label: 'Note (optional)',
                icon: Icons.edit_outlined,
                tc: tc,
              ),
              const SizedBox(height: 14),

              // Account selector
              _buildLabel('Account', tc),
              const SizedBox(height: 8),
              accountsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (accounts) {
                  _initAccount(accounts);
                  return _buildAccountSelector(accounts, tc);
                },
              ),
              const SizedBox(height: 14),

              // Date picker
              _buildDatePicker(tc),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(
                    widget.prefill != null
                        ? 'Update Transaction'
                        : 'Save Transaction',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(AppThemeColors tc) {
    Color typeAccent(TransactionType t) {
      switch (t) {
        case TransactionType.expense:
          return tc.expense;
        case TransactionType.income:
          return tc.income;
        case TransactionType.investment:
          return tc.investment;
        case TransactionType.lend:
          return tc.lend;
        case TransactionType.lendReturn:
          return tc.income;
        case TransactionType.borrow:
          return tc.borrow;
        case TransactionType.borrowReturn:
          return tc.expense;
      }
    }

    Widget typeButton(TransactionType type, String label, IconData icon) {
      final isSelected = _type == type;
      final accent = typeAccent(type);
      return Expanded(
        child: GestureDetector(
          onTap: () => _onTypeChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? accent.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: accent.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? accent : tc.onSurfaceVariant,
                  size: 16,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isSelected ? accent : tc.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: _row1Types
                .map((t) => typeButton(t.$1, t.$2, t.$3))
                .toList(),
          ),
          const SizedBox(height: 4),
          Row(
            children: _row2Types
                .map((t) => typeButton(t.$1, t.$2, t.$3))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField(CurrencyState currency, AppThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            currency.currency.symbol,
            style: GoogleFonts.inter(
              color: tc.onSurfaceVariant,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: widget.prefill == null,
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                final parsed = double.tryParse(v);
                if (parsed == null || parsed <= 0) return 'Invalid amount';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label, AppThemeColors tc) => Text(
    label,
    style: GoogleFonts.inter(
      color: tc.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );

  Widget _buildCategoryGrid(AppThemeColors tc) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _currentCategories.map((cat) {
        final isSelected = _category == cat.$2;
        return GestureDetector(
          onTap: () => setState(() => _category = cat.$2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? tc.onSurface : tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? Colors.transparent : tc.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.$1, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  cat.$2,
                  style: GoogleFonts.inter(
                    color: isSelected ? tc.surface : tc.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppThemeColors tc,
  }) => TextFormField(
    controller: controller,
    style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: tc.onSurfaceVariant, size: 20),
    ),
  );

  Widget _buildAccountSelector(List<AccountModel> accounts, AppThemeColors tc) {
    if (accounts.isEmpty) {
      return Text(
        'No accounts yet — add one in the Accounts tab',
        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _accountChip(null, 'None', tc),
        ...accounts.map((acc) => _accountChip(acc, acc.name, tc)),
      ],
    );
  }

  Widget _accountChip(AccountModel? acc, String label, AppThemeColors tc) {
    final isSelected = acc == null
        ? _selectedAccount == null
        : _selectedAccount?.id == acc.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccount = acc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? tc.onSurface : tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? Colors.transparent : tc.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (acc != null) ...[
              Icon(
                acc.type.icon,
                size: 12,
                color: isSelected ? tc.surface : acc.type.color,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? tc.surface : tc.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(AppThemeColors tc) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: tc.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(_date),
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
