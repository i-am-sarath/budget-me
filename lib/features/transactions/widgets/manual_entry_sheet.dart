import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:agent_money/features/categories/repositories/category_repository.dart';
import 'package:agent_money/features/trips/models/trip_model.dart';
import 'package:agent_money/features/trips/repositories/trip_repository.dart';
import 'package:intl/intl.dart';

class ManualEntrySheet extends ConsumerStatefulWidget {
  final TransactionModel? prefill;

  /// Open the sheet on a specific type (e.g. launch straight into "Repaid").
  final TransactionType? presetType;

  /// For settle flows (Repaid / Got Back): the debt or receivable account
  /// to settle, pre-selected (e.g. tapping "Repay" on a loan card).
  final AccountModel? settleTarget;

  const ManualEntrySheet({
    super.key,
    this.prefill,
    this.presetType,
    this.settleTarget,
  });

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
  bool _categoryTouched = false; // user manually picked → stop auto-suggesting
  AccountModel? _selectedAccount;
  AccountModel? _settleTarget; // debt/receivable to settle (Repaid / Got Back)
  bool _amountAutoFilled = false; // amount was filled from the settle target
  String? _selectedTripId; // optional Trip tag for expenses (travel tracking)
  DateTime _date = DateTime.now();
  List<(String, String)>? _dbExpenseCategoriesCache;

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
      ('📖', 'Books'),
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
    (TransactionType.expense,    'Expense',    Icons.arrow_upward_rounded),
    (TransactionType.income,     'Income',     Icons.arrow_downward_rounded),
    (TransactionType.investment, 'Invest',     Icons.trending_up_rounded),
  ];

  static const _row2Types = [
    (TransactionType.lend,         'Lend',       Icons.people_alt_rounded),
    (TransactionType.lendReturn,   'Got Back',   Icons.undo_rounded),
    (TransactionType.borrow,       'Borrow',     Icons.person_add_alt_1_rounded),
    (TransactionType.borrowReturn, 'Repaid',     Icons.redo_rounded),
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
    if (widget.presetType != null) {
      _type = widget.presetType!;
      final cats = _categories[_type];
      if (cats != null && cats.isNotEmpty &&
          !cats.any((c) => c.$2 == _category)) {
        _category = cats.first.$2;
      }
    }
    if (widget.settleTarget != null) {
      _settleTarget = widget.settleTarget;
      if (_amountController.text.isEmpty) {
        _amountController.text = widget.settleTarget!.balance.toStringAsFixed(2);
        _amountAutoFilled = true;
      }
    }
    // Tag new expenses to the trip currently being tracked (if any).
    _selectedTripId =
        widget.prefill?.tripId ?? ref.read(activeTripIdProvider);
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
      _selectedAccount =
          accounts.where((a) => a.id == prefillAccountId).firstOrNull;
    } else if (widget.prefill == null) {
      // Debt flows fund from a real cash/bank account, never from a
      // loan/receivable tracking account.
      if (_isDebtType) {
        _selectedAccount = _spendable(accounts).firstOrNull;
      } else {
        _selectedAccount = accounts.first;
      }
    }
  }

  /// Real spendable accounts (excludes loan/credit-card/receivable trackers).
  List<AccountModel> _spendable(List<AccountModel> accounts) => accounts
      .where((a) => !a.type.isLiability && !a.type.isReceivable)
      .toList();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _payeeController.dispose();
    super.dispose();
  }

  List<(String, String)> _currentCategories(List<(String, String)> dbExpense) {
    if (_type == TransactionType.expense) return dbExpense;
    return _categories[_type] ?? _categories[TransactionType.expense]!;
  }

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      final dbExpense =
          _dbExpenseCategoriesCache ?? _categories[TransactionType.expense]!;
      final cats = type == TransactionType.expense
          ? dbExpense
          : (_categories[type] ?? _categories[TransactionType.expense]!);
      if (!cats.any((c) => c.$2 == _category)) {
        _category = cats.isNotEmpty ? cats.first.$2 : 'General';
      }
    });
  }

  /// Opening a new debt: you lend money out, or you borrow money in.
  bool get _isOpenDebtType =>
      _type == TransactionType.lend || _type == TransactionType.borrow;

  /// Settling an existing debt: someone pays you back, or you repay a loan.
  bool get _isSettleType =>
      _type == TransactionType.lendReturn ||
      _type == TransactionType.borrowReturn;

  bool get _isDebtType => _isOpenDebtType || _isSettleType;

  /// Tracker-account type matching the current settle flow.
  AccountType get _settleTrackerType =>
      _type == TransactionType.lendReturn
          ? AccountType.receivable
          : AccountType.loan; // borrowReturn settles loans / credit cards

  /// Show the free-text person field when opening a new lend/borrow, or when
  /// editing any legacy debt transaction (which stored the person as payee).
  bool get _showPayeeField =>
      _isOpenDebtType || (widget.prefill != null && _isDebtType);

  /// Show the outstanding-debt picker only for a brand-new settle entry that
  /// wasn't launched against a specific debt/receivable (e.g. tapping "Repaid"
  /// from the type bar). When a [settleTarget] is preset (the user tapped
  /// "Repay" on a specific loan card) we skip the redundant picker so the
  /// "Pay from (your account)" selector is the clear next choice.
  bool get _showSettlePicker =>
      _isSettleType && widget.prefill == null && widget.settleTarget == null;

  String get _payeeLabel {
    switch (_type) {
      case TransactionType.lend:
        return 'Who did you lend to?';
      case TransactionType.borrow:
        return 'Who did you borrow from?';
      default:
        return 'Person / organisation';
    }
  }

  /// Label for the user's own cash/bank account in debt flows.
  String get _accountLabel {
    switch (_type) {
      case TransactionType.borrow:
        return 'Deposit into (your account)';
      case TransactionType.lend:
        return 'Paid from (your account)';
      case TransactionType.borrowReturn:
        return 'Pay from (your account)';
      case TransactionType.lendReturn:
        return 'Received into (your account)';
      default:
        return 'Account';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Debt flows (lend / borrow / repaid / got back) create a tracking account
    // plus an optional cash leg — handled separately. Editing an existing
    // transaction keeps the simple single-entry path.
    if (_isDebtType && widget.prefill == null) {
      _submitDebt();
      return;
    }

    HapticFeedback.mediumImpact();
    final amount = double.tryParse(_amountController.text) ?? 0;
    final transaction = TransactionModel(
      id: widget.prefill?.id,
      amount: amount,
      type: _type,
      category: _category,
      note: _noteController.text,
      payee: _payeeController.text.isEmpty ? null : _payeeController.text,
      accountId: _selectedAccount?.id,
      accountName: _selectedAccount?.name,
      tripId: _type == TransactionType.expense ? _selectedTripId : null,
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submitDebt() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }

    final txn = ref.read(transactionListProvider.notifier);
    final accounts = ref.read(accountProvider.notifier);
    final userAcct = _selectedAccount; // own cash/bank — optional cash leg
    final note = _noteController.text.trim();
    HapticFeedback.mediumImpact();

    if (_isOpenDebtType) {
      final person = _payeeController.text.trim();
      if (person.isEmpty) {
        _snack(_type == TransactionType.borrow
            ? 'Enter who you borrowed from'
            : 'Enter who you lent to');
        return;
      }
      final isBorrow = _type == TransactionType.borrow;
      // Find-or-create the debt (loan) / receivable account for this person.
      final tracker = await accounts.ensureTrackerAccount(
        name: person,
        type: isBorrow ? AccountType.loan : AccountType.receivable,
      );
      final defaultNote = isBorrow ? 'Borrowed from $person' : 'Lent to $person';
      // Debt-side: raises the outstanding balance on the tracker account.
      await txn.addTransaction(TransactionModel(
        amount: amount,
        type: _type,
        category: _category,
        note: note.isNotEmpty ? note : defaultNote,
        payee: person,
        accountId: tracker.id,
        accountName: tracker.name,
        date: _date,
      ));
      // Cash-side (optional): the money actually moving in/out of your account.
      if (userAcct != null) {
        await txn.addTransaction(TransactionModel(
          amount: amount,
          type: isBorrow
              ? TransactionType.transferIn
              : TransactionType.transferOut,
          category: isBorrow ? 'Borrowed' : 'Lent',
          note: defaultNote,
          accountId: userAcct.id,
          accountName: userAcct.name,
          date: _date,
        ));
      }
    } else {
      // Settle an existing debt / receivable.
      final target = _settleTarget;
      if (target == null) {
        _snack(_type == TransactionType.borrowReturn
            ? 'Select which loan you repaid'
            : 'Select who paid you back');
        return;
      }
      final isRepay = _type == TransactionType.borrowReturn;
      // Never settle more than what's outstanding.
      final pay = amount > target.balance ? target.balance : amount;
      await txn.addTransaction(TransactionModel(
        amount: pay,
        type: _type,
        category: _category,
        note: note.isNotEmpty ? note : '${isRepay ? 'Repaid' : 'Got back'} · ${target.name}',
        payee: target.name,
        accountId: target.id,
        accountName: target.name,
        date: _date,
      ));
      if (userAcct != null) {
        await txn.addTransaction(TransactionModel(
          amount: pay,
          type: isRepay
              ? TransactionType.transferOut
              : TransactionType.transferIn,
          category: isRepay ? 'Loan Repayment' : 'Money Back',
          note: '${isRepay ? 'Repaid' : 'Got back'} · ${target.name}',
          accountId: userAcct.id,
          accountName: userAcct.name,
          date: _date,
        ));
      }
      // Fully settled → close the tracking account.
      final updated = accounts.accounts
          .where((a) => a.id == target.id)
          .firstOrNull;
      if (updated != null && updated.balance <= 0.005) {
        await accounts.deleteAccount(target.id);
        _snack('${target.name} settled and closed');
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final tc = AppThemeColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerLow,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete this transaction?',
          style: AppFonts.sans(
              color: tc.onSurface, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'The linked account balance will be reversed.',
          style: AppFonts.sans(
              color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppFonts.sans(color: tc.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppFonts.sans(
                    color: tc.expense, fontWeight: FontWeight.w700)),
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
    final categoriesAsync = ref.watch(categoryListProvider);
    final freshDbExpense = categoriesAsync.valueOrNull
        ?.where((c) => c.transactionType == 'expense')
        .map((c) => (c.emoji, c.name))
        .toList();
    if (freshDbExpense != null && freshDbExpense.isNotEmpty) {
      _dbExpenseCategoriesCache = freshDbExpense;
    }
    final dbExpenseCategories =
        _dbExpenseCategoriesCache ?? _categories[TransactionType.expense]!;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final tc = AppThemeColors.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 24, right: 24, bottom: bottomPad + 32,
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
                    style: AppFonts.sans(
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
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: tc.expense.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: tc.expense, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Delete',
                              style: AppFonts.sans(
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
              _buildCategoryGrid(tc, dbExpenseCategories),
              const SizedBox(height: 14),

              // Trip tag — expenses only, so travel spending lands on a trip.
              if (_type == TransactionType.expense)
                _buildTripSelector(tc),

              // Payee field for opening a new lend/borrow
              if (_showPayeeField) ...[
                _buildTextField(
                  controller: _payeeController,
                  label: _payeeLabel,
                  icon: Icons.person_outline_rounded,
                  tc: tc,
                  onChanged: (_) => _maybeAutoPickCategory(),
                ),
                const SizedBox(height: 14),
              ],

              // Settle-target picker for Repaid / Got Back
              if (_showSettlePicker) ...[
                _buildLabel(
                    _type == TransactionType.borrowReturn
                        ? 'Which loan are you repaying?'
                        : 'Who is paying you back?',
                    tc),
                const SizedBox(height: 8),
                accountsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (accounts) => _buildSettleTargetSelector(accounts, tc),
                ),
                const SizedBox(height: 14),
              ]
              // Preset target (launched from a specific card) — show a summary
              // of what's being settled instead of the redundant picker.
              else if (_isSettleType && _settleTarget != null) ...[
                _buildSettleTargetSummary(_settleTarget!, currency, tc),
                const SizedBox(height: 14),
              ],

              // Note
              _buildTextField(
                controller: _noteController,
                label: 'Note (optional)',
                icon: Icons.edit_outlined,
                tc: tc,
                onChanged: (_) => _maybeAutoPickCategory(),
              ),
              const SizedBox(height: 14),

              // Account selector (own cash/bank account)
              _buildLabel(_isDebtType ? _accountLabel : 'Account', tc),
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
                    widget.prefill != null ? 'Update Transaction' : 'Save Transaction',
                    style: AppFonts.sans(
                        fontWeight: FontWeight.w700, fontSize: 15),
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
        case TransactionType.expense:      return tc.expense;
        case TransactionType.income:       return tc.income;
        case TransactionType.investment:   return tc.investment;
        case TransactionType.lend:         return tc.lend;
        case TransactionType.lendReturn:   return tc.income;
        case TransactionType.borrow:       return tc.borrow;
        case TransactionType.borrowReturn: return tc.expense;
        case TransactionType.transferOut:  return tc.investment;
        case TransactionType.transferIn:   return tc.investment;
      }
    }

    Widget typeButton(
        TransactionType type, String label, IconData icon) {
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
                Icon(icon,
                    color: isSelected ? accent : tc.onSurfaceVariant,
                    size: 16),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppFonts.sans(
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
            style: AppFonts.sans(
              color: tc.onSurfaceVariant,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: widget.prefill == null,
              style: AppFonts.sans(
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
                if (double.tryParse(v) == null) return 'Invalid amount';
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
        style: AppFonts.sans(
          color: tc.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );

  Widget _buildCategoryGrid(AppThemeColors tc, List<(String, String)> dbExpense) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _currentCategories(dbExpense).map((cat) {
        final isSelected = _category == cat.$2;
        return GestureDetector(
          onTap: () => setState(() {
            _category = cat.$2;
            _categoryTouched = true;
          }),
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
                  style: AppFonts.sans(
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
    ValueChanged<String>? onChanged,
  }) =>
      TextFormField(
        controller: controller,
        onChanged: onChanged,
        style: AppFonts.sans(color: tc.onSurface, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: tc.onSurfaceVariant, size: 20),
        ),
      );

  // ── Auto-category ────────────────────────────────────────
  // Guess the category from what the user typed (note/payee) so they don't
  // have to pick it by hand. Only runs for expenses and only until the user
  // taps a category themselves (then [_categoryTouched] stops it).
  static const Map<String, List<String>> _categoryKeywords = {
    'Food': ['swiggy', 'zomato', 'restaurant', 'cafe', 'coffee', 'lunch',
      'dinner', 'breakfast', 'pizza', 'burger', 'food', 'canteen', 'snack',
      'tea', 'biryani', 'dominos', 'kfc', 'mcd', 'starbucks', 'grocery',
      'groceries', 'bigbasket', 'blinkit', 'zepto', 'milk', 'vegetables'],
    'Transport': ['uber', 'ola', 'rapido', 'auto', 'cab', 'taxi', 'petrol',
      'diesel', 'fuel', 'metro', 'bus', 'train', 'parking', 'toll', 'flight',
      'irctc', 'fastag'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'shopping', 'clothes',
      'shoes', 'mall', 'meesho', 'nykaa', 'electronics'],
    'Bills': ['electricity', 'water bill', 'gas bill', 'recharge', 'mobile',
      'broadband', 'wifi', 'internet', 'dth', 'bill', 'postpaid', 'jio',
      'airtel', 'vi ', 'bsnl'],
    'Entertainment': ['netflix', 'spotify', 'prime', 'hotstar', 'movie',
      'cinema', 'pvr', 'inox', 'game', 'youtube', 'subscription', 'concert'],
    'Health': ['pharmacy', 'medical', 'medicine', 'hospital', 'doctor',
      'clinic', 'apollo', 'gym', 'fitness', 'pharmeasy', '1mg'],
    'Rent': ['rent', 'maintenance', 'society'],
    'Travel': ['hotel', 'oyo', 'airbnb', 'trip', 'travel', 'makemytrip',
      'goibibo', 'booking', 'resort', 'vacation'],
    'Education': ['course', 'tuition', 'school', 'college', 'fees', 'udemy',
      'coursera', 'books', 'exam', 'class'],
  };

  String? _guessCategory(String text) {
    final t = text.toLowerCase();
    if (t.trim().isEmpty) return null;
    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (t.contains(kw)) return entry.key;
      }
    }
    return null;
  }

  void _maybeAutoPickCategory() {
    if (_categoryTouched || _type != TransactionType.expense) return;
    final guess =
        _guessCategory('${_noteController.text} ${_payeeController.text}');
    if (guess != null && guess != _category) {
      setState(() => _category = guess);
    }
  }

  /// Optional Trip tag for an expense (travel tracking). Hidden entirely when
  /// the user has no trips, so it never clutters the common case.
  Widget _buildTripSelector(AppThemeColors tc) {
    final trips = ref.watch(tripListProvider).valueOrNull ?? const <TripModel>[];
    final active = trips.where((t) => t.isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    Widget chip({required bool selected, required String label, String? emoji,
        required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? tc.onSurface : tc.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: selected ? Colors.transparent : tc.outlineVariant,
                width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: AppFonts.sans(
                      color: selected ? tc.surface : tc.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Trip (optional)', tc),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(
              selected: _selectedTripId == null,
              label: 'None',
              onTap: () => setState(() => _selectedTripId = null),
            ),
            ...active.map((t) => chip(
                  selected: _selectedTripId == t.id,
                  label: t.name,
                  emoji: t.emoji,
                  onTap: () => setState(() => _selectedTripId = t.id),
                )),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildAccountSelector(List<AccountModel> accounts, AppThemeColors tc) {
    // Debt flows fund from spendable accounts only.
    final options = _isDebtType ? _spendable(accounts) : accounts;
    if (options.isEmpty) {
      return Text(
        'No accounts yet — add one in the Accounts tab',
        style: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _accountChip(null, 'None', tc),
        ...options.map((acc) => _accountChip(acc, acc.name, tc)),
      ],
    );
  }

  /// Compact summary of the debt/receivable being settled when it was preset
  /// (e.g. tapping "Repay" on a loan card). Shows the outstanding balance so
  /// the user knows how much is left before they enter the amount.
  Widget _buildSettleTargetSummary(
      AccountModel target, CurrencyState currency, AppThemeColors tc) {
    final isRepay = _type == TransactionType.borrowReturn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(target.type.icon, size: 18, color: target.type.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRepay ? 'Repaying ${target.name}' : 'From ${target.name}',
                  style: AppFonts.sans(
                      color: tc.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  '${currency.format(target.balance)} outstanding',
                  style: AppFonts.sans(
                      color: tc.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Picker over outstanding debts/receivables for the Repaid / Got Back flows.
  Widget _buildSettleTargetSelector(
      List<AccountModel> accounts, AppThemeColors tc) {
    final targets = accounts
        .where((a) => a.type == _settleTrackerType && a.balance > 0.005)
        .toList();

    if (targets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Text(
          _type == TransactionType.borrowReturn
              ? 'No outstanding loans to repay. Record a "Borrow" first.'
              : 'No one owes you yet. Record a "Lend" first.',
          style: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 12),
        ),
      );
    }

    final currency = ref.read(currencyProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: targets.map((acc) {
        final isSelected = _settleTarget?.id == acc.id;
        return GestureDetector(
          onTap: () => setState(() {
            _settleTarget = acc;
            // Default the amount to the full outstanding balance.
            if (_amountController.text.isEmpty || _amountAutoFilled) {
              _amountController.text = acc.balance.toStringAsFixed(2);
              _amountAutoFilled = true;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Icon(acc.type.icon,
                    size: 13,
                    color: isSelected ? tc.surface : acc.type.color),
                const SizedBox(width: 6),
                Text(
                  acc.name,
                  style: AppFonts.sans(
                    color: isSelected ? tc.surface : tc.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  currency.format(acc.balance),
                  style: AppFonts.sans(
                    color: isSelected
                        ? tc.surface.withOpacity(0.8)
                        : tc.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
              Icon(acc.type.icon,
                  size: 12,
                  color: isSelected ? tc.surface : acc.type.color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppFonts.sans(
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
            Icon(Icons.calendar_month_outlined,
                color: tc.onSurfaceVariant, size: 18),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(_date),
              style: AppFonts.sans(color: tc.onSurface, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
